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
  // POST /api/orders/direct - 直接下单（不经过购物车，从视频/直播立即购买）
  app.post('/api/orders/direct', async (req: FastifyRequest<{ Body: {
    user_id: string;
    product_id: string;
    quantity?: number;
    spec?: string;
    address?: Record<string, string>;
    coupon_id?: string;
  } }>) => {
    const db = getDb();
    const { user_id, product_id, quantity = 1, spec = '', address = {}, coupon_id } = req.body;

    if (!product_id) {
      return { code: 400, message: '商品 ID 不能为空' };
    }

    // 查询商品
    const product = db.prepare(
      'SELECT id, name, cover_url, price, stock FROM products WHERE id = ? AND status = ?'
    ).get(product_id, 'on') as Record<string, unknown> | undefined;

    if (!product) {
      return { code: 404, message: '商品不存在或已下架' };
    }
    if ((product.stock as number) < quantity) {
      return { code: 422, message: `商品 ${product.name} 库存不足` };
    }

    // 计算金额
    const totalAmount = (product.price as number) * quantity;

    // 应用优惠券
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

    const orderItems = [{
      product_id: product.id,
      product_name: product.name,
      product_cover: product.cover_url,
      product_price: product.price,
      spec,
      quantity,
      subtotal: totalAmount,
    }];

    const orderId = crypto.randomUUID();

    // 扣减库存
    db.prepare('UPDATE products SET stock = stock - ?, sales = sales + ? WHERE id = ?').run(
      quantity, quantity, product_id
    );

    // 创建订单
    db.prepare(
      `INSERT INTO orders (id, user_id, total_amount, discount_amount, pay_amount, status, address, items)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      orderId,
      user_id,
      totalAmount,
      discountAmount,
      payAmount,
      'pending',
      JSON.stringify(address),
      JSON.stringify(orderItems)
    );

    return {
      code: 0,
      data: {
        id: orderId,
        total_amount: totalAmount,
        discount_amount: discountAmount,
        pay_amount: payAmount,
        status: 'pending',
        items: orderItems,
        product_id,
        quantity,
      },
    };
  });

  // POST /api/orders - 创建订单（从购物车结算）
  app.post('/api/orders', async (req: FastifyRequest<{ Body: {
    user_id: string;
    items: Array<{ product_id: string; spec?: string; quantity: number; cart_item_id?: string; coupon_discount?: number }>;
    address?: Record<string, string>;
    coupon_id?: string;
    pay_amount?: number;
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
        coupon_discount: item.coupon_discount ?? 0,
      });

      // Deduct stock
      db.prepare('UPDATE products SET stock = stock - ?, sales = sales + ? WHERE id = ?').run(
        item.quantity, item.quantity, product.id
      );
    }

    // 优先使用客户端传入的实付金额（含优惠券计算），否则走服务端优惠券逻辑
    let discountAmount = 0;
    let payAmount: number;

    if (req.body.pay_amount !== undefined && typeof req.body.pay_amount === 'number') {
      payAmount = req.body.pay_amount;
      discountAmount = Math.max(0, totalAmount - payAmount);
    } else if (coupon_id) {
      const coupon = db.prepare(
        'SELECT * FROM coupons WHERE id = ? AND status = ?'
      ).get(coupon_id, 'active') as Record<string, unknown> | undefined;

      if (coupon && totalAmount >= (coupon.min_order as number)) {
        discountAmount = coupon.amount as number;
        db.prepare('UPDATE coupons SET used_count = used_count + 1 WHERE id = ?').run(coupon_id);
      }
      payAmount = Math.max(0, totalAmount - discountAmount);
    } else {
      payAmount = totalAmount;
    }
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

    const list = orders.map((o) => {
      const oid = o.id as string;
      const refundedRows = db.prepare(
        'SELECT DISTINCT product_id FROM refund_records WHERE order_id = ?'
      ).all(oid) as Array<{ product_id: string }>;
      return {
        ...o,
        items: JSON.parse(o.items as string),
        address: JSON.parse(o.address as string),
        refunded_product_ids: refundedRows.map(r => r.product_id),
      };
    });

    return { code: 0, data: { list, total, page, page_size: pageSize, has_more: offset + pageSize < total } };
  });

  // GET /api/orders/detail/:id - 订单详情
  app.get('/api/orders/detail/:id', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!order) {
      return { code: 404, message: '订单不存在' };
    }

    const oid = order.id as string;
    const refundedRows = db.prepare(
      'SELECT DISTINCT product_id FROM refund_records WHERE order_id = ?'
    ).all(oid) as Array<{ product_id: string }>;

    return {
      code: 0,
      data: {
        ...order,
        items: JSON.parse(order.items as string),
        address: JSON.parse(order.address as string),
        refunded_product_ids: refundedRows.map(r => r.product_id),
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

  // POST /api/orders/:id/refund - 退货退款（商品级别退款，不改变订单整体状态）
  app.post('/api/orders/:id/refund', async (req: FastifyRequest<{ Params: { id: string }; Body: { product_id: string; reason: string } }>) => {
    const db = getDb();
    const orderId = req.params.id;
    const { product_id, reason } = req.body;

    if (!product_id || !reason) {
      return { code: 400, message: '参数错误：缺少商品ID或退款原因' };
    }

    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId) as Record<string, unknown> | undefined;

    if (!order) {
      return { code: 404, message: '订单不存在' };
    }
    if (order.status !== 'completed') {
      return { code: 422, message: '仅已完成订单可以申请退款' };
    }

    // 检查该商品是否已经退过款
    const existingRefund = db.prepare(
      'SELECT id FROM refund_records WHERE order_id = ? AND product_id = ?'
    ).get(orderId, product_id) as Record<string, unknown> | undefined;
    if (existingRefund) {
      return { code: 422, message: '该商品已申请过退款' };
    }

    const items = JSON.parse(order.items as string) as Array<Record<string, unknown>>;
    const targetItem = items.find((item) => item.product_id === product_id);

    if (!targetItem) {
      return { code: 404, message: '订单中未找到该商品' };
    }

    const quantity = targetItem.quantity as number;
    const productPrice = targetItem.product_price as number;
    const totalAmount = order.total_amount as number;
    const payAmount = order.pay_amount as number;

    // 退款公式（区分商品券和满减券）：
    // ① 商品券后价格 = 原价×数量 - 商品券折扣（商品独立优惠，全额退回）
    const itemCouponDiscount = (targetItem.coupon_discount as number) ?? 0;
    const itemSubtotal = productPrice * quantity;
    const itemAfterProductCoupon = itemSubtotal - itemCouponDiscount;

    // ② 满减券按各商品券后价比例分摊
    // 满减总面额 = 商品总额 - 实付金额 - 所有商品券折扣之和
    const totalProductCouponDiscount = items.reduce(
      (sum, it) => sum + ((it.coupon_discount as number) ?? 0), 0
    );
    const fullReductionAmount = totalAmount - payAmount - totalProductCouponDiscount;

    // 该商品券后价 / 所有商品券后总价 → 满减分摊比例
    const totalAfterProductCoupon = totalAmount - totalProductCouponDiscount;
    const fullReductionRatio = totalAfterProductCoupon > 0
      ? itemAfterProductCoupon / totalAfterProductCoupon
      : 0;
    const itemFullReductionShare = fullReductionAmount * fullReductionRatio;

    // ③ 退款 = 商品券后价 - 该商品承担的满减
    const refundAmount = Math.round((itemAfterProductCoupon - itemFullReductionShare) * 100) / 100;

    // 注意：不修改订单 status，订单保持 'completed' 状态不变
    // 退款仅通过 refund_records 表记录

    // 退还抖币到用户余额
    db.prepare('UPDATE users SET coin_balance = coin_balance + ?, updated_at = datetime(\'now\') WHERE id = ?').run(refundAmount, order.user_id as string);

    // 插入退款记录
    const refundId = `RF${Date.now()}${crypto.randomUUID().slice(0, 8)}`;
    db.prepare(`
      INSERT INTO refund_records (id, order_id, user_id, product_id, product_name, quantity, refund_amount, reason)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(refundId, orderId, order.user_id as string, product_id, targetItem.product_name as string, quantity, refundAmount, reason);

    // 查询该订单所有已退款商品ID
    const refundedRows = db.prepare(
      'SELECT DISTINCT product_id FROM refund_records WHERE order_id = ?'
    ).all(orderId) as Array<{ product_id: string }>;
    const refundedProductIds = refundedRows.map(r => r.product_id);

    // 获取更新后的余额
    const updated = db.prepare('SELECT coin_balance FROM users WHERE id = ?').get(order.user_id as string) as { coin_balance: number };

    return {
      code: 0,
      data: {
        refund_id: refundId,
        refund_amount: refundAmount,
        refunded_product_ids: refundedProductIds,
        new_balance: updated.coin_balance,
        message: '退款成功，抖币已退还到您的账户',
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
