import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';

export async function liveRoutes(app: FastifyInstance) {
  // GET /api/live/rooms - 直播间列表
  app.get('/api/live/rooms', async () => {
    const db = getDb();

    const videos = db.prepare(
      "SELECT * FROM videos WHERE status = 'published' ORDER BY play_count DESC LIMIT 5"
    ).all() as Array<Record<string, unknown>>;

    const rooms = videos.map((v) => ({
      id: v.id,
      title: v.title,
      cover_url: v.cover_url,
      video_url: v.video_url,
      author_id: v.author_id,
      author_name: v.author_name,
      author_avatar: v.author_avatar,
      online_count: Math.floor(Math.random() * 500) + 50,
      tags: JSON.parse(v.tags as string),
    }));

    return {
      code: 0,
      data: { list: rooms },
    };
  });

  // GET /api/live/rooms/:id - 直播间详情
  app.get('/api/live/rooms/:id', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const video = db.prepare('SELECT * FROM videos WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!video) {
      return { code: 404, message: '直播间不存在' };
    }

    const products = db.prepare(
      "SELECT * FROM products WHERE video_id = ? AND status = 'on'"
    ).all(req.params.id) as Array<Record<string, unknown>>;

    // Get available coupons
    const coupons = db.prepare(
      "SELECT * FROM coupons WHERE status = 'active' AND end_time > datetime('now') LIMIT 3"
    ).all() as Array<Record<string, unknown>>;

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
        coupons: coupons.map((c) => ({
          id: c.id,
          title: c.title,
          amount: c.amount,
          min_order: c.min_order,
          total_count: c.total_count,
          used_count: c.used_count,
          end_time: c.end_time,
        })),
      },
    };
  });

  // POST /api/live/gift - 发送礼物
  app.post('/api/live/gift', async (req) => {
    const { user_id, gift_id, gift_name, price, room_id } = req.body as {
      user_id: string; gift_id: string; gift_name: string; price: number; room_id: string;
    };
    const db = getDb();

    const user = db.prepare('SELECT id FROM users WHERE id = ?').get(user_id);
    if (!user) {
      return { code: 404, message: '用户不存在' };
    }

    return {
      code: 0,
      data: { user_id, gift_id, gift_name, price, room_id, timestamp: new Date().toISOString() },
    };
  });
}
