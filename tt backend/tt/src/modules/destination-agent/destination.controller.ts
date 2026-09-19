import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { authenticate } from '../auth/auth.middleware.js';
import { DestinationService } from './destination.service.js';
import { DestinationGenerationRequestSchema } from './schemas/destination.schema.js';

export async function destinationRoutes(fastify: FastifyInstance) {
  // 1. Generate itinerary
  fastify.post(
    '/generate',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Queue a new AI-powered itinerary generation job',
        tags: ['Destination'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['destination', 'startDate', 'endDate', 'preferences'],
          properties: {
            destination: { type: 'string', minLength: 1 },
            startDate: { type: 'string', format: 'date-time' },
            endDate: { type: 'string', format: 'date-time' },
            preferences: {
              type: 'object',
              required: ['interests', 'budget', 'transport', 'travelStyle'],
              properties: {
                interests: {
                  type: 'array',
                  items: { type: 'string', enum: ['NATURE', 'CULTURE', 'FOOD', 'ADVENTURE', 'SHOPPING', 'NIGHTLIFE', 'RELAXATION', 'PHOTOGRAPHY'] },
                },
                budget: { type: 'string', enum: ['BUDGET', 'MEDIUM', 'LUXURY'] },
                transport: {
                  type: 'array',
                  items: { type: 'string', enum: ['PUBLIC', 'PRIVATE', 'WALKING', 'BICYCLE'] },
                },
                travelStyle: { type: 'string', enum: ['FAST', 'MODERATE', 'SLOW'] },
              },
            },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as any;
        const { jobId, requestHash } = await DestinationService.createGenerationJob({
          userId: request.user.id,
          destination: body.destination,
          startDate: body.startDate,
          endDate: body.endDate,
          preferences: body.preferences,
        });
        return reply.status(202).send({ generationId: jobId, status: 'QUEUED' });
      } catch (err: any) {
        return reply.status(500).send({ error: 'GenerationFailed', message: err.message });
      }
    }
  );

  // 2. Get generation job status
  fastify.get(
    '/generation/:jobId',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Get status of an itinerary generation job',
        tags: ['Destination'],
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          required: ['jobId'],
          properties: {
            jobId: { type: 'string', format: 'uuid' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const { jobId } = request.params as { jobId: string };
        const status = await DestinationService.getGenerationStatus(jobId);
        return reply.send(status);
      } catch (err: any) {
        return reply.status(404).send({ error: 'NotFound', message: err.message });
      }
    }
  );

  // 3. Get completed itinerary
  fastify.get(
    '/itinerary/:generationId',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Get a completed itinerary with all items',
        tags: ['Destination'],
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          required: ['generationId'],
          properties: {
            generationId: { type: 'string', format: 'uuid' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const { generationId } = request.params as { generationId: string };
        const itinerary = await DestinationService.getItinerary(generationId);
        if (!itinerary) {
          return reply.status(404).send({ error: 'NotFound', message: 'Itinerary not found or not yet completed' });
        }
        return reply.send(itinerary);
      } catch (err: any) {
        return reply.status(500).send({ error: 'FetchFailed', message: err.message });
      }
    }
  );

  // 4. Get user's generations
  fastify.get(
    '/my-generations',
    {
      preHandler: [authenticate],
      schema: {
        description: 'List authenticated user recent itinerary generations',
        tags: ['Destination'],
        security: [{ bearerAuth: [] }],
        querystring: {
          type: 'object',
          properties: {
            limit: { type: 'integer', minimum: 1, maximum: 100, default: 20 },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const { limit } = request.query as { limit?: number };
        const generations = await DestinationService.getUserGenerations(request.user.id, limit);
        return reply.send({ generations });
      } catch (err: any) {
        return reply.status(500).send({ error: 'FetchFailed', message: err.message });
      }
    }
  );

  // 5. Search destinations
  fastify.get(
    '/search',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Search destinations by name',
        tags: ['Destination'],
        security: [{ bearerAuth: [] }],
        querystring: {
          type: 'object',
          required: ['q'],
          properties: {
            q: { type: 'string', minLength: 1 },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const { q } = request.query as { q: string };
        const destinations = await DestinationService.searchDestinations(q);
        return reply.send({ destinations });
      } catch (err: any) {
        return reply.status(500).send({ error: 'SearchFailed', message: err.message });
      }
    }
  );

  // 6. Get destination by ID
  fastify.get(
    '/:destinationId',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Get destination details by ID',
        tags: ['Destination'],
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          required: ['destinationId'],
          properties: {
            destinationId: { type: 'string', format: 'uuid' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const { destinationId } = request.params as { destinationId: string };
        const destination = await DestinationService.getDestinationById(destinationId);
        if (!destination) {
          return reply.status(404).send({ error: 'NotFound', message: 'Destination not found' });
        }
        return reply.send({ destination });
      } catch (err: any) {
        return reply.status(500).send({ error: 'FetchFailed', message: err.message });
      }
    }
  );
}
