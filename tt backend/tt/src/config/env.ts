import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

// z.coerce.boolean() treats any non-empty string (including "false") as true.
// Parse explicit env flags properly so local dev does not force SSL.
const envBoolean = (defaultValue: boolean) =>
  z
    .string()
    .optional()
    .transform((value) => {
      if (value === undefined || value === '') return defaultValue;
      return !['false', '0', 'no', 'off'].includes(value.toLowerCase());
    });

const envSchema = z.object({
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('192.168.110.44'),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  
  // JWT
  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 characters long'),

  // PostgreSQL + PostGIS
  DATABASE_URL: z.string().optional(),
  DB_HOST: z.string().default('localhost'),
  DB_PORT: z.coerce.number().default(5432),
  DB_USER: z.string().default('postgres'),
  DB_PASSWORD: z.string().default('postgres_travel_2026'),
  DB_NAME: z.string().default('travel_emergency_db'),
  DB_SSL: envBoolean(false),

  // Redis
  REDIS_HOST: z.string().default('localhost'),
  REDIS_PORT: z.coerce.number().default(6379),
  REDIS_PASSWORD: z.string().optional(),

  // MinIO / S3
  MINIO_ENDPOINT: z.string().default('localhost'),
  MINIO_PORT: z.coerce.number().default(9000),
  MINIO_USE_SSL: envBoolean(false),
  MINIO_ACCESS_KEY: z.string().default('minioadmin'),
  MINIO_SECRET_KEY: z.string().default('minioadmin123'),
  MINIO_BUCKET: z.string().default('travel-media'),
  MINIO_REGION: z.string().default('us-east-1'),

  // Emergency integrations
  TELEGRAM_BOT_TOKEN: z.string().optional(),
  TELEGRAM_EMERGENCY_CHAT_ID: z.string().optional(),
  FIREBASE_SERVICE_ACCOUNT_KEY: z.string().optional(),

  // Destination Agent
  DESTINATION_AGENT_ENABLED: z.coerce.boolean().default(true),
  GOOGLE_GEMINI_API_KEY: z.string().optional(),
  GOOGLE_PLACES_API_KEY: z.string().optional(),
  GOOGLE_ROUTES_API_KEY: z.string().optional(),
});

export const env = envSchema.parse(process.env);
