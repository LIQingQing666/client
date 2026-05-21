import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';
import crypto from 'node:crypto';

export async function cartRoutes(app: FastifyInstance) {
  // GET /api/cart/:user_id - 购物车列表
  app.get('/api/cart/:user_id', async (req: FastifyRequest<{ Params: { user_id: string } }>) => {
    const db = getDb();
    const items = db.prepare(
      `SELECT ci.*, p.name as product_name, p.cover_url as product_cover, p.price as product_price,
              p.original_price as product_original_price, p.stock as product_stock, p.specs as product_specs
       FROM cart_items ci
       JOIN products p ON ci.product_id = p.id
       WHERE ci.user_id = ?
       ORDER BY ci.created_at DESC`
    ).all(req.params.user_id) as Array<Record<string, unknown>>;

    const list = items.map((item) => ({
      ...item,
      product_specs: JSON.parse(item.product_specs as string),
    }));

    return { code: 0, data: { list } };
  });

  // POST /api/cart - 加入购物车
  app.post('/api/cart', async (req: FastifyRequest<{ Body: { user_id: string; product_id: string; spec?: string; quantity?: number } }>) => {
    const db = getDb();
    const { user_id, product_id, spec = '', quantity = 1 } = req.body;

    // Check stock
    const product = db.prepare('SELECT stock, status FROM products WHERE id = ?').get(product_id) as
      | { stock: number; status: string }
      | undefined;
    if (!product || product.status !== 'on') {
      return { code: 404, message: '商品不存在或已下架' };
    }
    if (product.stock < quantity) {
      return { code: 422, message: '库存不足' };
    }

    // Check existing
    const existing = db.prepare(
      'SELECT id, quantity FROM cart_items WHERE user_id = ? AND product_id = ? AND spec = ?'
    ).get(user_id, product_id, spec) as { id: string; quantity: number } | undefined;

    if (existing) {
      const newQty = existing.quantity + quantity;
      if (newQty > product.stock) {
        return { code: 422, message: '库存不足' };
      }
      db.prepare('UPDATE cart_items SET quantity = ? WHERE id = ?').run(newQty, existing.id);
      return { code: 0, data: { id: existing.id, quantity: newQty } };
    }

    const id = crypto.randomUUID();
    db.prepare(
      'INSERT INTO cart_items (id, user_id, product_id, spec, quantity) VALUES (?, ?, ?, ?, ?)'
    ).run(id, user_id, product_id, spec, quantity);

    return { code: 0, data: { id, quantity } };
  });

  // PUT /api/cart/:id - 更新数量/选中状态
  app.put('/api/cart/:id', async (req: FastifyRequest<{ Params: { id: string }; Body: { quantity?: number; selected?: number } }>) => {
    const db = getDb();
    const item = db.prepare('SELECT * FROM cart_items WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!item) {
      return { code: 404, message: '购物车项目不存在' };
    }

    if (req.body.quantity !== undefined) {
      db.prepare('UPDATE cart_items SET quantity = ? WHERE id = ?').run(req.body.quantity, req.params.id);
    }
    if (req.body.selected !== undefined) {
      db.prepare('UPDATE cart_items SET selected = ? WHERE id = ?').run(req.body.selected, req.params.id);
    }

    return { code: 0, message: '更新成功' };
  });

  // DELETE /api/cart/:id - 删除购物车项目
  app.delete('/api/cart/:id', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    db.prepare('DELETE FROM cart_items WHERE id = ?').run(req.params.id);
    return { code: 0, message: '已删除' };
  });
}
