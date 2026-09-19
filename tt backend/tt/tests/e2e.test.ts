import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';

describe('Fastify End-to-End API Integration', () => {
  let app: FastifyInstance;
  let guideToken: string;
  let memberToken: string;
  let createdGroupId: string;
  let inviteCode: string;

  beforeAll(async () => {
    app = await buildApp();
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health should return 200 and healthy status', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health',
    });
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.status).toBe('healthy');
  });

  it('POST /api/auth/register should register a Guide and return JWT', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: `lead-guide-${Date.now()}@e2e.com`,
        password: 'Password123!',
        name: 'Lead Guide E2E',
        role: 'GUIDE',
      },
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.body);
    expect(body.token).toBeDefined();
    expect(body.user.role).toBe('GUIDE');
    guideToken = body.token;
  });

  it('POST /api/auth/register should register a Member', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/auth/register',
      payload: {
        email: `hiker-${Date.now()}@e2e.com`,
        password: 'Password123!',
        name: 'Hiker Member E2E',
        role: 'MEMBER',
      },
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.body);
    memberToken = body.token;
  });

  it('POST /api/groups should allow Guide to create group', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/groups',
      headers: { authorization: `Bearer ${guideToken}` },
      payload: {
        name: 'Manaslu Circuit Team',
        description: 'Challenging high pass trek',
      },
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.body);
    expect(body.group.id).toBeDefined();
    expect(body.group.invite_code).toBeDefined();
    createdGroupId = body.group.id;
    inviteCode = body.group.invite_code;
  });

  it('POST /api/groups/join should allow Member to join group via inviteCode', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/groups/join',
      headers: { authorization: `Bearer ${memberToken}` },
      payload: {
        inviteCode,
      },
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.group.id).toBe(createdGroupId);
  });

  it('POST /api/plans should allow Guide to create a plan with GeoJSON', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/plans',
      headers: { authorization: `Bearer ${guideToken}` },
      payload: {
        groupId: createdGroupId,
        title: 'Larkya La Pass Stage',
        geoJsonPayload: {
          type: 'LineString',
          coordinates: [
            [84.62, 28.65],
            [84.64, 28.66],
            [84.67, 28.68],
          ],
        },
      },
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.body);
    expect(body.plan.id).toBeDefined();
    expect(body.plan.total_distance_meters).toBeGreaterThan(0);
  });

  it('POST /api/telemetry/location should ingest live GPS telemetry', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/telemetry/location',
      headers: { authorization: `Bearer ${memberToken}` },
      payload: {
        groupId: createdGroupId,
        lat: 28.6601,
        lng: 84.6412,
        altitude: 4460,
        speed: 1.1,
        battery: 76,
      },
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.success).toBe(true);
  });

  it('GET /api/feed should return nearby public points', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/feed?lat=28.66&lng=84.64&radius=10000',
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.activities).toBeDefined();
  });
});
