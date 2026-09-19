import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { PlansService } from './plans.service.js';
import { authenticate } from '../auth/auth.middleware.js';

export async function planRoutes(fastify: FastifyInstance) {
  // 1. Task BE-2.2 & Sequence 1: Create Travel Plan (Upload GeoJSON/GPX)
  fastify.post(
    '/',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Create a travel plan from GeoJSON or GPX track and broadcast to group members',
        tags: ['Plans'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['groupId', 'title'],
          properties: {
            groupId: { type: 'string' },
            title: { type: 'string', minLength: 2 },
            description: { type: 'string' },
            geoJsonPayload: { type: 'object' },
            gpxPayload: { type: 'string' },
            startTime: { type: 'string' },
            endTime: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as any;
        const plan = await PlansService.createPlan({
          groupId: body.groupId,
          title: body.title,
          description: body.description,
          geoJsonPayload: body.geoJsonPayload,
          gpxPayload: body.gpxPayload,
          startTime: body.startTime,
          endTime: body.endTime,
        });

        return reply.status(201).send({
          message: 'Travel plan created and broadcast to group',
          plan,
        });
      } catch (err: any) {
        return reply.status(400).send({ error: 'CreatePlanFailed', message: err.message });
      }
    }
  );

  // 2. Task BE-2.3: Map Data Endpoint (ST_MakeEnvelope bounding-box metadata)
  fastify.get(
    '/map-data',
    {
      schema: {
        description: 'Get routes and suggested activities within a spatial bounding box',
        tags: ['Plans'],
        querystring: {
          type: 'object',
          required: ['minLat', 'minLng', 'maxLat', 'maxLng'],
          properties: {
            minLat: { type: 'number', minimum: -90, maximum: 90 },
            minLng: { type: 'number', minimum: -180, maximum: 180 },
            maxLat: { type: 'number', minimum: -90, maximum: 90 },
            maxLng: { type: 'number', minimum: -180, maximum: 180 },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const query = request.query as {
        minLat: number;
        minLng: number;
        maxLat: number;
        maxLng: number;
      };
      const data = await PlansService.getMapDataInBoundingBox(query);
      return reply.send(data);
    }
  );

  // 3. Get Plan Details by ID
  fastify.get(
    '/:planId',
    {
      schema: {
        description: 'Get travel plan details by ID with GeoJSON route and bounding box',
        tags: ['Plans'],
        params: {
          type: 'object',
          required: ['planId'],
          properties: {
            planId: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const params = request.params as { planId: string };
      const plan = await PlansService.getPlanById(params.planId);
      if (!plan) {
        return reply.status(404).send({ error: 'NotFound', message: 'Plan not found' });
      }
      return reply.send({ plan });
    }
  );

  // 4. Get All Plans for a Group
  fastify.get(
    '/group/:groupId',
    {
      schema: {
        description: 'Get all travel plans for a specific group',
        tags: ['Plans'],
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
      const plans = await PlansService.getPlansByGroup(params.groupId);
      return reply.send({ plans });
    }
  );
}
