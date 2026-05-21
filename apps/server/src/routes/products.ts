import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';

export async function productRoutes(app: FastifyInstance) {
  // GET /api/products - 商品列表
  app.get('/api/products', async (req: FastifyRequest<{ Querystring: { page?: string; page_size?: string; category?: string; keyword?: string } }>) => {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;

    let where = "WHERE status = 'on'";
    const params: unknown[] = [];

    if (req.query.category) {
      where += ' AND category = ?';
      params.push(req.query.category);
    }
    if (req.query.keyword) {
      where += ' AND name LIKE ?';
      params.push(`%${req.query.keyword}%`);
    }

    const total = (db.prepare(
      `SELECT COUNT(*) as count FROM products ${where}`
    ).get(...params) as { count: number }).count;

    const products = db.prepare(
      `SELECT * FROM products ${where} ORDER BY sales DESC LIMIT ? OFFSET ?`
    ).all(...params, pageSize, offset) as Array<Record<string, unknown>>;

    const list = products.map((p) => ({
      ...p,
      tags: JSON.parse(p.tags as string),
      images: JSON.parse(p.images as string),
      specs: JSON.parse(p.specs as string),
    }));

    return {
      code: 0,
      data: {
        list,
        total,
        page,
        page_size: pageSize,
        has_more: offset + pageSize < total,
      },
    };
  });

  // GET /api/products/:id - 商品详情
  app.get('/api/products/:id', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;

    if (!product) {
      return { code: 404, message: '商品不存在' };
    }

    // 获取关联视频
    const video = product.video_id
      ? db.prepare('SELECT id, title, cover_url, author_name FROM videos WHERE id = ?').get(product.video_id as string) as Record<string, unknown> | undefined
      : null;

    // 获取评论
    const comments = db.prepare(
      'SELECT * FROM comments WHERE product_id = ? ORDER BY created_at DESC LIMIT 20'
    ).all(req.params.id) as Array<Record<string, unknown>>;

    // 猜你喜欢（同类别）
    const related = db.prepare(
      "SELECT id, name, cover_url, price, original_price, sales FROM products WHERE category = ? AND id != ? AND status = 'on' ORDER BY sales DESC LIMIT 6"
    ).all(product.category as string, req.params.id) as Array<Record<string, unknown>>;

    return {
      code: 0,
      data: {
        ...product,
        tags: JSON.parse(product.tags as string),
        images: JSON.parse(product.images as string),
        specs: JSON.parse(product.specs as string),
        video,
        comments,
        related_products: related,
      },
    };
  });

  // GET /api/products/recommend - 猜你喜欢
  app.get('/api/products/recommend', async (req: FastifyRequest<{ Querystring: { user_id?: string; limit?: string } }>) => {
    const db = getDb();
    const limit = Math.min(20, Math.max(1, parseInt(req.query.limit ?? '6', 10)));

    let products: Array<Record<string, unknown>>;

    if (req.query.user_id) {
      // 基于用户浏览/点赞/加购历史的类别推荐
      const likedVideos = db.prepare(
        'SELECT video_id FROM user_likes WHERE user_id = ? AND video_id != ?'
      ).all(req.query.user_id, '') as Array<{ video_id: string }>;

      if (likedVideos.length > 0) {
        const placeholders = likedVideos.map(() => '?').join(',');
        const videoProducts = db.prepare(
          `SELECT DISTINCT category FROM products WHERE video_id IN (${placeholders}) AND status = 'on'`
        ).all(...likedVideos.map((l) => l.video_id)) as Array<{ category: string }>;

        if (videoProducts.length > 0) {
          const categories = [...new Set(videoProducts.map((p) => p.category))];
          const catPlaceholders = categories.map(() => '?').join(',');
          products = db.prepare(
            `SELECT id, name, cover_url, price, original_price, sales, category FROM products WHERE category IN (${catPlaceholders}) AND status = 'on' ORDER BY sales DESC LIMIT ?`
          ).all(...categories, limit) as Array<Record<string, unknown>>;
          return { code: 0, data: { list: products } };
        }
      }
    }

    // 默认热门推荐
    products = db.prepare(
      "SELECT id, name, cover_url, price, original_price, sales, category FROM products WHERE status = 'on' ORDER BY sales DESC LIMIT ?"
    ).all(limit) as Array<Record<string, unknown>>;

    return { code: 0, data: { list: products } };
  });

  // GET /api/products/:id/ai-sales-point - AI卖点
  app.get('/api/products/:id/ai-sales-point', async (req: FastifyRequest<{ Params: { id: string } }>) => {
    const db = getDb();
    const product = db.prepare(
      'SELECT ai_sales_point, name FROM products WHERE id = ?'
    ).get(req.params.id) as Record<string, unknown> | undefined;

    if (!product) {
      return { code: 404, message: '商品不存在' };
    }

    return {
      code: 0,
      data: {
        product_name: product.name,
        sales_point: product.ai_sales_point || '暂无AI卖点文案',
      },
    };
  });
}
