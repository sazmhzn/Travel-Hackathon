import { query } from '../../config/database.js';
import { logger } from '../../utils/logger.js';

export class DestinationRepository {
  static async findOrCreateDestination(
    name: string,
    latitude?: number,
    longitude?: number,
    country?: string,
    region?: string,
    description?: string,
    source?: any
  ): Promise<any> {
    try {
      const normalized = name.trim().toLowerCase();
      const existing = await query(
        'SELECT * FROM destinations WHERE normalized_name = $1 LIMIT 1',
        [normalized]
      );
      if (existing.rows.length > 0) return existing.rows[0];

      const result = await query(
        `INSERT INTO destinations (name, normalized_name, latitude, longitude, country, region, description, source)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [name, normalized, latitude ?? null, longitude ?? null, country ?? null, region ?? null, description ?? null, source ? JSON.stringify(source) : null]
      );
      return result.rows[0];
    } catch (err) {
      logger.error({ err, name }, 'findOrCreateDestination failed');
      throw err;
    }
  }

  static async getDestinationById(id: string): Promise<any> {
    try {
      const result = await query('SELECT * FROM destinations WHERE id = $1', [id]);
      return result.rows[0] ?? null;
    } catch (err) {
      logger.error({ err, id }, 'getDestinationById failed');
      throw err;
    }
  }

  static async savePlace(destinationId: string, place: any): Promise<any> {
    try {
      const result = await query(
        `INSERT INTO places (
           destination_id, provider, provider_place_id, name, category,
           latitude, longitude, rating, rating_count, price_level,
           opening_hours, website_url, phone, popularity_signal, photos, source
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
         ON CONFLICT (provider, provider_place_id)
         DO UPDATE SET
           name = EXCLUDED.name,
           category = EXCLUDED.category,
           latitude = EXCLUDED.latitude,
           longitude = EXCLUDED.longitude,
           rating = EXCLUDED.rating,
           rating_count = EXCLUDED.rating_count,
           price_level = EXCLUDED.price_level,
           opening_hours = EXCLUDED.opening_hours,
           website_url = EXCLUDED.website_url,
           phone = EXCLUDED.phone,
           popularity_signal = EXCLUDED.popularity_signal,
           photos = EXCLUDED.photos,
           source = EXCLUDED.source,
           updated_at = NOW()
         RETURNING *`,
        [
          destinationId,
          place.source?.provider ?? place.provider,
          place.id ?? place.providerPlaceId,
          place.name,
          place.category,
          place.location?.latitude ?? place.latitude,
          place.location?.longitude ?? place.longitude,
          place.rating ?? null,
          place.ratingCount ?? place.rating_count ?? null,
          place.priceLevel ?? place.price_level ?? null,
          place.openingHours ? JSON.stringify(place.openingHours) : null,
          place.websiteUrl ?? place.website_url ?? null,
          place.phone ?? null,
          place.popularitySignal ?? place.popularity_signal ?? null,
          place.photos ? JSON.stringify(place.photos) : null,
          place.source ? JSON.stringify(place.source) : null,
        ]
      );
      return result.rows[0];
    } catch (err) {
      logger.error({ err, destinationId, place }, 'savePlace failed');
      throw err;
    }
  }

  static async getPlacesByDestination(destinationId: string, category?: string): Promise<any[]> {
    try {
      if (category) {
        const result = await query(
          'SELECT * FROM places WHERE destination_id = $1 AND category = $2 ORDER BY rating DESC NULLS LAST',
          [destinationId, category]
        );
        return result.rows;
      }
      const result = await query(
        'SELECT * FROM places WHERE destination_id = $1 ORDER BY rating DESC NULLS LAST',
        [destinationId]
      );
      return result.rows;
    } catch (err) {
      logger.error({ err, destinationId }, 'getPlacesByDestination failed');
      throw err;
    }
  }

  static async findPlaceByProvider(provider: string, providerPlaceId: string): Promise<any> {
    try {
      const result = await query(
        'SELECT * FROM places WHERE provider = $1 AND provider_place_id = $2',
        [provider, providerPlaceId]
      );
      return result.rows[0] ?? null;
    } catch (err) {
      logger.error({ err, provider, providerPlaceId }, 'findPlaceByProvider failed');
      throw err;
    }
  }

  static async saveDataSnapshot(
    destinationId: string,
    dataType: string,
    provider: string,
    requestParams: any,
    responseData: any,
    expiresAt?: string
  ): Promise<any> {
    try {
      const result = await query(
        `INSERT INTO data_snapshots (destination_id, data_type, provider, request_params, response_data, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [
          destinationId,
          dataType,
          provider,
          JSON.stringify(requestParams),
          JSON.stringify(responseData),
          expiresAt ?? null,
        ]
      );
      return result.rows[0];
    } catch (err) {
      logger.error({ err, destinationId, dataType }, 'saveDataSnapshot failed');
      throw err;
    }
  }

  static async getDataSnapshots(destinationId: string, dataType: string, limit: number = 10): Promise<any[]> {
    try {
      const result = await query(
        `SELECT * FROM data_snapshots
         WHERE destination_id = $1 AND data_type = $2
         ORDER BY created_at DESC
         LIMIT $3`,
        [destinationId, dataType, limit]
      );
      return result.rows;
    } catch (err) {
      logger.error({ err, destinationId, dataType }, 'getDataSnapshots failed');
      throw err;
    }
  }

  static async saveGenerationJob(userId: string, destinationId: string | null, requestHash: string): Promise<any> {
    try {
      const result = await query(
        `INSERT INTO generation_jobs (user_id, destination_id, request_hash, status)
         VALUES ($1, $2, $3, 'QUEUED')
         RETURNING *`,
        [userId, destinationId, requestHash]
      );
      return result.rows[0];
    } catch (err) {
      logger.error({ err, userId, requestHash }, 'saveGenerationJob failed');
      throw err;
    }
  }

  static async updateGenerationJob(
    id: string,
    updates: { status?: string; startedAt?: string; completedAt?: string; error?: string; destinationId?: string }
  ): Promise<void> {
    try {
      const sets: string[] = [];
      const params: any[] = [];
      let idx = 1;

      if (updates.status !== undefined) {
        sets.push(`status = $${idx++}`);
        params.push(updates.status);
      }
      if (updates.startedAt !== undefined) {
        sets.push(`started_at = $${idx++}`);
        params.push(updates.startedAt);
      }
      if (updates.completedAt !== undefined) {
        sets.push(`completed_at = $${idx++}`);
        params.push(updates.completedAt);
      }
      if (updates.error !== undefined) {
        sets.push(`error = $${idx++}`);
        params.push(updates.error);
      }
      if (updates.destinationId !== undefined) {
        sets.push(`destination_id = $${idx++}`);
        params.push(updates.destinationId);
      }

      if (sets.length === 0) return;

      sets.push(`updated_at = NOW()`);
      params.push(id);

      await query(
        `UPDATE generation_jobs SET ${sets.join(', ')} WHERE id = $${idx}`,
        params
      );
    } catch (err) {
      logger.error({ err, id }, 'updateGenerationJob failed');
      throw err;
    }
  }

  static async findGenerationJobByHash(requestHash: string): Promise<any> {
    try {
      const result = await query(
        'SELECT * FROM generation_jobs WHERE request_hash = $1 ORDER BY created_at DESC LIMIT 1',
        [requestHash]
      );
      return result.rows[0] ?? null;
    } catch (err) {
      logger.error({ err, requestHash }, 'findGenerationJobByHash failed');
      throw err;
    }
  }

  static async saveItineraryGeneration(
    userId: string,
    destinationId: string,
    requestHash: string,
    requestJson: any,
    model?: string,
    promptVersion?: string
  ): Promise<any> {
    try {
      const result = await query(
        `INSERT INTO itinerary_generations (user_id, destination_id, request_hash, request_json, model, prompt_version, status)
         VALUES ($1, $2, $3, $4, $5, $6, 'PENDING')
         RETURNING *`,
        [userId, destinationId, requestHash, JSON.stringify(requestJson), model ?? null, promptVersion ?? null]
      );
      return result.rows[0];
    } catch (err) {
      logger.error({ err, userId, requestHash }, 'saveItineraryGeneration failed');
      throw err;
    }
  }

  static async updateItineraryGeneration(
    id: string,
    updates: { status?: string; sourceSnapshotIds?: string[]; resultJson?: any; error?: string; completedAt?: string }
  ): Promise<void> {
    try {
      const sets: string[] = [];
      const params: any[] = [];
      let idx = 1;

      if (updates.status !== undefined) {
        sets.push(`status = $${idx++}`);
        params.push(updates.status);
      }
      if (updates.sourceSnapshotIds !== undefined) {
        sets.push(`source_snapshot_ids = $${idx++}`);
        params.push(updates.sourceSnapshotIds);
      }
      if (updates.resultJson !== undefined) {
        sets.push(`result_json = $${idx++}`);
        params.push(JSON.stringify(updates.resultJson));
      }
      if (updates.error !== undefined) {
        sets.push(`error = $${idx++}`);
        params.push(updates.error);
      }
      if (updates.completedAt !== undefined) {
        sets.push(`completed_at = $${idx++}`);
        params.push(updates.completedAt);
      }

      if (sets.length === 0) return;

      sets.push(`updated_at = NOW()`);
      params.push(id);

      await query(
        `UPDATE itinerary_generations SET ${sets.join(', ')} WHERE id = $${idx}`,
        params
      );
    } catch (err) {
      logger.error({ err, id }, 'updateItineraryGeneration failed');
      throw err;
    }
  }

  static async getItineraryGeneration(id: string): Promise<any> {
    try {
      const result = await query('SELECT * FROM itinerary_generations WHERE id = $1', [id]);
      return result.rows[0] ?? null;
    } catch (err) {
      logger.error({ err, id }, 'getItineraryGeneration failed');
      throw err;
    }
  }

  static async saveItineraryItems(generationId: string, items: any[]): Promise<void> {
    try {
      if (items.length === 0) return;

      const valueSets: string[] = [];
      const params: any[] = [];
      let idx = 1;

      for (const item of items) {
        valueSets.push(
          `($${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++})`
        );
        params.push(
          generationId,
          item.dayNumber,
          item.sequence,
          item.placeId ?? null,
          item.title,
          item.description ?? null,
          item.startTime,
          item.endTime,
          item.durationMinutes,
          item.transportMode ?? null,
          item.travelMinutes ?? null,
          item.reason
        );
      }

      await query(
        `INSERT INTO itinerary_items (generation_id, day_number, sequence, place_id, title, description, start_time, end_time, duration_minutes, transport_mode, travel_minutes, reason)
         VALUES ${valueSets.join(', ')}`,
        params
      );
    } catch (err) {
      logger.error({ err, generationId }, 'saveItineraryItems failed');
      throw err;
    }
  }

  static async getItineraryItems(generationId: string): Promise<any[]> {
    try {
      const result = await query(
        'SELECT * FROM itinerary_items WHERE generation_id = $1 ORDER BY day_number, sequence',
        [generationId]
      );
      return result.rows;
    } catch (err) {
      logger.error({ err, generationId }, 'getItineraryItems failed');
      throw err;
    }
  }

  static async getGenerationsByUser(userId: string, limit: number = 20): Promise<any[]> {
    try {
      const result = await query(
        `SELECT ig.*, d.name as destination_name
         FROM itinerary_generations ig
         LEFT JOIN destinations d ON d.id = ig.destination_id
         WHERE ig.user_id = $1
         ORDER BY ig.created_at DESC
         LIMIT $2`,
        [userId, limit]
      );
      return result.rows;
    } catch (err) {
      logger.error({ err, userId }, 'getGenerationsByUser failed');
      throw err;
    }
  }
}
