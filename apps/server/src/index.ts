import Fastify from 'fastify';
import cors from '@fastify/cors';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { initDb } from './db/schema.js';
import './db/seed.js';
import { videoRoutes } from './routes/videos.js';
import { productRoutes } from './routes/products.js';
import { cartRoutes } from './routes/cart.js';
import { orderRoutes } from './routes/orders.js';
import { userRoutes } from './routes/users.js';
import { commentRoutes } from './routes/comments.js';
import { adminRoutes } from './routes/admin.js';
import { liveRoutes } from './routes/live.js';
import { createWebSocketServer } from './websocket/live.js';

const PORT = parseInt(process.env.PORT ?? '3000', 10);
const HOST = process.env.HOST ?? '0.0.0.0';

async function main() {
  // Init database
  initDb();

  // Create Fastify
  const app = Fastify({ logger: true });

  // CORS
  await app.register(cors, {
    origin: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  });

  // Register routes
  await app.register(videoRoutes);
  await app.register(productRoutes);
  await app.register(cartRoutes);
  await app.register(orderRoutes);
  await app.register(userRoutes);
  await app.register(commentRoutes);
  await app.register(liveRoutes);
  await app.register(adminRoutes);

  // Health check
  app.get('/api/health', async () => ({ code: 0, message: 'ok', timestamp: new Date().toISOString() }));

  // Serve test client page via HTTP (avoids file:// CORS issues)
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const testClientPath = path.join(__dirname, '..', 'public', 'test-client.html');
  app.get('/test-client', async (_req, res) => {
    const html = fs.readFileSync(testClientPath, 'utf-8');
    return res.type('text/html; charset=utf-8').send(html);
  });

  // Ensure Fastify creates its HTTP server before we attach WebSocket
  await app.ready();

  // Attach WebSocket to Fastify's HTTP server
  const io = createWebSocketServer(app.server);

  // Make io accessible to routes via module-level store
  import('./websocket/live.js').then((m) => m.setIO(io));

  // Start
  await app.listen({ port: PORT, host: HOST });
  console.log(`Server running at http://${HOST}:${PORT}`);
  console.log(`WebSocket ready at ws://${HOST}:${PORT}`);

  // Graceful shutdown
  const shutdown = () => {
    console.log('\nShutting down...');
    io.close();
    app.close().then(() => process.exit(0));
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
