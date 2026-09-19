import { query } from '../../config/database.js';
import {
  parseGeoJsonLineString,
  parseGpx,
  coordinatesToLineStringWkt,
  bboxToPolygonWkt,
  RouteMetadata,
} from '../../utils/geojson.js';
import { broadcastToGroup } from '../../sockets/gateway.js';

export interface TravelPlan {
  id: string;
  group_id: string;
  title: string;
  description?: string;
  route_geojson?: any;
  bounding_box_geojson?: any;
  total_distance_meters: number;
  elevation_gain: number;
  start_time?: string;
  end_time?: string;
  created_at?: string;
}

// In-memory fallback
export const inMemoryPlans = new Map<string, TravelPlan>();

export class PlansService {
  static async createPlan(data: {
    groupId: string;
    title: string;
    description?: string;
    geoJsonPayload?: any;
    gpxPayload?: string;
    startTime?: string;
    endTime?: string;
  }): Promise<TravelPlan> {
    let routeMeta: RouteMetadata;

    if (data.gpxPayload) {
      routeMeta = parseGpx(data.gpxPayload);
    } else if (data.geoJsonPayload) {
      routeMeta = parseGeoJsonLineString(data.geoJsonPayload);
    } else {
      throw new Error('Either geoJsonPayload or gpxPayload must be provided');
    }

    const lineWkt = coordinatesToLineStringWkt(routeMeta.geometry.coordinates);
    const bboxWkt = bboxToPolygonWkt(routeMeta.bbox);

    try {
      const res = await query(
        `INSERT INTO travel_plans (
          group_id, title, description,
          route, bounding_box,
          total_distance_meters, elevation_gain,
          start_time, end_time
        )
        VALUES (
          $1, $2, $3,
          ST_SetSRID(ST_GeomFromText($4), 4326),
          ST_SetSRID(ST_GeomFromText($5), 4326),
          $6, $7, $8, $9
        )
        RETURNING
          id, group_id, title, description,
          ST_AsGeoJSON(route) as route_geojson,
          ST_AsGeoJSON(bounding_box) as bounding_box_geojson,
          total_distance_meters, elevation_gain,
          start_time, end_time, created_at`,
        [
          data.groupId,
          data.title,
          data.description || null,
          lineWkt,
          bboxWkt,
          routeMeta.totalDistanceMeters,
          routeMeta.elevationGainMeters,
          data.startTime || null,
          data.endTime || null,
        ]
      );

      const row = res.rows[0];
      const plan: TravelPlan = {
        ...row,
        route_geojson: JSON.parse(row.route_geojson),
        bounding_box_geojson: row.bounding_box_geojson ? JSON.parse(row.bounding_box_geojson) : null,
      };

      // Sequence 1: Broadcast PlanUpdate to Room [GroupID] via WebSocket
      broadcastToGroup(data.groupId, 'PlanUpdate', {
        planId: plan.id,
        groupId: plan.group_id,
        title: plan.title,
        route: plan.route_geojson,
        totalDistanceMeters: plan.total_distance_meters,
      });

      return plan;
    } catch (err: any) {
      if (err.code === 'ECONNREFUSED' || err.message?.includes('connect')) {
        const plan: TravelPlan = {
          id: `plan-${Date.now()}`,
          group_id: data.groupId,
          title: data.title,
          description: data.description,
          route_geojson: routeMeta.geometry,
          bounding_box_geojson: {
            type: 'Polygon',
            coordinates: [[
              [routeMeta.bbox[0], routeMeta.bbox[1]],
              [routeMeta.bbox[2], routeMeta.bbox[1]],
              [routeMeta.bbox[2], routeMeta.bbox[3]],
              [routeMeta.bbox[0], routeMeta.bbox[3]],
              [routeMeta.bbox[0], routeMeta.bbox[1]],
            ]],
          },
          total_distance_meters: routeMeta.totalDistanceMeters,
          elevation_gain: routeMeta.elevationGainMeters,
          start_time: data.startTime,
          end_time: data.endTime,
          created_at: new Date().toISOString(),
        };
        inMemoryPlans.set(plan.id, plan);

        broadcastToGroup(data.groupId, 'PlanUpdate', {
          planId: plan.id,
          groupId: plan.group_id,
          title: plan.title,
          route: plan.route_geojson,
          totalDistanceMeters: plan.total_distance_meters,
        });

        return plan;
      }
      throw err;
    }
  }

  static async getPlanById(planId: string): Promise<TravelPlan | null> {
    try {
      const res = await query(
        `SELECT
          id, group_id, title, description,
          ST_AsGeoJSON(route) as route_geojson,
          ST_AsGeoJSON(bounding_box) as bounding_box_geojson,
          total_distance_meters, elevation_gain,
          start_time, end_time, created_at
         FROM travel_plans
         WHERE id = $1`,
        [planId]
      );

      if (res.rowCount === 0) return null;
      const row = res.rows[0];
      return {
        ...row,
        route_geojson: JSON.parse(row.route_geojson),
        bounding_box_geojson: row.bounding_box_geojson ? JSON.parse(row.bounding_box_geojson) : null,
      };
    } catch (err: any) {
      return inMemoryPlans.get(planId) || null;
    }
  }

  static async getPlansByGroup(groupId: string): Promise<TravelPlan[]> {
    try {
      const res = await query(
        `SELECT
          id, group_id, title, description,
          ST_AsGeoJSON(route) as route_geojson,
          ST_AsGeoJSON(bounding_box) as bounding_box_geojson,
          total_distance_meters, elevation_gain,
          start_time, end_time, created_at
         FROM travel_plans
         WHERE group_id = $1
         ORDER BY created_at DESC`,
        [groupId]
      );

      return res.rows.map((row) => ({
        ...row,
        route_geojson: JSON.parse(row.route_geojson),
        bounding_box_geojson: row.bounding_box_geojson ? JSON.parse(row.bounding_box_geojson) : null,
      }));
    } catch (err: any) {
      return Array.from(inMemoryPlans.values()).filter((p) => p.group_id === groupId);
    }
  }

  /**
   * Task BE-2.3: Map Data Endpoint
   * Serves bounding-box metadata and suggested local activities using ST_MakeEnvelope
   */
  static async getMapDataInBoundingBox(bbox: {
    minLng: number;
    minLat: number;
    maxLng: number;
    maxLat: number;
  }): Promise<{ routes: any[]; activities: any[] }> {
    try {
      // Find all travel routes intersecting the bounding envelope
      const routesRes = await query(
        `SELECT
          id, group_id, title, description,
          ST_AsGeoJSON(route) as route_geojson,
          total_distance_meters, elevation_gain
         FROM travel_plans
         WHERE ST_Intersects(route, ST_MakeEnvelope($1, $2, $3, $4, 4326))`,
        [bbox.minLng, bbox.minLat, bbox.maxLng, bbox.maxLat]
      );

      // Find all public activities within the bounding envelope
      const activitiesRes = await query(
        `SELECT
          id, user_id, title, description,
          ST_AsGeoJSON(location) as location_geojson,
          media_urls, created_at
         FROM activities
         WHERE visibility = 'PUBLIC'
           AND ST_Intersects(location, ST_MakeEnvelope($1, $2, $3, $4, 4326))`,
        [bbox.minLng, bbox.minLat, bbox.maxLng, bbox.maxLat]
      );

      return {
        routes: routesRes.rows.map((r) => ({
          ...r,
          route_geojson: JSON.parse(r.route_geojson),
        })),
        activities: activitiesRes.rows.map((a) => ({
          ...a,
          location_geojson: JSON.parse(a.location_geojson),
        })),
      };
    } catch (err: any) {
      // In-memory fallback
      const routes = Array.from(inMemoryPlans.values()).filter((p) => {
        const coords = p.route_geojson.coordinates;
        return coords.some(
          ([lng, lat]: [number, number]) =>
            lng >= bbox.minLng && lng <= bbox.maxLng && lat >= bbox.minLat && lat <= bbox.maxLat
        );
      });
      return { routes, activities: [] };
    }
  }
}
