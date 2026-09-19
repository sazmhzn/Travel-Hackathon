import { describe, it, expect, beforeAll } from 'vitest';
import { PlansService } from '../src/modules/plans/plans.service.js';
import { AuthService } from '../src/modules/auth/auth.service.js';
import { GroupsService } from '../src/modules/groups/groups.service.js';

describe('PlansService Integration', () => {
  let groupId: string;

  const sampleGeoJson = {
    type: 'LineString',
    coordinates: [
      [85.3240, 27.7172],
      [85.3300, 27.7200],
      [85.3450, 27.7350],
    ],
  };

  beforeAll(async () => {
    const guide = await AuthService.register({
      email: `plan-guide-${Date.now()}@test.com`,
      password: 'Password123!',
      name: 'Plan Guide',
      role: 'GUIDE',
    });

    const group = await GroupsService.createGroup({
      name: 'Shivapuri Hiking Team',
      createdBy: guide.id,
    });

    groupId = group.id;
  });

  it('should create travel plan and calculate distance and bounding box', async () => {
    const plan = await PlansService.createPlan({
      groupId,
      title: 'Shivapuri National Park Trail',
      description: 'Day hike to peak',
      geoJsonPayload: sampleGeoJson,
    });

    expect(plan).toBeDefined();
    expect(plan.id).toBeDefined();
    expect(plan.title).toBe('Shivapuri National Park Trail');
    expect(plan.total_distance_meters).toBeGreaterThan(0);
    expect(plan.route_geojson).toBeDefined();
    expect(plan.route_geojson.type).toBe('LineString');
    expect(plan.route_geojson.coordinates.length).toBe(3);

    // Retrieve by ID
    const fetched = await PlansService.getPlanById(plan.id);
    expect(fetched).toBeDefined();
    expect(fetched?.title).toBe(plan.title);
  });

  it('should find routes inside bounding box using map-data query', async () => {
    const data = await PlansService.getMapDataInBoundingBox({
      minLat: 27.7000,
      minLng: 85.3000,
      maxLat: 27.7500,
      maxLng: 85.3600,
    });

    expect(data).toBeDefined();
    expect(Array.isArray(data.routes)).toBe(true);
    expect(Array.isArray(data.activities)).toBe(true);
    // The previously created plan intersects this envelope
    expect(data.routes.length).toBeGreaterThanOrEqual(1);
  });
});
