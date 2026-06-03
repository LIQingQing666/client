import { FastifyInstance } from 'fastify';
import { getDb } from '../db/schema.js';
import crypto from 'node:crypto';
import { askAI, getWelcomeMessage, type ChatMessage } from '../services/langchain_cs.js';

/**
 * 内存中的历史会话记录
 * key: `${order_id}:${user_id}`
 * 生产环境可改用 Redis 或数据库持久化
 */
const sessionHistory = new Map<string, ChatMessage[]>();

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

  // ==================== 用户发送消息（接入 AI 智能回复） ====================
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

    // 订单卡片消息：保存卡片 + 生成 AI 欢迎语（首次进入时自动自我介绍）
    if (msg_type === 'order_card') {
      const sessionKey = `${order_id}:${user_id}`;
      const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

      // 保存订单卡片消息
      const cardId = crypto.randomUUID();
      db.prepare(`
        INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
        VALUES (?, ?, ?, 'user', ?, ?, ?)
      `).run(cardId, order_id, user_id, content, msg_type, now);

      const cardMessage: CsMessage = {
        id: cardId, order_id, user_id, sender_type: 'user',
        content, msg_type, created_at: now,
      };

      // 生成 AI 欢迎语（自我介绍）
      const welcomeMsg = getWelcomeMessage();
      const welcomeId = crypto.randomUUID();
      db.prepare(`
        INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
        VALUES (?, ?, ?, 'ai', ?, 'text', ?)
      `).run(welcomeId, order_id, user_id, welcomeMsg, now);

      const welcomeMessage: CsMessage = {
        id: welcomeId, order_id, user_id, sender_type: 'ai',
        content: welcomeMsg, msg_type: 'text', created_at: now,
      };

      // 初始化会话历史（包含欢迎语）
      const prevHistory: ChatMessage[] = [
        { role: 'assistant', content: welcomeMsg },
      ];
      sessionHistory.set(sessionKey, prevHistory);

      return res.send({
        code: 0,
        data: {
          messages: [cardMessage, welcomeMessage],
        },
      });
    }

    const now = new Date().toISOString().replace('T', ' ').slice(0, 19);

    // 保存用户消息到数据库
    const userMsgId = crypto.randomUUID();
    db.prepare(`
      INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
      VALUES (?, ?, ?, 'user', ?, ?, ?)
    `).run(userMsgId, order_id, user_id, content, msg_type || 'text', now);

    const userMessage: CsMessage = {
      id: userMsgId, order_id, user_id, sender_type: 'user',
      content: content, msg_type: msg_type || 'text', created_at: now,
    };

    // 判断是否是首次对话
    const sessionKey = `${order_id}:${user_id}`;
    const prevHistory = sessionHistory.get(sessionKey) || [];

    let aiReplyText: string;
    let isFirstMessage = false;

    if (prevHistory.length === 0) {
      // 首次消息：生成欢迎语 + AI 回复
      isFirstMessage = true;
      const welcomeMsg = getWelcomeMessage();
      // 先存欢迎语到历史（但不存数据库，因为下次加载会从数据库重建）
      prevHistory.push({ role: 'assistant', content: welcomeMsg });
      // 再调用 AI 针对用户问题生成回复
      aiReplyText = await askAI(content, prevHistory);
    } else {
      // 非首次消息：追加用户消息后调用 AI
      prevHistory.push({ role: 'user', content });
      aiReplyText = await askAI(content, prevHistory);
    }

    // 保存 AI 回复到数据库
    const aiMsgId = crypto.randomUUID();
    db.prepare(`
      INSERT INTO customer_service_messages (id, order_id, user_id, sender_type, content, msg_type, created_at)
      VALUES (?, ?, ?, 'ai', ?, 'text', ?)
    `).run(aiMsgId, order_id, user_id, aiReplyText, now);

    const aiMessage: CsMessage = {
      id: aiMsgId, order_id, user_id, sender_type: 'ai',
      content: aiReplyText, msg_type: 'text', created_at: now,
    };

    // 更新历史记录（限制最大条数）
    prevHistory.push({ role: 'assistant', content: aiReplyText });
    if (prevHistory.length > 20) {
      // 保留最近 20 条
      sessionHistory.set(sessionKey, prevHistory.slice(-20));
    } else {
      sessionHistory.set(sessionKey, prevHistory);
    }

    return res.send({ code: 0, data: { messages: [userMessage, aiMessage] } });
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
