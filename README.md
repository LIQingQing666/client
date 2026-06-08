# 直播/短视频带货 App

移动端直播+短视频电商项目，覆盖完整电商闭环：**内容流浏览 → 直播间实时互动 → 商品讲解 → 商品卡 → 加购/下单 → 支付 → 订单管理**。



---

## 目录

- [项目结构](#项目结构)
- [技术架构](#技术架构)
- [快速启动](#快速启动)
- [路由表](#路由表)
- [核心功能详解](#核心功能详解)
  - [内容流浏览](#1-内容流浏览-feed)
  - [直播间实时互动](#2-直播间实时互动)
  - [播放器池与预加载](#3-播放器池与预加载)
  - [小窗播放 PiP](#4-小窗播放-pip)
  - [商品购物链路](#5-商品购物链路)
  - [收藏页独立播放](#6-收藏页独立播放)
  - [商品讲解片段定位](#7-商品讲解片段定位)
  - [商家后台看板](#8-商家后台看板)
  - [个人中心](#9-个人中心)
- [状态管理架构](#状态管理架构)
- [API 接口一览](#api-接口一览)
- [WebSocket 实时通信](#websocket-实时通信)
- [数据库设计](#数据库设计)
- [重难点问题与解决方案](#重难点问题与解决方案)
- [项目规模](#项目规模)
- [测试账号](#测试账号)
- [项目文档](#项目文档)
- [待完成功能](#待完成功能)

---

## 项目结构

```
client/
├── apps/
│   ├── mobile/                    # Flutter 移动端（iOS + Android）
│   │   ├── lib/
│   │   │   ├── api/               # Dio 封装
│   │   │   ├── core/              # 路由/常量/主题
│   │   │   ├── models/            # 数据模型
│   │   │   ├── pages/             # 页面
│   │   │   │   ├── feed/          #   短视频 Feed
│   │   │   │   ├── live/          #   直播列表 + 直播间 + 主播端
│   │   │   │   ├── video/         #   独立视频播放页
│   │   │   │   ├── auth/          #   登录
│   │   │   │   ├── cart/          #   购物车
│   │   │   │   ├── order/         #   订单列表/确认/详情/支付/客服
│   │   │   │   ├── mine/          #   个人中心/收藏/关注/设置
│   │   │   │   ├── admin/         #   商家后台看板
│   │   │   │   ├── search/        #   搜索
│   │   │   │   ├── message/       #   消息
│   │   │   │   └── recharge/      #   抖币充值
│   │   │   ├── provider/          # Riverpod 状态管理
│   │   │   ├── services/          # 播放器池/WebSocket/预加载/本地存储
│   │   │   ├── utils/             # Toast / 响应式工具
│   │   │   └── widgets/           # 公共组件
│   │   └── pubspec.yaml
│   ├── server/                    # Node.js + Fastify 后端
│   │   └── src/
│   │       ├── db/                # schema.ts+ seed.ts
│   │       ├── middleware/        # JWT 鉴权
│   │       ├── routes/            # 11 个路由模块
│   │       ├── websocket/         # Socket.IO 实时通信
│   │       ├── services/          # AI 客服 (LangChain)、向量检索
│   │       └── index.ts           # 入口
│   └── restful_api/               # Dart Frog 备选后端（内存 + JSON 持久化）
├── images/                        # 项目图片资源
└── *.md                           # 根级文档
```

---

## 技术架构

```
┌──────────────────────────────────────────────────────────────┐
│                      Flutter Mobile                          │
│  ┌──────────┐ ┌───────────┐ ┌─────────────────────────────┐  │
│  │ go_router│ │ Riverpod  │ │ video_player + PlayerPool   │  │
│  │(5 Tab    │ │(13 State  │ │ (LRU 3, 引用计数, URL去重)  │  │
│  │ Shell)   │ │ Notifier) │ │ socket_io_client            │  │
│  └──────────┘ └───────────┘ └─────────────────────────────┘  │
│                      │ Dio (Auth + Retry + Log 拦截器)       │
└──────────────────────┼─────────────────────────────────────—─┘
                       │ HTTP REST + WebSocket
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐    ┌──────────────────────┐
│  Node.js Server  │    │  Dart Frog Server    │
│  (主后端)        │    │  (备选后端)          │
│  Fastify 5       │    │  Dart Frog 1.1       │
│  Socket.IO 4     │    │  内存 + JSON 持久化  │
│  better-sqlite3  │    │  :8080               │
│  JWT 鉴权        │    │                      │
│  :3000           │    │                      │
└──────────────────┘    └──────────────────────┘
```

### 技术选型

| 层级 | 技术 | 说明 |
|------|------|------|
| **移动端** | Flutter 3.22+ / Dart 3.12+ | 跨平台，自绘引擎 |
| **状态管理** | Riverpod 2.6+ (StateNotifier) | 编译安全，13 个 Notifier 管理全局/局部状态 |
| **路由** | go_router 14+ (StatefulShellRoute) | 声明式路由，5 个底部 Tab + 嵌套导航 |
| **视频播放** | video_player 2.9+ + 自定义 PlayerPool | 引用计数池化（上限 3），URL 去重，防并发初始化 |
| **视频预加载** | VideoPreloadManager | 优先级队列，WiFi 感知，串行加载 |
| **图片** | cached_network_image 3.4+ | 磁盘缓存 + 占位/降级 |
| **HTTP** | Dio 5.7+ (Auth + Log + Retry 拦截器) | 自动重试 2 次（500ms/1000ms） |
| **WebSocket** | socket_io_client 2.0+ | 指数退避重连（1s→2s→4s→8s） |
| **本地存储** | shared_preferences + Hive | Token / 配置 / 收藏 |
| **PiP** | 自定义浮窗 (PipProvider + FloatingVideoPlayer) | 全局挂载，可拖拽，无缝续播 |
| **后端** | Fastify 5 + TypeScript | 高性能，Schema 内建 |
| **数据库** | SQLite (better-sqlite3, WAL 模式) | 零配置，单机原型 |
| **实时通信** | Socket.IO 4 | 弹幕/商品/人数推送 |
| **认证** | JWT (PBKDF2 密码哈希) | 7 天过期 |

---

## 快速启动

### 环境要求

| 工具 | 最低版本 |
|------|---------|
| Flutter | >= 3.22 |
| Dart | >= 3.12 |
| Node.js | >= 18 |
| npm | >= 9 |

### 启动后端

```bash
cd apps/server
npm install
npm run dev        # tsx watch 模式，自动重载 + 自动播种
```

服务器启动时会自动：
1. 执行 `initDb()` → 创建所有表
2. 执行 `seed()` → 清除旧数据 → 插入种子数据

启动日志：
```
Server running at http://0.0.0.0:3000
WebSocket ready at ws://0.0.0.0:3000
Seed completed! 5 users, 10 videos, 20 products, 2 coupons, 8 comments, 3 cart items, 2 orders, 5 live rooms
```

### 配置移动端

编辑 `apps/mobile/lib/core/app_constants.dart`：

```dart
static const String baseUrl = 'http://<你的IP>:3000/api';   // REST API
static const String wsUrl = 'http://<你的IP>:3000';         // WebSocket（无 /api 后缀！）
```

- 模拟器用 `10.0.2.2`（Android）或 `localhost`（iOS）
- 真机用电脑局域网 IP

### 启动移动端

```bash
cd apps/mobile
flutter pub get
flutter run
```

---

## 路由表

### 5 个底部 Tab（StatefulShellRoute.indexedStack 保活）

| 索引 | Tab | 路由 | 页面 | 行数 |
|------|-----|------|------|------|
| 0 | 视频 | `/feed` | FeedPage | 576 |
| 1 | 直播 | `/live` | LivePage | 715 |
| 2 | 购物车 | `/cart` | CartPage | 693 |
| 3 | 订单 | `/order` | OrderPage | 461 |
| 4 | 我的 | `/mine` | MinePage | 247 |

### 非 Tab 路由

| 路由 | 页面 | 说明 |
|------|------|------|
| `/login` | LoginPage | 登录 |
| `/search` | SearchPage | 搜索 |
| `/video/:videoId` | SingleVideoPlayerPage | 独立视频播放（收藏页入口） |
| `/play/:videoId` | FeedPage(带初始视频) | 跳转到 Feed 指定视频 |
| `/live/:roomId` | LiveRoomPage | 直播间（1208 行，最大文件） |
| `/order/confirm` | OrderConfirmPage | 订单确认 |
| `/order/detail/:orderId` | OrderDetailPage | 订单详情 |
| `/payment/detail/:orderId` | PaymentDetailPage | 支付详情 |
| `/payment/:orderId` | PaymentResultPage | 支付结果 |
| `/favorites` | FavoritesPage | 收藏列表 |
| `/following` | FollowingPage | 关注列表 |
| `/edit-profile` | EditProfilePage | 编辑资料 |
| `/settings` | SettingsPage | 设置 |
| `/coupons` | CouponListPage | 优惠券 |
| `/recharge` | CoinRechargePage | 抖币充值 |
| `/messages` | MessagePage | 消息列表 |
| `/message/:id` | MessageDetailPage | 消息详情 |

### 商家路由（需 merchant 角色）

| 路由 | 页面 | 说明 |
|------|------|------|
| `/admin` | AdminDashboardPage | 数据看板 |
| `/admin/product/:id` | ProductDetailPage | 商品详情管理 |
| `/admin/video/:id` | VideoDetailPage | 视频详情管理 |
| `/admin/add-product` | AddProductPage | 添加商品 |
| `/admin/edit-product/:id` | EditProductPage | 编辑商品 |
| `/admin/add-video` | AddVideoPage | 添加视频 |
| `/admin/edit-video/:id` | EditVideoPage | 编辑视频 |
| `/admin/gmv-ranking` | GmvRankingPage | GMV 排行 |
| `/admin/category-analysis` | CategoryAnalysisPage | 品类分析 |

---

## 核心功能详解

### 1. 内容流浏览 (Feed)

**架构**：`PageView.builder` (Axis.vertical) + `VideoPlayerWidget` + `FeedNotifier`

```
PageView.builder(垂直滑动)
├── VideoPlayerWidget (active)     ← 播放 + 封面淡出动画 (300ms)
│   ├── FittedBox > VideoPlayer    ← 全屏铺满
│   ├── CachedNetworkImage (封面)  ← 淡出过渡
│   ├── 底部信息区                  ← 头像/作者/标题/描述/标签
│   ├── 右侧操作栏                  ← 静音/点赞/评论/分享/收藏
│   ├── FloatingProductCard        ← 悬浮商品卡
│   └── 进度条 (Slider, 可拖拽)     ← ValueListenableBuilder 驱动
├── VideoPlayerWidget (inactive)   ← 暂停 + 释放 PlayerPool 引用
└── TopBar (推荐/关注 Tab)          ← 支持关注变化后自动刷新
```

**关键技术点**：
- `isActive` 双重保护：仅当前可见视频渲染 `VideoPlayer` 平台视图 + 仅 `isActive` 时播放
- `didUpdateWidget` → `_syncPlayState()` 控制播放/暂停
- 距末尾 3 条自动 `loadMore()` 分页
- 点赞乐观更新：先改 UI → API 调用 → 失败回滚
- 关注 Tab 切换竞态修复：`switchTab` 强制 `isLoading = false` 防止旧请求阻塞

### 2. 直播间实时互动

**架构**：`LiveRoomPage` 双层结构 + `LiveNotifier` + `DanmakuOverlay` + `WebSocketService`

```
LiveRoomPage (ConsumerStatefulWidget)
├── PageView.builder (多房间滑动)
│   ├── _LiveRoomActiveContent (当前页)
│   │   ├── VideoPlayer (IgnorePointer 包裹, 触摸穿透)
│   │   ├── DanmakuOverlay (弹幕动画)
│   │   ├── 评论列表 (最近 10 条)
│   │   ├── FloatingProductCard (商品卡)
│   │   ├── CouponCountdown (优惠券倒计时)
│   │   └── 底部操作栏 (输入/购物车/点赞/礼物/分享)
│   └── _LiveRoomPlaceholder (非活跃页, 封面图)
└── LiveNotifier (_active 标志位防 crash)
```

**WebSocket 事件流**：
```
WebSocketService.connect()
  → eventStream.listen(_handleEvent)
    → danmaku          → 弹幕 + 评论
    → online_count     → 在线人数
    → explaining_product → 切换讲解商品
    → new_comment      → 新评论(去重)
    → stock_update     → 库存变化
    → room_state       → 新加入者同步
    → room_products    → 商品列表
```

**关键修复**：
- **`_active` 标志位**：`leaveRoom()` 同步清除 `_active = false` → `cancel()` 之前防止 microtask 队列中残留的 WebSocket 事件触发 state 更新导致 crash
- **消息去重**：`sendMessage()`/`sendGift()` 乐观添加后，用 `_pendingMsgFingerprints` 集合匹配 WebSocket 回显，跳过重复
- **弹幕动画**：`AnimationController` 4~7s 从右到左，随机 Y 坐标（40% 屏幕），随机字号 12~15pt，最多 12 条
- **房间列表同步**：`LivePage._loadRooms()` → `roomListProvider` → `LiveRoomPage` 多房间滑动

### 3. 播放器池与预加载

**PlayerPool** (`lib/services/player_pool.dart`, 146 行)：

```
poolSize = 3 (上限)
_players: Map<videoId, {controller, url, refCount}>
_initializing: Set<videoId>  (防并发)

acquire(videoId, url):
  1. videoId 命中 → refCount++ → 返回
  2. URL 去重命中 → refCount++ → 别名 → seekTo(0)
  3. 正在初始化 → 等 200ms → 重试
  4. 池满 → 淘汰 refCount 最小
  5. 创建 → initialize() 15s 超时

release(videoId):
  refCount-- → 归零时 pause (不 dispose)
```

**VideoPreloadManager** (`lib/services/video_preload_manager.dart`, 180 行)：
- 优先级队列，仅预加载下一个视频（`preloadVideoCount = 1`）
- 串行加载（`maxConcurrent = 1`）
- WiFi 感知：蜂窝网络自动暂停
- 启动延迟 1500ms：优先保证当前视频缓冲

### 4. 小窗播放 (PiP)

**四文件协同**：

| 文件 | 职责 |
|------|------|
| `provider/pip_provider.dart` | 全局状态：isActive, videoController, roomInfo |
| `widgets/floating_video_player.dart` | 浮窗 UI：可拖拽，120~150px 宽，16:9 |
| `main.dart` | 全局挂载点（MaterialApp.router.builder 最顶层） |
| `pages/live/live_room_page.dart` | 4 个 PiP 入口 |

**4 个 PiP 入口**：系统返回键 / 购物车 / 立即购买 / 返回箭头

**无缝续播**：`enterPip()` 保存 controller → 返回直播间 `initState` 检测 PiP controller → 直接复用不重新下载

### 5. 商品购物链路

```
商品卡 (FloatingProductCard)
  → 点击 → ProductDetailSheet (半屏, 896 行)
    ├── 图片轮播 + 价格/原价/折扣
    ├── 规格选择 + 数量调整
    ├── 优惠券入口 + AI 卖点文案
    ├── 讲解片段跳转 (seek + 高亮闪烁)
    └── 底部操作栏 (⭐收藏 / 加入购物车 / 立即购买)
      → 加入购物车 / 立即购买
        → OrderConfirmPage (使用优惠券、选择地址)
          → PaymentDetailPage (模拟支付)
            → PaymentResultPage (成功/失败)
```

### 6. 收藏页独立播放

`SingleVideoPlayerPage` 与 Feed 页完全解耦：
- 自建 controller，不走 PlayerPool（避免与 Feed IndexedStack 竞争解码器）
- 独立生命周期：init → play → dispose（立即释放 ExoPlayer）
- 可拖拽进度条 + 作者面板 + 喜欢按钮（乐观更新 + 失败回滚）
- await 200ms 后 push 路由（解决 pop 弹窗 + push 新页的 Navigator 竞态）

### 7. 商品讲解片段定位

- 数据模型：`ProductModel.highlightTime` (单点) + `segments` (多段)
- Feed 页：`_seekTrigger` ValueNotifier → `controller.seekTo()` + 1.2s 金色边框高亮
- 收藏页：`pop()` → `await 200ms` → `pushNamed('singleVideo', {seek: time})`
- 双重 clamp 保护：`clamp(0, durMs - 500)` 防止 seek 到尾帧之外

### 8. 商家后台看板

- 四级转化漏斗：曝光 → 点击商品 → 加购 → 下单（含转化率）
- 热门商品 Top 10 + 视频 GMV 排行 + 品类分布
- 总 GMV 汇总卡片
- 从漏斗/Top 列表钻取到详情页
- 商家角色鉴权（`requireMerchant` middleware）

### 9. 个人中心

- 用户信息展示、编辑资料（头像上传 → `/api/upload/image`）
- 收藏列表（视频 Tab + 商品 Tab，含作者头像/关注按钮）
- 关注列表
- 优惠券列表
- 消息中心（分类通知）
- 设置页（清除缓存、退出登录）

---

## 状态管理架构

13 个 Riverpod StateNotifier：

```
authProvider          → 登录态 (token, userId, role)
userProvider          → 用户资料 (nickname, avatar, coin_balance)
feedProvider          → Feed 状态 (videos[], currentIndex, tab, pagination)
liveProvider          → 直播状态 (room, messages[], onlineCount, products, _active flag)
cartProvider          → 购物车 (items[], selectedIds, totalPrice)
orderProvider         → 订单列表 (orders[], statusFilter)
favoriteProvider      → 收藏 (items[], video/product toggle, 本地持久化)
followProvider        → 关注 (followingIds Set, loadFollowing 初始化)
couponProvider        → 优惠券 (claimed[], available[])
customerServiceProvider → 客服消息
adminProvider         → 管理后台数据
pipProvider           → PiP 状态 (isActive, videoController, roomInfo)
muteStateProvider     → 全局静音
```

**Provider 层级关系**：
```
service_providers.dart (DI 根)
├── dioClientProvider         → DioClient(StorageService)
├── webSocketServiceProvider  → WebSocketService(StorageService)
├── playerPoolProvider        → PlayerPool(3)
├── videoPreloadManagerProvider → VideoPreloadManager
├── storageServiceProvider    → StorageService
├── uplaodApiProvider         → UploadApi(DioClient)
├── liveApiProvider           → LiveApi(DioClient)
├── videoApiProvider          → VideoApi(DioClient)
└── productApiProvider        → ProductApi(DioClient)
```

---

## API 接口一览

### 用户 (`/api/users`, `/api/auth`)

| 方法 | 路径 | 鉴权 |
|------|------|------|
| POST | `/api/auth/register` | - |
| POST | `/api/auth/login` | - |
| GET | `/api/users/:id` | Bearer |
| PUT | `/api/users/:id` | Bearer |
| POST | `/api/users/:id/avatar` | Bearer |
| POST | `/api/users/:id/follow` | Bearer |
| DELETE | `/api/users/:id/follow` | Bearer |
| GET | `/api/users/:id/following` | Bearer |

### 视频 (`/api/videos`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/videos` | 分页列表 |
| GET | `/api/videos/:id` | 详情 (+1 播放量) |
| GET | `/api/videos/recommend` | 推荐 (按播放量) |
| GET | `/api/videos/follow?user_id=` | 关注者视频 (JOIN follows 表) |
| GET | `/api/videos/search?keyword=` | 搜索 |
| POST | `/api/videos/:id/like` | 切换点赞 |

### 商品 (`/api/products`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/products` | 分页列表 |
| GET | `/api/products/:id` | 详情 (含关联视频) |
| GET | `/api/products/recommend` | 推荐 |
| GET | `/api/products/:id/ai-sales-point` | AI 卖点 |

### 购物车 (`/api/cart`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/cart/:userId` | 购物车列表 |
| POST | `/api/cart` | 加入 |
| PUT | `/api/cart/:id` | 更新 |
| DELETE | `/api/cart/:id` | 删除 |

### 订单 (`/api/orders`)

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/orders` | 创建 |
| GET | `/api/orders/:userId` | 列表 |
| GET | `/api/orders/detail/:id` | 详情 |
| POST | `/api/orders/:id/pay` | 模拟支付 |

### 评论 (`/api/comments`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/comments` | 列表 (video_id/product_id 筛选) |
| POST | `/api/comments` | 创建 |

### 直播 (`/api/live`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/live/rooms` | 列表 (live + preview) |
| GET | `/api/live/rooms/:id` | 详情 + 商品 + 优惠券 |
| GET | `/api/live/rooms/mine` | 我的直播间 (商家) |
| POST | `/api/live/rooms` | 创建 (商家) |
| POST | `/api/live/rooms/:id/start` | 开播 (商家) |
| POST | `/api/live/rooms/:id/end` | 结束 (商家) |
| POST | `/api/live/rooms/:id/product` | 切换讲解商品 (商家, 广播 WS) |
| POST | `/api/live/gift` | 送礼物 (扣抖币) |

### 其他

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/upload/image` | 上传图片 (multipart) |
| POST | `/api/upload/video` | 上传视频 (multipart) |
| GET | `/api/admin/dashboard` | 数据看板 (商家) |
| GET | `/api/recharge/plans` | 充值套餐 |
| POST | `/api/recharge` | 创建充值 |

---

## WebSocket 实时通信

### 服务端事件处理

| 事件 | 方向 | 载荷 | 说明 |
|------|------|------|------|
| `join` | C→S | `{room, namespace}` | 加入房间 → 返回 room_state + 历史弹幕 |
| `leave` | C→S | `{room}` | 离开房间 |
| `send_message` | C→S | `{room, user_id, content}` | 发消息 → 广播 danmaku |
| `danmaku` | S→C | `{event, id, user_name, content, type}` | 弹幕广播 |
| `online_count` | S→C | `{count}` | 在线人数 |
| `explaining_product` | S→C | `{product, timestamp}` | 讲解商品切换 |
| `new_comment` | S→C | `{...message}` | 新评论广播 |
| `stock_update` | S→C | `{product_id, stock}` | 库存更新 |
| `room_state` | S→C | `{online_count, current_product}` | 新加入者同步 |
| `room_products` | S→C | `{list}` | 商品列表 |

### 断线重连

指数退避：1s → 2s → 4s → 8s，最多 5 次。WAL 模式 + `_reconnectTimer?.isActive` 防重复。

---

## 数据库设计

SQLite WAL 模式，15 张表：

| 表 | 核心字段 | 说明 |
|----|---------|------|
| `users` | id, nickname, avatar, phone, password(PBKDF2), role, coin_balance | 用户 |
| `videos` | id, title, cover_url, video_url, author_id, tags(JSON), like/comment/share/play_count, status | 视频 |
| `products` | id, name, price, original_price, stock, sales, specs(JSON), video_id, ai_sales_point | 商品 |
| `cart_items` | id, user_id, product_id, spec, quantity, selected | 购物车 |
| `orders` | id, user_id, total_amount, pay_amount, status, items(JSON), address(JSON) | 订单 |
| `comments` | id, user_id, video_id, product_id, content, like_count | 评论 |
| `coupons` | id, title, amount, min_order, total_count, used_count | 优惠券 |
| `user_coupons` | id, user_id, coupon_id, used | 领券 |
| `user_likes` | id, user_id, video_id, product_id (UNIQUE) | 点赞 |
| `follows` | id, follower_id, following_id (UNIQUE) | 关注 |
| `live_rooms` | id, title, video_url, author_id, product_ids(JSON), status(preview/live/ended) | 直播间 |
| `live_messages` | id, room_id, user_id, content, type(user/system/product) | 直播消息 |
| `live_interactions` | id, room_id, user_id, type(like/share/join/leave) | 互动 |
| `gifts` | id, name, icon, price, animation_type | 礼物配置 |
| `gift_records` | id, room_id, user_id, gift_id, gift_name, price | 送礼记录 |

### 种子数据

| 实体 | 数量 | 说明 |
|------|------|------|
| 用户 | 5 | 1 普通(u1) + 4 商家(u2~u5) |
| 视频 | 10 | 4 个不同 mp4 文件（butterfly / video2 / video3 / 梦工厂奶茶店视频） |
| 商品 | 20 | 10 关联视频 + 10 独立 |
| 直播间 | 5 | 2 live + 2 preview + 1 ended |
| 优惠券 | 2 | 满100减20 / 满200减50 |
| 评论 | 8 | 分布在 8 个视频 |

---

## 重难点问题与解决方案

| 问题 | 根因 | 解决方案 |
|------|------|---------|
| **直播页 Crash** (defunct widget) | WebSocket microtask 队列残留事件在 `cancel()` 后仍触发 `state=` | `_active` 标志位：`leaveRoom()` 同步清除 → `_handleEvent` 入口检查 |
| **Feed 红屏/BufferPool 驱逐** | ExoPlayer 并发超 MediaTek 芯片上限 (3-4) | Pool 降容 4→3 + `_initializing` 防并发 + 15s 超时 |
| **弹幕完全不显示** | `wsUrl` 多出 `/api` 后缀 | REST API 需 `/api`，Socket.IO 挂 HTTP Server 根路径 |
| **PiP 返回黑屏** | API 未完成时 `room=null` → PiP 未创建 → controller 被 dispose | 三级 fallback：`state.room ?? widget.room ?? pipState.roomInfo` |
| **关注 Tab 推荐视频混入** | `switchTab` 中 `isLoading` 旧值阻塞新 Tab 的 `loadVideos()` | `switchTab` 强制 `isLoading = false` |
| **连续视频画面相同** | URL 去重返回同一 controller 未重置位置 | `seekTo(Duration.zero)` |
| **进度条不跟随播放** | 手动 `addListener` 因 widget 重建失效 | 改用 `ValueListenableBuilder<VideoPlayerValue>` |
| **评论发布提示失败但已保存** | 不检查 response.code，解析异常误入 catch | 显式检查 `response.data['code'] == 0` |
| **头像 CSV URI 错误** | 本地文件路径直接传入 `CachedNetworkImageProvider` | multipart 上传 → 使用返回的公网 URL + `isNetworkImageUrl()` 守卫 |
| **送礼消息重复 2 条** | 乐观添加 + WebSocket 回显格式不同，指纹不匹配 | `sendGift()` 用服务端回显格式建指纹：`system\|赠送礼物\|$giftName` |
| **收藏图标不更新** | `ProductDetailSheet` 用外部快照 `ref.read` 非响应式 | 改用 `ref.watch(favoriteProvider).isFavorited(product.id)` |
| **Dart Error vs Exception** | `TypeError extends Error` 被 `on Exception` 漏掉 | 全局 `catch(e)` 替代 `on Exception` |

---

## 项目规模

| 类别 | 文件数 | 代码行数 |
|------|--------|---------|
| **Flutter 移动端** | ~90 | ~19,400 |
| ├─ 页面 (39 文件) | 39 | ~10,866 |
| ├─ Provider (13 文件) | 13 | ~2,229 |
| ├─ Widgets (13 文件) | 13 | ~4,542 |
| ├─ API 层 (11 文件) | 11 | ~1,633 |
| ├─ Models (8 文件) | 8 | ~850 |
| └─ Services (4 文件) | 4 | ~620 |
| **Node.js 服务端** | 21 | ~5,074 |
| ├─ 路由 (11 文件) | 11 | ~3,550 |
| ├─ 数据库 (2 文件) | 2 | ~1,196 |
| └─ WebSocket (1 文件) | 1 | ~258 |
| **合计** | ~111 | ~24,500 |

最大文件：
1. `live_room_page.dart` — 1,208 行
2. `live_broadcast_page.dart` — 985 行
3. `product_detail_sheet.dart` — 896 行
4. `seed.ts` — 874 行
5. `live_page.dart` — 715 行

---

## 测试账号

| 昵称 | ID | 密码 | 角色 |
|------|-----|------|------|
| 测试用户 | u1 | 123456 | 普通用户 |
| 小明数码 | u2 | 123456 | 商家 |
| 小红穿搭 | u3 | 123456 | 商家 |
| 阿杰户外 | u4 | 123456 | 商家 |
| 数码控小王 | u5 | 123456 | 商家 |

---

## 项目文档

| 文档 | 说明 |
|------|------|
| `client内容流七个点详细解析.md` | 7 个核心模块的架构设计、实现思路、重难点详解 |
| `client内容流模块亮点总结.md` | 模块亮点与技术总结 |
| `重难点记录.md` | 17+ 个调试 Bug 及其根因修复 |
| `技术方案.md` | 技术方案文档 |
| `购物支付链路技术文档.md` | 购物 → 支付 → 订单完整链路 |
| `三个核心技术点详解.md` | PlayerPool / PiP / 直播互动 |
| `架构图-Mermaid.md` | 系统架构 Mermaid 图 |
| `模块Mermaid流程图.md` | 各模块流程图 |
| `全功能实现状态检查.md` | 功能实现清单 |

---

## 待完成功能

- 真正的推荐算法（当前按播放量/热度排序）
- AIGC 接入真实 LLM（当前客户端模板，服务端已对接 DeepSeek）
- 支付网关对接（当前模拟支付 90% 成功率）
- Push 通知
- 单元测试与集成测试
- CI/CD 流水线
- 视频预加载磁盘缓存（当前仅内存缓存）
- 商家后台内容管理 / 商品管理 / 直播间配置的完整交互界面
