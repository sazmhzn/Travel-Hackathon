import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { generatePresignedUploadUrl, generatePresignedDownloadUrl } from '../../config/minio.js';
import { authenticate } from '../auth/auth.middleware.js';

export async function storageRoutes(fastify: FastifyInstance) {
  fastify.addHook('preHandler', authenticate);

  // 1. Task BE-1.4: Pre-signed Upload URL
  fastify.post(
    '/presigned-upload',
    {
      schema: {
        description: 'Generate a pre-signed S3/MinIO upload URL for media (photos/videos)',
        tags: ['Storage'],
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          required: ['fileName', 'contentType'],
          properties: {
            fileName: { type: 'string' },
            contentType: { type: 'string' },
          },
        },
      },
    },
    async (
      request: FastifyRequest<{ Body: { fileName: string; contentType: string } }>,
      reply: FastifyReply
    ) => {
      try {
        const presigned = await generatePresignedUploadUrl(
          request.body.fileName,
          request.body.contentType
        );
        return reply.send(presigned);
      } catch (err: any) {
        return reply.status(500).send({ error: 'StorageError', message: err.message });
      }
    }
  );

  // 2. Pre-signed Download URL
  fastify.get(
    '/presigned-download',
    {
      schema: {
        description: 'Generate a pre-signed download URL for private group media',
        tags: ['Storage'],
        security: [{ bearerAuth: [] }],
        querystring: {
          type: 'object',
          required: ['fileKey'],
          properties: {
            fileKey: { type: 'string' },
          },
        },
      },
    },
    async (request: FastifyRequest<{ Querystring: { fileKey: string } }>, reply: FastifyReply) => {
      try {
        const downloadUrl = await generatePresignedDownloadUrl(request.query.fileKey);
        return reply.send({ downloadUrl });
      } catch (err: any) {
        return reply.status(500).send({ error: 'StorageError', message: err.message });
      }
    }
  );
}
