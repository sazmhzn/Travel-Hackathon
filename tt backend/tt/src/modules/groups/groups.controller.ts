import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { GroupsService } from './groups.service.js';
import { authenticate } from '../auth/auth.middleware.js';

export async function groupRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // 1. Create a Travel Group (Guide or User)
  fastify.post(
    '/',
    {
      schema: {
        description: 'Create a new travel group',
        tags: ['Groups'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['name'],
          properties: {
            name: { type: 'string', minLength: 3 },
            description: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as { name: string; description?: string };
        const group = await GroupsService.createGroup({
          name: body.name,
          description: body.description,
          createdBy: request.user.id,
        });
        return reply.status(201).send({ group });
      } catch (err: any) {
        return reply.status(400).send({ error: 'CreateGroupFailed', message: err.message });
      }
    }
  );

  // 2. Join a Group with Invite Code
  fastify.post(
    '/join',
    {
      schema: {
        description: 'Join a travel group using an invite code',
        tags: ['Groups'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['inviteCode'],
          properties: {
            inviteCode: { type: 'string', minLength: 4 },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as { inviteCode: string };
        const group = await GroupsService.joinGroupByInviteCode(request.user.id, body.inviteCode);
        return reply.send({ message: 'Successfully joined group', group });
      } catch (err: any) {
        return reply.status(400).send({ error: 'JoinFailed', message: err.message });
      }
    }
  );

  // 3. Get My Groups
  fastify.get(
    '/my-groups',
    {
      schema: {
        description: 'Get all groups the authenticated user belongs to',
        tags: ['Groups'],
        security: [{ bearerAuth: [] }],
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const groups = await GroupsService.getUserGroups(request.user.id, request.user.role);
      return reply.send({ groups });
    }
  );

  // 4. Get Group Details (roster + live/missing breakdown)
  fastify.get(
    '/:groupId',
    {
      schema: {
        description: 'Get full details for a group including members and missing status',
        tags: ['Groups'],
        security: [{ bearerAuth: [] }],
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
      try {
        const params = request.params as { groupId: string };
        const details = await GroupsService.getGroupDetails(params.groupId, request.user.id);
        return reply.send(details);
      } catch (err: any) {
        return reply.status(404).send({ error: 'GroupDetailsFailed', message: err.message });
      }
    }
  );

  // 5. Activate / Deactivate a Group (Guide only)
  fastify.patch(
    '/:groupId/status',
    {
      schema: {
        description: 'Activate or deactivate an expedition (guide only)',
        tags: ['Groups'],
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          required: ['groupId'],
          properties: {
            groupId: { type: 'string' },
          },
        },
        body: {
          type: 'object',
          required: ['isActive'],
          properties: {
            isActive: { type: 'boolean' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const params = request.params as { groupId: string };
        const body = request.body as { isActive: boolean };
        const group = await GroupsService.setGroupStatus(
          request.user.id,
          params.groupId,
          body.isActive
        );
        return reply.send({ group });
      } catch (err: any) {
        const status = /guide/i.test(err.message) ? 403 : 400;
        return reply.status(status).send({ error: 'GroupStatusFailed', message: err.message });
      }
    }
  );

  // 6. Get Group Members
  fastify.get(
    '/:groupId/members',
    {
      schema: {
        description: 'Get all members and guides in a group',
        tags: ['Groups'],
        security: [{ bearerAuth: [] }],
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
      const params = request.params as { groupId: string };
      const members = await GroupsService.getGroupMembers(params.groupId);
      return reply.send({ members });
    }
  );
}
