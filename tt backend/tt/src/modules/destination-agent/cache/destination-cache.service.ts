import { redisClient, isRedisConnected } from '../../../config/redis.js';
import { logger } from '../../../utils/logger.js';

const localCache = new Map<string, { value: string; expiresAt: number }>();

function cleanExpired(key: string): boolean {
  const entry = localCache.get(key);
  if (!entry) return false;
  if (Date.now() > entry.expiresAt) {
    localCache.delete(key);
    return false;
  }
  return true;
}

export class DestinationCacheService {
  static async get<T>(key: string): Promise<T | null> {
    try {
      if (isRedisConnected) {
        const raw = await redisClient.get(key);
        return raw ? (JSON.parse(raw) as T) : null;
      }
      if (!cleanExpired(key)) return null;
      const entry = localCache.get(key)!;
      return JSON.parse(entry.value) as T;
    } catch (err) {
      logger.warn({ err, key }, 'Cache get failed');
      return null;
    }
  }

  static async set(key: string, value: any, ttlSeconds: number): Promise<void> {
    try {
      const serialized = JSON.stringify(value);
      if (isRedisConnected) {
        await redisClient.set(key, serialized, 'EX', ttlSeconds);
        return;
      }
      localCache.set(key, {
        value: serialized,
        expiresAt: Date.now() + ttlSeconds * 1000,
      });
    } catch (err) {
      logger.warn({ err, key }, 'Cache set failed');
    }
  }

  static async del(...keys: string[]): Promise<void> {
    try {
      if (isRedisConnected) {
        await redisClient.del(...keys);
        return;
      }
      for (const key of keys) {
        localCache.delete(key);
      }
    } catch (err) {
      logger.warn({ err, keys }, 'Cache del failed');
    }
  }

  static async getWeather(destination: string, date: string): Promise<any> {
    return this.get(`weather:${destination}:${date}`);
  }

  static async setWeather(destination: string, date: string, data: any): Promise<void> {
    return this.set(`weather:${destination}:${date}`, data, 1800);
  }

  static async getPlaces(destination: string): Promise<any> {
    return this.get(`places:${destination}`);
  }

  static async setPlaces(destination: string, data: any): Promise<void> {
    return this.set(`places:${destination}`, data, 43200);
  }

  static async getPlace(provider: string, providerPlaceId: string): Promise<any> {
    return this.get(`place:${provider}:${providerPlaceId}`);
  }

  static async setPlace(provider: string, providerPlaceId: string, data: any): Promise<void> {
    return this.set(`place:${provider}:${providerPlaceId}`, data, 43200);
  }

  static async getRoute(originKey: string, destKey: string, mode: string): Promise<any> {
    return this.get(`routes:${originKey}:${destKey}:${mode}`);
  }

  static async setRoute(originKey: string, destKey: string, mode: string, data: any): Promise<void> {
    return this.set(`routes:${originKey}:${destKey}:${mode}`, data, 7200);
  }

  static async getElevation(lat: number, lng: number): Promise<any> {
    return this.get(`elevation:${lat}:${lng}`);
  }

  static async setElevation(lat: number, lng: number, data: any): Promise<void> {
    return this.set(`elevation:${lat}:${lng}`, data, 2592000);
  }

  static async getEvents(destination: string, month: string): Promise<any> {
    return this.get(`events:${destination}:${month}`);
  }

  static async setEvents(destination: string, month: string, data: any): Promise<void> {
    return this.set(`events:${destination}:${month}`, data, 7200);
  }

  static async getSafety(destination: string): Promise<any> {
    return this.get(`safety:${destination}`);
  }

  static async setSafety(destination: string, data: any): Promise<void> {
    return this.set(`safety:${destination}`, data, 900);
  }
}
