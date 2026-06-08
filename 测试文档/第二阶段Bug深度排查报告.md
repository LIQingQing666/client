# 第二阶段：Bug深度排查报告

> 2026-06-01 | 按 5 个维度逐一排查

---

## 一、状态管理Bug

### B1-1 [P0] PlayerPool URL去重引发引用计数混乱
- **文件**: `lib/services/player_pool.dart:24-34`
- **触发**: 两个不同 videoId 指向同一 URL 时
- **表现**: 同一 controller 被两个 `_PooledPlayer` 引用，refCount 不同步。其中一个 evict 会 dispose controller，另一个变成野指针 → 视频崩溃/黑屏
- **修复**: URL 去重时不创建新条目，直接复用已有条目

### B1-2 [P1] WebSocket 重复订阅
- **文件**: `lib/provider/live_provider.dart:enterRoom()`
- **触发**: `enterRoom` 被多次调用（重连/快速切换）
- **表现**: `_eventSub` 未被取消就创建新订阅 → 重复事件 → 弹幕消息双倍
- **修复**: `enterRoom` 开头先 `_eventSub?.cancel()`

### B1-3 [P2] didUpdateWidget 竞态
- **文件**: `lib/widgets/video_player_widget.dart:98-107`
- **触发**: 快速滑动 `PageView` 导致 widget 连续 rebuild
- **表现**: `_releasePlayer()` 后立即 `_initPlayer()`，旧 acquire 仍在等待，可能导致双 player 实例
- **修复**: 添加取消令牌标记

---

## 二、边界条件Bug

### B2-1 [P1] 视频 URL 为空时无回退
- **文件**: `lib/widgets/video_player_widget.dart:_initPlayer()`
- **触发**: API 返回 `videoUrl: ""`
- **表现**: 白屏无提示，用户不知原因
- **状态**: ⚠️ 部分已有 fallback（封面图），但无明确提示

### B2-2 [P1] 购物车价格为0或负数
- **文件**: `lib/pages/cart/cart_page.dart:_CartBottomBar`
- **触发**: 后端返回异常价格
- **表现**: 显示 "¥0" 或 "¥-99"，结算按钮仍可用
- **修复**: 价格 < 0 时显示 "价格异常" + 禁用结算

### B2-3 [P2] 快速连续点击加购
- **文件**: `lib/provider/cart_provider.dart:addToCart()`
- **触发**: 用户快速点两次"加入购物车"
- **表现**: 重复添加 → API 两次调用 → 购物车出现两个相同商品
- **修复**: 添加 `_isAddingToCart` 防抖标记

---

## 三、内存与性能Bug

### B3-1 [P0] VideoPreloadManager 未在页面退出时 dispose
- **文件**: `lib/services/video_preload_manager.dart`
- **触发**: 切换到其他 Tab 或退出 App
- **表现**: `Connectivity` 订阅持续活跃 → 内存泄漏
- **修复**: `FeedNotifier.dispose()` 中调用 `preloadManager.dispose()`

### B3-2 [P1] 直播间 WebSocket 连接未在离开时清理
- **文件**: `lib/pages/live/live_room_page.dart:dispose()`
- **触发**: 用户从直播间 push 到其他页面
- **表现**: WebSocket 保持连接 → 后台消耗带宽
- **修复**: `dispose()` 确保调用 `leaveRoom()`

### B3-3 [P2] 评论列表无限增长
- **文件**: `lib/widgets/video_comments_sheet.dart`
- **触发**: 翻页加载大量评论
- **表现**: 内存无限增长
- **修复**: 设置最大缓存条数 100

---

## 四、数据一致性Bug

### B4-1 [P1] 购物车持久化字段不完整
- **文件**: `lib/provider/cart_provider.dart:_persist()`
- **触发**: 恢复本地缓存的购物车
- **表现**: `productSpecs` 等字段未序列化 → 恢复后规格丢失
- **修复**: 补充完整序列化字段

### B4-2 [P2] 收藏状态未跨页面同步
- **文件**: `lib/provider/favorite_provider.dart`
- **触发**: 在详情页收藏后返回列表
- **表现**: 列表的收藏按钮状态未更新 → 需手动刷新
- **状态**: ⚠️ Hive 持久化存在但依赖 `_persist()` 调用时机

### B4-3 [P2] 订单列表未实时更新
- **文件**: `lib/provider/order_provider.dart`
- **触发**: 支付完成后查看订单
- **表现**: 订单仍显示"待支付"
- **状态**: ⚠️ `payment_result_page.dart` 已调用 `loadOrders()` 但依赖 `mounted` 检查

---

## 五、UI/UX Bug

### B5-1 [P1] 视频封面闪屏
- **文件**: `lib/widgets/video_player_widget.dart:_syncPlayState()`
- **触发**: 切换 Tab 再切回 → `isActive` 变化
- **表现**: `_isCoverVisible=true` → 封面闪烁一下再显示视频
- **修复**: 使用 `ValueListenableBuilder` 替代标志位

### B5-2 [P2] 小屏手机按钮重叠
- **文件**: `lib/pages/live/live_room_page.dart` 底栏
- **触发**: 屏幕宽度 < 320px
- **表现**: 底栏 4 个按钮 + 输入栏拥挤
- **修复**: 小屏时减少到 3 个按钮 (保留 🛒♥📤)

### B5-3 [P2] 键盘弹出时半屏被遮挡
- **文件**: `lib/widgets/product_detail_sheet.dart`
- **触发**: 评论输入框聚焦
- **表现**: 底部 sheet 未随键盘上移
- **状态**: ✅ `isScrollControlled: true` 已设置

---

## P0 修复实施

### P0-1: PlayerPool URL 去重修复
### P0-2: VideoPreloadManager dispose
