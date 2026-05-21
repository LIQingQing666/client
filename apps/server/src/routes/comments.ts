import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';
import crypto from 'node:crypto';

export async function commentRoutes(app: FastifyInstance) {
  // GET /api/comments - 评论列表
  app.get('/api/comments', async (req: FastifyRequest<{ Querystring: { video_id?: string; product_id?: string; page?: string; page_size?: string } }>) => {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '20', 10)));
    const offset = (page - 1) * pageSize;

    let where = 'WHERE 1=1';
    const params: unknown[] = [];

    if (req.query.video_id) {
      where += ' AND video_id = ?';
      params.push(req.query.video_id);
    }
    if (req.query.product_id) {
      where += ' AND product_id = ?';
      params.push(req.query.product_id);
    }

    const total = (db.prepare(
      `SELECT COUNT(*) as count FROM comments ${where}`
    ).get(...params) as { count: number }).count;

    const comments = db.prepare(
      `SELECT * FROM comments ${where} ORDER BY like_count DESC, created_at DESC LIMIT ? OFFSET ?`
    ).all(...params, pageSize, offset) as Array<Record<string, unknown>>;

    return {
      code: 0,
      data: {
        list: comments,
        total,
        page,
        page_size: pageSize,
        has_more: offset + pageSize < total,
      },
    };
  });

  // POST /api/comments - 发表评论
  app.post('/api/comments', async (req: FastifyRequest<{ Body: {
    user_id: string;
    video_id?: string;
    product_id?: string;
    content: string;
    parent_id?: string;
  } }>) => {
    const db = getDb();
    const { user_id, video_id = '', product_id = '', content, parent_id = '' } = req.body;

    if (!content.trim()) {
      return { code: 400, message: '评论内容不能为空' };
    }

    const user = db.prepare('SELECT nickname, avatar FROM users WHERE id = ?').get(user_id) as
      | { nickname: string; avatar: string }
      | undefined;

    const id = crypto.randomUUID();
    db.prepare(
      `INSERT INTO comments (id, user_id, user_name, user_avatar, video_id, product_id, content, parent_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      id,
      user_id,
      user?.nickname ?? '',
      user?.avatar ?? '',
      video_id,
      product_id,
      content.trim(),
      parent_id,
    );

    // Update comment count
    if (video_id) {
      db.prepare('UPDATE videos SET comment_count = comment_count + 1 WHERE id = ?').run(video_id);
    }

    return { code: 0, data: { id } };
  });
}
