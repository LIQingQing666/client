# 直播/短视频带货 App

移动端直播/短视频电商项目，核心闭环：**内容浏览 → 商品讲解 → 点击商品卡 → 加购/下单 → 支付 → 订单状态**。

## 项目结构

```
livestream-commerce/
├── apps/
│   ├── mobile/          # Flutter 移动端（iOS + Android）
│   │   ├── lib/
│   │   │   ├── api/           # Dio 封装、接口层
│   │   │   ├── core/          # 路由、主题、常量
│   │   │   ├── models/        # 数据模型
│   │   │   ├── pages/         # 页面（feed/live/cart/order/mine/admin）
│   │   │   ├── provider/      # Riverpod 状态管理
│   │   │   ├── services/      # 播放器池、WebSocket 管理
│   │   │   ├── utils/         # Toast 等工具
│   │   │   └── widgets/       # 公共组件
│   │   └── pubspec.yaml
│   └── server/          # Node.js 后端
│       └── src/
│           ├── routes/        # API 路由（videos/products/cart/orders/live/admin）
│           ├── db/            # 数据库 schema + seed
│           └── index.ts       # 入口
└── README.md
```

## 快速启动

### 环境要求

- **Flutter** >= 3.22 / **Dart** >= 3.12
- **Node.js** >= 18 / **npm** >= 9

### 1. 启动后端

```bash
cd apps/server
npm install
npm run db:init    # 建表
npm run db:seed    # 生成种子数据
npm run dev        # 启动开发服务器，默认 http://localhost:3000
```

### 2. 启动移动端

```bash
cd apps/mobile
flutter pub get
flutter run          # 连接设备或模拟器后运行
```

## 技术选型

| 层级 | 技术 | 选型理由 |
|------|------|---------|
| **移动框架** | Flutter 3.22+ / Dart 3.12+ | 高性能跨平台，自绘引擎保证 60fps 视频流 |
| **状态管理** | Riverpod 2.6+ (StateNotifier) | 编译安全、无依赖注入问题，适合复杂异步状态 |
| **路由** | go_router 14+ (StatefulShellRoute) | 声明式路由，支持底部 Tab 嵌套导航 |
| **视频播放** | video_player 2.9+ + 自定义 PlayerPool | 引用计数池化，预加载相邻视频，避免内存泄漏 |
| **图片** | cached_network_image 3.4+ | 磁盘缓存 + 占位/降级，弱网下仍可渲染 |
| **网络** | Dio 5.7+ (RetryInterceptor) | 拦截器链：日志 → 重试 → 鉴权 → 错误映射 |
| **WebSocket** | socket_io_client 2.0+ | 与后端 socket.io 对齐，自动重连 |
| **后端框架** | Fastify 5 + TypeScript | 性能接近 Express 的 2x，Schema 验证内置 |
| **数据库** | better-sqlite3 | 零配置、WAL 模式、适合单机原型 |
| **实时通信** | socket.io | 直播间弹幕、讲解商品同步、在线人数推送 |

## 核心功能

### 短视频流（Feed）
- PageView.builder 垂直滑动全屏播放
- 播放器池预加载 ±1 视频，首帧封面淡入
- 可见性监听自动播放/暂停
- 分页懒加载，距末尾 3 条自动触发

### 商品卡片与购物链路
- 点击视频商品按钮 → 获取视频关联商品 → 弹出半屏详情
- DraggableScrollableSheet 规格选择 + 数量调整
- 加入购物车 / 立即购买（→ 订单确认 → 支付结果）
- 购物车 CRUD（增、删、改数量、勾选、全选）
- 订单列表按状态筛选（待付款/已支付/已发货/已完成）

### 直播间
- 独立直播间页面，WebSocket 实时通信
- 弹幕飘屏（随机位置，8s 自动消失，IgnorePointer 不阻挡操作）
- 在线人数实时更新
- 讲解商品高亮卡片 + 自动弹出
- 优惠券倒计时 + 进度条 + 抢券按钮
- 聊天输入 + 商品列表弹窗

### 后台数据看板
- 四级转化漏斗（曝光 → 点击 → 加购 → 下单）+ 转化率
- 热门商品 Top 10 + 视频 GMV 排行 + 品类分布
- 总 GMV 汇总卡片

## 加分项

| 加分项 | 实现 |
|--------|------|
| **智能推荐** | `RecommendProducts` 组件，横向滚动商品卡片，集成于购物车底部 + 支付成功页，调用 `/api/products/recommend` |
| **视频时间点跳转** | 商品详情页「跳转到讲解 (MM:SS)」按钮，通过 `ValueNotifier<int>` + `video_player.seek()` 精准跳转至商品讲解位置 |
| **AIGC 卖点** | 商品详情展示 AI 生成卖点文案，支持「AI 重新生成」刷新，后端 `/api/products/:id/ai-sales-point` |
| **数据看板** | Admin 页面，漏斗图（LinearProgressIndicator）+ Top 10 商品 + 视频 GMV 排行 + 品类分布 |
| **优惠券倒计时** | 直播间商品列表展示可用优惠券，倒计时 + 领取进度条 + 抢券交互 |

## 性能优化

- 视频 PlayerPool 引用计数 + LRU 淘汰（上限 3 实例）
- PageView 根据可见性控制播放/暂停，离屏立即释放资源
- CachedNetworkImage 全面覆盖 placeholder + errorWidget 降级
- Dio 拦截器自动重试 2 次（500ms / 1000ms 线性退避）
- 分页加载（页大小 10），滑动距末尾 3 条自动触发
- 全局 Toast 错误提示，13 个关键错误路径覆盖
- 所有异步操作 `mounted` 检查，防止 setState 在 dispose 后调用

## 已知问题与未实现功能

### 已知问题
- 视频播放器在极低端设备上首帧时间可能超过 500ms
- 弹幕大量涌入时（>50条/秒）可能出现短暂卡顿
- 优惠券仅限单次领取，不支持定时批量发放
- iOS 端视频播放器偶现 seek 后音画不同步

### 未实现功能
- 用户登录/注册系统（当前 hardcode u1 用户）
- 支付网关对接（当前为模拟支付）
- Push 通知（订单状态变更通知）
- 视频预加载队列的磁盘缓存（当前仅内存缓存）
- 真正的推荐算法（当前为随机推荐）
- AIGC 接入真实 LLM（当前为固定模板生成）
- 单元测试与集成测试覆盖
- CI/CD 流水线

### 截图
> 以下截图位置供项目交付时补充：

| 页面 | 截图 |
|------|------|
| 短视频流 | `<screenshots/feed.png>` |
| 商品详情半屏 | `<screenshots/product_detail.png>` |
| 购物车 | `<screenshots/cart.png>` |
| 订单确认 | `<screenshots/order_confirm.png>` |
| 直播间 | `<screenshots/live_room.png>` |
| 数据看板 | `<screenshots/admin_dashboard.png>` |
| 支付结果 | `<screenshots/payment_result.png>` |
