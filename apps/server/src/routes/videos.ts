import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';

interface PaginationQuery {
  page?: string;
  page_size?: string;
}

export async function videoRoutes(app: FastifyInstance) {
  // GET /api/videos - 视频列表（分页）
  app.get('/api/videos', async (req: FastifyRequest<{ Querystring: PaginationQuery }>) => {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;

    const total = (db.prepare(
      'SELECT COUNT(*) as count FROM videos WHERE status = ?'
    ).get('published') as { count: number }).count;

    const videos = db.prepare(
      'SELECT * FROM videos WHERE status = ? ORDER BY created_at DESC LIMIT ? OFFSET ?'
    ).all('published', pageSize, offset) as Array<Record<string, unknown>>;

    const list = videos.map((v) => ({
      ...v,
      tags: JSON.parse(v.tags as string),
    }));

    return {
      code: 0,
      data: {
        list,
        total,
        page,
        page_size: pageSize,
        has_more: offset + pageSize < total,
      },
    };
  });

  // GET /api/videos/:id - 视频详情
  app.get('/api/videos/:id', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const video = db.prepare('SELECT * FROM videos WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!video) {
      return { code: 404, message: '视频不存在' };
    }

    // 增加播放量
    db.prepare('UPDATE videos SET play_count = play_count + 1 WHERE id = ?').run(req.params.id);

    // 获取关联商品
    const products = db.prepare(
      'SELECT * FROM products WHERE video_id = ? AND status = ?'
    ).all(req.params.id, 'on') as Array<Record<string, unknown>>;

    // 获取评论
    const comments = db.prepare(
      'SELECT * FROM comments WHERE video_id = ? ORDER BY like_count DESC LIMIT 20'
    ).all(req.params.id) as Array<Record<string, unknown>>;

    return {
      code: 0,
      data: {
        ...video,
        tags: JSON.parse(video.tags as string),
        products: products.map((p) => ({
          ...p,
          tags: JSON.parse(p.tags as string),
          images: JSON.parse(p.images as string),
          specs: JSON.parse(p.specs as string),
        })),
        comments,
      },
    };
  });

  // GET /api/videos/recommend - 推荐视频（按播放量）
  app.get('/api/videos/recommend', async (req: FastifyRequest<{ Querystring: PaginationQuery }>) => {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;

    const total = (db.prepare(
      "SELECT COUNT(*) as count FROM videos WHERE status = 'published'"
    ).get() as { count: number }).count;

    const videos = db.prepare(
      "SELECT * FROM videos WHERE status = 'published' ORDER BY play_count DESC LIMIT ? OFFSET ?"
    ).all(pageSize, offset) as Array<Record<string, unknown>>;

    const list = videos.map((v) => ({ ...v, tags: JSON.parse(v.tags as string) }));

    return {
      code: 0,
      data: { list, total, page, page_size: pageSize, has_more: offset + pageSize < total },
    };
  });

  // GET /api/videos/follow - 关注用户的视频
  app.get('/api/videos/follow', async (req: FastifyRequest<{ Querystring: PaginationQuery & { user_id?: string } }>) => {
    const db = getDb();
    const userId = req.query.user_id;
    if (!userId) {
      return { code: 0, data: { list: [], total: 0, page: 1, page_size: 10, has_more: false } };
    }

    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;

    const total = (db.prepare(
      `SELECT COUNT(*) as count FROM videos v
       JOIN follows f ON v.author_id = f.following_id
       WHERE f.follower_id = ? AND v.status = 'published'`
    ).get(userId) as { count: number }).count;

    const videos = db.prepare(
      `SELECT v.* FROM videos v
       JOIN follows f ON v.author_id = f.following_id
       WHERE f.follower_id = ? AND v.status = 'published'
       ORDER BY v.created_at DESC LIMIT ? OFFSET ?`
    ).all(userId, pageSize, offset) as Array<Record<string, unknown>>;

    const list = videos.map((v) => ({ ...v, tags: JSON.parse(v.tags as string) }));

    return {
      code: 0,
      data: { list, total, page, page_size: pageSize, has_more: offset + pageSize < total },
    };
  });

  // GET /api/videos/search - 搜索视频
  app.get('/api/videos/search', async (req: FastifyRequest<{ Querystring: PaginationQuery & { keyword?: string } }>) => {
    const db = getDb();
    const keyword = req.query.keyword ?? '';
    if (!keyword.trim()) {
      return { code: 0, data: { list: [], total: 0, page: 1, page_size: 10, has_more: false } };
    }

    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;
    const like = `%${keyword}%`;

    const total = (db.prepare(
      "SELECT COUNT(*) as count FROM videos WHERE status = 'published' AND (title LIKE ? OR description LIKE ?)"
    ).get(like, like) as { count: number }).count;

    const videos = db.prepare(
      "SELECT * FROM videos WHERE status = 'published' AND (title LIKE ? OR description LIKE ?) ORDER BY play_count DESC LIMIT ? OFFSET ?"
    ).all(like, like, pageSize, offset) as Array<Record<string, unknown>>;

    const list = videos.map((v) => ({ ...v, tags: JSON.parse(v.tags as string) }));

    return {
      code: 0,
      data: { list, total, page, page_size: pageSize, has_more: offset + pageSize < total },
    };
  });

  // POST /api/videos/:id/like - 点赞/取消点赞
  app.post('/api/videos/:id/like', async (req: FastifyRequest<{ Params: { id: string }; Body: { user_id: string } }>) => {
    const db = getDb();
    const { id } = req.params;
    const { user_id } = req.body;

    const existing = db.prepare(
      'SELECT id FROM user_likes WHERE user_id = ? AND video_id = ?'
    ).get(user_id, id);

    if (existing) {
      db.prepare('DELETE FROM user_likes WHERE user_id = ? AND video_id = ?').run(user_id, id);
      db.prepare('UPDATE videos SET like_count = MAX(0, like_count - 1) WHERE id = ?').run(id);
      return { code: 0, data: { liked: false } };
    }

    db.prepare('INSERT INTO user_likes (id, user_id, video_id) VALUES (?, ?, ?)').run(
      crypto.randomUUID(), user_id, id
    );
    db.prepare('UPDATE videos SET like_count = like_count + 1 WHERE id = ?').run(id);
    return { code: 0, data: { liked: true } };
  });
}
