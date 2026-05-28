import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';
import crypto from 'node:crypto';

function processOrder(row: Record<string, unknown>) {
  return {
    ...row,
    items: JSON.parse(row.items as string),
    address: JSON.parse(row.address as string),
  };
}

export async function orderRoutes(app: FastifyInstance) {
  // POST /api/orders - 创建订单
  app.post('/api/orders', async (req: FastifyRequest<{ Body: {
    user_id: string;
    items: Array<{ product_id: string; spec?: string; quantity: number; cart_item_id?: string }>;
    address?: Record<string, string>;
    coupon_id?: string;
  } }>) => {
    const db = getDb();
    const { user_id, items, address = {}, coupon_id } = req.body;

    if (!items || items.length === 0) {
      return { code: 400, message: '订单商品不能为空' };
    }

    // Calculate amounts
    let totalAmount = 0;
    const orderItems: Array<Record<string, unknown>> = [];

    for (const item of items) {
      const product = db.prepare(
        'SELECT id, name, cover_url, price, stock FROM products WHERE id = ? AND status = ?'
      ).get(item.product_id, 'on') as Record<string, unknown> | undefined;

      if (!product) {
        return { code: 404, message: `商品 ${item.product_id} 不存在或已下架` };
      }
      if ((product.stock as number) < item.quantity) {
        return { code: 422, message: `商品 ${product.name} 库存不足` };
      }

      const subtotal = (product.price as number) * item.quantity;
      totalAmount += subtotal;

      orderItems.push({
        product_id: product.id,
        product_name: product.name,
        product_cover: product.cover_url,
        product_price: product.price,
        spec: item.spec ?? '',
        quantity: item.quantity,
        subtotal,
      });

      // Deduct stock
      db.prepare('UPDATE products SET stock = stock - ?, sales = sales + ? WHERE id = ?').run(
        item.quantity, item.quantity, product.id
      );
    }

    // Apply coupon
    let discountAmount = 0;
    if (coupon_id) {
      const coupon = db.prepare(
        'SELECT * FROM coupons WHERE id = ? AND status = ?'
      ).get(coupon_id, 'active') as Record<string, unknown> | undefined;

      if (coupon && totalAmount >= (coupon.min_order as number)) {
        discountAmount = coupon.amount as number;
        db.prepare('UPDATE coupons SET used_count = used_count + 1 WHERE id = ?').run(coupon_id);
      }
    }

    const payAmount = Math.max(0, totalAmount - discountAmount);
    const orderId = crypto.randomUUID();

    const insertOrder = db.prepare(
      `INSERT INTO orders (id, user_id, total_amount, discount_amount, pay_amount, status, address, items)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    );
    insertOrder.run(
      orderId,
      user_id,
      totalAmount,
      discountAmount,
      payAmount,
      'pending',
      JSON.stringify(address),
      JSON.stringify(orderItems)
    );

    // Remove from cart
    for (const item of items) {
      if (item.cart_item_id) {
        db.prepare('DELETE FROM cart_items WHERE id = ?').run(item.cart_item_id);
      }
    }

    return {
      code: 0,
      data: {
        id: orderId,
        total_amount: totalAmount,
        discount_amount: discountAmount,
        pay_amount: payAmount,
        status: 'pending',
        items: orderItems,
      },
    };
  });

  // GET /api/orders/:user_id - 订单列表
  app.get('/api/orders/:user_id', async (req: FastifyRequest<{ Params: { user_id: string }; Querystring: { status?: string; page?: string; page_size?: string } }>) => {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;

    let where = 'WHERE user_id = ?';
    const params: unknown[] = [req.params.user_id];
    if (req.query.status) {
      where += ' AND status = ?';
      params.push(req.query.status);
    }

    const total = (db.prepare(
      `SELECT COUNT(*) as count FROM orders ${where}`
    ).get(...params) as { count: number }).count;

    const orders = db.prepare(
      `SELECT * FROM orders ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`
    ).all(...params, pageSize, offset) as Array<Record<string, unknown>>;

    const list = orders.map((o) => ({
      ...o,
      items: JSON.parse(o.items as string),
      address: JSON.parse(o.address as string),
    }));

    return { code: 0, data: { list, total, page, page_size: pageSize, has_more: offset + pageSize < total } };
  });

  // GET /api/orders/detail/:id - 订单详情
  app.get('/api/orders/detail/:id', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!order) {
      return { code: 404, message: '订单不存在' };
    }

    return {
      code: 0,
      data: {
        ...order,
        items: JSON.parse(order.items as string),
        address: JSON.parse(order.address as string),
      },
    };
  });

  // POST /api/orders/:id/pay - 模拟支付（支持微信、支付宝、抖币）
  app.post('/api/orders/:id/pay', async (req: FastifyRequest<{ Params: { id: string }; Body: { payment_method?: string } }>) => {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!order) {
      return { code: 404, message: '订单不存在' };
    }
    if (order.status !== 'pending') {
      return { code: 422, message: '订单状态不允许支付' };
    }

    const paymentMethod = req.body?.payment_method || 'wechat';
    const payAmount = order.pay_amount as number;

    // 抖币支付处理
    if (paymentMethod === 'coin') {
      const user = db.prepare('SELECT id, coin_balance FROM users WHERE id = ?').get(order.user_id as string) as { id: string; coin_balance: number } | undefined;
      if (!user) {
        return { code: 404, message: '用户不存在' };
      }
      // coin_balance 单位是抖币（1:1对应人民币），需足够支付
      if (user.coin_balance < payAmount) {
        return { code: 422, message: '抖币余额不足', data: { balance: user.coin_balance, need: payAmount } };
      }
      // 扣减余额
      db.prepare('UPDATE users SET coin_balance = coin_balance - ?, updated_at = datetime(\'now\') WHERE id = ?').run(payAmount, order.user_id as string);
    }

    // Simulate payment: 90% success
    const success = Math.random() > 0.1;
    const status = success ? 'paid' : 'payment_failed';

    db.prepare('UPDATE orders SET status = ?, updated_at = datetime(\'now\') WHERE id = ?').run(status, req.params.id);

    // 如果支付失败且是抖币支付，退还扣减的余额
    if (!success && paymentMethod === 'coin') {
      db.prepare('UPDATE users SET coin_balance = coin_balance + ?, updated_at = datetime(\'now\') WHERE id = ?').run(payAmount, order.user_id as string);
    }

    // 获取更新后的余额
    const updatedUser = db.prepare('SELECT coin_balance FROM users WHERE id = ?').get(order.user_id as string) as { coin_balance: number };

    return {
      code: 0,
      data: {
        status,
        message: success ? '支付成功' : '支付失败，请重试',
        new_balance: updatedUser.coin_balance,
      },
    };
  });

  // POST /api/orders/:id/confirm - 确认收货
  app.post('/api/orders/:id/confirm', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!order) {
      return { code: 404, message: '订单不存在' };
    }
    if (order.status !== 'paid') {
      return { code: 422, message: '仅已支付订单可以确认收货' };
    }

    db.prepare('UPDATE orders SET status = ?, updated_at = datetime(\'now\') WHERE id = ?').run('completed', req.params.id);

    const updated = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id) as Record<string, unknown>;

    return {
      code: 0,
      data: processOrder(updated),
    };
  });
}
