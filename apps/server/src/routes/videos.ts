import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';
import { requireMerchant } from '../middleware/auth.js';
import * as dotenv from 'dotenv';
dotenv.config();

interface PaginationQuery {
  page?: string;
  page_size?: string;
}

const VALID_VIDEO_STATUSES = new Set(['draft', 'published', 'inactive']);

interface VideoCreateBody {
  title?: unknown;
  description?: unknown;
  cover_url?: unknown;
  video_url?: unknown;
  author_id?: unknown;
  author_name?: unknown;
  author_avatar?: unknown;
  tags?: unknown;
  linked_product_ids?: unknown;
  duration?: unknown;
  status?: unknown;
}

function asString(v: unknown): string {
  return typeof v === 'string' ? v.trim() : '';
}

function asStringArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.filter((x): x is string => typeof x === 'string' && x.length > 0);
}

function rowToVideo(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...row,
    tags: JSON.parse((row.tags as string) || '[]'),
  };
}

export async function videoRoutes(app: FastifyInstance) {
  // GET /api/videos - 视频列表（分页）
  // `status` query param: omitted/'published' = consumer default (published only),
  // 'draft' | 'inactive' = exact match, 'all' = no status filter.
  app.get('/api/videos', async (req: FastifyRequest<{ Querystring: PaginationQuery & { status?: string } }>) => {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;

    const statusFilter = req.query.status;
    let where: string;
    const params: unknown[] = [];
    if (statusFilter === 'all') {
      // 'all' is the merchant management view — show every status except deleted.
      where = "WHERE status != 'deleted'";
    } else if (statusFilter === 'draft' || statusFilter === 'inactive') {
      where = 'WHERE status = ?';
      params.push(statusFilter);
    } else {
      where = "WHERE status = 'published'";
    }

    const total = (db.prepare(
      `SELECT COUNT(*) as count FROM videos ${where}`,
    ).get(...params) as { count: number }).count;

    const videos = db.prepare(
      `SELECT * FROM videos ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
    ).all(...params, pageSize, offset) as Array<Record<string, unknown>>;

    const list = videos.map(rowToVideo);

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

  // POST /api/videos - 创建视频（仅商家）
  app.post<{ Body: VideoCreateBody }>(
    '/api/videos',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return;
      const body = req.body ?? {};

      const title = asString(body.title);
      const videoUrl = asString(body.video_url);
      if (!title) {
        reply.status(400).send({ code: 400, message: '视频标题不能为空' });
        return;
      }
      if (!videoUrl) {
        reply.status(400).send({ code: 400, message: '视频地址不能为空' });
        return;
      }

      const description = asString(body.description);
      const coverUrl = asString(body.cover_url);
      // Author defaults to the merchant token's user, but accept overrides so the
      // mobile add-video form (which already fills these from the merchant profile)
      // doesn't have to round-trip through us.
      const authorId = asString(body.author_id) || req.user.userId;
      const authorName = asString(body.author_name);
      const authorAvatar = asString(body.author_avatar);
      const duration = typeof body.duration === 'number' && body.duration >= 0
        ? Math.floor(body.duration)
        : 0;
      const tags = asStringArray(body.tags);
      const linkedProductIds = asStringArray(body.linked_product_ids);

      const rawStatus = asString(body.status) || 'draft';
      if (!VALID_VIDEO_STATUSES.has(rawStatus)) {
        reply.status(400).send({
          code: 400,
          message: "status 必须是 'draft' / 'published' / 'inactive'",
        });
        return;
      }

      const db = getDb();
      const id = crypto.randomUUID();
      db.prepare(
        `INSERT INTO videos
          (id, title, description, cover_url, video_url, author_id, author_name,
           author_avatar, duration, tags, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).run(
        id,
        title,
        description,
        coverUrl,
        videoUrl,
        authorId,
        authorName,
        authorAvatar,
        duration,
        JSON.stringify(tags),
        rawStatus,
      );

      // Link products → this video. The products table stores a single video_id
      // per product, so we just point each selected product at the new video.
      if (linkedProductIds.length > 0) {
        const link = db.prepare(
          "UPDATE products SET video_id = ?, updated_at = datetime('now') WHERE id = ?",
        );
        for (const pid of linkedProductIds) {
          link.run(id, pid);
        }
      }

      const row = db
        .prepare('SELECT * FROM videos WHERE id = ?')
        .get(id) as Record<string, unknown>;
      return { code: 0, data: rowToVideo(row) };
    },
  );

  // PUT /api/videos/:id - 修改视频信息（仅商家）
  app.put<{ Params: { id: string }; Body: VideoCreateBody }>(
    '/api/videos/:id',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return;
      const db = getDb();

      const existing = db
        .prepare('SELECT id FROM videos WHERE id = ?')
        .get(req.params.id) as { id: string } | undefined;
      if (!existing) {
        reply.status(404).send({ code: 404, message: '视频不存在' });
        return;
      }

      const body = req.body ?? {};
      const title = asString(body.title);
      const videoUrl = asString(body.video_url);
      if (!title) {
        reply.status(400).send({ code: 400, message: '视频标题不能为空' });
        return;
      }
      if (!videoUrl) {
        reply.status(400).send({ code: 400, message: '视频地址不能为空' });
        return;
      }

      const description = asString(body.description);
      const coverUrl = asString(body.cover_url);
      const authorId = asString(body.author_id) || req.user.userId;
      const authorName = asString(body.author_name);
      const authorAvatar = asString(body.author_avatar);
      const duration = typeof body.duration === 'number' && body.duration >= 0
        ? Math.floor(body.duration)
        : 0;
      const tags = asStringArray(body.tags);

      // status only enforced when present — omitting it keeps the current value.
      const hasStatus = body.status !== undefined;
      const rawStatus = hasStatus ? asString(body.status) : '';
      if (hasStatus && !VALID_VIDEO_STATUSES.has(rawStatus)) {
        reply.status(400).send({
          code: 400,
          message: "status 必须是 'draft' / 'published' / 'inactive'",
        });
        return;
      }

      if (hasStatus) {
        db.prepare(
          `UPDATE videos
              SET title = ?, description = ?, cover_url = ?, video_url = ?,
                  author_id = ?, author_name = ?, author_avatar = ?,
                  duration = ?, tags = ?, status = ?,
                  updated_at = datetime('now')
            WHERE id = ?`,
        ).run(
          title, description, coverUrl, videoUrl,
          authorId, authorName, authorAvatar,
          duration, JSON.stringify(tags), rawStatus,
          req.params.id,
        );
      } else {
        db.prepare(
          `UPDATE videos
              SET title = ?, description = ?, cover_url = ?, video_url = ?,
                  author_id = ?, author_name = ?, author_avatar = ?,
                  duration = ?, tags = ?,
                  updated_at = datetime('now')
            WHERE id = ?`,
        ).run(
          title, description, coverUrl, videoUrl,
          authorId, authorName, authorAvatar,
          duration, JSON.stringify(tags),
          req.params.id,
        );
      }

      // Re-sync product links only when the field is explicitly provided.
      // Omitting `linked_product_ids` from the body preserves existing links.
      if (body.linked_product_ids !== undefined) {
        const linkedIds = asStringArray(body.linked_product_ids);
        // Detach products previously linked to this video, then re-link the
        // provided set — empty array means "clear all links".
        db.prepare(
          "UPDATE products SET video_id = '', updated_at = datetime('now') WHERE video_id = ?",
        ).run(req.params.id);
        if (linkedIds.length > 0) {
          const attach = db.prepare(
            "UPDATE products SET video_id = ?, updated_at = datetime('now') WHERE id = ?",
          );
          for (const pid of linkedIds) {
            attach.run(req.params.id, pid);
          }
        }
      }

      const row = db
        .prepare('SELECT * FROM videos WHERE id = ?')
        .get(req.params.id) as Record<string, unknown>;
      return { code: 0, data: rowToVideo(row) };
    },
  );

  // PATCH /api/videos/:id - 更新视频状态（仅商家）
  app.patch<{ Params: { id: string }; Body: { status?: unknown } }>(
    '/api/videos/:id',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return;
      const db = getDb();

      const existing = db
        .prepare('SELECT id FROM videos WHERE id = ?')
        .get(req.params.id) as { id: string } | undefined;
      if (!existing) {
        reply.status(404).send({ code: 404, message: '视频不存在' });
        return;
      }

      const status = asString(req.body?.status);
      if (!VALID_VIDEO_STATUSES.has(status)) {
        reply.status(400).send({
          code: 400,
          message: "status 必须是 'draft' / 'published' / 'inactive'",
        });
        return;
      }

      db.prepare(
        "UPDATE videos SET status = ?, updated_at = datetime('now') WHERE id = ?",
      ).run(status, req.params.id);

      const row = db
        .prepare('SELECT * FROM videos WHERE id = ?')
        .get(req.params.id) as Record<string, unknown>;
      return { code: 0, data: rowToVideo(row) };
    },
  );

  // DELETE /api/videos/:id - 软删除视频（仅商家）
  // Marks the row as 'deleted' so it's hidden from every list view but the row
  // stays put — orders.items, comments.video_id, products.video_id all keep
  // their references intact.
  app.delete<{ Params: { id: string } }>(
    '/api/videos/:id',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return;
      const db = getDb();

      const info = db
        .prepare(
          "UPDATE videos SET status = 'deleted', updated_at = datetime('now') WHERE id = ? AND status != 'deleted'",
        )
        .run(req.params.id);

      if (info.changes === 0) {
        reply.status(404).send({ code: 404, message: '视频不存在' });
        return;
      }

      return { code: 0, data: { id: req.params.id } };
    },
  );

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

  app.post('/api/videos/ai-video-info', async (req, reply) => {
    try {
      const { product_name, product_description, product_category, product_tags } = req.body;

      if (!product_name) {
        reply.status(400).send({ code: 400, message: '商品名称不能为空' });
        return;
      }

      const prompt = `基于以下商品信息，生成一个吸引人的短视频标题和描述。

  商品名称：${product_name}
  商品类目：${product_category}
  商品描述：${product_description}
  商品标签：${product_tags?.join('、')}

  要求：
  - 标题：20字以内，吸引眼球，适合短视频平台
  - 描述：50-80字，突出卖点，引导购买

  请以JSON格式返回：{"title": "标题", "description": "描述"}`;

      const response = await fetch('https://api.deepseek.com/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'deepseek-chat',
          messages: [
            { role: 'system', content: '你是短视频内容创作者，擅长写吸引人的标题和描述。' },
            { role: 'user', content: prompt },
          ],
          temperature: 0.8,
          max_tokens: 200,
        }),
      });

      if (!response.ok) {
        throw new Error(`AI API 错误: ${response.status}`);
      }

      const data = await response.json();
      const content = data.choices[0].message.content;

      // 解析 AI 返回的 JSON
      let result;
      try {
        result = JSON.parse(content);
      } catch {
        // 如果不是标准 JSON，尝试提取
        const titleMatch = content.match(/标题[：:]\s*["']?(.+?)["']?[\n,]/);
        const descMatch = content.match(/描述[：:]\s*["']?(.+?)["']?$/);
        result = {
          title: titleMatch?.[1] || `${product_name}，真的好用`,
          description: descMatch?.[1] || `${product_name}，${product_description?.slice(0, 50)}...`,
        };
      }

      return { code: 0, data: result };

    } catch (error) {
      // 降级方案
      const fallbackTitle = `${req.body.product_name} | 限时优惠，速来抢购`;
      const fallbackDesc = `${req.body.product_name}，${req.body.product_description?.slice(0, 50) || '品质之选'}。错过今天等一年！`;

      return {
        code: 0,
        data: {
          title: fallbackTitle,
          description: fallbackDesc,
          fallback: true
        }
      };
    }
  });
}
