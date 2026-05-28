import crypto from 'node:crypto';
import { FastifyInstance } from 'fastify';
import { getDb } from '../db/schema.js';

// 充值套餐固定赠送规则（与前端 coin_recharge_page 的 _packages 保持一致）
const PACKAGE_BONUS: Record<number, number> = {
  6: 0,
  30: 3,
  98: 15,
  198: 45,
  328: 85,
  648: 200,
};

function getBonus(amount: number): number {
  // 如果金额匹配预置套餐，使用固定赠送
  if (PACKAGE_BONUS[amount] !== undefined) {
    return PACKAGE_BONUS[amount];
  }
  // 自定义金额：赠送比例为 5%（向下取整）
  if (amount > 0) {
    const bonus = Math.floor(amount * 0.05 * 100) / 100;
    return bonus > 0 ? bonus : 0;
  }
  return 0;
}

export async function rechargeRoutes(app: FastifyInstance) {
  // POST /api/recharge/create - 创建充值订单
  app.post('/api/recharge/create', async (req, reply) => {
    const { user_id, amount, payment_method } = req.body as {
      user_id: string;
      amount: number;
      payment_method: string;
    };

    if (!user_id || !amount || amount <= 0) {
      reply.status(400).send({ code: 400, message: '参数错误' });
      return;
    }

    if (!['wechat', 'alipay'].includes(payment_method)) {
      reply.status(400).send({ code: 400, message: '不支持的支付方式' });
      return;
    }

    const db = getDb();

    // 检查用户是否存在
    const user = db.prepare('SELECT id FROM users WHERE id = ?').get(user_id);
    if (!user) {
      reply.status(404).send({ code: 404, message: '用户不存在' });
      return;
    }

    // 根据充值金额计算赠送（预置套餐固定赠送，自定义金额 5%）
    const bonusAmount = getBonus(amount);
    const totalCoins = Math.round((amount + bonusAmount) * 100) / 100;
    const orderId = `R${Date.now()}${crypto.randomUUID().slice(0, 8)}`;

    // 创建充值记录
    db.prepare(`
      INSERT INTO recharge_records (id, user_id, amount, bonus_amount, total_coins, payment_method, status)
      VALUES (?, ?, ?, ?, ?, ?, 'success')
    `).run(orderId, user_id, amount, bonusAmount, totalCoins, payment_method);

    // 更新用户抖币余额
    db.prepare(`
      UPDATE users SET coin_balance = coin_balance + ?, updated_at = datetime('now')
      WHERE id = ?
    `).run(totalCoins, user_id);

    // 获取更新后的余额
    const updated = db.prepare('SELECT coin_balance FROM users WHERE id = ?').get(user_id) as {
      coin_balance: number;
    };

    return {
      code: 0,
      data: {
        order_id: orderId,
        amount,
        bonus_amount: bonusAmount,
        total_coins: totalCoins,
        payment_method,
        new_balance: updated.coin_balance,
      },
    };
  });

  // GET /api/recharge/records/:userId - 获取充值记录
  app.get('/api/recharge/records/:userId', async (req) => {
    const db = getDb();
    const userId = (req.params as Record<string, string>).userId;

    const records = db
      .prepare(
        'SELECT * FROM recharge_records WHERE user_id = ? ORDER BY created_at DESC LIMIT 50'
      )
      .all(userId);

    return { code: 0, data: { list: records } };
  });

  // GET /api/users/:id/coins - 获取用户抖币余额（复用用户信息路由或独立接口）
  app.get('/api/users/:id/coins', async (req) => {
    const db = getDb();
    const userId = (req.params as Record<string, string>).id;

    const user = db
      .prepare('SELECT id, coin_balance FROM users WHERE id = ?')
      .get(userId) as { id: string; coin_balance: number } | undefined;

    if (!user) {
      return { code: 404, message: '用户不存在' };
    }

    return { code: 0, data: { coin_balance: user.coin_balance } };
  });
}
