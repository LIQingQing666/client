import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';
import { getIO } from '../websocket/live.js';

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

  // PUT /api/live/rooms/:roomId/explaining_product - 切换当前讲解商品（Admin/主播触发）
  app.put('/api/live/rooms/:roomId/explaining_product', async (req, res) => {
    const { roomId } = req.params as { roomId: string };
    const { product_id } = req.body as { product_id: string };
    const db = getDb();

    const product = db.prepare(
      'SELECT id, name, cover_url, price, original_price, sales, ai_sales_point FROM products WHERE id = ?'
    ).get(product_id) as Record<string, unknown> | undefined;

    if (!product) {
      return res.status(404).send({ code: 404, message: '商品不存在' });
    }

    // Broadcast to all clients in the room via Socket.IO
    getIO().to(roomId).emit('explaining_product', {
      product,
      timestamp: new Date().toISOString(),
    });

    return {
      code: 0,
      data: { room_id: roomId, product_id, product_name: product.name },
      message: '讲解商品已切换',
    };
  });

  // POST /api/live/gift - 发送礼物（抖币扣减）
  app.post('/api/live/gift', async (req, reply) => {
    const { user_id, gift_id, gift_name, price, room_id } = req.body as {
      user_id: string; gift_id: string; gift_name: string; price: number; room_id: string;
    };
    const db = getDb();

    // 校验用户存在
    const user = db.prepare('SELECT id, coin_balance FROM users WHERE id = ?').get(user_id) as
      { id: string; coin_balance: number } | undefined;
    if (!user) {
      return reply.status(404).send({ code: 404, message: '用户不存在' });
    }

    // 校验余额是否足够
    if (user.coin_balance < price) {
      return reply.status(422).send({
        code: 422,
        message: '抖币余额不足',
        data: { balance: user.coin_balance, need: price, diff: price - user.coin_balance },
      });
    }

    // 扣减抖币
    db.prepare('UPDATE users SET coin_balance = coin_balance - ?, updated_at = datetime(\'now\') WHERE id = ?')
      .run(price, user_id);

    // 获取更新后余额
    const updated = db.prepare('SELECT coin_balance FROM users WHERE id = ?').get(user_id) as {
      coin_balance: number;
    };

    // 通过 WebSocket 广播礼物消息到直播间
    const io = getIO();
    io.to(room_id).emit('danmaku', {
      event: 'danmaku',
      id: `gift_${Date.now()}`,
      user_name: '赠送礼物',
      content: `${gift_name}`,
      type: 'system',
      timestamp: new Date().toISOString(),
    });

    return {
      code: 0,
      data: {
        user_id,
        gift_id,
        gift_name,
        price,
        room_id,
        new_balance: updated.coin_balance,
        timestamp: new Date().toISOString(),
      },
    };
  });
}
