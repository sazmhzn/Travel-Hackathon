import { FastifyReply, FastifyRequest } from 'fastify';

export interface AuthUser {
  id: string;
  email: string;
  role: 'GUIDE' | 'MEMBER' | 'ADMIN';
}

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: AuthUser;
    user: AuthUser;
  }
}

export async function authenticate(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      reply.status(401).send({ error: 'Unauthorized', message: 'Missing or malformed Bearer token' });
      return;
    }

    const payload = await request.jwtVerify<AuthUser>();
    request.user = payload;
  } catch (err: any) {
    reply.status(401).send({ error: 'Unauthorized', message: 'Invalid or expired token' });
  }
}

export function requireRole(allowedRoles: Array<'GUIDE' | 'MEMBER' | 'ADMIN'>) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    if (!request.user || !allowedRoles.includes(request.user.role)) {
      reply.status(403).send({
        error: 'Forbidden',
        message: `Requires one of the following roles: ${allowedRoles.join(', ')}`,
      });
    }
  };
}
