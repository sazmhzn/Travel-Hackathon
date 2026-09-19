import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';

describe('Spatial Path Ingestion (Routes API)', () => {
  let app: FastifyInstance;
  let guideToken: string;
  let memberToken: string;
  let createdRouteId: string;

  const validHimalayanTrack = {
    type: 'LineString',
    coordinates: [
      [86.7125, 27.8010], // Dingboche
      [86.7230, 27.8105],
      [86.7350, 27.8220],
      [86.7460, 27.8340], // Dughla
      [86.7640, 27.8480], // Lobuche
    ],
  };

  beforeAll(async () => {
    app = await buildApp();
    await app.ready();

    // Register Guide user
    const guideRes = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: `track-guide-${Date.now()}@example.com`,
        password: 'Password123!',
        name: 'Himalayan Sherpa Guide',
        role: 'GUIDE',
      },
    });
    expect(guideRes.statusCode).toBe(201);
    guideToken = JSON.parse(guideRes.body).token;

    // Register Member user
    const memberRes = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: `track-member-${Date.now()}@example.com`,
        password: 'Password123!',
        name: 'Regular Hiker Member',
        role: 'MEMBER',
      },
    });
    expect(memberRes.statusCode).toBe(201);
    memberToken = JSON.parse(memberRes.body).token;
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/routes/record - should record spatial path, simplify, calculate distance and bounding box for Guide', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/routes/record',
      headers: {
        authorization: `Bearer ${guideToken}`,
      },
      payload: {
        title: 'Dingboche to Lobuche High Pass',
        activity_type: 'trekking',
        visibility: 'public',
        geoJson: validHimalayanTrack,
      },
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.body);
    expect(body.message).toBe('Spatial path recorded successfully');
    expect(body.route).toBeDefined();
    expect(body.route.id).toBeDefined();
    expect(body.route.title).toBe('Dingboche to Lobuche High Pass');
    expect(body.route.activity_type).toBe('trekking');
    expect(body.route.visibility).toBe('public');

    // Task 3.3 Distance Verification (Geodesic meters)
    expect(body.route.total_distance_meters).toBeGreaterThan(1000);

    // Task 3.4 Bounding Box Verification
    expect(body.route.bounding_box).toBeDefined();
    expect(body.route.bounding_box.type).toBe('Polygon');
    expect(body.route.bounding_box.coordinates[0].length).toBeGreaterThanOrEqual(4);

    // Task 3.1 & 3.2 Path Verification
    expect(body.route.path).toBeDefined();
    expect(body.route.path.type).toBe('LineString');
    expect(body.route.path.coordinates.length).toBeGreaterThanOrEqual(2);

    createdRouteId = body.route.id;
  });

  it('GET /api/routes/:id - should retrieve the saved route details and geometries', async () => {
    const res = await app.inject({
      method: 'GET',
      url: `/api/routes/${createdRouteId}`,
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.route).toBeDefined();
    expect(body.route.id).toBe(createdRouteId);
    expect(body.route.title).toBe('Dingboche to Lobuche High Pass');
    expect(body.route.total_distance_meters).toBeGreaterThan(0);
    expect(body.route.bounding_box.type).toBe('Polygon');
  });

  it('POST /api/routes/record - should reject Member role with 403 Forbidden', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/routes/record',
      headers: {
        authorization: `Bearer ${memberToken}`,
      },
      payload: {
        title: 'Unauthorized Member Track',
        activity_type: 'trekking',
        geoJson: validHimalayanTrack,
      },
    });

    expect(res.statusCode).toBe(403);
    const body = JSON.parse(res.body);
    expect(body.error).toBe('Forbidden');
  });

  it('POST /api/routes/record - should reject unauthenticated request with 401 Unauthorized', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/routes/record',
      payload: {
        title: 'Unauthenticated Track',
        activity_type: 'trekking',
        geoJson: validHimalayanTrack,
      },
    });

    expect(res.statusCode).toBe(401);
  });

  it('POST /api/routes/record - should reject non-LineString GeoJSON with 400 Bad Request', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/routes/record',
      headers: {
        authorization: `Bearer ${guideToken}`,
      },
      payload: {
        title: 'Invalid Point Geometry',
        activity_type: 'trekking',
        geoJson: {
          type: 'Point',
          coordinates: [86.7125, 27.8010],
        },
      },
    });

    expect(res.statusCode).toBe(400);
  });

  it('POST /api/routes/record - should reject LineString with fewer than 2 coordinate points', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/routes/record',
      headers: {
        authorization: `Bearer ${guideToken}`,
      },
      payload: {
        title: 'Single Point Line',
        activity_type: 'trekking',
        geoJson: {
          type: 'LineString',
          coordinates: [[86.7125, 27.8010]],
        },
      },
    });

    expect(res.statusCode).toBe(400);
  });

  it('POST /api/routes/record - should reject out-of-range coordinates', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/routes/record',
      headers: {
        authorization: `Bearer ${guideToken}`,
      },
      payload: {
        title: 'Out of range track',
        activity_type: 'trekking',
        geoJson: {
          type: 'LineString',
          coordinates: [
            [250.0, 27.8010], // Longitude > 180 invalid
            [86.7230, 27.8105],
          ],
        },
      },
    });

    expect(res.statusCode).toBe(400);
  });

  it('POST /api/routes/record - should accept 3D coordinates with altitude and convert safely using ST_Force2D', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/routes/record',
      headers: {
        authorization: `Bearer ${guideToken}`,
      },
      payload: {
        title: '3D High Altitude Route',
        activity_type: 'climbing',
        visibility: 'public',
        geoJson: {
          type: 'LineString',
          coordinates: [
            [86.7125, 27.8010, 4200.5], // [lng, lat, alt]
            [86.7230, 27.8105, 4350.0],
            [86.7350, 27.8220, 4500.2],
          ],
        },
      },
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.body);
    expect(body.route).toBeDefined();
    expect(body.route.id).toBeDefined();
    expect(body.route.total_distance_meters).toBeGreaterThan(0);
    expect(body.route.bounding_box.type).toBe('Polygon');
    expect(body.route.path.type).toBe('LineString');
  });
});

