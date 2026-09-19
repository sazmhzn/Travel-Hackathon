import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { FeedService } from './feed.service.js';
import { authenticate } from '../auth/auth.middleware.js';
import { GroupsService } from '../groups/groups.service.js';

export async function feedRoutes(fastify: FastifyInstance) {
  // 1. Task BE-4.5: Spatial Feed Query (GET /feed?lat=x&lng=y&radius=z)
  fastify.get(
    '/',
    {
      schema: {
        description: 'Discover nearby activities, media pins, and routes using PostGIS ST_DWithin',
        tags: ['Feed'],
        querystring: {
          type: 'object',
          required: ['lat', 'lng'],
          properties: {
            lat: { type: 'number', minimum: -90, maximum: 90 },
            lng: { type: 'number', minimum: -180, maximum: 180 },
            radius: { type: 'number', default: 50000, description: 'Search radius in meters (default 50km)' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const query = request.query as { lat: number; lng: number; radius?: number };
      const lat = Number(query.lat);
      const lng = Number(query.lng);
      const radius = query.radius ? Number(query.radius) : 50000;
      let userGroupIds: string[] = [];

      // Extract user token if provided (optional authentication for privacy filters)
      try {
        const authHeader = request.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
          const payload = await request.jwtVerify<{ id: string }>();
          if (payload?.id) {
            const userGroups = await GroupsService.getUserGroups(payload.id);
            userGroupIds = userGroups.map((g) => g.id);
          }
        }
      } catch {
        // Unauthenticated request - will only see PUBLIC items
      }

      const feed = await FeedService.getSpatialFeed({
        lat,
        lng,
        radiusMeters: radius,
        userGroupIds,
      });

      return reply.send({
        center: { lat, lng },
        radiusMeters: radius,
        count: feed.activities.length,
        activities: feed.activities,
        routes: feed.routes,
      });
    }
  );

  // 2. Create Activity Pin with MinIO Media
  fastify.post(
    '/activities',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Post an activity or media pin with spatial coordinates',
        tags: ['Feed'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['title', 'lat', 'lng'],
          properties: {
            title: { type: 'string', minLength: 2 },
            description: { type: 'string' },
            groupId: { type: 'string' },
            visibility: { type: 'string', enum: ['PUBLIC', 'GROUP_ONLY'], default: 'PUBLIC' },
            lat: { type: 'number', minimum: -90, maximum: 90 },
            lng: { type: 'number', minimum: -180, maximum: 180 },
            mediaUrls: { type: 'array', items: { type: 'string' } },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const body = request.body as any;
      const activity = await FeedService.createActivity({
        userId: request.user.id,
        groupId: body.groupId,
        title: body.title,
        description: body.description,
        visibility: body.visibility,
        lat: body.lat,
        lng: body.lng,
        mediaUrls: body.mediaUrls,
      });

      return reply.status(201).send({ activity });
    }
  );
}
