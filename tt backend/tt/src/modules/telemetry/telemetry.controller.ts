import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { TelemetryService } from './telemetry.service.js';
import { authenticate } from '../auth/auth.middleware.js';
import { GroupsService } from '../groups/groups.service.js';

export async function telemetryRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // 1. HTTP Live Location Ingestion (Alternative/fallback to WebSockets)
  fastify.post(
    '/location',
    {
      schema: {
        description: 'Send live telemetry ping',
        tags: ['Telemetry'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['groupId', 'lat', 'lng'],
          properties: {
            groupId: { type: 'string' },
            lat: { type: 'number', minimum: -90, maximum: 90 },
            lng: { type: 'number', minimum: -180, maximum: 180 },
            altitude: { type: 'number' },
            speed: { type: 'number' },
            battery: { type: 'number', minimum: 0, maximum: 100 },
            timestamp: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const body = request.body as any;
      await TelemetryService.ingestLiveLocation({
        userId: request.user.id,
        groupId: body.groupId,
        lat: body.lat,
        lng: body.lng,
        altitude: body.altitude,
        speed: body.speed,
        battery: body.battery,
        recordedAt: body.timestamp ? new Date(body.timestamp) : new Date(),
      });

      return reply.send({ success: true });
    }
  );

  // 2. Get Live Locations of All Members in a Group
  fastify.get(
    '/group/:groupId/live',
    {
      schema: {
        description: 'Get real-time locations of all members in a group from Redis cache',
        tags: ['Telemetry'],
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          required: ['groupId'],
          properties: {
            groupId: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const params = request.params as { groupId: string };
      const members = await GroupsService.getGroupMembers(params.groupId);
      const memberIds = members.map((m) => m.user_id);
      const liveLocations = await TelemetryService.getGroupLiveLocations(params.groupId, memberIds);

      // Merge user profile details with their live telemetry
      const enriched = liveLocations.map((loc) => {
        const member = members.find((m) => m.user_id === loc.userId);
        return {
          ...loc,
          name: member?.name || 'Unknown',
          role: member?.role || 'MEMBER',
          phone: member?.phone,
        };
      });

      return reply.send({ groupId: params.groupId, members: enriched });
    }
  );

  // 3. Task BE-3.3: Third-Party Telemetry Sync (Good Samaritan mesh network relay)
  fastify.post(
    '/mesh-sync',
    {
      schema: {
        description: 'Upload location ledgers captured from peer devices via mesh network',
        tags: ['Telemetry'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['records'],
          properties: {
            records: {
              type: 'array',
              items: {
                type: 'object',
                required: ['userId', 'groupId', 'lat', 'lng', 'recordedAt'],
                properties: {
                  userId: { type: 'string' },
                  groupId: { type: 'string' },
                  lat: { type: 'number', minimum: -90, maximum: 90 },
                  lng: { type: 'number', minimum: -180, maximum: 180 },
                  altitude: { type: 'number' },
                  speed: { type: 'number' },
                  battery: { type: 'number' },
                  recordedAt: { type: 'string' },
                },
              },
            },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as { records: any[] };
        const result = await TelemetryService.syncMeshRelayLedger(request.user.id, body.records);
        return reply.status(200).send({
          message: 'Mesh telemetry ledger successfully processed',
          processedCount: result.processed,
          recoveredUsers: result.recoveredUsers,
        });
      } catch (err: any) {
        return reply.status(400).send({ error: 'MeshSyncFailed', message: err.message });
      }
    }
  );
}
