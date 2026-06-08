# 任务：全面改进移动端直播/短视频带货 App

## 当前状态

App 已成功运行在真机上，视频可以播放，但存在以下问题需要修复。

---

## 问题清单与改进要求

### 1. 界面主题问题（高优先级）
**问题**：整个屏幕覆盖红色蒙层（除了底部 TabBar），视频内容区域正常播放但被红色遮罩覆盖
**要求**：
- 移除所有红色背景遮罩
- 使用深色主题（背景黑色 `#0D0D0D`，卡片深灰 `#1A1A1A`）
- 强调色使用橙色 `#E8453C` 仅用于按钮、价格、选中状态
- 确保所有页面的 `Scaffold.backgroundColor` 设置为深色
- 检查 `MaterialApp` 的 `theme` 配置，不要使用红色作为 `primarySwatch`

### 2. 视频流问题（高优先级）
**问题**：只有一个视频，滑动时可能出现白屏
**要求**：
- 后端 seed 数据中至少添加 10 个视频
- 视频 URL 使用以下真实可播放的测试视频：
  - `https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4`
  - `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4`
  - `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnTheRoadAndInTheField.mp4`
  - `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4`
  - `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCar.mp4`
- 每个视频关联 2-3 个商品
- 实现播放器池，预加载上一个和下一个视频
- 视频切换时无白屏、无卡顿

### 3. 直播间问题（中优先级）
**问题**：
- 直播间的视频是静止的，没有播放
- 直播间里面没有商品卡

**要求**：
- 直播间页面使用 video_player 播放视频（可使用本地视频或测试视频模拟）
- 直播间底部展示商品卡片列表，可上下滑动
- 支持 WebSocket 实时通信（弹幕、在线人数、讲解商品）
- 商品卡片点击后弹出半屏详情

### 4. 个人中心/登录问题（中优先级）
**问题**：
- 点击"我的"直接显示测试用户
- 没有登录界面
- 设置按钮没有反应

**要求**：
- 实现登录页面（`lib/pages/auth/login_page.dart`）
- 登录方式：用户名/密码（测试账号：test / 123456，user / 123456）
- 未登录时点击"我的"跳转到登录页
- 登录成功后存储 token 到 Hive
- 实现设置页面（`lib/pages/mine/settings_page.dart`），包含：
  - 退出登录（清除 token，跳转登录页）
  - 清除缓存
  - 关于我们
- 我的页面显示用户头像、昵称、订单入口、设置入口

### 5. 购物车功能（低优先级）
**问题**：购物车功能需要完善
**要求**：
- 购物车页面支持数量修改、删除、全选/取消全选
- 底部显示总价和结算按钮
- 点击结算跳转订单确认页

### 6. 订单功能（低优先级）
**问题**：订单功能需要完善
**要求**：
- 订单确认页：显示商品信息、收货地址（模拟）、优惠金额、实付金额
- 模拟下单（调用后端 API）
- 模拟支付（成功率 90%）
- 订单列表按状态筛选（全部/待支付/已支付/已完成）

---

## 具体修改文件清单

### 前端修改

1. **`lib/core/app_theme.dart`** - 主题配色
   - 移除红色背景
   - 设置深色主题

2. **`lib/pages/feed/feed_page.dart`** - 视频流主页面
   - 确保 PageView 上下滑流畅

3. **`lib/pages/feed/video_player_item.dart`** - 视频播放组件
   - 移除红色背景
   - 优化首帧显示

4. **`lib/services/video_controller_pool.dart`** - 播放器池
   - 确保预加载前后视频

5. **`lib/pages/auth/login_page.dart`** - 新增登录页面
6. **`lib/pages/mine/settings_page.dart`** - 新增设置页面
7. **`lib/pages/mine/mine_page.dart`** - 修改我的页面

8. **`lib/pages/live/live_room_page.dart`** - 直播间页面
   - 修复视频播放
   - 添加商品卡片列表

9. **`lib/pages/cart/cart_page.dart`** - 购物车页面
10. **`lib/pages/order/order_page.dart`** - 订单页面
11. **`lib/pages/order/order_confirm_page.dart`** - 订单确认页
12. **`lib/pages/order/payment_result_page.dart`** - 支付结果页

### 后端修改

1. **`apps/server/src/db/seed.ts`** - 增加视频数据（至少 10 条）
2. **`apps/server/src/routes/videos.ts`** - 确认视频 API 返回正确数据
3. **`apps/server/src/routes/cart.ts`** - 确认购物车 API
4. **`apps/server/src/routes/orders.ts`** - 确认订单 API
5. **`apps/server/src/websocket/live.ts`** - 确认 WebSocket 实时通信

---

## 路由配置

在 `app_router.dart` 中添加以下路由：

```dart
// 登录页
GoRoute(
  path: '/login',
  name: 'login',
  builder: (context, state) => const LoginPage(),
),

// 设置页
GoRoute(
  path: '/settings',
  name: 'settings',
  builder: (context, state) => const SettingsPage(),
),

// 订单确认页
GoRoute(
  path: '/order/confirm',
  name: 'orderConfirm',
  builder: (context, state) => const OrderConfirmPage(),
),

// 支付结果页
GoRoute(
  path: '/payment/:orderId',
  name: 'paymentResult',
  builder: (context, state) => PaymentResultPage(orderId: state.pathParameters['orderId']!),
),
```

## 验收标准

- 界面不再是红色，改为深色主题
- 视频列表至少 10 个，上下滑流畅无白屏
- 直播间视频可以播放，有商品卡片
- 未登录时点击"我的"跳转登录页
- 登录后才能使用购物车、订单
- 设置页面可以退出登录
- 购物车功能正常（增删改查、结算）
- 订单功能正常（创建订单、模拟支付、订单列表）

## 技术栈

- 移动端：Flutter + Riverpod + video_player
- 后端：Node.js + Fastify + better-sqlite3

请按优先级依次修复，每完成一项告诉我。

---

## 使用方法

1. **复制上面的完整提示词**
2. **发送给 Claude**
3. **按 Claude 的指示执行修改**

---

把这段提示词发给 Claude，它会帮你一次性修复所有问题。