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
      const replyContent = '您好，我是智能助手小抖！收到您的售后咨询，请问有什么可以帮您的？如果您需要转接人工客服，请点击上方的「转人工」按钮。';
      db.prepare(`
        INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
        VALUES (?, ?, ?, 'ai', ?, 'text', ?)
      `).run(replyId, order_id, user_id, replyContent, now);

      results.push({
        id: replyId,
        order_id,
        user_id,
        sender_type: 'ai',
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

  // ==================== 转接人工客服 ====================
  // POST /api/customer-service/transfer
  // Body: { order_id, user_id }
  app.post('/api/customer-service/transfer', async (req, res) => {
    const { order_id, user_id } = req.body as {
      order_id: string;
      user_id: string;
    };

    if (!order_id || !user_id) {
      return res.status(400).send({ code: 1, message: '缺少必要参数' });
    }

    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

    // 插入转接系统提示
    const sysId = crypto.randomUUID();
    const systemContent = '您已转接人工客服，正在为您分配客服人员，请稍候...';
    db.prepare(`
      INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
      VALUES (?, ?, ?, 'system', ?, 'text', ?)
    `).run(sysId, order_id, user_id, systemContent, now);

    // 插入人工客服欢迎语
    const humanId = crypto.randomUUID();
    const humanContent = '您好，我是人工客服小美，很高兴为您服务！请问有什么可以帮助您的？';
    db.prepare(`
      INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
      VALUES (?, ?, ?, 'admin', ?, 'text', ?)
    `).run(humanId, order_id, user_id, humanContent, now);

    const results = [
      {
        id: sysId,
        order_id,
        user_id,
        sender_type: 'system',
        content: systemContent,
        msg_type: 'text',
        created_at: now,
      },
      {
        id: humanId,
        order_id,
        user_id,
        sender_type: 'admin',
        content: humanContent,
        msg_type: 'text',
        created_at: now,
      },
    ];

    return res.send({ code: 0, data: { messages: results } });
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
