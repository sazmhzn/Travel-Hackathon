import * as turf from '@turf/turf';
import { query } from '../../config/database.js';
import { logger } from '../../utils/logger.js';

export interface GeoJsonLineString {
  type: 'LineString';
  coordinates: number[][]; // [[lng, lat], [lng, lat], ...]
}

export interface RecordRouteInput {
  guideId: string;
  title: string;
  activityType: string;
  visibility?: 'public' | 'private' | 'group';
  groupId?: string;
  geoJson: GeoJsonLineString;
}

export interface RouteRecord {
  id: string;
  guide_id: string;
  group_id?: string | null;
  title: string;
  activity_type: string;
  visibility: 'public' | 'private' | 'group';
  total_distance_meters: number;
  bounding_box: {
    type: 'Polygon';
    coordinates: number[][][];
  };
  path: GeoJsonLineString;
  created_at: string;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// In-memory fallback map for offline/disconnected test environments
export const inMemoryRoutes = new Map<string, RouteRecord>();

export class RoutesService {
  /**
   * Validates that payload contains a valid GeoJSON LineString
   */
  static validateGeoJson(geojson: any): GeoJsonLineString {
    if (!geojson || typeof geojson !== 'object') {
      throw new Error('Missing or invalid GeoJSON payload');
    }

    if (geojson.type !== 'LineString') {
      throw new Error('GeoJSON type must be "LineString"');
    }

    if (!Array.isArray(geojson.coordinates) || geojson.coordinates.length < 2) {
      throw new Error('LineString must contain at least 2 coordinate pairs: [[lng, lat], [lng, lat], ...]');
    }

    for (const [idx, point] of geojson.coordinates.entries()) {
      if (!Array.isArray(point) || point.length < 2) {
        throw new Error(`Coordinate at index ${idx} must be an array of at least 2 numbers [lng, lat]`);
      }
      const [lng, lat] = point;
      if (typeof lng !== 'number' || typeof lat !== 'number' || isNaN(lng) || isNaN(lat)) {
        throw new Error(`Invalid coordinate values at index ${idx}: expected numbers for [lng, lat]`);
      }
      if (lng < -180 || lng > 180) {
        throw new Error(`Longitude out of range [-180, 180] at index ${idx}: ${lng}`);
      }
      if (lat < -90 || lat > 90) {
        throw new Error(`Latitude out of range [-90, 90] at index ${idx}: ${lat}`);
      }
    }

    return geojson as GeoJsonLineString;
  }

  /**
   * Ingest and record an offline-synced guide spatial path
   */
  static async recordRoute(input: RecordRouteInput): Promise<RouteRecord> {
    const validGeoJson = this.validateGeoJson(input.geoJson);
    const visibility = input.visibility || 'public';
    const geoJsonString = JSON.stringify(validGeoJson);
    // Fallback stores may hand out non-UUID group ids; only persist real UUIDs.
    const dbGroupId =
      input.groupId && UUID_RE.test(input.groupId) ? input.groupId : null;

    try {
      // Spatial SQL pipeline:
      // 1. Convert incoming GeoJSON into PostGIS geometry (SRID 4326)
      // 2. ST_Simplify using Douglas-Peucker (tolerance: 0.0001)
      // 3. ST_Envelope to calculate rectangular map download boundary
      // 4. ST_Length(path::geography) to calculate geodesic distance in meters
      const res = await query(
        `WITH raw_input AS (
          SELECT ST_Force2D(ST_SetSRID(ST_GeomFromGeoJSON($4), 4326)) AS raw_geom
        ),
        processed AS (
          SELECT 
            CASE 
              WHEN ST_NPoints(ST_Simplify(raw_geom, 0.0001)) >= 2 
              THEN ST_Simplify(raw_geom, 0.0001) 
              ELSE raw_geom 
            END AS simplified_path
          FROM raw_input
        )
        INSERT INTO routes (
          guide_id,
          title,
          activity_type,
          visibility,
          group_id,
          path,
          bounding_box,
          total_distance_meters
        )
        SELECT
          $1, $2, $3, $5, $6,
          simplified_path,
          ST_SetSRID(ST_Envelope(simplified_path), 4326),
          ROUND(ST_Length(simplified_path::geography)::numeric, 2)
        FROM processed
        RETURNING
          id,
          guide_id,
          group_id,
          title,
          activity_type,
          visibility,
          total_distance_meters,
          ST_AsGeoJSON(bounding_box)::json AS bounding_box,
          ST_AsGeoJSON(path)::json AS path,
          created_at;`,
        [
          input.guideId,
          input.title,
          input.activityType,
          geoJsonString,
          visibility,
          dbGroupId,
        ]
      );

      const row = res.rows[0];
      const record: RouteRecord = {
        id: row.id,
        guide_id: row.guide_id,
        group_id: row.group_id,
        title: row.title,
        activity_type: row.activity_type,
        visibility: row.visibility,
        total_distance_meters: parseFloat(row.total_distance_meters) || 0,
        bounding_box: row.bounding_box,
        path: row.path,
        created_at: row.created_at,
      };

      inMemoryRoutes.set(record.id, record);
      return record;
    } catch (err: any) {
      // In-memory fallback if database connection is unavailable
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect') || !err.code) {
        logger.warn({ err: err.message }, 'PostgreSQL not available. Using Turf.js in-memory spatial processing');
        return this.recordRouteFallback(input, validGeoJson);
      }
      logger.error({ err }, 'Failed to record spatial route in database');
      throw err;
    }
  }

  /**
   * Resilient in-memory fallback processor using Turf.js
   */
  private static recordRouteFallback(input: RecordRouteInput, validGeoJson: GeoJsonLineString): RouteRecord {
    const rawLine = turf.lineString(validGeoJson.coordinates.map((c) => [c[0], c[1]]));
    const simplifiedLine = turf.simplify(rawLine, { tolerance: 0.0001, highQuality: true });
    const distanceKm = turf.length(simplifiedLine, { units: 'kilometers' });
    const bbox = turf.bbox(simplifiedLine); // [minLng, minLat, maxLng, maxLat]

    const boundingBoxPolygon: RouteRecord['bounding_box'] = {
      type: 'Polygon',
      coordinates: [[
        [bbox[0], bbox[1]],
        [bbox[2], bbox[1]],
        [bbox[2], bbox[3]],
        [bbox[0], bbox[3]],
        [bbox[0], bbox[1]],
      ]],
    };

    const record: RouteRecord = {
      id: `route-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`,
      guide_id: input.guideId,
      group_id: input.groupId || null,
      title: input.title,
      activity_type: input.activityType,
      visibility: input.visibility || 'public',
      total_distance_meters: Math.round(distanceKm * 1000 * 100) / 100,
      bounding_box: boundingBoxPolygon,
      path: {
        type: 'LineString',
        coordinates: simplifiedLine.geometry.coordinates,
      },
      created_at: new Date().toISOString(),
    };

    inMemoryRoutes.set(record.id, record);
    return record;
  }

  /**
   * Fetch route record by ID
   */
  static async getRouteById(id: string): Promise<RouteRecord | null> {
    try {
      const res = await query(
        `SELECT 
          id,
          guide_id,
          group_id,
          title,
          activity_type,
          visibility,
          total_distance_meters,
          ST_AsGeoJSON(bounding_box)::json AS bounding_box,
          ST_AsGeoJSON(path)::json AS path,
          created_at
        FROM routes 
        WHERE id = $1`,
        [id]
      );

      if (res.rows.length === 0) {
        return inMemoryRoutes.get(id) || null;
      }

      const row = res.rows[0];
      return {
        id: row.id,
        guide_id: row.guide_id,
        group_id: row.group_id,
        title: row.title,
        activity_type: row.activity_type,
        visibility: row.visibility,
        total_distance_meters: parseFloat(row.total_distance_meters) || 0,
        bounding_box: row.bounding_box,
        path: row.path,
        created_at: row.created_at,
      };
    } catch {
      return inMemoryRoutes.get(id) || null;
    }
  }

  /**
   * Lists every route a guide recorded within a specific expedition.
   */
  static async getRoutesByGroup(groupId: string): Promise<RouteRecord[]> {
    try {
      const res = await query(
        `SELECT
          id,
          guide_id,
          group_id,
          title,
          activity_type,
          visibility,
          total_distance_meters,
          ST_AsGeoJSON(bounding_box)::json AS bounding_box,
          ST_AsGeoJSON(path)::json AS path,
          created_at
        FROM routes
        WHERE group_id = $1
        ORDER BY created_at DESC`,
        [groupId]
      );

      return res.rows.map((row) => ({
        id: row.id,
        guide_id: row.guide_id,
        group_id: row.group_id,
        title: row.title,
        activity_type: row.activity_type,
        visibility: row.visibility,
        total_distance_meters: parseFloat(row.total_distance_meters) || 0,
        bounding_box: row.bounding_box,
        path: row.path,
        created_at: row.created_at,
      }));
    } catch {
      return [...inMemoryRoutes.values()]
        .filter((r) => r.group_id === groupId)
        .sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
    }
  }
}
