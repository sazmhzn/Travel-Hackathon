import { Worker, Queue } from 'bullmq';
import { DestinationOrchestrator } from '../destination.orchestrator.js';
import { DestinationRepository } from '../destination.repository.js';
import { logger } from '../../../utils/logger.js';
import { env } from '../../../config/env.js';

const QUEUE_NAME = 'destination-generation';

const connection = {
  host: env.REDIS_HOST,
  port: env.REDIS_PORT,
  password: env.REDIS_PASSWORD || undefined,
};

export const destinationQueue = new Queue(QUEUE_NAME, { connection });

let worker: Worker | null = null;

export function startDestinationWorker(): Worker {
  if (worker) {
    logger.warn('Destination worker already running');
    return worker;
  }

  worker = new Worker(
    QUEUE_NAME,
    async (job) => {
      const { userId, jobId, destination, startDate, endDate, preferences } = job.data;
      const log = logger.child({ jobId, userId, destination });

      log.info('Processing destination generation job');

      // Update status to PROCESSING
      await DestinationRepository.updateGenerationJob(jobId, {
        status: 'PROCESSING',
        startedAt: new Date().toISOString(),
      });

      try {
        const result = await DestinationOrchestrator.generate({
          userId,
          destination,
          startDate,
          endDate,
          preferences,
        });

        // Update status to COMPLETED
        await DestinationRepository.updateGenerationJob(jobId, {
          status: 'COMPLETED',
          completedAt: new Date().toISOString(),
          destinationId: result.destinationId,
        });

        // Emit WebSocket notification
        try {
          const { broadcastToUser } = await import('../../../sockets/gateway.js');
          broadcastToUser(userId, 'generation:completed', {
            jobId,
            generationId: result.generationId,
            destination: result.destinationId,
            warnings: result.warnings,
          });
        } catch {
          // Gateway may not be available in worker-only processes
        }

        log.info({ generationId: result.generationId }, 'Job completed successfully');
        return result;
      } catch (err: any) {
        // Update status to FAILED
        const errorMessage = err?.message ?? String(err);
        await DestinationRepository.updateGenerationJob(jobId, {
          status: 'FAILED',
          error: errorMessage,
          completedAt: new Date().toISOString(),
        });

        // Emit failure notification
        try {
          const { broadcastToUser } = await import('../../../sockets/gateway.js');
          broadcastToUser(userId, 'generation:failed', {
            jobId,
            error: errorMessage,
          });
        } catch {
          // Gateway may not be available
        }

        log.error({ err }, 'Job failed');
        throw err;
      }
    },
    {
      connection,
      concurrency: 2,
      limiter: {
        max: 10,
        duration: 60_000,
      },
    },
  );

  worker.on('failed', (job, err) => {
    logger.error({ jobId: job?.id, err }, 'Worker job failed');
  });

  worker.on('completed', (job) => {
    logger.info({ jobId: job.id }, 'Worker job completed');
  });

  worker.on('error', (err) => {
    logger.error({ err }, 'Worker error');
  });

  logger.info('Destination generation worker started');
  return worker;
}

export async function stopDestinationWorker(): Promise<void> {
  if (worker) {
    await worker.close();
    worker = null;
    logger.info('Destination generation worker stopped');
  }
}

export async function addDestinationGenerationJob(input: {
  userId: string;
  jobId: string;
  destination: string;
  startDate: string;
  endDate: string;
  preferences: any;
}): Promise<void> {
  await destinationQueue.add('generate', input, {
    jobId: input.jobId,
    removeOnComplete: { age: 86400 },
    removeOnFail: { age: 604800 },
    attempts: 2,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
  });

  logger.info({ jobId: input.jobId, destination: input.destination }, 'Added destination generation job to queue');
}
