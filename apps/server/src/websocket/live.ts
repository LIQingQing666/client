import type { Server as HttpServer } from 'node:http';
import { Server as SocketIOServer } from 'socket.io';
import { getDb } from '../db/schema.js';
import crypto from 'node:crypto';

// Module-level io storage for access from routes
let _io: SocketIOServer | null = null;

export function setIO(io: SocketIOServer): void {
  _io = io;
}

export function getIO(): SocketIOServer {
  if (!_io) throw new Error('Socket.IO not initialized');
  return _io;
}

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
      isLive: boolean;
  }>();

  io.on('connection', (socket) => {
    console.log('[WS] client connected:', socket.id);

    socket.on('join', (data: { namespace?: string; room?: string }) => {
      const room = data.room ?? data.namespace ?? 'default';
      socket.join(room);

      // Track online count
      if (!roomState.has(room)) {
        roomState.set(room, {
          onlineCount: 0,
          currentProductId: '',
          isLive: true  // 默认直播中
        });
      }
      const state = roomState.get(room)!;
      state.onlineCount += 1;

      // Send current room state to the new joiner
      const roomStatePayload: Record<string, unknown> = {
        online_count: state.onlineCount,
        current_product_id: state.currentProductId,
        is_live: state.isLive,
      };

      // If there's a current explaining product, send full product data
      if (state.currentProductId) {
        const currentProduct = db.prepare(
          'SELECT * FROM products WHERE id = ?'
        ).get(state.currentProductId) as Record<string, unknown> | undefined;
        if (currentProduct) {
          roomStatePayload.current_product = {
            ...currentProduct,
            tags: JSON.parse(currentProduct.tags as string),
            images: JSON.parse(currentProduct.images as string),
            specs: JSON.parse(currentProduct.specs as string),
          };
        }
      }

      socket.emit('room_state', roomStatePayload);

      // Broadcast updated online count
      io.to(room).emit('online_count', { count: state.onlineCount });

      // Send pre-set history comments (3+ required by spec)
      const historyComments = [
        { user_name: '小明数码', content: '这款真的超好用，我已经回购三次了！', delay: 300 },
        { user_name: '小红穿搭', content: '主播今天讲解的好详细啊，学到了', delay: 600 },
        { user_name: '阿杰户外', content: '已下单，期待收货！', delay: 900 },
        { user_name: '系统消息', content: '欢迎进入直播间！', delay: 1200, type: 'system' },
      ];
      historyComments.forEach((c) => {
        setTimeout(() => {
          socket.emit('danmaku', {
            id: crypto.randomUUID(),
            user_name: c.user_name,
            content: c.content,
            type: (c as Record<string, unknown>).type ?? 'user',
          });
        }, c.delay);
      });
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
      const state = roomState.get(data.room);
      if (state && !state.isLive) {
          socket.emit('error', {
            message: '直播已结束，无法发送消息',
            code: 'LIVE_ENDED'
          });
          return;
        }

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
      const state = roomState.get(data.room);

      if (state && !state.isLive) {
        socket.emit('error', {
          message: '直播已结束，无法发送礼物',
          code: 'LIVE_ENDED'
        });
        return;
      }
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
        'SELECT * FROM products WHERE id = ?'
      ).get(data.product_id) as Record<string, unknown> | undefined;

      if (product) {
        if (!roomState.has(data.room)) {
          roomState.set(data.room, { onlineCount: 0, currentProductId: '' });
        }
        roomState.get(data.room)!.currentProductId = data.product_id;

        const serializedProduct = {
          ...product,
          tags: JSON.parse(product.tags as string),
          images: JSON.parse(product.images as string),
          specs: JSON.parse(product.specs as string),
        };

        io.to(data.room).emit('explaining_product', {
          product: serializedProduct,
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

    socket.on('start_live', (data: { room: string; liveInfo?: Record<string, unknown> }) => {
      const db = getDb();
      const room = data.room;

      try {
        // 使用 started_at 字段（而不是 start_time）
        db.prepare("UPDATE live_rooms SET status = 'live', started_at = ? WHERE id = ?")
          .run(new Date().toISOString(), room);

        console.log(`[WS] Live started in room: ${room}`);
      } catch (error) {
        console.error(`[WS] Error starting live in room ${room}:`, error);
      }

      // 初始化房间状态
      if (!roomState.has(room)) {
        roomState.set(room, { onlineCount: 0, currentProductId: '', isLive: true });
      } else {
        const state = roomState.get(room)!;
        state.isLive = true;
      }

      // 通知房间内所有用户直播开始
      io.to(room).emit('live_started', {
        room_id: room,
        started_at: new Date().toISOString(),
        live_info: data.liveInfo || {},
        message: '直播已开始',
      });

      // 恢复房间交互功能
      io.to(room).emit('room_disabled', {
        room_id: room,
        disabled: false,
        message: '直播已开始，互动功能已恢复',
      });
    });

    // 主播结束直播 - 核心功能
    socket.on('end_live', (data: { room: string; summary?: Record<string, unknown> }) => {
      const db = getDb();
      const room = data.room;

      try {
        const tableInfo = db.prepare("PRAGMA table_info('live_rooms')").all() as Array<{
          name: string;
        }>;
        const columnNames = tableInfo.map(col => col.name);

        // 构建更新语句
        const updates: string[] = [];
        const params: Record<string, unknown> = { id: room };

        // 更新状态为 ended
        updates.push("status = 'ended'");

        // 更新结束时间（使用 ended_at 字段名）
        updates.push("ended_at = @ended_at");
        params['ended_at'] = new Date().toISOString();

        // 如果表中有 summary 字段，才更新
        if (columnNames.includes('summary')) {
          updates.push("summary = @summary");
          params['summary'] = JSON.stringify(data.summary || {});
        }

        // 执行更新
        const sql = `UPDATE live_rooms SET ${updates.join(', ')} WHERE id = @id`;
        db.prepare(sql).run(params);

        console.log(`[WS] Updated live_rooms for room ${room}:`, params);

      } catch (error) {
        console.error(`[WS] Database update error for room ${room}:`, error);

        // 如果数据库更新失败，至少尝试更新 status
        try {
          db.prepare("UPDATE live_rooms SET status = 'ended', ended_at = ? WHERE id = ?")
            .run(new Date().toISOString(), room);
        } catch (e) {
          console.error('[WS] Fallback update also failed:', e);
        }
      }

      // 更新房间状态（内存中的状态）
      const state = roomState.get(room);
      if (state) {
        state.isLive = false;
      }

      // 发送直播结束通知给房间内所有观众
      io.to(room).emit('live_ended', {
        room_id: room,
        ended_at: new Date().toISOString(),
        summary: data.summary || {
          total_viewers: state?.onlineCount || 0,
          duration: '直播已结束',
        },
        message: '主播已结束直播，评论区已关闭',
      });

      // 禁用房间交互功能
      io.to(room).emit('room_disabled', {
        room_id: room,
        disabled: true,
        disabled_features: ['send_message', 'send_gift', 'danmaku'],
        message: '直播已结束，互动功能已关闭',
      });

      // 更新 roomState
      if (state) {
        state.isLive = false;
      }

      console.log(`[WS] Live ended in room: ${room}`);
    });


    // 获取直播状态
    socket.on('get_live_status', (data: { room: string }, callback?: Function) => {
      const db = getDb();
      const room = data.room;

      try {
        // 使用正确的字段名查询
        const liveRoom = db.prepare(
          "SELECT id, status, started_at, ended_at, online_count, current_product_id FROM live_rooms WHERE id = ?"
        ).get(room) as Record<string, unknown> | undefined;

        const state = roomState.get(room);
        const isLive = liveRoom?.status === 'live';

        const status = {
          room_id: room,
          is_live: isLive,
          status: liveRoom?.status || 'unknown',
          online_count: state?.onlineCount || 0,
          current_product_id: state?.currentProductId || liveRoom?.current_product_id || '',
          started_at: liveRoom?.started_at || null,
          ended_at: liveRoom?.ended_at || null,
        };

        if (callback) {
          callback({ code: 0, data: status });
        } else {
          socket.emit('live_status', status);
        }

        console.log(`[WS] Live status for room ${room}:`, status);

      } catch (error) {
        console.error(`[WS] Error getting live status for room ${room}:`, error);

        const fallbackStatus = {
          room_id: room,
          is_live: false,
          status: 'error',
          online_count: 0,
        };

        if (callback) {
          callback({ code: -1, data: fallbackStatus, message: 'Failed to get status' });
        } else {
          socket.emit('live_status', fallbackStatus);
        }
      }
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
