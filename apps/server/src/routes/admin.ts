import { FastifyInstance } from 'fastify';
import { getDb } from '../db/schema.js';
import { requireMerchant } from '../middleware/auth.js';

export async function adminRoutes(app: FastifyInstance) {
  // GET /api/admin/dashboard - 数据看板
  app.get('/api/admin/dashboard', { preHandler: [requireMerchant] }, async () => {
    const db = getDb();

    // Funnel data
    const totalPlays = (db.prepare(
      'SELECT COALESCE(SUM(play_count), 0) as total FROM videos'
    ).get() as { total: number }).total;

    const totalProductSales = (db.prepare(
      'SELECT COALESCE(SUM(sales), 0) as total FROM products'
    ).get() as { total: number }).total;

    const cartCount = (db.prepare(
      'SELECT COUNT(*) as count FROM cart_items'
    ).get() as { count: number }).count;

    const orderCount = (db.prepare(
      'SELECT COUNT(*) as count FROM orders'
    ).get() as { count: number }).count;

    const totalGMV = (db.prepare(
      "SELECT COALESCE(SUM(pay_amount), 0) as total FROM orders WHERE status IN ('paid', 'shipped', 'completed')"
    ).get() as { total: number }).total;

    // Conversion rates
    const clickRate = totalPlays > 0 ? (totalProductSales / totalPlays * 100) : 0;
    const cartRate = totalProductSales > 0 ? (cartCount / totalProductSales * 100) : 0;
    const orderRate = cartCount > 0 ? (orderCount / cartCount * 100) : 0;

    const funnel = {
      impressions: totalPlays,
      product_clicks: totalProductSales,
      add_to_cart: cartCount,
      orders: orderCount,
      rates: {
        click_through: Math.round(clickRate * 100) / 100,
        cart_conversion: Math.round(cartRate * 100) / 100,
        order_conversion: Math.round(orderRate * 100) / 100,
      },
    };

    // Top 10 products by sales
    const topProducts = db.prepare(
      "SELECT id, name, cover_url, price, original_price, sales, category FROM products WHERE status = 'on' ORDER BY sales DESC LIMIT 10"
    ).all() as Array<Record<string, unknown>>;

    // Video GMV ranking
    const videoGMV = db.prepare(`
      SELECT v.id, v.title, v.author_name, v.play_count,
             COALESCE(SUM(p.sales * p.price), 0) as gmv,
             COALESCE(SUM(p.sales), 0) as product_sales
      FROM videos v
      LEFT JOIN products p ON p.video_id = v.id
      GROUP BY v.id
      ORDER BY gmv DESC
      LIMIT 10
    `).all() as Array<Record<string, unknown>>;

    // Category distribution
    const categories = db.prepare(
      "SELECT category, COUNT(*) as count, SUM(sales) as total_sales FROM products WHERE status = 'on' GROUP BY category ORDER BY total_sales DESC"
    ).all() as Array<Record<string, unknown>>;

    return {
      code: 0,
      data: {
        funnel,
        top_products: topProducts,
        video_gmv: videoGMV,
        categories,
        total_gmv: totalGMV,
      },
    };
  });
}
