import { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { redisClient, redisSubscriber, isRedisConnected } from '../config/redis.js';
import { logger } from '../utils/logger.js';
import { TelemetryService } from '../modules/telemetry/telemetry.service.js';

export let io: SocketIOServer;

export interface AuthenticatedSocket extends Socket {
  data: {
    user?: {
      id: string;
      email: string;
      role: 'GUIDE' | 'MEMBER' | 'ADMIN';
    };
  };
}

export function initializeSocketIO(httpServer: HttpServer): SocketIOServer {
  io = new SocketIOServer(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
  });

  // Attach Redis Adapter if connected for multi-node clustering
  if (isRedisConnected && redisClient && redisSubscriber) {
    try {
      io.adapter(createAdapter(redisClient, redisSubscriber));
      logger.info('Socket.io attached to Redis Adapter for multi-node room broadcasting.');
    } catch (err) {
      logger.warn({ err }, 'Could not attach Redis adapter to Socket.io. Operating in single-instance mode.');
    }
  }

  // Handshake JWT Authentication Middleware
  io.use((socket: AuthenticatedSocket, next) => {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace('Bearer ', '');

    if (!token) {
      return next(new Error('Authentication error: Missing token'));
    }

    try {
      const decoded = jwt.verify(token, env.JWT_SECRET) as any;
      socket.data.user = {
        id: decoded.id,
        email: decoded.email,
        role: decoded.role,
      };
      next();
    } catch (err) {
      return next(new Error('Authentication error: Invalid or expired token'));
    }
  });

  // Connection Handler
  io.on('connection', (socket: AuthenticatedSocket) => {
    const user = socket.data.user;
    logger.info({ socketId: socket.id, userId: user?.id }, 'WebSocket client connected');

    // Join personal user room for notifications (destination agent, etc.)
    if (user?.id) {
      socket.join(`user:${user.id}`);
    }

    // 1. Join Travel Group Room
    socket.on('join_group', ({ groupId }: { groupId: string }) => {
      if (!groupId) return;
      socket.join(`group:${groupId}`);
      logger.info({ userId: user?.id, groupId }, 'User joined group room');

      socket.to(`group:${groupId}`).emit('member:joined', {
        userId: user?.id,
        timestamp: new Date().toISOString(),
      });
    });

    // 2. Leave Travel Group Room
    socket.on('leave_group', ({ groupId }: { groupId: string }) => {
      if (!groupId) return;
      socket.leave(`group:${groupId}`);
      socket.to(`group:${groupId}`).emit('member:left', {
        userId: user?.id,
        timestamp: new Date().toISOString(),
      });
    });

    // 3. High-Frequency Live Location Updates (Task BE-3.2)
    socket.on('location:update', async (payload: {
      groupId: string;
      lat: number;
      lng: number;
      altitude?: number;
      speed?: number;
      battery?: number;
      timestamp?: string;
    }) => {
      if (!user || !payload.groupId || typeof payload.lat !== 'number' || typeof payload.lng !== 'number') {
        return;
      }

      try {
        // Ingest into Redis GEO / Hash cache and queue for batch DB persistence
        await TelemetryService.ingestLiveLocation({
          userId: user.id,
          groupId: payload.groupId,
          lat: payload.lat,
          lng: payload.lng,
          altitude: payload.altitude,
          speed: payload.speed,
          battery: payload.battery,
          recordedAt: payload.timestamp ? new Date(payload.timestamp) : new Date(),
        });

        // Broadcast to group room
        socket.to(`group:${payload.groupId}`).emit('member:location', {
          userId: user.id,
          lat: payload.lat,
          lng: payload.lng,
          altitude: payload.altitude,
          speed: payload.speed,
          battery: payload.battery,
          timestamp: payload.timestamp || new Date().toISOString(),
        });
      } catch (err) {
        logger.error({ err, userId: user.id }, 'Error processing live location update');
      }
    });

    // 4. Plan Receipt ACK (Sequence 1)
    socket.on('plan:ack', ({ planId, groupId }: { planId: string; groupId: string }) => {
      logger.debug({ userId: user?.id, planId, groupId }, 'Member acknowledged plan receipt');
    });

    socket.on('disconnect', () => {
      logger.info({ socketId: socket.id, userId: user?.id }, 'WebSocket client disconnected');
    });
  });

  return io;
}

export function broadcastToGroup(groupId: string, event: string, payload: any): void {
  if (io) {
    io.to(`group:${groupId}`).emit(event, payload);
  }
}

export function broadcastToUser(userId: string, event: string, payload: any): void {
  if (io) {
    io.to(`user:${userId}`).emit(event, payload);
  }
}
