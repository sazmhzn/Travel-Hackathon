import { redisClient, inMemoryFallback, isRedisConnected } from '../../config/redis.js';
import { query } from '../../config/database.js';
import { logger } from '../../utils/logger.js';
import { broadcastToGroup } from '../../sockets/gateway.js';

export interface LocationPayload {
  userId: string;
  groupId: string;
  lat: number;
  lng: number;
  altitude?: number;
  speed?: number;
  battery?: number;
  recordedAt: Date;
  syncedBy?: string; // Good Samaritan user ID if relayed
}

// In-memory buffer for batch persisting telemetry to Postgres
const telemetryBuffer: LocationPayload[] = [];
const BATCH_FLUSH_INTERVAL_MS = 15000; // 15 seconds

export class TelemetryService {
  /**
   * Task BE-3.2: Ingest high-frequency live location into Redis (TTL 1hr)
   */
  static async ingestLiveLocation(payload: LocationPayload): Promise<void> {
    const redis = isRedisConnected ? redisClient : inMemoryFallback;
    const geoKey = `group:${payload.groupId}:locations`;
    const userKey = `user:${payload.userId}:telemetry`;

    try {
      // 1. Store in Redis GEO set for spatial radius queries across group
      await redis.geoadd(geoKey, payload.lng, payload.lat, payload.userId);
      await redis.expire(geoKey, 3600); // 1-hour TTL

      // 2. Store detailed telemetry hash
      await redis.hset(userKey, {
        lat: payload.lat.toString(),
        lng: payload.lng.toString(),
        altitude: (payload.altitude || 0).toString(),
        speed: (payload.speed || 0).toString(),
        battery: (payload.battery || 100).toString(),
        recordedAt: payload.recordedAt.toISOString(),
        groupId: payload.groupId,
      });
      await redis.expire(userKey, 3600); // 1-hour TTL

      // 3. Queue into persistence buffer
      telemetryBuffer.push(payload);
    } catch (err) {
      logger.error({ err, userId: payload.userId }, 'Failed to cache telemetry in Redis');
      telemetryBuffer.push(payload);
    }
  }

  /**
   * Get latest live locations for all members in a group from Redis
   */
  static async getGroupLiveLocations(groupId: string, memberUserIds: string[]): Promise<any[]> {
    const redis = isRedisConnected ? redisClient : inMemoryFallback;
    const geoKey = `group:${groupId}:locations`;

    if (memberUserIds.length === 0) return [];

    try {
      const positions = await redis.geopos(geoKey, ...memberUserIds);
      const results: any[] = [];

      for (let i = 0; i < memberUserIds.length; i++) {
        const userId = memberUserIds[i];
        const pos = positions[i];
        if (pos) {
          const telemetry = await redis.hgetall(`user:${userId}:telemetry`);
          results.push({
            userId,
            lng: parseFloat(pos[0]),
            lat: parseFloat(pos[1]),
            altitude: telemetry.altitude ? parseFloat(telemetry.altitude) : null,
            speed: telemetry.speed ? parseFloat(telemetry.speed) : null,
            battery: telemetry.battery ? parseInt(telemetry.battery, 10) : null,
            recordedAt: telemetry.recordedAt || null,
          });
        }
      }
      return results;
    } catch (err) {
      logger.error({ err, groupId }, 'Failed to read group live locations from Redis');
      return [];
    }
  }

  /**
   * Task BE-3.3: Third-Party Telemetry Sync (Good Samaritan relay)
   */
  static async syncMeshRelayLedger(
    goodSamaritanUserId: string,
    records: Array<{
      userId: string;
      groupId: string;
      lat: number;
      lng: number;
      altitude?: number;
      speed?: number;
      battery?: number;
      recordedAt: string;
    }>
  ): Promise<{ processed: number; recoveredUsers: string[] }> {
    const recoveredUsersSet = new Set<string>();
    const now = new Date();

    for (const record of records) {
      const recordedAt = new Date(record.recordedAt);

      // Validate timestamp: must not be in the future (with 5 min grace for clock drift)
      if (isNaN(recordedAt.getTime()) || recordedAt.getTime() > now.getTime() + 300000) {
        logger.warn({ record }, 'Skipping relay record with invalid future timestamp');
        continue;
      }

      const payload: LocationPayload = {
        userId: record.userId,
        groupId: record.groupId,
        lat: record.lat,
        lng: record.lng,
        altitude: record.altitude,
        speed: record.speed,
        battery: record.battery,
        recordedAt,
        syncedBy: goodSamaritanUserId,
      };

      // Ingest into live cache
      await this.ingestLiveLocation(payload);
      recoveredUsersSet.add(record.userId);

      // Immediately persist relayed locations to PostGIS for disaster audit trail
      try {
        await query(
          `INSERT INTO location_history (
            user_id, group_id, location, altitude, speed, battery_level, recorded_at, synced_by
          )
          VALUES (
            $1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326), $5, $6, $7, $8, $9
          )`,
          [
            payload.userId,
            payload.groupId,
            payload.lng,
            payload.lat,
            payload.altitude || null,
            payload.speed || null,
            payload.battery || null,
            payload.recordedAt,
            goodSamaritanUserId,
          ]
        );
      } catch (dbErr) {
        logger.debug({ dbErr }, 'DB write skipped in relay fallback');
      }

      // Notify Guide's room that a lost member's telemetry was recovered!
      broadcastToGroup(record.groupId, 'member:location_recovered', {
        userId: record.userId,
        lat: record.lat,
        lng: record.lng,
        altitude: record.altitude,
        battery: record.battery,
        recordedAt: payload.recordedAt.toISOString(),
        relayedBy: goodSamaritanUserId,
      });
    }

    return {
      processed: records.length,
      recoveredUsers: Array.from(recoveredUsersSet),
    };
  }

  /**
   * Flush telemetry buffer into PostgreSQL location_history table
   */
  static async flushTelemetryBuffer(): Promise<number> {
    if (telemetryBuffer.length === 0) return 0;

    const itemsToFlush = telemetryBuffer.splice(0, telemetryBuffer.length);
    let flushedCount = 0;

    try {
      for (const item of itemsToFlush) {
        await query(
          `INSERT INTO location_history (
            user_id, group_id, location, altitude, speed, battery_level, recorded_at, synced_by
          )
          VALUES (
            $1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326), $5, $6, $7, $8, $9
          )`,
          [
            item.userId,
            item.groupId,
            item.lng,
            item.lat,
            item.altitude || null,
            item.speed || null,
            item.battery || null,
            item.recordedAt,
            item.syncedBy || null,
          ]
        );
        flushedCount++;
      }
      logger.debug(`Flushed ${flushedCount} telemetry points to PostgreSQL.`);
    } catch (err) {
      logger.debug({ err }, 'Telemetry buffer flush skipped (database offline/test mode)');
    }

    return flushedCount;
  }
}

// Start periodic flush worker
setInterval(() => {
  TelemetryService.flushTelemetryBuffer().catch((err) => {
    logger.error({ err }, 'Error during telemetry buffer flush');
  });
}, BATCH_FLUSH_INTERVAL_MS).unref();
