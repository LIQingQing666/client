import crypto from 'node:crypto';
import { FastifyInstance } from 'fastify';
import { getDb } from '../db/schema.js';
import { generateToken, hashPassword, verifyPassword } from '../middleware/auth.js';

export async function userRoutes(app: FastifyInstance) {
  // POST /api/auth/register
  app.post('/api/auth/register', async (req, reply) => {
    const { nickname, password, role } = req.body as {
      nickname?: string;
      password?: string;
      role?: string;
    };

    if (!nickname || !password) {
      reply.status(400).send({ code: 400, message: '用户名和密码不能为空' });
      return;
    }

    const db = getDb();
    const existing = db.prepare('SELECT id FROM users WHERE nickname = ?').get(nickname);
    if (existing) {
      reply.status(400).send({ code: 400, message: '用户名已存在' });
      return;
    }

    const userId = crypto.randomUUID();
    const hashed = hashPassword(password);
    const userRole = role === 'merchant' ? 'merchant' : 'user';

    db.prepare(
      'INSERT INTO users (id, nickname, password, role) VALUES (?, ?, ?, ?)',
    ).run(userId, nickname, hashed, userRole);

    const token = generateToken(userId, userRole);
    return {
      code: 0,
      data: { token, userId, nickname, avatar: '', role: userRole },
    };
  });

  // POST /api/auth/login
  app.post('/api/auth/login', async (req, reply) => {
    const { nickname, password } = req.body as {
      nickname?: string;
      password?: string;
    };

    if (!nickname || !password) {
      reply.status(400).send({ code: 400, message: '用户名和密码不能为空' });
      return;
    }

    const db = getDb();
    const user = db
      .prepare('SELECT id, nickname, avatar, password, role FROM users WHERE nickname = ?')
      .get(nickname) as
      | { id: string; nickname: string; avatar: string; password: string; role: string }
      | undefined;

    if (!user) {
      reply.status(401).send({ code: 401, message: '用户名或密码错误' });
      return;
    }

    if (!verifyPassword(password, user.password)) {
      reply.status(401).send({ code: 401, message: '用户名或密码错误' });
      return;
    }

    const token = generateToken(user.id, user.role);
    return {
      code: 0,
      data: {
        token,
        userId: user.id,
        nickname: user.nickname,
        avatar: user.avatar,
        role: user.role,
      },
    };
  });

  // GET /api/messages/:userId - 消息列表
  app.get('/api/messages/:userId', async (req) => {
    const userId = (req.params as Record<string, string>).userId;
    const messages = [
      { id: 'm1', userId, type: 'system', title: '系统通知', content: '欢迎来到 LiveCommerce！', detail: '感谢您的加入，平台为您准备了专属优惠券礼包。快去个人中心查看吧！', time: '2026-05-21 10:00', isRead: true },
      { id: 'm2', userId, type: 'like', title: '点赞通知', content: '你的评论获得了 32 个赞', detail: '你在视频《懒人必备！智能扫地机器人实测》中的评论获得了很多用户的认可，继续加油！', time: '2026-05-21 09:30', isRead: false },
      { id: 'm3', userId, type: 'coupon', title: '活动助手', content: '满200减50优惠券已发放到你的账户', detail: '满200减50优惠券已发放到你的账户，有效期至2026年6月21日。快去使用吧！', time: '2026-05-20 18:00', isRead: false },
      { id: 'm4', userId, type: 'order', title: '订单通知', content: '您的订单已发货，请注意查收', detail: '订单号：O20260520001，商品：智能扫地机器人已发货。预计3-5个工作日送达。', time: '2026-05-20 15:00', isRead: true },
      { id: 'm5', userId, type: 'follow', title: '关注通知', content: '小红穿搭关注了你', detail: '小红穿搭刚刚关注了你，去看看她的主页吧！', time: '2026-05-19 12:00', isRead: true },
    ];
    return { code: 0, data: { list: messages } };
  });
  // GET /api/users/:id - 用户信息
  app.get('/api/users/:id', async (req) => {
    const db = getDb();
    const user = db.prepare('SELECT id, nickname, avatar, phone FROM users WHERE id = ?').get(
      (req.params as Record<string, string>).id
    ) as Record<string, unknown> | undefined;

    if (!user) {
      return { code: 404, message: '用户不存在' };
    }

    // 订单数
    const orderCount = (db.prepare('SELECT COUNT(*) as count FROM orders WHERE user_id = ?').get(
      (req.params as Record<string, string>).id
    ) as { count: number }).count;

    // 购物车商品数
    const cartCount = (db.prepare('SELECT COUNT(*) as count FROM cart_items WHERE user_id = ?').get(
      (req.params as Record<string, string>).id
    ) as { count: number }).count;

    // 优惠券数量
    const couponCount = (db.prepare('SELECT COUNT(*) as count FROM user_coupons WHERE user_id = ? AND used = 0').get(
      (req.params as Record<string, string>).id
    ) as { count: number }).count;

    return {
      code: 0,
      data: {
        ...user,
        order_count: orderCount,
        cart_count: cartCount,
        coupon_count: couponCount,
      },
    };
  });

  // POST /api/users/:id/follow - 关注用户
  app.post('/api/users/:id/follow', async (req) => {
    const db = getDb();
    const targetId = (req.params as Record<string, string>).id;
    const { user_id } = req.body as { user_id: string };

    const existing = db.prepare(
      'SELECT id FROM follows WHERE follower_id = ? AND following_id = ?'
    ).get(user_id, targetId);

    if (existing) {
      return { code: 0, data: { followed: true } };
    }

    db.prepare('INSERT INTO follows (id, follower_id, following_id) VALUES (?, ?, ?)').run(
      crypto.randomUUID(), user_id, targetId
    );
    return { code: 0, data: { followed: true } };
  });

  // DELETE /api/users/:id/follow - 取消关注
  app.delete('/api/users/:id/follow', async (req) => {
    const db = getDb();
    const targetId = (req.params as Record<string, string>).id;
    const { user_id } = req.body as { user_id: string };

    db.prepare('DELETE FROM follows WHERE follower_id = ? AND following_id = ?').run(user_id, targetId);
    return { code: 0, data: { followed: false } };
  });

  // GET /api/users/:id/following - 关注列表
  app.get('/api/users/:id/following', async (req) => {
    const db = getDb();
    const userId = (req.params as Record<string, string>).id;
    const list = db.prepare(
      'SELECT u.id, u.nickname, u.avatar FROM follows f JOIN users u ON f.following_id = u.id WHERE f.follower_id = ?'
    ).all(userId) as Array<Record<string, unknown>>;
    return { code: 0, data: { list } };
  });

  // GET /api/users/:id/coupons - 用户优惠券
  app.get('/api/users/:id/coupons', async (req) => {
    const db = getDb();
    const coupons = db.prepare(
      `SELECT c.*, uc.used
       FROM user_coupons uc
       JOIN coupons c ON uc.coupon_id = c.id
       WHERE uc.user_id = ?
       ORDER BY c.amount DESC`
    ).all((req.params as Record<string, string>).id) as Array<Record<string, unknown>>;

    return { code: 0, data: { list: coupons } };
  });

  // PUT /api/users/:id - 修改用户信息
  app.put('/api/users/:id', async (req) => {
    const db = getDb();
    const userId = (req.params as Record<string, string>).id;
    const { nickname, avatar } = req.body as { nickname?: string; avatar?: string };

    const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
    if (!user) {
      return { code: 404, message: '用户不存在' };
    }

    if (nickname !== undefined) {
      db.prepare('UPDATE users SET nickname = ?, updated_at = datetime(\'now\') WHERE id = ?').run(nickname, userId);
    }
    if (avatar !== undefined) {
      db.prepare('UPDATE users SET avatar = ?, updated_at = datetime(\'now\') WHERE id = ?').run(avatar, userId);
    }

    const updated = db.prepare('SELECT id, nickname, avatar FROM users WHERE id = ?').get(userId);
    return { code: 0, data: updated };
  });

  // POST /api/users/:id/avatar - 上传头像
  app.post('/api/users/:id/avatar', async (req) => {
    const db = getDb();
    const userId = (req.params as Record<string, string>).id;
    const { avatar_url } = req.body as { avatar_url: string };

    db.prepare('UPDATE users SET avatar = ?, updated_at = datetime(\'now\') WHERE id = ?').run(avatar_url, userId);
    return { code: 0, data: { avatar: avatar_url } };
  });
}
