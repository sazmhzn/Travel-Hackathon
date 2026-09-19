import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { AuthService } from './auth.service.js';
import { authenticate } from './auth.middleware.js';

export async function authRoutes(fastify: FastifyInstance) {
  // 1. User Registration
  fastify.post(
    '/register',
    {
      schema: {
        description: 'Register a new user (Guide or Member)',
        tags: ['Authentication'],
        body: {
          type: 'object',
          required: ['email', 'password', 'name'],
          properties: {
            email: { type: 'string', format: 'email' },
            password: { type: 'string', minLength: 6 },
            name: { type: 'string', minLength: 2 },
            phone: { type: 'string' },
            role: { type: 'string', enum: ['GUIDE', 'MEMBER'], default: 'MEMBER' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as any;
        const user = await AuthService.register(body);
        const token = fastify.jwt.sign(
          { id: user.id, email: user.email, role: user.role },
          { expiresIn: '7d' }
        );
        return reply.status(201).send({ user, token });
      } catch (err: any) {
        return reply.status(400).send({ error: 'RegistrationFailed', message: err.message });
      }
    }
  );

  // 2. User Login
  fastify.post(
    '/login',
    {
      schema: {
        description: 'Login with email and password to receive JWT',
        tags: ['Authentication'],
        body: {
          type: 'object',
          required: ['email', 'password'],
          properties: {
            email: { type: 'string', format: 'email' },
            password: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as any;
        const user = await AuthService.login(body);
        const token = fastify.jwt.sign(
          { id: user.id, email: user.email, role: user.role },
          { expiresIn: '7d' }
        );
        return reply.send({ user, token });
      } catch (err: any) {
        return reply.status(401).send({ error: 'AuthenticationFailed', message: err.message });
      }
    }
  );

  // 3. Current User Profile
  fastify.get(
    '/me',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Get authenticated user details',
        tags: ['Authentication'],
        security: [{ bearerAuth: [] }],
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const user = await AuthService.getUserById(request.user.id);
      if (!user) {
        return reply.status(404).send({ error: 'NotFound', message: 'User not found' });
      }
      return reply.send({ user });
    }
  );

  // 4. Update FCM Push Token
  fastify.put(
    '/fcm-token',
    {
      preHandler: [authenticate],
      schema: {
        description: 'Update user Firebase Cloud Messaging device token',
        tags: ['Authentication'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['token'],
          properties: {
            token: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const body = request.body as { token: string };
      await AuthService.updateFcmToken(request.user.id, body.token);
      return reply.send({ success: true, message: 'FCM token updated' });
    }
  );
}
