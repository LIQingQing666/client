import type { Server as HttpServer } from 'node:http';
import { Server as SocketIOServer } from 'socket.io';
import { getDb } from '../db/schema.js';
import crypto from 'node:crypto';

export function createWebSocketServer(httpServer: HttpServer): SocketIOServer {
  const io = new SocketIOServer(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
  });

  // Room state tracking
  const roomState = new Map<string, {
    onlineCount: number;
    currentProductId: string;
  }>();

  io.on('connection', (socket) => {
    console.log('[WS] client connected:', socket.id);

    socket.on('join', (data: { namespace?: string; room?: string }) => {
      const room = data.room ?? data.namespace ?? 'default';
      socket.join(room);

      // Track online count
      if (!roomState.has(room)) {
        roomState.set(room, { onlineCount: 0, currentProductId: '' });
      }
      const state = roomState.get(room)!;
      state.onlineCount += 1;

      // Send current room state to the new joiner
      socket.emit('room_state', {
        online_count: state.onlineCount,
        current_product_id: state.currentProductId,
      });

      // Broadcast updated online count
      io.to(room).emit('online_count', { count: state.onlineCount });

      // Send mock danmaku welcome
      setTimeout(() => {
        socket.emit('danmaku', {
          id: crypto.randomUUID(),
          user_name: '系统消息',
          content: '欢迎进入直播间！',
          type: 'system',
        });
      }, 500);
    });

    socket.on('leave', (data: { room?: string }) => {
      const room = data.room ?? 'default';
      socket.leave(room);

      const state = roomState.get(room);
      if (state) {
        state.onlineCount = Math.max(0, state.onlineCount - 1);
        io.to(room).emit('online_count', { count: state.onlineCount });
      }
    });

    // Chat message / danmaku
    socket.on('send_message', (data: { room: string; user_id: string; content: string }) => {
      const db = getDb();
      const user = db.prepare('SELECT nickname, avatar FROM users WHERE id = ?').get(data.user_id) as
        | { nickname: string; avatar: string }
        | undefined;

      const message = {
        id: crypto.randomUUID(),
        user_id: data.user_id,
        user_name: user?.nickname ?? '匿名用户',
        user_avatar: user?.avatar ?? '',
        content: data.content,
        timestamp: new Date().toISOString(),
      };

      io.to(data.room).emit('danmaku', { ...message, type: 'user' });
    });

    // Send gift
    socket.on('send_gift', (data: { room: string; giftId: string; giftName: string; price: number; user_id: string }) => {
      const db = getDb();
      const user = db.prepare('SELECT nickname, avatar FROM users WHERE id = ?').get(data.user_id) as
        | { nickname: string; avatar: string }
        | undefined;

      const giftEvent = {
        id: crypto.randomUUID(),
        userId: data.user_id,
        userName: user?.nickname ?? '匿名用户',
        userAvatar: user?.avatar ?? '',
        giftName: data.giftName,
        giftId: data.giftId,
        price: data.price,
        animation: data.giftName.includes('🚀') ? 'rocket' : data.giftName.includes('👑') ? 'crown' : 'heart',
        timestamp: new Date().toISOString(),
      };

      io.to(data.room).emit('gift_sent', giftEvent);
    });

    // Admin: set current explaining product
    socket.on('set_explaining_product', (data: { room: string; product_id: string }) => {
      const db = getDb();
      const product = db.prepare(
        'SELECT id, name, cover_url, price, original_price, sales, ai_sales_point FROM products WHERE id = ?'
      ).get(data.product_id) as Record<string, unknown> | undefined;

      if (product && roomState.has(data.room)) {
        roomState.get(data.room)!.currentProductId = data.product_id;

        io.to(data.room).emit('explaining_product', {
          product,
          timestamp: new Date().toISOString(),
        });
      }
    });

    // Get room products
    socket.on('get_room_products', (data: { room: string; video_id?: string }, callback?: Function) => {
      const db = getDb();
      let products: Array<Record<string, unknown>>;

      if (data.video_id) {
        products = db.prepare(
          "SELECT * FROM products WHERE video_id = ? AND status = 'on' ORDER BY sales DESC"
        ).all(data.video_id) as Array<Record<string, unknown>>;
      } else {
        products = db.prepare(
          "SELECT * FROM products WHERE status = 'on' ORDER BY sales DESC LIMIT 10"
        ).all() as Array<Record<string, unknown>>;
      }

      const list = products.map((p) => ({
        ...p,
        tags: JSON.parse(p.tags as string),
        images: JSON.parse(p.images as string),
        specs: JSON.parse(p.specs as string),
      }));

      if (callback) {
        callback({ code: 0, data: { list } });
      } else {
        socket.emit('room_products', { list });
      }
    });

    // Simulate periodic danmaku
    const danmakuInterval = setInterval(() => {
      const mockMessages = [
        '这个质量真的好吗？',
        '已下单！期待收货！',
        '主播讲得好详细啊',
        '价格真划算啊',
        '有优惠券吗？',
        '买过的人说说怎么样',
        '主播今天好美！',
        '已加购，等发工资就买',
        '666666',
        '这个颜色好漂亮',
      ];
      const content = mockMessages[Math.floor(Math.random() * mockMessages.length)];
      const room = socket.rooms.values().next().value as string | undefined;

      if (room && room !== socket.id) {
        io.to(room).emit('danmaku', {
          id: crypto.randomUUID(),
          user_name: `观众${Math.floor(Math.random() * 10000)}`,
          content,
          type: 'user',
          timestamp: new Date().toISOString(),
        });
      }
    }, 5000);

    socket.on('disconnect', () => {
      clearInterval(danmakuInterval);

      // Update online count for all rooms the socket was in
      for (const room of socket.rooms) {
        if (room !== socket.id) {
          const state = roomState.get(room);
          if (state) {
            state.onlineCount = Math.max(0, state.onlineCount - 1);
            io.to(room).emit('online_count', { count: state.onlineCount });
          }
        }
      }

      console.log('[WS] client disconnected:', socket.id);
    });
  });

  // Simulate online count fluctuation
  setInterval(() => {
    for (const [room, state] of roomState) {
      if (state.onlineCount > 0) {
        const delta = Math.floor(Math.random() * 5) - 2; // -2 to +2
        state.onlineCount = Math.max(0, state.onlineCount + delta);
        io.to(room).emit('online_count', { count: state.onlineCount });
      }
    }
  }, 10000);

  return io;
}
