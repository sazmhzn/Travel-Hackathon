import {
  S3Client,
  CreateBucketCommand,
  HeadBucketCommand,
  PutObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from './env.js';
import { logger } from '../utils/logger.js';

export const s3Client = new S3Client({
  endpoint: `http://${env.MINIO_ENDPOINT}:${env.MINIO_PORT}`,
  region: env.MINIO_REGION,
  credentials: {
    accessKeyId: env.MINIO_ACCESS_KEY,
    secretAccessKey: env.MINIO_SECRET_KEY,
  },
  forcePathStyle: true, // Crucial for MinIO self-hosted compatibility
});

export async function ensureBucketExists(): Promise<void> {
  try {
    await s3Client.send(new HeadBucketCommand({ Bucket: env.MINIO_BUCKET }));
    logger.info(`MinIO bucket "${env.MINIO_BUCKET}" verified.`);
  } catch (error: any) {
    if (error.name === 'NotFound' || error.$metadata?.httpStatusCode === 404) {
      try {
        await s3Client.send(new CreateBucketCommand({ Bucket: env.MINIO_BUCKET }));
        logger.info(`MinIO bucket "${env.MINIO_BUCKET}" created successfully.`);
      } catch (createErr) {
        logger.warn({ createErr }, `Could not auto-create MinIO bucket "${env.MINIO_BUCKET}"`);
      }
    } else {
      logger.warn({ error }, 'MinIO storage check failed or storage not currently running.');
    }
  }
}

export async function generatePresignedUploadUrl(
  fileName: string,
  contentType: string,
  expiresIn = 3600
): Promise<{ uploadUrl: string; fileKey: string; publicUrl: string }> {
  const timestamp = Date.now();
  const sanitized = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
  const fileKey = `uploads/${timestamp}-${sanitized}`;

  const command = new PutObjectCommand({
    Bucket: env.MINIO_BUCKET,
    Key: fileKey,
    ContentType: contentType,
  });

  const uploadUrl = await getSignedUrl(s3Client, command, { expiresIn });
  const publicUrl = `http://${env.MINIO_ENDPOINT}:${env.MINIO_PORT}/${env.MINIO_BUCKET}/${fileKey}`;

  return { uploadUrl, fileKey, publicUrl };
}

export async function generatePresignedDownloadUrl(
  fileKey: string,
  expiresIn = 3600
): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: env.MINIO_BUCKET,
    Key: fileKey,
  });

  return getSignedUrl(s3Client, command, { expiresIn });
}
