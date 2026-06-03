import { FastifyInstance, FastifyRequest } from 'fastify';
import { v4 as uuid } from 'uuid';
import { getDb } from '../db/schema.js';
import { getIO } from '../websocket/live.js';
import { requireMerchant } from '../middleware/auth.js';

interface LiveRoomRow {
  id: string;
  title: string;
  cover_url: string;
  video_url: string;
  author_id: string;
  author_name: string;
  author_avatar: string;
  status: 'preview' | 'live' | 'ended';
  product_ids: string;
  current_product_id: string | null;
  tags: string;
  heat_count: number;
  like_count: number;
  started_at: string | null;
  ended_at: string | null;
  created_at: string;
  updated_at: string;
}

function safeJsonParse<T>(raw: string | null | undefined, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

function serializeRoom(row: LiveRoomRow, onlineCount = 0): Record<string, unknown> {
  return {
    id: row.id,
    title: row.title,
    cover_url: row.cover_url,
    video_url: row.video_url,
    author_id: row.author_id,
    author_name: row.author_name,
    author_avatar: row.author_avatar,
    online_count: onlineCount,
    heat_count: row.heat_count,
    like_count: row.like_count,
    tags: safeJsonParse<string[]>(row.tags, []),
    status: row.status,
    product_ids: safeJsonParse<string[]>(row.product_ids, []),
    current_product_id: row.current_product_id,
    started_at: row.started_at,
    ended_at: row.ended_at,
  };
}

function fakeOnline(): number {
  return Math.floor(Math.random() * 500) + 50;
}

export async function liveRoutes(app: FastifyInstance) {
  // ============ 商家：我的直播间列表 ============
  // NOTE: 此路由必须先于 /api/live/rooms/:id 注册，避免 "mine" 被匹配为 id
  app.get('/api/live/rooms/mine', { preHandler: requireMerchant }, async (req) => {
    const db = getDb();
    const userId = req.user!.userId;
    const rows = db.prepare(
      'SELECT * FROM live_rooms WHERE author_id = ? ORDER BY (status = \'live\') DESC, created_at DESC'
    ).all(userId) as LiveRoomRow[];

    return {
      code: 0,
      data: { list: rows.map((r) => serializeRoom(r, fakeOnline())) },
    };
  });

  // ============ 商家：创建直播间 ============
  app.post('/api/live/rooms', { preHandler: requireMerchant }, async (req, reply) => {
    const db = getDb();
    const userId = req.user!.userId;

    const body = (req.body ?? {}) as {
      title?: string;
      cover_url?: string;
      product_ids?: string[];
      tags?: string[];
      video_url?: string;
    };

    const title = body.title?.trim() ?? '';
    const coverUrl = body.cover_url?.trim() ?? '';
    const productIds = Array.isArray(body.product_ids) ? body.product_ids : [];
    const tags = Array.isArray(body.tags) ? body.tags : [];
    const videoUrl = body.video_url?.trim() ?? '';

    if (!title) {
      return reply.status(400).send({ code: 400, message: '请填写直播标题' });
    }
    if (!coverUrl) {
      return reply.status(400).send({ code: 400, message: '请上传直播封面' });
    }
    if (productIds.length === 0) {
      return reply.status(400).send({ code: 400, message: '请至少选择一件讲解商品' });
    }

    // 校验商品存在且上架
    const placeholders = productIds.map(() => '?').join(',');
    const validCount = db.prepare(
      `SELECT COUNT(*) as cnt FROM products WHERE id IN (${placeholders}) AND status = 'on'`
    ).get(...productIds) as { cnt: number };
    if (validCount.cnt !== productIds.length) {
      return reply.status(400).send({ code: 400, message: '存在无效或已下架的商品' });
    }

    const user = db.prepare(
      'SELECT id, nickname, avatar FROM users WHERE id = ?'
    ).get(userId) as { id: string; nickname: string; avatar: string } | undefined;
    if (!user) {
      return reply.status(404).send({ code: 404, message: '用户不存在' });
    }

    const id = uuid();
    db.prepare(`
      INSERT INTO live_rooms (
        id, title, cover_url, video_url,
        author_id, author_name, author_avatar,
        status, product_ids, tags
      ) VALUES (?, ?, ?, ?, ?, ?, ?, 'preview', ?, ?)
    `).run(
      id,
      title,
      coverUrl,
      videoUrl,
      user.id,
      user.nickname,
      user.avatar ?? '',
      JSON.stringify(productIds),
      JSON.stringify(tags),
    );

    const row = db.prepare('SELECT * FROM live_rooms WHERE id = ?').get(id) as LiveRoomRow;

    return {
      code: 0,
      data: serializeRoom(row, 0),
      message: '直播间创建成功',
    };
  });

  // ============ 商家：开始直播 ============
  app.post('/api/live/rooms/:id/start', { preHandler: requireMerchant }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const userId = req.user!.userId;
    const db = getDb();

    const row = db.prepare('SELECT * FROM live_rooms WHERE id = ?').get(id) as LiveRoomRow | undefined;
    if (!row) {
      return reply.status(404).send({ code: 404, message: '直播间不存在' });
    }
    if (row.author_id !== userId) {
      return reply.status(403).send({ code: 403, message: '无权操作他人直播间' });
    }
    if (row.status === 'live') {
      return { code: 0, data: serializeRoom(row, fakeOnline()), message: '直播已在进行中' };
    }
    if (row.status === 'ended') {
      return reply.status(400).send({ code: 400, message: '直播已结束，无法重新开始' });
    }

    db.prepare(`
      UPDATE live_rooms
      SET status = 'live', started_at = datetime('now'), updated_at = datetime('now')
      WHERE id = ?
    `).run(id);

    const updated = db.prepare('SELECT * FROM live_rooms WHERE id = ?').get(id) as LiveRoomRow;

    try {
      getIO().to(id).emit('room_status', {
        room_id: id,
        status: 'live',
        timestamp: new Date().toISOString(),
      });
    } catch {
      // WebSocket 尚未就绪，忽略广播失败
    }

    return { code: 0, data: serializeRoom(updated, 0), message: '直播已开始' };
  });

  // ============ 商家：结束直播 ============
  app.post('/api/live/rooms/:id/end', { preHandler: requireMerchant }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const userId = req.user!.userId;
    const db = getDb();

    const row = db.prepare('SELECT * FROM live_rooms WHERE id = ?').get(id) as LiveRoomRow | undefined;
    if (!row) {
      return reply.status(404).send({ code: 404, message: '直播间不存在' });
    }
    if (row.author_id !== userId) {
      return reply.status(403).send({ code: 403, message: '无权操作他人直播间' });
    }
    if (row.status === 'ended') {
      return { code: 0, data: serializeRoom(row, 0), message: '直播已结束' };
    }

    db.prepare(`
      UPDATE live_rooms
      SET status = 'ended', ended_at = datetime('now'), updated_at = datetime('now')
      WHERE id = ?
    `).run(id);

    const updated = db.prepare('SELECT * FROM live_rooms WHERE id = ?').get(id) as LiveRoomRow;

    try {
      getIO().to(id).emit('room_status', {
        room_id: id,
        status: 'ended',
        timestamp: new Date().toISOString(),
      });
    } catch {
      // ignore
    }

    return { code: 0, data: serializeRoom(updated, 0), message: '直播已结束' };
  });

  // ============ 商家：切换讲解商品 ============
  app.post('/api/live/rooms/:id/product', { preHandler: requireMerchant }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const { product_id } = (req.body ?? {}) as { product_id?: string };
    const userId = req.user!.userId;
    const db = getDb();

    if (!product_id) {
      return reply.status(400).send({ code: 400, message: '缺少 product_id' });
    }

    const row = db.prepare('SELECT * FROM live_rooms WHERE id = ?').get(id) as LiveRoomRow | undefined;
    if (!row) {
      return reply.status(404).send({ code: 404, message: '直播间不存在' });
    }
    if (row.author_id !== userId) {
      return reply.status(403).send({ code: 403, message: '无权操作他人直播间' });
    }

    const product = db.prepare(
      'SELECT * FROM products WHERE id = ?'
    ).get(product_id) as Record<string, unknown> | undefined;
    if (!product) {
      return reply.status(404).send({ code: 404, message: '商品不存在' });
    }

    db.prepare(
      'UPDATE live_rooms SET current_product_id = ?, updated_at = datetime(\'now\') WHERE id = ?'
    ).run(product_id, id);

    const serializedProduct = {
      ...product,
      tags: safeJsonParse<string[]>(product.tags as string, []),
      images: safeJsonParse<string[]>(product.images as string, []),
      specs: safeJsonParse<unknown[]>(product.specs as string, []),
    };

    try {
      getIO().to(id).emit('explaining_product', {
        product: serializedProduct,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      console.error('[HTTP] 广播讲解商品失败:', err);
    }

    return {
      code: 0,
      data: { room_id: id, product_id, product_name: product.name },
      message: '讲解商品已切换',
    };
  });

  // ============ 公共：直播间列表 ============
  app.get('/api/live/rooms', async () => {
    const db = getDb();

    const rows = db.prepare(`
      SELECT * FROM live_rooms
      WHERE status IN ('live', 'preview')
      ORDER BY (status = 'live') DESC, created_at DESC
      LIMIT 20
    `).all() as LiveRoomRow[];

    return {
      code: 0,
      data: { list: rows.map((r) => serializeRoom(r, fakeOnline())) },
    };
  });

  // ============ 公共：直播间详情 ============
  app.get('/api/live/rooms/:id', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const row = db.prepare('SELECT * FROM live_rooms WHERE id = ?').get(req.params.id) as
      | LiveRoomRow
      | undefined;

    if (!row) {
      return { code: 404, message: '直播间不存在' };
    }

    const productIds = safeJsonParse<string[]>(row.product_ids, []);
    let products: Array<Record<string, unknown>> = [];
    if (productIds.length > 0) {
      const placeholders = productIds.map(() => '?').join(',');
      products = db.prepare(
        `SELECT * FROM products WHERE id IN (${placeholders}) AND status = 'on'`
      ).all(...productIds) as Array<Record<string, unknown>>;
    }

    const coupons = db.prepare(
      "SELECT * FROM coupons WHERE status = 'active' AND end_time > datetime('now') LIMIT 3"
    ).all() as Array<Record<string, unknown>>;

    const serialized = serializeRoom(row, fakeOnline());

    return {
      code: 0,
      data: {
        ...serialized,
        products: products.map((p) => ({
          ...p,
          tags: safeJsonParse<string[]>(p.tags as string, []),
          images: safeJsonParse<string[]>(p.images as string, []),
          specs: safeJsonParse<unknown[]>(p.specs as string, []),
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

  // ============ 管理员：切换当前讲解商品（兼容旧接口） ============
  app.put('/api/live/rooms/:roomId/explaining_product', async (req, reply) => {
    const { roomId } = req.params as { roomId: string };
    const { product_id } = (req.body ?? {}) as { product_id?: string };
    const db = getDb();

    if (!product_id) {
      return reply.status(400).send({ code: 400, message: '缺少 product_id' });
    }

    const product = db.prepare(
      'SELECT * FROM products WHERE id = ?'
    ).get(product_id) as Record<string, unknown> | undefined;

    if (!product) {
      return reply.status(404).send({ code: 404, message: '商品不存在' });
    }

    db.prepare(
      'UPDATE live_rooms SET current_product_id = ?, updated_at = datetime(\'now\') WHERE id = ?'
    ).run(product_id, roomId);

    const serializedProduct = {
      ...product,
      tags: safeJsonParse<string[]>(product.tags as string, []),
      images: safeJsonParse<string[]>(product.images as string, []),
      specs: safeJsonParse<unknown[]>(product.specs as string, []),
    };

    try {
      getIO().to(roomId).emit('explaining_product', {
        product: serializedProduct,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      console.error('[HTTP] 广播讲解商品失败:', err);
    }

    return {
      code: 0,
      data: { room_id: roomId, product_id, product_name: product.name },
      message: '讲解商品已切换',
    };
  });

  // ============ 发送礼物（抖币扣减） ============
  app.post('/api/live/gift', async (req, reply) => {
    const { user_id, gift_id, gift_name, price, room_id } = req.body as {
      user_id: string;
      gift_id: string;
      gift_name: string;
      price: number;
      room_id: string;
    };
    const db = getDb();

    const user = db.prepare('SELECT id, coin_balance FROM users WHERE id = ?').get(user_id) as
      | { id: string; coin_balance: number }
      | undefined;
    if (!user) {
      return reply.status(404).send({ code: 404, message: '用户不存在' });
    }

    if (user.coin_balance < price) {
      return reply.status(422).send({
        code: 422,
        message: '抖币余额不足',
        data: { balance: user.coin_balance, need: price, diff: price - user.coin_balance },
      });
    }

    db.prepare(
      'UPDATE users SET coin_balance = coin_balance - ?, updated_at = datetime(\'now\') WHERE id = ?'
    ).run(price, user_id);

    const updated = db.prepare('SELECT coin_balance FROM users WHERE id = ?').get(user_id) as {
      coin_balance: number;
    };

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
