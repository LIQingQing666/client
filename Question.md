# 稳定性问题分析报告

## 问题描述

在虚拟安卓机上运行 App 时，当 PC 终端通过 `flutter run` 保持连接时，App 运行不稳定，出现卡顿、掉帧甚至无响应。断开 PC 终端连接（关闭 flutter run 终端）后，App 反而能稳定运行。

---

## 结论：问题根因在**直播界面模块**，与购物链路无关

经过多轮排查确认，导致 App 崩溃/卡顿的根本原因是**直播界面频繁的全页面 rebuild**，而非底层网络或 WebSocket 配置问题。

**购物链路（登录、充值、订单、支付）不受影响**，以下分析仅针对直播/视频模块。

---

## 根因分析（直播/视频模块内部问题）

### 根因 1：`live_room_page.dart` 顶层 `ref.watch(liveProvider)` 导致全页面频繁重建

```dart
// live_room_page.dart build() 方法
final state = ref.watch(liveProvider);  // ← 问题根源
```

`liveProvider` 的状态变化频率极高：
- **弹幕消息**：服务端每 5 秒发送一条模拟弹幕
- **在线人数**：服务端每 10 秒随机波动一次（-2 到 +2）
- 每一次状态变化都触发 `live_room_page.dart` **整个页面**的 build 方法重新执行

在 debug 模式下，Dart VM 的服务协议会对每次 widget build 进行额外追踪和序列化，放大性能开销。

### 根因 2：`danmaku_overlay.dart` 监听器双重注册（已修复）

```dart
// 修复前的问题代码：
@override
void didChangeDependencies() {
  // 第一处：didChangeDependencies 中监听消息
  if (currentCount > _lastMessageCount) { _spawnDanmaku(...); }
}

@override
Widget build(BuildContext context) {
  ref.listen<LiveState>(liveProvider, (prev, next) {
    // 第二处：ref.listen 中再次监听（重复触发）
    if (next.messages.length > _lastMessageCount) { _spawnDanmaku(...); }
  });
}
```

`didChangeDependencies` + `ref.listen` 两处同时监听，造成同一事件触发两次弹幕生成，进一步加剧 UI 线程压力。

### 根因 3：`live_provider.dart` 的 `state.copyWith` 高频触发

每 5 秒弹幕 → `_addMessage()` → `state = state.copyWith(messages: messages)` → 通知所有 watcher
每 10 秒在线人数波动 → `state = state.copyWith(onlineCount: count)` → 通知所有 watcher
高频的 `copyWith` 导致 Provider 不断通知所有订阅者，而没有做任何选择性监听优化。

### 根因 4：Dart VM Debug 模式放大器（非代码问题，但加剧了症状）

`flutter run` 启用 debug 模式时：
- Dart VM 开启 JIT + 调试协议，每帧有额外的序列化和通信开销
- Widget rebuild 在 debug 模式下比 release 模式慢 3-5 倍
- 调试协议断开后，这些开销消失，App 恢复稳定

---

## 文件归属与责任划分

| 文件 | 模块归属 | 是否与购物链路相关 |
|------|----------|-------------------|
| `apps/mobile/lib/pages/live/live_room_page.dart` | **直播模块** | ❌ 不相关 |
| `apps/mobile/lib/widgets/danmaku_overlay.dart` | **直播模块** | ❌ 不相关 |
| `apps/mobile/lib/provider/live_provider.dart` | **直播模块** | ❌ 不相关 |
| `apps/server/src/websocket/live.ts` | **直播模块** | ❌ 不相关 |
| `apps/mobile/lib/services/websocket_service.dart` | 底层基础服务 | 已做防御性修复，非根因 |
| `apps/mobile/lib/pages/auth/login_page.dart` | 购物链路 | ✅ 不受影响 |
| `apps/mobile/lib/pages/recharge/coin_recharge_page.dart` | 购物链路 | ✅ 不受影响 |
| `apps/mobile/lib/pages/order/` | 购物链路 | ✅ 不受影响 |
| `apps/mobile/lib/api/recharge_api.dart` | 购物链路 | ✅ 不受影响 |

---

## websocket_service.dart 修复说明（已做，防御性，非根因）

已在 `connect()` 前增加 `_cleanupSocket()` 方法，确保重连时清理旧连接。此修复是好的工程实践，但不是解决卡顿问题的关键。

---

## 建议

**如果只负责购物链路，以下问题无需处理**，由直播/视频模块的负责人优化：

1. `live_room_page.dart` — 将顶层 `ref.watch(liveProvider)` 拆分为细粒度的 `select()` 监听，避免全页面 rebuild
2. `danmaku_overlay.dart` — 已修复双重监听问题
3. `live_provider.dart` — 可考虑批量更新或 debounce 机制减少高频通知

**购物链路的代码（登录、充值、订单、支付）在 debug 模式下单独运行不会有卡顿问题。**

---

## 附：全项目架构示意图

> 模仿购物支付链路技术方案中的架构图风格，覆盖 Mobile 端和 Server 端所有模块。

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Mobile 端 (Flutter)                                │
│                                                                        │
│  用户层 (Pages)            状态管理层 (Providers)         网络层 (APIs)   │
│  ┌──────────────────┐    ┌────────────────────┐    ┌──────────────┐   │
│  │  Auth / 登录注册   │    │ authProvider         │    │ AuthApi      │   │
│  │  LoginPage        │───▶│ (用户身份/Token)      │───▶│              │   │
│  ├──────────────────┤    ├────────────────────┤    ├──────────────┤   │
│  │  内容流浏览         │    │ feedProvider         │    │ FeedApi      │   │
│  │  FeedPage         │───▶│ (视频流/推荐列表)      │───▶│              │   │
│  │  VideoDetailPage  │    │                     │    │              │   │
│  ├──────────────────┤    ├────────────────────┤    ├──────────────┤   │
│  │  直播模块           │    │ liveProvider         │    │ LiveApi      │   │
│  │  LiveRoomPage     │───▶│ (弹幕/在线人数/商品卡)  │───▶│              │   │
│  │  DanmakuOverlay   │    │                     │    │              │   │
│  ├──────────────────┤    ├────────────────────┤    ├──────────────┤   │
│  │  购物链路 ★        │    │ ★ 购物链路 Providers  │    │ ★ 购物链路 APIs│   │
│  │  CartPage         │───▶│ CartProvider         │───▶│ CartApi       │   │
│  │  OrderConfirmPage │    │ OrderNotifier        │    │ OrderApi      │   │
│  │  PaymentDetailPage│    │ UserNotifier         │    │ RechargeApi   │   │
│  │  PaymentResultPage│    │ 优惠券 ×4 Providers  │    │              │   │
│  │  OrderPage        │    └────────────────────┘    └──────┬───────┘   │
│  │  OrderDetailPage  │                                      │           │
│  │  RefundReasonPage │                                      │           │
│  │  RefundSuccessPage│                                      │           │
│  ├──────────────────┤                                      │ HTTP      │
│  │  充值 + 客服       │                                      │           │
│  │  CoinRechargePage │───▶ (状态由 UserNotifier 管理)      │           │
│  │  RechargeResultPage│                                    │           │
│  │  CustomerServicePg│───▶ CsProvider → CsApi            │           │
│  └──────────────────┘                                      │           │
│                                                            │           │
│                WebSocket (Socket.IO) ◀──── 实时通信 ───▶   │           │
└────────────────────────────────────────────────────────────┼───────────┘
                                                             │
                                                             │
┌────────────────────────────────────────────────────────────┼───────────┐
│                     Server 端 (Node.js + Fastify)            │           │
│                                                              │           │
│  Routes 层                  Services 层          Database 层 │           │
│  ┌────────────────┐    ┌─────────────────┐    ┌──────────┐  │           │
│  │ auth.ts         │    │ authService      │    │          │  │           │
│  │ (登录/注册/TK刷新) │───▶│ (JWT签发/验证)     │───▶│          │  │           │
│  ├────────────────┤    ├─────────────────┤    │  SQLite  │  │           │
│  │ feed.ts         │    │ recommendService  │    │          │  │◀──────────┘
│  │ (视频推荐流)      │───▶│ (推荐算法逻辑)      │───▶│ commerce  │
│  ├────────────────┤    ├─────────────────┤    │  .db     │
│  │ ★ orders.ts     │    │ ★ 自定义服务       │    │          │
│  │   recharge.ts   │───▶│   langchain_cs   │    │          │
│  │   cart.ts       │    │   vector_store   │    │          │
│  │   customer_svc  │    │   product_docs   │    │          │
│  │   users.ts      │    └─────────────────┘    └──────────┘
│  ├────────────────┤
│  │ live.ts (直播)   │───▶ WebSocket 推送       ┌─────────┐
│  │ (WS处理/弹幕/人数)│     (无需数据库)          │ Redis   │
│  └────────────────┘                            │(预留缓存)│
│                                                └─────────┘
│  Middleware:
│    auth.ts → 身份验证 (注册/登录/支付/下单等接口)
│    error.ts → 统一异常捕获
└────────────────────────────────────────────────────────────────
```

### 模块说明

| 模块 | 负责人 | Mobile 页数 | Server 路由数 | 数据库表 |
|------|--------|-----------|-------------|---------|
| **★ 购物支付链路** | 赵鹏 | 10 页 | 5 个 | 6 张 (orders/cart/coupons/user_coupons/recharge/users) |
| 内容流浏览 | 多人 | 2 页 | 1 个 | 1 张 (videos) |
| 直播互动 | 多人 | 2 页 | 1 个 (WS) | 无 (全内存) |
| 智能客服 | 赵鹏 | 1 页 | 2 个 | 1 张 (messages) |
| 认证 | 基础层 | 1 页 | 1 个 | 1 张 (users) |

### 数据流向

```
浏览内容流 ──▶ 点击商品卡 ──▶ 加购/领券 ──▶ 提交订单 ──▶ 支付 ──▶ 确认收货
     │              │              │             │          │
     ▼              ▼              ▼             ▼          ▼
  Feed模块     商品卡组件      购物车模块      订单模块     支付模块
  (别人负责)   (共用组件)      (购物链路)     (购物链路)   (购物链路)