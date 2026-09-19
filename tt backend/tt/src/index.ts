import { buildApp } from './app.js';
import { env } from './config/env.js';
import { logger } from './utils/logger.js';
import { checkDatabaseConnection } from './config/database.js';
import { runMigrations } from './database/migrator.js';
import { initializeRedis } from './config/redis.js';
import { ensureBucketExists } from './config/minio.js';
import { initializeSocketIO } from './sockets/gateway.js';

async function startServer() {
  try {
    logger.info('Initializing Travel & Emergency App backend...');

    // 1. Initialize Redis connection
    initializeRedis();

    // 2. Check Database & Auto-Run Migrations if connected
    const dbConnected = await checkDatabaseConnection();
    if (dbConnected) {
      logger.info('PostgreSQL connection verified. Running migrations...');
      try {
        await runMigrations();
      } catch (migErr) {
        logger.error({ migErr }, 'Migration execution failed');
      }
    } else {
      logger.warn('PostgreSQL not accessible. Running with resilient in-memory fallback layer.');
    }

    // 3. MinIO S3 Bucket Check
    await ensureBucketExists();

    // 4. Build Fastify App
    const app = await buildApp();

    // 5. Initialize Socket.io on Fastify's raw HTTP server
    initializeSocketIO(app.server);

    // 6. Start Listening
    await app.listen({ port: env.PORT, host: env.HOST });
    logger.info(`🚀 Server listening at http://${env.HOST}:${env.PORT}`);
    logger.info(`📖 Swagger documentation available at http://${env.HOST}:${env.PORT}/docs`);
    logger.info(`⚡ Socket.io real-time broker active on ws://${env.HOST}:${env.PORT}`);
  } catch (err) {
    logger.error({ err }, 'Failed to start server');
    process.exit(1);
  }
}

startServer();
