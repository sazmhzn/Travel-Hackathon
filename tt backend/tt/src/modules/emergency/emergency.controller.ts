import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { EmergencyService } from './emergency.service.js';
import { authenticate } from '../auth/auth.middleware.js';

export async function emergencyRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // Task BE-4.4: Free Emergency Trigger
  fastify.post(
    '/trigger',
    {
      schema: {
        description: 'Trigger Rescue Mode: alerts Guide via FCM and broadcasts to Telegram Emergency Channel',
        tags: ['Emergency'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['groupId', 'lat', 'lng'],
          properties: {
            groupId: { type: 'string' },
            lat: { type: 'number', minimum: -90, maximum: 90 },
            lng: { type: 'number', minimum: -180, maximum: 180 },
            battery: { type: 'number', minimum: 0, maximum: 100 },
            reason: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as any;
        const result = await EmergencyService.triggerRescueMode({
          userId: request.user.id,
          groupId: body.groupId,
          lat: body.lat,
          lng: body.lng,
          battery: body.battery,
          reason: body.reason,
        });

        return reply.status(200).send({
          success: true,
          message: 'Rescue Mode successfully triggered',
          alertId: result.alertId,
          telegramDelivered: result.telegramDelivered,
          fcmGuidesNotified: result.fcmGuidesNotified,
        });
      } catch (err: any) {
        return reply.status(500).send({ error: 'EmergencyTriggerFailed', message: err.message });
      }
    }
  );

  // Resolve / clear an active Rescue Mode alert (any member of the group).
  fastify.post(
    '/resolve',
    {
      schema: {
        description: 'Resolve active Rescue Mode alerts for a group (optionally one user)',
        tags: ['Emergency'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['groupId'],
          properties: {
            groupId: { type: 'string' },
            userId: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = request.body as { groupId: string; userId?: string };
        const result = await EmergencyService.resolveEmergency(
          body.groupId,
          body.userId,
          request.user.id
        );
        return reply.status(200).send({ success: true, ...result });
      } catch (err: any) {
        const status = /member/i.test(err.message) ? 403 : 400;
        return reply.status(status).send({ error: 'EmergencyResolveFailed', message: err.message });
      }
    }
  );
}
