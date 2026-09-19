import fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import { env } from './config/env.js';

import { authRoutes } from './modules/auth/auth.controller.js';
import { groupRoutes } from './modules/groups/groups.controller.js';
import { planRoutes } from './modules/plans/plans.controller.js';
import { telemetryRoutes } from './modules/telemetry/telemetry.controller.js';
import { emergencyRoutes } from './modules/emergency/emergency.controller.js';
import { feedRoutes } from './modules/feed/feed.controller.js';
import { storageRoutes } from './modules/storage/storage.controller.js';
import { destinationRoutes } from './modules/destination-agent/destination.controller.js';
import { routeRoutes } from './modules/routes/routes.controller.js';

export async function buildApp(): Promise<FastifyInstance> {
  const app = fastify({
    logger: false, // Using our centralized Pino logger
  });

  // CORS
  await app.register(cors, {
    origin: '*',
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: '*',
  });

  // JWT
  await app.register(jwt, {
    secret: env.JWT_SECRET,
  });

  // Swagger Documentation
  await app.register(swagger, {
    openapi: {
      info: {
        title: 'Travel & Emergency App Spatial Backend API',
        description:
          'High-throughput spatial processing API powered by PostGIS, Redis, WebSockets, and MinIO storage.',
        version: '1.0.0',
      },
      components: {
        securitySchemes: {
          bearerAuth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT',
          },
        },
      },
    },
  });

  await app.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'list',
      deepLinking: true,
    },
  });

  // Health Check
  app.get('/health', async () => ({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: env.NODE_ENV,
  }));

  // API Routes
  await app.register(authRoutes, { prefix: '/api/auth' });
  await app.register(groupRoutes, { prefix: '/api/groups' });
  await app.register(planRoutes, { prefix: '/api/plans' });
  await app.register(telemetryRoutes, { prefix: '/api/telemetry' });
  await app.register(emergencyRoutes, { prefix: '/api/emergency' });
  await app.register(feedRoutes, { prefix: '/api/feed' });
  await app.register(storageRoutes, { prefix: '/api/storage' });
  await app.register(destinationRoutes, { prefix: '/api/destinations' });
  await app.register(routeRoutes, { prefix: '/api/routes' });

  return app;
}
