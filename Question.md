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
