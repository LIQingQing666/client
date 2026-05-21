import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import type { FastifyRequest, FastifyReply } from 'fastify';

const JWT_SECRET = process.env.JWT_SECRET ?? 'livestream-commerce-secret';
const TOKEN_EXPIRY = '7d';

export interface JwtPayload {
  userId: string;
  role: string;
}

// Extend FastifyRequest to carry user info
declare module 'fastify' {
  interface FastifyRequest {
    user?: JwtPayload;
  }
}

export function generateToken(userId: string, role: string): string {
  return jwt.sign({ userId, role } satisfies JwtPayload, JWT_SECRET, {
    expiresIn: TOKEN_EXPIRY,
  });
}

export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
  return `${salt}:${hash}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(':');
  if (!salt || !hash) return false;
  const computed = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
  return crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(hash));
}

export async function requireAuth(
  req: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    reply.status(401).send({ code: 401, message: '未登录或登录已过期' });
    return;
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, JWT_SECRET) as JwtPayload;
    req.user = payload;
  } catch {
    reply.status(401).send({ code: 401, message: '登录已过期，请重新登录' });
  }
}

export async function requireMerchant(
  req: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  await requireAuth(req, reply);
  // If auth failed, requireAuth already sent a reply — check before proceeding
  if (!req.user) return;

  if (req.user.role !== 'merchant') {
    reply.status(403).send({ code: 403, message: '无权限，仅商家可操作' });
  }
}
