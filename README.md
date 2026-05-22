# 直播/短视频带货 App

移动端直播/短视频电商项目，核心闭环：**内容浏览 → 商品讲解 → 点击商品卡 → 加购/下单 → 支付 → 订单状态**。

## 目录

- [项目结构](#项目结构)
- [技术架构](#技术架构)
- [快速启动](#快速启动)
- [核心功能](#核心功能)
- [API 接口一览](#api-接口一览)
- [WebSocket 实时通信](#websocket-实时通信)
- [数据库设计](#数据库设计)
- [加分项](#加分项)
- [性能优化](#性能优化)
- [已知问题与未实现功能](#已知问题与未实现功能)
- [项目文档说明](#项目文档说明)

---

## 项目结构

```
client/
├── apps/
│   ├── mobile/              # Flutter 移动端（iOS + Android）
│   │   ├── lib/
│   │   │   ├── api/               # Dio 封装、拦截器、异常处理
│   │   │   ├── core/              # 路由 (go_router)、主题、常量配置
│   │   │   ├── models/            # 数据模型 (video / product / cart / order / live)
│   │   │   ├── pages/             # 页面
│   │   │   │   ├── admin/         #   商家后台看板
│   │   │   │   ├── auth/          #   登录/注册
│   │   │   │   ├── cart/          #   购物车
│   │   │   │   ├── feed/          #   短视频流
│   │   │   │   ├── live/          #   直播间列表 + 直播间
│   │   │   │   ├── message/       #   消息中心
│   │   │   │   ├── mine/          #   我的（个人中心/收藏/关注/设置）
│   │   │   │   ├── order/         #   订单列表/详情/确认/支付结果
│   │   │   │   └── search/        #   搜索
│   │   │   ├── provider/          # Riverpod 状态管理（auth / feed / cart / order / live / admin / favorite / follow / user）
│   │   │   ├── services/          # 播放器池、WebSocket 管理、本地存储
│   │   │   ├── utils/             # Toast 等工具函数
│   │   │   └── widgets/           # 公共组件（弹幕层、商品详情半屏、视频播放器、评论区等）
│   │   └── pubspec.yaml
│   ├── server/              # Node.js + Fastify 后端（主后端）
│   │   └── src/
│   │       ├── db/                # 数据库 schema + seed + init
│   │       ├── middleware/        # 鉴权中间件（JWT）
│   │       ├── routes/            # API 路由（videos / products / cart / orders / users / comments / live / admin）
│   │       ├── websocket/         # Socket.IO 实时通信
│   │       ├── types.d.ts         # TypeScript 类型声明
│   │       └── index.ts           # 入口
│   └── restful_api/         # Dart Frog REST API 后端（备选后端，纯内存 + JSON 持久化）
│       ├── lib/
│       │   ├── data/              # 数据库（内存 + JSON 文件持久化）
│       │   └── middleware/        # 鉴权中间件
│       ├── routes/api/            # API 路由（users / videos / products / cart / orders / comments）
│       └── server.dart            # 入口
├── packages/
│   └── shared/              # 共享包（预留）
├── images/                  # 项目图片资源
├── 基本架构/                 # 架构设计提示词与迭代记录（8 个 md 文件）
├── 工程架构/                 # 工程架构文档
├── 用户端移动客户端-xxx/      # 各需求模块的提示词文档
├── 后端服务-xxx/             # 后端服务提示词与源码
├── 商家运营后台-xxx/          # 商家后台提示词（预留）
├── 用户体验与客户端挑战/       # 体验挑战文档
├── 加分项-xxx/              # 加分项提示词（AIGC / 优惠券 / 数据看板 / 推荐 / 视频体验）
├── *.md                    # 根级项目文档（课题说明、案例、测试文档）
└── README.md
```

---

## 技术架构

```
┌───────────────────────────────────────────────────┐
│                    Flutter Mobile                  │
│  ┌──────────┐ ┌────────┐ ┌──────────────────────┐ │
│  │ go_router │ │Riverpod│ │ video_player +       │ │
│  │ (5 Tab    │ │(10+    │ │ PlayerPool (LRU 3)   │ │
│  │  Stateful │ │StateNot│ │ cached_network_image │ │
│  │  Shell)   │ │ifier)  │ │ socket_io_client     │ │
│  └──────────┘ └────────┘ └──────────────────────┘ │
│         │            │              │              │
│         └────────────┼──────────────┘              │
│                      │ Dio (Auth + Log + Retry)    │
└──────────────────────┼────────────────────────────┘
                       │ HTTP / WebSocket
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐    ┌──────────────────────┐
│  Node.js Server  │    │  Dart Frog Server    │
│  (主后端)         │    │  (备选后端)            │
│                  │    │                      │
│  Fastify 5       │    │  Dart Frog 1.1       │
│  Socket.IO 4     │    │  内存 + JSON 文件    │
│  better-sqlite3  │    │  持久化              │
│  JWT 鉴权        │    │  Token 鉴权          │
│  :3000           │    │  :8080              │
└──────────────────┘    └──────────────────────┘
```

### 技术选型

| 层级 | 技术 | 说明 |
|------|------|------|
| **移动框架** | Flutter 3.22+ / Dart 3.12+ | 跨平台，自绘引擎保证视频流性能 |
| **状态管理** | Riverpod 2.6+ (StateNotifier) | 编译安全，适合复杂异步状态 |
| **路由** | go_router 14+ (StatefulShellRoute) | 声明式路由，支持底部 5 Tab 嵌套导航 |
| **视频播放** | video_player 2.9+ + 自定义 PlayerPool | 引用计数池化，LRU 淘汰（上限 3），预加载相邻视频 |
| **图片** | cached_network_image 3.4+ | 磁盘缓存 + 占位/降级 |
| **网络** | Dio 5.7+ (Auth + Log + Retry 拦截器链) | 自动重试 2 次（500ms/1000ms），错误码映射 |
| **WebSocket** | socket_io_client 2.0+ | 与后端 Socket.IO 对齐，指数退避自动重连（最多 5 次） |
| **本地存储** | shared_preferences + Hive | Token / 用户配置 / 浏览历史 / 收藏 |
| **后端框架** | Fastify 5 + TypeScript | 高性能，Schema 验证内置 |
| **数据库** | better-sqlite3 (WAL 模式) | 零配置，适合单机原型 |
| **实时通信** | Socket.IO 4 | 直播间弹幕、商品同步、在线人数推送 |
| **认证** | JWT (PBKDF2 密码哈希) | 7 天过期，常量时间密码比较 |
| **备选后端** | Dart Frog 1.1 | 纯 Dart 实现，内存存储 + JSON 文件持久化 |

---

## 快速启动

### 环境要求

| 工具 | 最低版本 | 说明 |
|------|---------|------|
| Flutter | >= 3.22 | 移动端开发框架 |
| Dart | >= 3.12 | 与 Flutter 捆绑 |
| Node.js | >= 18 | 后端运行时 |
| npm | >= 9 | 包管理器 |
| Android Studio / Xcode | 最新稳定版 | 模拟器/真机调试 |

### 方式一：使用 Node.js 主后端（推荐）

#### 1. 启动后端

```bash
cd apps/server
npm install
npm run db:init    # 初始化数据库表结构
npm run db:seed    # 生成种子数据
npm run dev        # 启动开发服务器 → http://localhost:3000
```

#### 2. 配置移动端 API 地址

编辑 `apps/mobile/lib/core/app_constants.dart`：

```dart
static const String baseUrl = 'http://<你的IP>:3000/api';
static const String wsUrl = 'http://<你的IP>:3000';
```

将 `<你的IP>` 替换为你的局域网 IP（模拟器用 `10.0.2.2`，真机用电脑 IP）。

#### 3. 启动移动端

```bash
cd apps/mobile
flutter pub get
flutter run          # 连接设备或模拟器后运行
```

#### 测试账号

| 角色 | 用户名 | 密码 |
|------|--------|------|
│ 测试用户   │ 123456 │ 普通用户 │
├────────────┼────────┼──────────┤
│ 小明数码   │ 123456 │ 商家     │
├────────────┼────────┼──────────┤
│ 小红穿搭   │ 123456 │ 商家     │
├────────────┼────────┼──────────┤
│ 阿杰户外   │ 123456 │ 商家     │
├────────────┼────────┼──────────┤
│ 数码控小王 │ 123456 │ 商家   

---

### 方式二：使用 Dart Frog 备选后端

```bash
# 终端 1：启动 Dart Frog 后端
cd apps/restful_api
dart pub get
dart_frog dev --port 8080

# 终端 2：配置并启动移动端
# 修改 app_constants.dart 中 baseUrl 为 http://<IP>:8080
cd apps/mobile
flutter pub get
flutter run
```

Dart Frog 后端使用内存存储 + JSON 文件定时持久化，所有写操作后立即落盘。测试账号：`alice` / `123456`、`bob` / `123456`。

---

### 运行测试客户端

Node.js 后端内置了一个 WebSocket 测试页面：

```
浏览器打开: http://localhost:3000/test-client
```

可在此页面测试弹幕发送、商品讲解切换、在线人数等 WebSocket 功能。

---

## 核心功能

### 短视频流（Feed）
- `PageView.builder` 垂直滑动全屏播放
- 播放器池预加载 ±1 视频（引用计数管理，上限 3 实例）
- 可见性监听自动播放/暂停，离屏立即释放
- 分页懒加载，距末尾 3 条自动触发
- 右侧交互栏：头像关注、点赞（切换）、评论数、分享数
- 底部进度条 + 视频时长显示

### 商品与购物链路
- 视频/直播间内点击商品按钮 → 弹出半屏商品详情
- `DraggableScrollableSheet` 展示规格选择 + 数量调整
- 商品图片轮播 + 价格/原价/折扣标签 + 库存状态
- **加入购物车**：选择规格 → 加入购物车，对应不同规格独立存储
- **立即购买**：选择规格 → 跳转订单确认页 → 模拟支付 → 支付结果
- 购物车 CRUD：增删改数量、单品勾选、全选/取消全选、合计金额
- 订单列表按状态筛选（待付款 / 已支付 / 已发货 / 已完成）
- 订单详情页展示商品明细、收货地址、时间线

### 直播间
- 直播间列表（热门排序），独立直播间页面
- **弹幕系统**：WebSocket 实时接收，随机行飘屏动画（8s 自动消失）、`IgnorePointer` 不阻挡操作
- **在线人数**：实时更新 + 每 10s 随机波动模拟
- **讲解商品**：商家切换讲解商品时自动弹出商品高亮卡片
- **优惠券倒计时**：进度条 + 剩余数量 + 抢券按钮
- **礼物系统**：发送礼物带动画特效（🚀/👑/❤️）
- 底部操作栏：聊天输入 + 商品列表弹窗 + 礼物面板
- 弹幕预设消息：加入房间时推送 4 条历史消息

### 商家后台数据看板
- **四级转化漏斗**：曝光 → 点击商品 → 加购 → 下单（+ 转化率百分比）
- **热门商品 Top 10**：按销量排行
- **视频 GMV 排行**：按关联商品销售额排序
- **品类分布**：按商品类别统计
- **总 GMV 汇总卡片**：全部订单实付金额合计
- 支持从漏斗和 Top 列表钻取到详情页
- 商家角色鉴权保护（非 merchant 角色自动跳转）

### 个人中心
- 用户信息展示（头像、昵称）
- 浏览历史（最近 100 条）
- 收藏列表（视频 + 商品）
- 关注列表
- 消息中心（系统/点赞/优惠券/订单/关注通知）
- 设置页（清除缓存、退出登录）
- 编辑资料页

---

## API 接口一览

### 用户模块 (`/api/users` 或 `/api/auth`)

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| POST | `/api/auth/register` | 用户注册 | - |
| POST | `/api/auth/login` | 用户登录 | - |
| GET | `/api/users/:id` | 获取用户信息 | Bearer Token |
| PUT | `/api/users/:id` | 更新用户资料 | Bearer |
| POST | `/api/users/:id/avatar` | 上传头像 | Bearer |
| POST | `/api/users/:id/follow` | 关注用户 | Bearer |
| DELETE | `/api/users/:id/follow` | 取消关注 | Bearer |
| GET | `/api/users/:id/following` | 关注列表 | Bearer |
| GET | `/api/users/:id/coupons` | 用户优惠券 | Bearer |
| GET | `/api/messages/:userId` | 消息列表 | Bearer |

### 视频模块 (`/api/videos`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/videos` | 分页视频列表（page, page_size） |
| GET | `/api/videos/:id` | 视频详情（自动 +1 播放量） |
| GET | `/api/videos/recommend` | 推荐视频 |
| GET | `/api/videos/follow?user_id=` | 关注者视频 |
| GET | `/api/videos/search?keyword=` | 搜索视频 |
| POST | `/api/videos/:id/like` | 切换点赞 |

### 商品模块 (`/api/products`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/products` | 分页商品列表（category, keyword） |
| GET | `/api/products/:id` | 商品详情（含关联视频、评论） |
| GET | `/api/products/recommend` | 个性化推荐 |
| GET | `/api/products/:id/ai-sales-point` | AI 卖点文案 |

### 购物车模块 (`/api/cart`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/cart/:userId` | 购物车列表 |
| POST | `/api/cart` | 加入购物车 |
| PUT | `/api/cart/:id` | 更新数量/勾选状态 |
| DELETE | `/api/cart/:id` | 删除购物车项 |

### 订单模块 (`/api/orders`)

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/orders` | 创建订单（扣库存、清购物车、可用优惠券） |
| GET | `/api/orders/:userId` | 订单列表（status 筛选） |
| GET | `/api/orders/detail/:id` | 订单详情 |
| POST | `/api/orders/:id/pay` | 模拟支付（90% 成功率） |

### 评论模块 (`/api/comments`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/comments` | 评论列表（video_id, product_id 筛选） |
| POST | `/api/comments` | 创建评论 |

### 直播模块 (`/api/live`)

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/live/rooms` | 直播间列表 |
| GET | `/api/live/rooms/:id` | 直播间详情（含关联商品） |
| PUT | `/api/live/rooms/:roomId/explaining_product` | 切换讲解商品（广播 WebSocket） |
| POST | `/api/live/gift` | 发送礼物 |

### 管理后台 (`/api/admin`)

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| GET | `/api/admin/dashboard` | 数据看板（漏斗/排行/品类/GMV） | Merchant |

---

## WebSocket 实时通信

基于 Socket.IO，用于直播间实时交互。

### 客户端 → 服务端事件

| 事件 | 载荷 | 说明 |
|------|------|------|
| `join` | `{ room }` | 加入直播间 |
| `leave` | `{ room }` | 离开直播间 |
| `send_message` | `{ room, user_id, content }` | 发送弹幕消息 |
| `send_gift` | `{ room, giftId, giftName, price, user_id }` | 发送礼物 |
| `set_explaining_product` | `{ room, product_id }` | 设置讲解商品（商家） |
| `get_room_products` | `{ room, video_id? }` | 获取直播间商品列表 |

### 服务端 → 客户端事件

| 事件 | 载荷 | 说明 |
|------|------|------|
| `room_state` | `{ online_count, current_product_id }` | 加入时返回当前房间状态 |
| `online_count` | `{ count }` | 在线人数变化广播（±2 随机波动） |
| `danmaku` | `{ id, user_name, content, type }` | 弹幕消息广播 |
| `gift_sent` | `{ id, userId, userName, giftName, animation }` | 礼物动画广播 |
| `explaining_product` | `{ product, timestamp }` | 讲解商品切换广播 |
| `room_products` | `{ list }` | 商品列表返回 |

### 模拟行为
- 每 5 秒广播 1 条随机模拟弹幕（观众XXXX）
- 每 10 秒更新在线人数（-2~+2 随机波动）
- 新用户加入时推送 4 条预设历史弹幕（含系统欢迎消息）

---

## 数据库设计

Node.js 后端使用 SQLite（`apps/server/data/commerce.db`），WAL 模式。

### 核心表

| 表名 | 主要字段 | 说明 |
|------|---------|------|
| `users` | id, nickname, avatar, phone, password(PBKDF2), role | 用户（user/merchant） |
| `videos` | id, title, cover_url, video_url, author_id, like_count, tags(JSON), status | 视频内容 |
| `products` | id, name, price, original_price, stock, sales, category, specs(JSON), video_id, ai_sales_point | 商品 |
| `cart_items` | id, user_id, product_id, spec, quantity, selected | 购物车 |
| `orders` | id, user_id, total_amount, pay_amount, status, items(JSON), address(JSON) | 订单 |
| `comments` | id, user_id, video_id, product_id, content, parent_id | 评论 |
| `coupons` | id, title, amount, min_order, total_count, used_count, start_time, end_time | 优惠券模板 |
| `user_coupons` | id, user_id, coupon_id, used | 用户领券记录 |
| `user_likes` | id, user_id, video_id, product_id | 点赞记录（唯一约束） |
| `follows` | id, follower_id, following_id | 关注关系（唯一约束） |

### 种子数据
- 5 用户（1 普通 + 4 商家）
- 10 视频（各商家发布）
- 20 商品（10 关联视频 + 10 独立）
- 2 优惠券
- 3 购物车项 + 2 订单 + 8 评论

---

## 加分项

| 加分项 | 实现位置 | 说明 |
|--------|---------|------|
| **智能商品推荐** | `RecommendProducts` 组件 | 横向滚动商品卡，购物车底部 + 支付成功页 |
| **视频时间点跳转** | 商品详情页 | 「跳转到讲解 (MM:SS)」按钮，`video_player.seek()` 精准跳转 |
| **AIGC 卖点** | 商品详情 | AI 卖点文案 +「重新生成」按钮，`/api/products/:id/ai-sales-point` |
| **数据可视化看板** | Admin 页面 | 四级漏斗（曝光→点击→加购→下单）、Top 10、GMV 排行、品类分布 |
| **优惠券倒计时** | 直播间商品列表 | 倒计时 + 领取进度条 + 抢券交互 |
| **高级视频体验** | 播放器 + 弹幕 | 播放器池预加载、弹幕飘屏动画、首帧封面淡入 |

---

## 性能优化

| 优化项 | 实现 |
|--------|------|
| 视频播放器池 | 引用计数管理，上限 3 实例，LRU 淘汰，PageView 可见性自动控制 |
| 图片缓存 | `CachedNetworkImage` 全面覆盖，placeholder + errorWidget 降级 |
| 网络层 | Dio 拦截器自动重试 2 次（500ms / 1000ms 线性退避） |
| 分页加载 | 页大小 10，滑动距末尾 3 条自动触发 |
| 错误处理 | 全局 Toast 提示，13 个关键错误路径覆盖 |
| 内存安全 | 所有异步操作 `mounted` 检查，防止 setState 在 dispose 后调用 |
| WebSocket 重连 | 指数退避（1s/2s/4s/8s），最多 5 次 |

---

## 已知问题与未实现功能

### 已知问题
- 视频播放器在低端设备上首帧时间可能超过 500ms
- 弹幕大量涌入时（>50条/秒）可能出现短暂卡顿
- 优惠券仅限单次领取，不支持定时批量发放
- iOS 端视频播放器偶现 seek 后音画不同步

### 未实现功能
- 真正的推荐算法（当前基于热门/随机）
- AIGC 接入真实 LLM（当前为固定模板）
- 支付网关对接（当前为模拟支付 90% 成功率）
- Push 通知（订单状态变更通知）
- 视频预加载磁盘缓存（当前仅内存缓存）
- 单元测试与集成测试覆盖
- CI/CD 流水线
- 商家后台的内容管理、商品管理、直播间配置交互界面

---

## 项目文档说明

除了本 README，项目根目录还包含以下文档：

### 课题与案例

| 文件 | 说明 |
|------|------|
| `客户端课题.md` | 项目课题说明书，定义核心业务闭环、任务拆解、技术要求和加分项 |
| `客户端优秀案例.md` | 优秀学员项目案例——"小型 AI 对话流 App"，展示 MVI 架构、Compose、Room 等技术实践 |
| `直播视频商品卡.md` | 直播商品卡 Flutter 实现的严格规格文档，包含交互约束和验证清单 |

### 测试文档

| 文件 | 说明 |
|------|------|
| `测试后端服务-RESTful API.md` | REST API 测试指南，含 Dart Frog (8080) 和 Node.js (3000) 两套后端的 18+ curl 测试命令、API 对照表和功能对比 |
| `测试后端服务-实时通信.md` | WebSocket 实时通信测试文档，含 10 个测试场景（在线人数、弹幕、商品讲解、重连等）和预期结果 |
| `测试后端服务-数据持久化.md` | 数据持久化实现说明——Node.js 用 SQLite，Dart Frog 用 JSON 文件 + 3 秒定时 + 写操作即时落盘 |

### 迭代记录（子目录中的 md 文件）

| 目录 | 包含文件 | 说明 |
|------|---------|------|
| `基本架构/` | 8 个 md（提示词、改进、修复记录） | 多轮迭代提示词与开发记录 |
| `工程架构/` | 1 个 md | 工程架构设计文档 |
| `用户端移动客户端-内容流浏览/` | 1 个 md | 短视频流功能提示词 |
| `用户端移动客户端-互动能力/` | 1 个 md | 互动（点赞、评论、分享）提示词 |
| `用户端移动客户端-购物链路/` | 1 个 md | 购物链路（加购、下单、支付）提示词 |
| `后端服务-实时通信/` | 1 个 md | WebSocket 实时通信提示词 |
| `后端服务-数据持久化/` | 1 个 md | 数据持久化提示词 |
| `用户体验与客户端挑战/` | 1 个 md | 用户体验优化挑战文档 |
| `加分项-xxx/`（5 个目录） | 空 | AIGC/优惠券/数据看板/推荐/视频体验（功能已实现，提示词待补充） |
| `商家运营后台-xxx/`（3 个目录） | 空 | 内容管理/商品管理/直播间配置（待开发） |
