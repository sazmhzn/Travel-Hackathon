import { Redis } from 'ioredis';
import { env } from './env.js';
import { logger } from '../utils/logger.js';

export let redisClient: Redis;
export let redisSubscriber: Redis;
export let isRedisConnected = false;

// In-memory fallback cache if Redis instance is not available
class InMemoryRedisMock {
  private store = new Map<string, any>();
  private expiries = new Map<string, NodeJS.Timeout>();

  async set(key: string, value: string, mode?: string, duration?: number): Promise<'OK'> {
    this.store.set(key, value);
    if (mode === 'EX' && duration) {
      if (this.expiries.has(key)) clearTimeout(this.expiries.get(key)!);
      const timeout = setTimeout(() => this.store.delete(key), duration * 1000);
      this.expiries.set(key, timeout);
    }
    return 'OK';
  }

  async get(key: string): Promise<string | null> {
    return this.store.get(key) || null;
  }

  async hset(key: string, data: Record<string, any>): Promise<number> {
    const existing = this.store.get(key) || {};
    this.store.set(key, { ...existing, ...data });
    return Object.keys(data).length;
  }

  async hgetall(key: string): Promise<Record<string, string>> {
    return this.store.get(key) || {};
  }

  async expire(key: string, seconds: number): Promise<number> {
    if (this.expiries.has(key)) clearTimeout(this.expiries.get(key)!);
    const timeout = setTimeout(() => this.store.delete(key), seconds * 1000);
    this.expiries.set(key, timeout);
    return 1;
  }

  async geoadd(key: string, longitude: number, latitude: number, member: string): Promise<number> {
    const geoMap = this.store.get(key) || new Map<string, { lng: number; lat: number }>();
    geoMap.set(member, { lng: longitude, lat: latitude });
    this.store.set(key, geoMap);
    return 1;
  }

  async geopos(key: string, ...members: string[]): Promise<Array<[string, string] | null>> {
    const geoMap = this.store.get(key) as Map<string, { lng: number; lat: number }> | undefined;
    if (!geoMap) return members.map(() => null);
    return members.map((m) => {
      const pos = geoMap.get(m);
      return pos ? [pos.lng.toString(), pos.lat.toString()] : null;
    });
  }

  async del(...keys: string[]): Promise<number> {
    let count = 0;
    for (const key of keys) {
      if (this.store.delete(key)) count++;
      if (this.expiries.has(key)) {
        clearTimeout(this.expiries.get(key)!);
        this.expiries.delete(key);
      }
    }
    return count;
  }

  async ping(): Promise<'PONG'> {
    return 'PONG';
  }
}

export const inMemoryFallback = new InMemoryRedisMock();

export function initializeRedis(): { client: Redis; subscriber: Redis } {
  const options = {
    host: env.REDIS_HOST,
    port: env.REDIS_PORT,
    password: env.REDIS_PASSWORD || undefined,
    lazyConnect: true,
    maxRetriesPerRequest: 1,
    retryStrategy: (times: number) => {
      if (times > 3) {
        logger.warn('Redis connection retry limit reached. Falling back to in-memory store.');
        return null;
      }
      return Math.min(times * 100, 2000);
    },
  };

  redisClient = new Redis(options);
  redisSubscriber = new Redis(options);

  redisClient.on('connect', () => {
    isRedisConnected = true;
    logger.info('Connected to Redis server.');
  });

  redisClient.on('error', (err) => {
    logger.warn({ err: err.message }, 'Redis client connection error (using fallback if disconnected)');
    isRedisConnected = false;
  });

  redisClient.connect().catch(() => {
    isRedisConnected = false;
    logger.info('Redis not reachable, operating with in-memory telemetry fallback.');
  });

  return { client: redisClient, subscriber: redisSubscriber };
}
