import { query } from '../../config/database.js';
import * as turf from '@turf/turf';

export interface ActivityItem {
  id: string;
  userId: string;
  groupId?: string;
  title: string;
  description?: string;
  visibility: 'PUBLIC' | 'GROUP_ONLY';
  location: { type: 'Point'; coordinates: [number, number] };
  mediaUrls: string[];
  distanceMeters?: number;
  createdAt: string;
}

// In-memory activities store for fallback
export const inMemoryActivities: ActivityItem[] = [];

export class FeedService {
  /**
   * Create an activity with spatial Point (4326) and MinIO media URLs
   */
  static async createActivity(data: {
    userId: string;
    groupId?: string;
    title: string;
    description?: string;
    visibility?: 'PUBLIC' | 'GROUP_ONLY';
    lat: number;
    lng: number;
    mediaUrls?: string[];
  }): Promise<ActivityItem> {
    const visibility = data.visibility || 'PUBLIC';
    const mediaUrls = data.mediaUrls || [];

    try {
      const res = await query(
        `INSERT INTO activities (
          user_id, group_id, title, description, visibility,
          location, media_urls
        )
        VALUES (
          $1, $2, $3, $4, $5,
          ST_SetSRID(ST_MakePoint($6, $7), 4326), $8
        )
        RETURNING
          id, user_id, group_id, title, description, visibility,
          ST_AsGeoJSON(location) as location_geojson,
          media_urls, created_at`,
        [
          data.userId,
          data.groupId || null,
          data.title,
          data.description || null,
          visibility,
          data.lng,
          data.lat,
          mediaUrls,
        ]
      );

      const row = res.rows[0];
      return {
        id: row.id,
        userId: row.user_id,
        groupId: row.group_id,
        title: row.title,
        description: row.description,
        visibility: row.visibility,
        location: JSON.parse(row.location_geojson),
        mediaUrls: row.media_urls || [],
        createdAt: row.created_at,
      };
    } catch (err: any) {
      const item: ActivityItem = {
        id: `act-${Date.now()}`,
        userId: data.userId,
        groupId: data.groupId,
        title: data.title,
        description: data.description,
        visibility,
        location: { type: 'Point', coordinates: [data.lng, data.lat] },
        mediaUrls,
        createdAt: new Date().toISOString(),
      };
      inMemoryActivities.push(item);
      return item;
    }
  }

  /**
   * Task BE-4.5 & BE-4.6: Spatial Feed with ST_DWithin & Privacy Filter
   */
  static async getSpatialFeed(params: {
    lat: number;
    lng: number;
    radiusMeters: number;
    userGroupIds: string[];
  }): Promise<{ activities: ActivityItem[]; routes: any[] }> {
    try {
      // 1. Spatial query on activities with ST_DWithin and privacy filter
      const activitiesRes = await query(
        `SELECT
          a.id, a.user_id, a.group_id, a.title, a.description, a.visibility,
          ST_AsGeoJSON(a.location) as location_geojson,
          a.media_urls, a.created_at,
          ROUND(ST_Distance(a.location::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)) as distance_meters
         FROM activities a
         WHERE
           ST_DWithin(a.location::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
           AND (
             a.visibility = 'PUBLIC'
             OR (a.visibility = 'GROUP_ONLY' AND a.group_id = ANY($4::uuid[]))
           )
         ORDER BY distance_meters ASC
         LIMIT 50`,
        [params.lng, params.lat, params.radiusMeters, params.userGroupIds]
      );

      // 2. Spatial query on travel routes passing within radius
      const routesRes = await query(
        `SELECT
          tp.id, tp.group_id, tp.title, tp.description,
          ST_AsGeoJSON(tp.route) as route_geojson,
          tp.total_distance_meters, tp.elevation_gain,
          ROUND(ST_Distance(tp.route::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)) as distance_meters
         FROM travel_plans tp
         WHERE
           ST_DWithin(tp.route::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
           AND tp.group_id = ANY($4::uuid[])
         ORDER BY distance_meters ASC
         LIMIT 20`,
        [params.lng, params.lat, params.radiusMeters, params.userGroupIds]
      );

      const activities: ActivityItem[] = activitiesRes.rows.map((row) => ({
        id: row.id,
        userId: row.user_id,
        groupId: row.group_id,
        title: row.title,
        description: row.description,
        visibility: row.visibility,
        location: JSON.parse(row.location_geojson),
        mediaUrls: row.media_urls || [],
        distanceMeters: parseFloat(row.distance_meters),
        createdAt: row.created_at,
      }));

      const routes = routesRes.rows.map((row) => ({
        id: row.id,
        groupId: row.group_id,
        title: row.title,
        description: row.description,
        route: JSON.parse(row.route_geojson),
        totalDistanceMeters: row.total_distance_meters,
        elevationGain: row.elevation_gain,
        distanceMeters: parseFloat(row.distance_meters),
      }));

      return { activities, routes };
    } catch (err: any) {
      // In-memory fallback using Turf.js distance
      const centerPoint = turf.point([params.lng, params.lat]);
      const radiusKm = params.radiusMeters / 1000;

      const filtered = inMemoryActivities.filter((act) => {
        // Privacy check
        if (act.visibility === 'GROUP_ONLY' && (!act.groupId || !params.userGroupIds.includes(act.groupId))) {
          return false;
        }

        const pt = turf.point(act.location.coordinates);
        const distKm = turf.distance(centerPoint, pt, { units: 'kilometers' });
        act.distanceMeters = Math.round(distKm * 1000);
        return distKm <= radiusKm;
      });

      filtered.sort((a, b) => (a.distanceMeters || 0) - (b.distanceMeters || 0));
      return { activities: filtered, routes: [] };
    }
  }
}
