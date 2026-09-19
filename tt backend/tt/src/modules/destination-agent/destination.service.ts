import { createHash } from 'crypto';
import { query } from '../../config/database.js';
import { DestinationRepository } from './destination.repository.js';
import { logger } from '../../utils/logger.js';

const REQUEST_VERSION = 1;

export class DestinationService {
  static async createGenerationJob(input: {
    userId: string;
    destination: string;
    startDate: string;
    endDate: string;
    preferences: any;
  }): Promise<{ jobId: string; requestHash: string }> {
    const requestHash = createHash('sha256')
      .update(JSON.stringify({ ...input, version: REQUEST_VERSION }))
      .digest('hex');

    try {
      const existing = await DestinationRepository.findGenerationJobByHash(requestHash);
      if (existing && existing.status !== 'FAILED') {
        return { jobId: existing.id, requestHash };
      }

      const dest = await DestinationRepository.findOrCreateDestination(input.destination);
      const job = await DestinationRepository.saveGenerationJob(
        input.userId,
        dest?.id ?? null,
        requestHash
      );

      try {
        const { destinationQueue } = await import('./workers/destination-queue.js');
        await destinationQueue.add('generate', {
          jobId: job.id,
          userId: input.userId,
          destinationId: dest?.id ?? null,
          destination: input.destination,
          startDate: input.startDate,
          endDate: input.endDate,
          preferences: input.preferences,
          requestHash,
        });
      } catch (queueErr: any) {
        logger.warn({ err: queueErr, jobId: job.id }, 'Failed to enqueue generation job (queue may not be initialized)');
      }

      return { jobId: job.id, requestHash };
    } catch (err: any) {
      logger.error({ err, userId: input.userId }, 'createGenerationJob failed');
      throw err;
    }
  }

  static async getGenerationStatus(jobId: string): Promise<{
    jobId: string;
    status: string;
    startedAt?: string;
    completedAt?: string;
    error?: string;
    destinationId?: string;
  }> {
    try {
      const result = await query(
        'SELECT id, status, started_at, completed_at, error, destination_id FROM destination_generation_jobs WHERE id = $1',
        [jobId]
      );
      const job = result.rows[0];
      if (!job) {
        throw new Error('Generation job not found');
      }
      return {
        jobId: job.id,
        status: job.status,
        startedAt: job.started_at?.toISOString(),
        completedAt: job.completed_at?.toISOString(),
        error: job.error,
        destinationId: job.destination_id,
      };
    } catch (err: any) {
      logger.error({ err, jobId }, 'getGenerationStatus failed');
      throw err;
    }
  }

  static async getItinerary(generationId: string): Promise<{
    generation: any;
    items: any[];
  } | null> {
    try {
      const generation = await DestinationRepository.getItineraryGeneration(generationId);
      if (!generation || generation.status !== 'COMPLETED') {
        return null;
      }
      const items = await DestinationRepository.getItineraryItems(generationId);
      return { generation, items };
    } catch (err: any) {
      logger.error({ err, generationId }, 'getItinerary failed');
      throw err;
    }
  }

  static async getUserGenerations(userId: string, limit: number = 20): Promise<any[]> {
    try {
      return await DestinationRepository.getGenerationsByUser(userId, limit);
    } catch (err: any) {
      logger.error({ err, userId }, 'getUserGenerations failed');
      throw err;
    }
  }

  static async searchDestinations(queryStr: string): Promise<any[]> {
    try {
      const result = await query(
        `SELECT id, name, latitude, longitude, country, region, description
         FROM destinations
         WHERE name ILIKE $1 OR normalized_name ILIKE $1
         ORDER BY name
         LIMIT 20`,
        [`%${queryStr}%`]
      );
      return result.rows;
    } catch (err: any) {
      logger.error({ err, queryStr }, 'searchDestinations failed');
      throw err;
    }
  }

  static async getDestinationById(id: string): Promise<any | null> {
    try {
      return await DestinationRepository.getDestinationById(id);
    } catch (err: any) {
      logger.error({ err, id }, 'getDestinationById failed');
      throw err;
    }
  }
}
