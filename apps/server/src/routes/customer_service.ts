import { FastifyInstance } from 'fastify';
import { getDb } from '../db/schema.js';
import crypto from 'node:crypto';

interface CsMessage {
  id: string;
  order_id: string;
  user_id: string;
  sender_type: string;
  content: string;
  msg_type: string;
  created_at: string;
}

export async function customerServiceRoutes(app: FastifyInstance) {
  const db = getDb();

  // ==================== 用户发送消息 ====================
  // POST /api/customer-service/send
  // Body: { order_id, user_id, content, msg_type? }
  app.post('/api/customer-service/send', async (req, res) => {
    const { order_id, user_id, content, msg_type } = req.body as {
      order_id: string;
      user_id: string;
      content: string;
      msg_type?: string;
    };

    if (!order_id || !user_id || !content) {
      return res.status(400).send({ code: 1, message: '缺少必要参数' });
    }

    // 验证订单是否存在
    const order = db.prepare('SELECT id FROM orders WHERE id = ?').get(order_id);
    if (!order) {
      return res.status(404).send({ code: 1, message: '订单不存在' });
    }

    const id = crypto.randomUUID();
    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

    db.prepare(`
      INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
      VALUES (?, ?, ?, 'user', ?, ?, ?)
    `).run(id, order_id, user_id, content, msg_type || 'text', now);

    // 如果是用户首次发消息（该订单只有这一条消息），自动插入客服欢迎回复
    const count = db.prepare(
      'SELECT COUNT(*) as cnt FROM customer_service_messages WHERE order_id = ?'
    ).get(order_id) as { cnt: number };

    const results: CsMessage[] = [
      {
        id,
        order_id,
        user_id,
        sender_type: 'user',
        content,
        msg_type: msg_type || 'text',
        created_at: now,
      },
    ];

    if (count.cnt === 1) {
      const replyId = crypto.randomUUID();
      const replyContent = '您好，很高兴为您服务！您的售后咨询已收到，我会尽快为您处理。请问还有什么可以帮您的吗？';
      db.prepare(`
        INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
        VALUES (?, ?, ?, 'admin', ?, 'text', ?)
      `).run(replyId, order_id, user_id, replyContent, now);

      results.push({
        id: replyId,
        order_id,
        user_id,
        sender_type: 'admin',
        content: replyContent,
        msg_type: 'text',
        created_at: now,
      });
    }

    return res.send({ code: 0, data: { messages: results } });
  });

  // ==================== 获取聊天历史 ====================
  // GET /api/customer-service/messages/:orderId?userId=xxx
  app.get('/api/customer-service/messages/:orderId', async (req, res) => {
    const { orderId } = req.params as { orderId: string };
    const { userId } = req.query as { userId?: string };

    if (!orderId) {
      return res.status(400).send({ code: 1, message: '缺少订单ID' });
    }

    let stmt = 'SELECT * FROM customer_service_messages WHERE order_id = ?';
    const params: (string | number)[] = [orderId];

    if (userId) {
      stmt += ' AND user_id = ?';
      params.push(userId);
    }

    stmt += ' ORDER BY created_at ASC';

    const messages = db.prepare(stmt).all(...params) as CsMessage[];

    return res.send({ code: 0, data: { messages } });
  });

  // ==================== 客服回复（供后续管理后台使用） ====================
  // POST /api/customer-service/reply
  // Body: { order_id, user_id, content }
  app.post('/api/customer-service/reply', async (req, res) => {
    const { order_id, user_id, content } = req.body as {
      order_id: string;
      user_id: string;
      content: string;
    };

    if (!order_id || !user_id || !content) {
      return res.status(400).send({ code: 1, message: '缺少必要参数' });
    }

    const id = crypto.randomUUID();
    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

    db.prepare(`
      INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
      VALUES (?, ?, ?, 'admin', ?, 'text', ?)
    `).run(id, order_id, user_id, content, now);

    const message: CsMessage = {
      id,
      order_id,
      user_id,
      sender_type: 'admin',
      content,
      msg_type: 'text',
      created_at: now,
    };

    return res.send({ code: 0, data: { message } });
  });
}
