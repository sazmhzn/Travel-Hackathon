import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { RoutesService } from './routes.service.js';
import { authenticate, requireRole } from '../auth/auth.middleware.js';

export async function routeRoutes(fastify: FastifyInstance) {
  // POST /api/routes/record - Ingest and process offline-synced track data
  fastify.post(
    '/record',
    {
      preHandler: [authenticate, requireRole(['GUIDE', 'ADMIN'])],
      schema: {
        description: 'Ingest and optimize offline-synced GPS tracks with PostGIS simplification, distance, and bounding box computation (Guide role required)',
        tags: ['Routes'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['title', 'activity_type', 'geoJson'],
          properties: {
            title: { type: 'string', minLength: 2, maxLength: 255 },
            activity_type: { type: 'string', minLength: 2, maxLength: 50 },
            visibility: { 
              type: 'string', 
              enum: ['public', 'private', 'group'],
              default: 'public'
            },
            group_id: { type: 'string' },
            geoJson: {
              type: 'object',
              required: ['type', 'coordinates'],
              properties: {
                type: { type: 'string', const: 'LineString' },
                coordinates: {
                  type: 'array',
                  minItems: 2,
                  items: {
                    type: 'array',
                    minItems: 2,
                    items: { type: 'number' },
                  },
                },
              },
            },
          },
        },
        response: {
          201: {
            description: 'Route successfully processed and stored',
            type: 'object',
            properties: {
              message: { type: 'string' },
              route: {
                type: 'object',
                properties: {
                  id: { type: 'string' },
                  guide_id: { type: 'string' },
                  group_id: { type: ['string', 'null'] },
                  title: { type: 'string' },
                  activity_type: { type: 'string' },
                  visibility: { type: 'string' },
                  total_distance_meters: { type: 'number' },
                  bounding_box: { type: 'object', additionalProperties: true },
                  path: { type: 'object', additionalProperties: true },
                  created_at: { type: 'string' },
                },
              },
            },
          },
          400: {
            type: 'object',
            properties: {
              error: { type: 'string' },
              message: { type: 'string' },
            },
          },
          401: {
            type: 'object',
            properties: {
              error: { type: 'string' },
              message: { type: 'string' },
            },
          },
          403: {
            type: 'object',
            properties: {
              error: { type: 'string' },
              message: { type: 'string' },
            },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as any;
        const guideId = request.user.id;

        const route = await RoutesService.recordRoute({
          guideId,
          title: body.title,
          activityType: body.activity_type,
          visibility: body.visibility || 'public',
          groupId: body.group_id,
          geoJson: body.geoJson,
        });

        return reply.status(201).send({
          message: 'Spatial path recorded successfully',
          route,
        });
      } catch (err: any) {
        return reply.status(400).send({
          error: 'RecordRouteFailed',
          message: err.message || 'Failed to record spatial route',
        });
      }
    }
  );

  // GET /api/routes/group/:groupId - List routes recorded within an expedition
  fastify.get(
    '/group/:groupId',
    {
      schema: {
        description: 'List all routes recorded within a specific expedition',
        tags: ['Routes'],
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
      const { groupId } = request.params as { groupId: string };
      const routes = await RoutesService.getRoutesByGroup(groupId);
      return reply.send({ routes });
    }
  );

  // GET /api/routes/:id - Retrieve route details with spatial geometries
  fastify.get(
    '/:id',
    {
      schema: {
        description: 'Get route details by ID including GeoJSON path and bounding box',
        tags: ['Routes'],
        params: {
          type: 'object',
          required: ['id'],
          properties: {
            id: { type: 'string' },
          },
        },
        response: {
          200: {
            type: 'object',
            properties: {
              route: {
                type: 'object',
                properties: {
                  id: { type: 'string' },
                  guide_id: { type: 'string' },
                  title: { type: 'string' },
                  activity_type: { type: 'string' },
                  visibility: { type: 'string' },
                  total_distance_meters: { type: 'number' },
                  bounding_box: { type: 'object', additionalProperties: true },
                  path: { type: 'object', additionalProperties: true },
                  created_at: { type: 'string' },
                },
              },
            },
          },
          404: {
            type: 'object',
            properties: {
              error: { type: 'string' },
              message: { type: 'string' },
            },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const { id } = request.params as { id: string };
      const route = await RoutesService.getRouteById(id);

      if (!route) {
        return reply.status(404).send({
          error: 'RouteNotFound',
          message: `Route with id ${id} does not exist`,
        });
      }

      return reply.status(200).send({ route });
    }
  );
}
