import { FastifyInstance, FastifyRequest } from 'fastify';
import { createWriteStream } from 'node:fs';
import fs from 'node:fs/promises';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { requireAuth } from '../middleware/auth.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** Root directory served as static `/uploads/...` */
export const uploadsRoot = path.resolve(__dirname, '..', '..', 'public', 'uploads');

const IMAGE_EXTS = new Set(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']);
const VIDEO_EXTS = new Set(['mp4', 'mov', 'avi', 'webm', 'm4v', 'mkv']);

const MAX_IMAGE_BYTES = 10 * 1024 * 1024; // 10 MB
const MAX_VIDEO_BYTES = 200 * 1024 * 1024; // 200 MB

interface UploadOptions {
  /** Sub-directory under uploadsRoot (e.g. 'images', 'videos'). */
  subDir: 'images' | 'videos';
  /** Allowed lowercase extensions (no leading dot). */
  allowedExts: Set<string>;
  /** Per-file size limit in bytes. */
  maxBytes: number;
  /** User-facing label for error messages ('图片' / '视频'). */
  label: string;
}

function extOf(filename: string): string | null {
  const idx = filename.lastIndexOf('.');
  if (idx < 0 || idx === filename.length - 1) return null;
  return filename.slice(idx + 1).toLowerCase();
}

/**
 * Build an absolute URL the mobile client can hand straight to CachedNetworkImage,
 * regardless of which network interface the request came in on.
 */
function buildPublicUrl(req: FastifyRequest, relPath: string): string {
  const host = req.headers.host ?? `${req.hostname}`;
  return `${req.protocol}://${host}${relPath}`;
}

async function handleUpload(
  app: FastifyInstance,
  req: FastifyRequest,
  reply: import('fastify').FastifyReply,
  opts: UploadOptions,
): Promise<void> {
  if (!req.isMultipart()) {
    reply.status(400).send({ code: 400, message: `请使用 multipart/form-data 上传${opts.label}` });
    return;
  }

  let file: Awaited<ReturnType<typeof req.file>>;
  try {
    file = await req.file({ limits: { fileSize: opts.maxBytes } });
  } catch (err) {
    app.log.warn({ err }, 'multipart parse failed');
    reply.status(400).send({ code: 400, message: '表单数据解析失败' });
    return;
  }

  if (!file) {
    reply.status(400).send({ code: 400, message: '缺少字段: file' });
    return;
  }

  if (file.fieldname !== 'file') {
    file.file.resume();
    reply.status(400).send({ code: 400, message: '字段名必须为 file' });
    return;
  }

  const ext = extOf(file.filename ?? '');
  if (!ext || !opts.allowedExts.has(ext)) {
    // Drain the stream so the connection can close cleanly.
    file.file.resume();
    reply
      .status(400)
      .send({ code: 400, message: `不支持的${opts.label}格式，仅支持: ${[...opts.allowedExts].join(', ')}` });
    return;
  }

  const dir = path.join(uploadsRoot, opts.subDir);
  await fs.mkdir(dir, { recursive: true });

  const filename = `${Date.now()}_${randomUUID().slice(0, 8)}.${ext}`;
  const absPath = path.join(dir, filename);

  try {
    await pipeline(file.file, createWriteStream(absPath));
  } catch (err) {
    // Clean up partial file then surface a clear error.
    await fs.rm(absPath, { force: true });
    app.log.warn({ err }, 'upload write failed');
    reply.status(500).send({ code: 500, message: `${opts.label}上传失败` });
    return;
  }

  if (file.file.truncated) {
    // fastify-multipart will set `truncated` when fileSize limit was hit.
    await fs.rm(absPath, { force: true });
    reply.status(413).send({
      code: 413,
      message: `${opts.label}大小超过限制 (${Math.round(opts.maxBytes / (1024 * 1024))}MB)`,
    });
    return;
  }

  const stat = await fs.stat(absPath);
  const relUrl = `/uploads/${opts.subDir}/${filename}`;
  const url = buildPublicUrl(req, relUrl);

  reply.send({
    code: 0,
    data: {
      url,
      filename,
      size: stat.size,
      contentType: file.mimetype,
    },
  });
}

export async function uploadRoutes(app: FastifyInstance) {
  // POST /api/upload/image
  app.post('/api/upload/image', { preHandler: [requireAuth] }, async (req, reply) => {
    if (!req.user) return; // requireAuth already replied
    await handleUpload(app, req, reply, {
      subDir: 'images',
      allowedExts: IMAGE_EXTS,
      maxBytes: MAX_IMAGE_BYTES,
      label: '图片',
    });
  });

  // POST /api/upload/video
  app.post('/api/upload/video', { preHandler: [requireAuth] }, async (req, reply) => {
    if (!req.user) return;
    await handleUpload(app, req, reply, {
      subDir: 'videos',
      allowedExts: VIDEO_EXTS,
      maxBytes: MAX_VIDEO_BYTES,
      label: '视频',
    });
  });
}
