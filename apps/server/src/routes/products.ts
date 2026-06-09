import crypto from 'node:crypto';
import { FastifyInstance, FastifyRequest } from 'fastify';
import { getDb } from '../db/schema.js';
import { requireMerchant } from '../middleware/auth.js';
import * as dotenv from 'dotenv';
dotenv.config();

async function generateByAI(
  name: string,
  description: string,
  category: string,
  tags: string[]
): Promise<string> {
  const tagStr = tags.length > 0 ? tags.slice(0, 5).join('、') : '';

  const prompt = `商品：${name}
类目：${category}
描述：${description}
标签：${tagStr}

请为这个商品写一条吸引人的卖点文案（30-60字），突出核心优势。`;

  const response = await fetch('https://api.deepseek.com/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.DEEPSEEK_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'deepseek-chat',
      messages: [
        { role: 'system', content: '你是专业电商文案，写简短有吸引力的卖点。' },
        { role: 'user', content: prompt },
      ],
      max_tokens: 150,
      temperature: 0.8,
    }),
  });

  if (!response.ok) {
    throw new Error(`AI API 返回错误: ${response.status}`);
  }

  const data = await response.json() as any;
  return data.choices[0].message.content.trim();
}

interface ProductCreateBody {
  name?: unknown;
  description?: unknown;
  cover_url?: unknown;
  images?: unknown;
  price?: unknown;
  original_price?: unknown;
  stock?: unknown;
  category?: unknown;
  tags?: unknown;
  ai_sales_point?: unknown;
}

interface AiSalesPointBody {
  name?: unknown;
  description?: unknown;
  category?: unknown;
  tags?: unknown;
}

/** Baseline categories so the merchant dropdown always has options on a fresh install. */
const DEFAULT_CATEGORIES = ['数码', '服饰', '美妆', '户外', '家居', '食品', '宠物'];

// Mobile client speaks 'active'/'inactive'; the SQLite schema stores 'on'/'off'.
// Translate at the boundary so the wire format matches the mobile ProductModel
// without migrating existing rows.
const CLIENT_TO_DB_STATUS: Record<string, 'on' | 'off'> = {
  active: 'on',
  inactive: 'off',
};
const DB_TO_CLIENT_STATUS: Record<string, 'active' | 'inactive'> = {
  on: 'active',
  off: 'inactive',
};

function normalizeIncomingStatus(s: unknown): 'on' | 'off' | null {
  if (typeof s !== 'string') return null;
  if (s === 'on' || s === 'off') return s;
  return CLIENT_TO_DB_STATUS[s] ?? null;
}

interface ValidatedProduct {
  name: string;
  description: string;
  category: string;
  aiSalesPoint: string;
  price: number;
  originalPrice: number;
  stock: number;
  tags: string[];
  images: string[];
  coverUrl: string;
}

type ValidationResult =
  | { ok: true; value: ValidatedProduct }
  | { ok: false; message: string };

/**
 * Validates a product create/update body and normalises optional fields.
 * Same rules apply to POST (create) and PUT (update) — the only difference
 * is what the handlers do with the result.
 */
function validateProductBody(body: ProductCreateBody): ValidationResult {
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const description = typeof body.description === 'string' ? body.description.trim() : '';
  const coverUrl = typeof body.cover_url === 'string' ? body.cover_url.trim() : '';
  const category = typeof body.category === 'string' ? body.category.trim() : '';
  const aiSalesPoint =
    typeof body.ai_sales_point === 'string' ? body.ai_sales_point.trim() : '';

  const price = typeof body.price === 'number' ? body.price : Number.NaN;
  const originalPrice =
    typeof body.original_price === 'number' ? body.original_price : Number.NaN;
  const stock = typeof body.stock === 'number' ? body.stock : Number.NaN;

  if (!name) return { ok: false, message: '商品名称不能为空' };
  if (!category) return { ok: false, message: '请选择商品分类' };
  if (!Number.isFinite(price) || price < 0)
    return { ok: false, message: '售价必须是非负数字' };
  if (!Number.isFinite(originalPrice) || originalPrice < 0)
    return { ok: false, message: '原价必须是非负数字' };
  if (!Number.isInteger(stock) || stock < 0)
    return { ok: false, message: '库存必须是非负整数' };

  const tags = body.tags === undefined ? [] : body.tags;
  const images = body.images === undefined ? [] : body.images;
  if (!isStringArray(tags)) return { ok: false, message: 'tags 必须是字符串数组' };
  if (!isStringArray(images)) return { ok: false, message: 'images 必须是字符串数组' };

  const finalCoverUrl = coverUrl || images[0] || '';
  if (!finalCoverUrl) return { ok: false, message: '请提供封面图或至少一张商品图片' };
  const finalImages = images.length > 0 ? images : [finalCoverUrl];

  return {
    ok: true,
    value: {
      name,
      description,
      category,
      aiSalesPoint,
      price,
      originalPrice,
      stock,
      tags,
      images: finalImages,
      coverUrl: finalCoverUrl,
    },
  };
}

function isStringArray(v: unknown): v is string[] {
  return Array.isArray(v) && v.every((x) => typeof x === 'string');
}

/**
 * Reshape a row from the products table into the JSON the mobile ProductModel
 * expects (arrays parsed, never-null strings, etc).
 */
function rowToProduct(row: Record<string, unknown>): Record<string, unknown> {
  return {
    ...row,
    tags: JSON.parse((row.tags as string) || '[]'),
    images: JSON.parse((row.images as string) || '[]'),
    specs: JSON.parse((row.specs as string) || '[]'),
    status: DB_TO_CLIENT_STATUS[row.status as string] ?? row.status,
  };
}

export async function productRoutes(app: FastifyInstance) {
  // GET /api/products - 商品列表
  // `status` query param: omitted/'active' = on-shelf only (consumer default),
  // 'inactive' = off-shelf only, 'all' = both. Anything else falls back to default.
  app.get('/api/products', async (req: FastifyRequest<{ Querystring: { page?: string; page_size?: string; category?: string; keyword?: string; status?: string } }>) => {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page ?? '1', 10));
    const pageSize = Math.min(50, Math.max(1, parseInt(req.query.page_size ?? '10', 10)));
    const offset = (page - 1) * pageSize;

    const statusFilter = req.query.status;
    let where: string;
    const params: unknown[] = [];
    if (statusFilter === 'all') {
      where = 'WHERE 1=1';
    } else if (statusFilter === 'inactive') {
      where = "WHERE status = 'off'";
    } else {
      where = "WHERE status = 'on'";
    }

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

    const list = products.map(rowToProduct);

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

  // POST /api/products - 创建商品（仅商家）
  app.post<{ Body: ProductCreateBody }>(
    '/api/products',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return; // requireMerchant already replied
      const result = validateProductBody(req.body ?? {});
      if (!result.ok) {
        reply.status(400).send({ code: 400, message: result.message });
        return;
      }
      const v = result.value;

      const id = crypto.randomUUID();
      const db = getDb();
      db.prepare(
        `INSERT INTO products
          (id, name, description, cover_url, images, price, original_price,
           stock, sales, category, tags, specs, video_id, status, ai_sales_point, highlight_time)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, '[]', '', 'on', ?, 0)`,
      ).run(
        id,
        v.name,
        v.description,
        v.coverUrl,
        JSON.stringify(v.images),
        v.price,
        v.originalPrice,
        v.stock,
        v.category,
        JSON.stringify(v.tags),
        v.aiSalesPoint,
      );

      const row = db
        .prepare('SELECT * FROM products WHERE id = ?')
        .get(id) as Record<string, unknown>;

      return { code: 0, data: rowToProduct(row) };
    },
  );

  // PUT /api/products/batch-status - 批量上下架（仅商家）
  // Must be registered before PUT /api/products/:id so the literal path wins
  // over the `:id` parameter route.
  app.put<{ Body: { ids?: unknown; status?: unknown } }>(
    '/api/products/batch-status',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return;
      const body = req.body ?? {};
      const ids = Array.isArray(body.ids)
        ? body.ids.filter((x): x is string => typeof x === 'string' && x.length > 0)
        : [];
      if (ids.length === 0) {
        reply.status(400).send({ code: 400, message: 'ids 必须是非空字符串数组' });
        return;
      }
      const dbStatus = normalizeIncomingStatus(body.status);
      if (!dbStatus) {
        reply.status(400).send({ code: 400, message: "status 必须是 'active' 或 'inactive'" });
        return;
      }

      const db = getDb();
      const placeholders = ids.map(() => '?').join(',');
      const info = db
        .prepare(
          `UPDATE products SET status = ?, updated_at = datetime('now') WHERE id IN (${placeholders})`,
        )
        .run(dbStatus, ...ids);

      return { code: 0, data: { updated: info.changes } };
    },
  );

  // PUT /api/products/:id - 更新商品 / 切换上下架状态（仅商家）
  app.put<{ Params: { id: string }; Body: ProductCreateBody & { status?: unknown } }>(
    '/api/products/:id',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return;
      const db = getDb();
      const existing = db
        .prepare('SELECT id FROM products WHERE id = ?')
        .get(req.params.id) as { id: string } | undefined;
      if (!existing) {
        reply.status(404).send({ code: 404, message: '商品不存在' });
        return;
      }

      const body = (req.body ?? {}) as ProductCreateBody & { status?: unknown };
      const hasStatus = body.status !== undefined;
      const hasOtherFields =
        body.name !== undefined ||
        body.description !== undefined ||
        body.cover_url !== undefined ||
        body.images !== undefined ||
        body.price !== undefined ||
        body.original_price !== undefined ||
        body.stock !== undefined ||
        body.category !== undefined ||
        body.tags !== undefined ||
        body.ai_sales_point !== undefined;

      // Status-only update — the path used by mobile's activate/deactivate.
      if (hasStatus && !hasOtherFields) {
        const dbStatus = normalizeIncomingStatus(body.status);
        if (!dbStatus) {
          reply.status(400).send({ code: 400, message: "status 必须是 'active' 或 'inactive'" });
          return;
        }
        db.prepare("UPDATE products SET status = ?, updated_at = datetime('now') WHERE id = ?")
          .run(dbStatus, req.params.id);

        const row = db
          .prepare('SELECT * FROM products WHERE id = ?')
          .get(req.params.id) as Record<string, unknown>;
        return { code: 0, data: rowToProduct(row) };
      }

      const result = validateProductBody(body);
      if (!result.ok) {
        reply.status(400).send({ code: 400, message: result.message });
        return;
      }
      const v = result.value;

      // status optionally included alongside a full update — honor it.
      const dbStatus = hasStatus ? normalizeIncomingStatus(body.status) : null;
      if (hasStatus && !dbStatus) {
        reply.status(400).send({ code: 400, message: "status 必须是 'active' 或 'inactive'" });
        return;
      }

      if (dbStatus) {
        db.prepare(
          `UPDATE products
              SET name = ?,
                  description = ?,
                  cover_url = ?,
                  images = ?,
                  price = ?,
                  original_price = ?,
                  stock = ?,
                  category = ?,
                  tags = ?,
                  ai_sales_point = ?,
                  status = ?,
                  updated_at = datetime('now')
            WHERE id = ?`,
        ).run(
          v.name,
          v.description,
          v.coverUrl,
          JSON.stringify(v.images),
          v.price,
          v.originalPrice,
          v.stock,
          v.category,
          JSON.stringify(v.tags),
          v.aiSalesPoint,
          dbStatus,
          req.params.id,
        );
      } else {
        db.prepare(
          `UPDATE products
              SET name = ?,
                  description = ?,
                  cover_url = ?,
                  images = ?,
                  price = ?,
                  original_price = ?,
                  stock = ?,
                  category = ?,
                  tags = ?,
                  ai_sales_point = ?,
                  updated_at = datetime('now')
            WHERE id = ?`,
        ).run(
          v.name,
          v.description,
          v.coverUrl,
          JSON.stringify(v.images),
          v.price,
          v.originalPrice,
          v.stock,
          v.category,
          JSON.stringify(v.tags),
          v.aiSalesPoint,
          req.params.id,
        );
      }

      const row = db
        .prepare('SELECT * FROM products WHERE id = ?')
        .get(req.params.id) as Record<string, unknown>;

      return { code: 0, data: rowToProduct(row) };
    },
  );

  // DELETE /api/products/:id - 下架商品（软删除，保留外键引用）
  app.delete<{ Params: { id: string } }>(
    '/api/products/:id',
    { preHandler: [requireMerchant] },
    async (req, reply) => {
      if (!req.user) return;
      const db = getDb();
      const info = db
        .prepare("UPDATE products SET status = 'off', updated_at = datetime('now') WHERE id = ? AND status = 'on'")
        .run(req.params.id);

      if (info.changes === 0) {
        reply.status(404).send({ code: 404, message: '商品不存在' });
        return;
      }

      return { code: 0, data: { id: req.params.id } };
    },
  );

  // GET /api/categories - 商品分类列表
  app.get('/api/categories', async () => {
    const db = getDb();
    const rows = db
      .prepare("SELECT DISTINCT category FROM products WHERE category != '' ORDER BY category")
      .all() as Array<{ category: string }>;
    const fromDb = rows.map((r) => r.category);
    // Merge defaults first so familiar options stay at the top of the dropdown.
    const merged = Array.from(new Set([...DEFAULT_CATEGORIES, ...fromDb]));
    return { code: 0, data: { list: merged } };
  });

  // POST /api/products/ai-sales-point - 根据名称/描述/分类生成卖点（模板，非真实 LLM）
  app.post<{ Body: AiSalesPointBody }>(
    '/api/products/ai-sales-point',
    async (req, reply) => {
      const body = req.body ?? {};
      const name = typeof body.name === 'string' ? body.name.trim() : '';
      const description = typeof body.description === 'string' ? body.description.trim() : '';
      const category = typeof body.category === 'string' ? body.category.trim() : '';
      const rawTags = Array.isArray(body.tags) ? body.tags : [];
      const tags = rawTags.filter((t): t is string => typeof t === 'string' && t.trim() !== '');

      if (!name) {
        reply.status(400).send({ code: 400, message: '商品名称不能为空' });
        return;
      }

      // ==== 新增：尝试 AI 生成 ====
      try {
        console.log('🤖 正在调用 AI 生成卖点...');
        const aiResult = await generateByAI(name, description, category, tags);
        console.log('✅ AI 生成成功:', aiResult);
        return { code: 0, data: { sales_point: aiResult } };
      } catch (error) {
        console.log('⚠️ AI 调用失败，使用模板降级:', error.message);
      }
      // ==== 新增结束 ====

      // 降级：原来的模板代码（不动）
      const tagPhrase = tags.length > 0 ? `${tags.slice(0, 3).join(' / ')}` : '';
      const categoryPhrase = category ? `【${category}】` : '';
      const descSentence = description ? `${description}，` : '';

      const templates = [
        `${categoryPhrase}${name} · ${descSentence}匠心打磨，品质细节经得起放大镜审视${tagPhrase ? `，${tagPhrase}` : ''}。`,
        `${categoryPhrase}${name}：${descSentence}用过的都说真香，限时入手价更友好${tagPhrase ? `（${tagPhrase}）` : ''}。`,
        `${categoryPhrase}懂行的人都在悄悄回购的${name}。${descSentence}颜值与实用并存${tagPhrase ? `，主打 ${tagPhrase}` : ''}。`,
        `${categoryPhrase}${name} | ${descSentence}日常使用稳定可靠，长期主义者的安心之选${tagPhrase ? `，关键词：${tagPhrase}` : ''}。`,
      ];
      const idx = name.length % templates.length;
      const salesPoint = templates[idx]!;

      return { code: 0, data: { sales_point: salesPoint } };
    },
  );
}
