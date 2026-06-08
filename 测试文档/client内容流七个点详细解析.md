# 客户端内容流七个核心模块 — 详细解析

> 涵盖架构设计、实现思路、重难点问题、解决方案

---

## 一、内容流浏览：FeedPage 上下滑切换 + VideoPlayerWidget 播放器组件 + FeedNotifier 状态管理

### 1.1 架构概览

```
FeedPage (ConsumerStatefulWidget)
├── PageView.builder (Axis.vertical)         ← 垂直滑动容器
│   ├── VideoPlayerWidget (active)           ← 当前可见：播放
│   └── VideoPlayerWidget (inactive)         ← 非可见：暂停 + 释放引用
├── Top bar (推荐/关注 Tab 切换)
├── VideoPreloadManager                      ← 预加载调度
└── PlayerPool                               ← 播放器复用池
```

**数据流**：
```
FeedNotifier.loadVideos()
  → VideoApi.getRecommend() / getFollow()
    → 返回 VideoListResponse
  → state = FeedState(videos, currentIndex, hasMore, page)
  → FeedPage 重建 → VideoPlayerWidget(isActive: index == currentIndex)
    → PlayerPool.acquire(videoId, url)
      → VideoPlayerController.networkUrl → initialize → play
```

### 1.2 核心实现

**FeedPage** (`lib/pages/feed/feed_page.dart`, ~500 行)

- 使用 `PageView.builder` + `scrollDirection: Axis.vertical` 实现短视频上下滑
- `_seekTrigger` ValueNotifier 驱动商品讲解片段的 seek 跳转
- `_productCache` 缓存已加载的产品数据，避免重复 API 调用

```dart
// 核心结构
PageView.builder(
  controller: _pageController,
  scrollDirection: Axis.vertical,
  itemCount: feedState.videos.length + (feedState.hasMore ? 1 : 0),
  onPageChanged: (index) {
    if (index >= feedState.videos.length - 3 && feedState.hasMore) {
      notifier.loadMore();  // 提前 3 个触发分页
    }
    notifier.setCurrentIndex(index);
  },
  itemBuilder: (context, index) {
    final isActive = _isTabActive && index == feedState.currentIndex;
    return VideoPlayerWidget(
      key: ValueKey(video.id),
      video: video,
      pool: ref.read(playerPoolProvider),
      isActive: isActive,
      isMuted: isMuted,
      // ... 回调
    );
  },
)
```

**VideoPlayerWidget** (`lib/widgets/video_player_widget.dart`, ~685 行) 是播放器 UI 的核心组件：

```
Stack（层级自下而上）
├── 视频层: FittedBox + SizedBox + VideoPlayer (仅 isActive 时渲染平台视图)
├── 封面层: CachedNetworkImage + 300ms 淡出动画
├── 高亮闪烁: 讲解片段跳转 1.2s 金色边框反馈
├── 播放/暂停图标 (60px 白色半透明)
├── 底部信息区 (_VideoInfoSection): 头像 + 作者名 + 关注 + 标题 + 描述 + 标签
├── 右侧操作栏 (_VideoActionBar): 静音 + 点赞 + 评论 + 分享 + 收藏
├── 悬浮商品卡: FloatingProductCard (TikTok 风格可滑动)
├── 进度条 (_VideoProgressBar): Slider + 时间显示 (mm:ss)
└── Loading spinner
```

**播放状态同步** (`_syncPlayState`)：

```dart
void _syncPlayState() {
  if (widget.isActive) {
    _controller?.play();
    _applyMuteState();
  } else {
    _controller?.pause();
    _releasePlayer(dispose: false);  // 释放引用但不销毁
    // 恢复封面图
    if (!_isCoverVisible) {
      _isCoverVisible = true;
      _fadeController.value = 0;
    }
  }
}
```

**封面淡入动画**：`AnimationController` + `Tween<double>(1.0 → 0.0)` + `CurvedAnimation(Curves.easeOut)`，时长 300ms。视频就绪后 `forward()` 淡出封面。

**FeedNotifier** (`lib/provider/feed_provider.dart`):

```
FeedState {
  videos: List<VideoModel>          // 视频列表
  currentIndex: int                 // 当前页
  tab: 'recommend' | 'follow'       // 推荐/关注
  hasMore: bool, page: int          // 分页
  isLoading: bool, errorMessage: String?
}
```

| 方法 | 职责 |
|------|------|
| `loadVideos()` | 拉取推荐或关注列表，支持 `page` 分页 |
| `loadMore()` | 追加下一页，防重复加载 |
| `setCurrentIndex(n)` | 更新索引，触发预加载 + 取消远离预加载 |
| `toggleLike(id)` | API 调用 + 乐观更新 `isLiked`/`likeCount` |
| `insertVideoAtFront(video)` | `/play/:videoId` 跳转时插入指定视频到列表首 |

### 1.3 重难点问题

**问题 1：快速滑动时多视频同时播放 → 声音重叠**

- **根因**：PageView 滑动过渡阶段，两个 Widget 同时处于 `isActive=true`，`_syncPlayState` 都会调用 `play()`
- **解决**：
  1. `isActive=false` 时不仅 `pause()`，还调用 `_releasePlayer(dispose: false)` 释放 Pool 引用
  2. render 层双重保护：`if (_controller != null && _isInitialized && widget.isActive)` 才渲染 `VideoPlayer` 平台视图

**问题 2：MediaTek 芯片 ExoPlayer 并发超限 → 红屏 + evictor expired**

- **根因**：
  1. Pool 大小 4 + 预加载 2 = 最多 6 个并发 ExoPlayer，超出芯片解码器上限（通常 3-4 个）
  2. `_controller!.value.size` 在状态不一致时返回零尺寸 → crash
  3. `on Exception` 不捕获 `TypeError` → 未处理 → 红屏
  4. 多个 controller 同时 `initialize()` 抢占带宽
- **解决**：
  1. Pool 4→3，增加 `_initializing` 防并发 set
  2. `initialize()` 加 15s 超时
  3. `build()` 中 `size.isEmpty` → 回退封面图
  4. `_syncPlayState` 加 try/catch → 异常自动重建
  5. `on Exception` → `catch(e)` 全类型捕获
  6. 预加载 2→1，启动延迟 800ms→1500ms

**问题 3：关注 Tab 切换后列表不更新**

- **根因**：`FeedNotifier` 不感知关注状态变化，`StatefulShellRoute` 保活 Tab 不会重新 `initState`
- **解决**：`ref.listen(followProvider)` 监听关注/取关变化 → 自动 `loadVideos()`

---

## 二、直播间实时互动：LiveRoomPage + DanmakuOverlay + WebSocket

### 2.1 架构概览

```
LiveRoomPage (ConsumerStatefulWidget, 接收 roomId)
├── PageView.builder (多房间滑动, displayRooms)
│   ├── _LiveRoomActiveContent (当前页, ConsumerStatefulWidget)
│   │   ├── VideoPlayerController (自建, 不走 PlayerPool)
│   │   ├── ValueListenableBuilder → FittedBox → VideoPlayer
│   │   ├── DanmakuOverlay 弹幕层
│   │   ├── 评论列表 _CommentList
│   │   └── FloatingProductCard 商品卡
│   └── _LiveRoomPlaceholder (非活跃页, 封面图)
└── LiveNotifier (WebSocket events → LiveState)
```

**数据流**：
```
LiveRoomPage.initState
  → LiveNotifier.enterRoom(roomId)
    → HTTP: LiveApi.getRoomDetail()
      → LiveState(room, products, coupons)
    → WebSocket: WebSocketService.connect(roomId)
      → joinRoom(roomId)
      → eventStream.listen(_handleEvent)
        → danmaku / online_count / explaining_product / stock_update / room_products
```

### 2.2 核心实现

**LiveNotifier** (`lib/provider/live_provider.dart`, ~305 行)

```
LiveState {
  room: LiveRoomInfo?, messages: List<LiveMessage>,
  onlineCount, likeCount, isLiked, heatCount,
  currentProduct: ProductModel?, products: List<ProductModel>,
  coupons: List<LiveCoupon>,
  isLoading, isConnected, errorMessage
}
```

**WebSocket 事件处理**（`_handleEvent`）：

```dart
void _handleEvent(Map<String, dynamic> event) {
  if (!_active) return;  // 离开房间后静默丢弃
  try {
    switch (event['event']) {
      case 'danmaku':          _addMessage(LiveMessage.fromJson(event));
      case 'online_count':     state = state.copyWith(onlineCount: count);
      case 'explaining_product': // 更新当前讲解商品
      case 'room_products':    // 更新商品列表
      case 'stock_update':     // 实时库存变化
      case 'room_state':       // 新加入者同步状态
    }
  } catch (e, stack) { debugPrint(stack.toString()); }
}
```

**DanmakuOverlay** (`lib/widgets/danmaku_overlay.dart`, ~190 行):

```dart
ref.listen<LiveState>(liveProvider, (prev, next) {
  if (next.messages.length > _lastMessageCount) {
    for (int i = _lastMessageCount; i < next.messages.length; i++) {
      _spawnDanmaku(next.messages[i]);
    }
    _lastMessageCount = next.messages.length;
  }
});
```

每条弹幕：`AnimationController` 驱动 4~7s 从右到左 + 随机 Y 坐标（屏幕 40%）+ 随机字号（12~15pt）- 使用 `IgnorePointer` 包裹不禁用下层交互。最多 12 条同时，超出移除最旧。

**WebSocket 服务** (`lib/services/websocket_service.dart`, ~170 行):

```dart
_socket = io.io(
  wsUrl,  // http://192.168.50.174:3000（注意：无 /api 后缀！）
  OptionBuilder()
    .setTransports(['websocket'])
    .setPath('/socket.io')
    .setAuth({'token': token})
    .build(),
);
```

- 事件流：`eventStream`（broadcast StreamController）→ `_handleEvent`
- 断线重连：指数退避 1s→2s→4s→8s，最多 5 次，WAL 模式防重复 Timer
- `connectCompleter` 模式：异步等待连接完成，10s 超时

**观众列表**：`_generateAudiences(onlineCount)` 动态生成。前 4 个为种子用户（小明数码等），后续伪随机生成（prefix×6 + suffix×32 + 数字 → 组合）。最多展示 30 人。

**房间列表 Provider**：`roomListProvider` 在 `LivePage._loadRooms()` 中填充，`LiveRoomPage` 通过 `PageView.builder` 支持上下滑切换直播间，`switchRoom()` 取消旧 WebSocket 订阅 → 加载新房间数据。

### 2.3 重难点问题

**问题 1：WebSocket 事件投递 vs Widget 生命周期竞态 → crash**

- **现象**：离开直播间后崩溃，`_lifecycleState != _ElementLifecycle.defunct`
- **根因链条**：
  1. 用户返回 → `LiveRoomPage.dispose()` → `leaveRoom()` → `_eventSub.cancel()`
  2. **但** `cancel()` 只能阻止未来事件，microtask 队列中已排队的 WebSocket 事件仍会投递到 `_handleEvent`
  3. `_handleEvent` 中 `mounted` 检查无效——`LiveNotifier` 是全局 `StateNotifierProvider`，never disposed
  4. `state = ...` → Riverpod 通知已销毁的 Widget → `markNeedsBuild` on defunct element → crash
- **解决**：引入 `_active` 标志位（**不是** `mounted`）：
  ```dart
  // enterRoom() — 第一个 await 之前同步设置
  _active = true;

  // leaveRoom() — cancel 之前同步清除（关键时序！）
  void leaveRoom() {
    _active = false;             // ← 先同步标记不活跃
    _eventSub?.cancel();         // ← 再取消订阅
    _eventSub = null;
    if (state.room != null) wsService.leaveRoom(state.room!.id);
  }

  // _handleEvent — 入口检查
  if (!_active) return;  // 静默丢弃残留事件
  ```
  关键点：Dart 是单线程，`_active = false` 在 `cancel()` 之前执行，任何已排队的 microtask 在恢复执行时看到 `_active=false` 直接 return。

**问题 2：Android SurfaceView 拦截触摸 → PageView 无法滑动**

- **根因**：`VideoPlayer` 底层 SurfaceView 作为平台视图覆盖触摸事件
- **解决**：`IgnorePointer` 包裹视频层 → 触摸穿透到外层 PageView。单独的手势（如点击）由独立的 `GestureDetector` 处理

**问题 3：弹幕完全不显示 + WebSocket 状态始终 reconnecting**

- **根因**：`wsUrl` 错误配置了 `/api` 后缀，导致 Socket.IO 握手路径变成 `/api/socket.io/...`（正确应为 `/socket.io/...`）
- **解决**：`wsUrl = 'http://192.168.50.174:3000'`（不含 `/api`）。关键：REST API 需 `/api`（Fastify 路由），Socket.IO 直接挂 HTTP Server

**问题 4：`roomListProvider` 未填充 → 多房间滑动失效**

- **根因**：`LivePage._loadRooms()` 仅把数据存在本地 `_rooms` 中，未同步到 `roomListProvider`
- **解决**：`_loadRooms()` 中增加 `ref.read(roomListProvider.notifier).state = rooms;`

---

## 三、播放器池：PlayerPool 引用计数复用 + URL 去重 + LRU 淘汰

### 3.1 架构设计

**PlayerPool** (`lib/services/player_pool.dart`, ~144 行)

```
PlayerPool(poolSize: 3)
├── _players: Map<String, _PooledPlayer>     // videoId → {controller, url, refCount}
├── _initializing: Set<String>               // 防并发初始化
│
├── acquire(videoId, url) → controller       // 4 级查找策略
├── release(videoId, dispose: false)         // 减引用，不立即销毁
├── preload(videoId, url)                    // 预热下载
├── cancelPreload(videoId)                   // 取消未引用的预加载
└── _evictIfNeeded()                         // refCount 最小淘汰
```

### 3.2 核心实现

**acquire 五级策略**：

```
1. videoId 命中 → refCount++ → 直接返回 (O(1))
2. URL 去重命中 → refCount++ → 别名指向 → seekTo(0) 从头播放 (O(n), n≤3)
3. 正在初始化中 → 等待 200ms 后重试 (防并发)
4. 池满 (length ≥ poolSize) → 淘汰 refCount 最小的空闲播放器
5. 新建 controller → initialize() 15s 超时 → 存入 _players
```

```dart
Future<VideoPlayerController> acquire(String videoId, String url) async {
  // 1. videoId 命中
  if (_players.containsKey(videoId)) {
    _players[videoId]!.refCount++;
    return _players[videoId]!.controller;
  }
  // 2. URL 去重 + seekTo(0) 从头播放
  for (final entry in _players.entries) {
    if (entry.value.url == url) {
      entry.value.refCount++;
      _players[videoId] = entry.value;          // 别名指向
      entry.value.controller.seekTo(Duration.zero);  // ← 关键修复
      return entry.value.controller;
    }
  }
  // 3. 防并发初始化
  if (_initializing.contains(videoId)) {
    await Future.delayed(const Duration(milliseconds: 200));
    if (_players.containsKey(videoId)) {
      _players[videoId]!.refCount++;
      return _players[videoId]!.controller;
    }
  }
  _initializing.add(videoId);
  try {
    _evictIfNeeded();  // 4. 池满淘汰
    // 5. 创建
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize().timeout(Duration(seconds: 15));
    await controller.setLooping(true);
    await controller.setVolume(1.0);
    _players[videoId] = _PooledPlayer(controller, 1, url);
    return controller;
  } finally {
    _initializing.remove(videoId);
  }
}
```

**release 策略**：`refCount--`；归零时 `pause()` 不 `dispose()`——保留已解码首帧和缓冲，下次 `acquire` 瞬时返回

**evict 策略**：选择 `refCount` 最小的 entry 淘汰（空闲中的播放器），不使用 FIFO——避免回滑时刚淘汰的视频需重新下载

### 3.3 重难点问题

**问题：同 URL 视频连续出现 → 画面相同**

- **现象**：种子里 4 个视频共用 `butterfly.mp4`，Feed 页按播放量排序后连续出现 → URL 去重返回同一 controller → 第二个视频从第一个的播放位置继续（画面完全相同）
- **根因**：`acquire` 的 URL 去重逻辑（第 2 级）只做别名指向，未重置播放位置
- **解决**：别名时增加 `entry.value.controller.seekTo(Duration.zero)` 从头播放

**问题：快速滑动时同一 videoId 重复初始化**

- **根因**：首个 `acquire` 在 `await initialize()` 时，滑动回来再 `acquire`，`_players` 中无记录
- **解决**：增加 `_initializing` Set 跟踪进行中的初始化，并发请求等待 200ms 后从池中获取

---

## 四、视频预加载：VideoPreloadManager 优先级队列 + WiFi 感知 + 串行加载

### 4.1 架构设计

**VideoPreloadManager** (`lib/services/video_preload_manager.dart`, ~180 行)

```
FeedNotifier.setCurrentIndex(n)
  → _preloadAround(n)                    // 预加载 n+1
  → _cancelStalePreloads(n)              // 取消远离的视频
    → VideoPreloadManager.enqueue(videoId, url, priority)
        → _queue.sort((a,b) => b.priority - a.priority)  // 优先级排序
        → _processQueue()
            → 串行 (_currentTask != null → return)
            → _preloadOne(task)
                → PlayerPool.preload(videoId, url)
                    → acquire → release(refCount=0 → pause 不 dispose)
```

### 4.2 核心配置

| 参数 | 值 | 设计理由 |
|------|-----|---------|
| `preloadVideoCount` | 1 | 仅下一个视频，减少带宽竞争 |
| `maxConcurrent` | 1 | 串行下载，不抢当前视频 |
| `wifiOnly` | true | 蜂窝网络自动暂停 |
| `startupDelay` | 1500ms | 当前视频优先缓冲 |
| `timeout` | 20s | 网络异常保护 |

**WiFi 感知**：
```dart
void _onNetworkChanged(List<ConnectivityResult> results) {
  if (!wasWifi && _isOnWifi) {
    _processQueue();    // WiFi 恢复 → 继续预加载
  } else if (wasWifi && !_isOnWifi) {
    cancelAll();        // 切到蜂窝 → 取消全部
  }
}
```

### 4.3 重难点问题

**问题：预加载与当前视频带宽竞争**

- **根因**：预加载和当前 `initialize()` 并发下载 → 首帧加载慢 1-2s
- **解决**：启动延迟 800ms→1500ms（当前视频充足的初始缓冲时间）+ `maxConcurrent=1` 串行 + 预加载数 2→1

---

## 五、小窗播放（PiP）：PipProvider + FloatingVideoPlayer + 进出 PiP 生命周期管理

### 5.1 架构设计

**四文件协同**：

```
PipProvider (全局状态)
├── PipState { isActive, videoController?, roomInfo? }
├── enterPip(controller, room)   → 保存 controller，isActive=true
├── exitPip()                    → isActive=false，保留 controller
├── releaseController()          → 转移所有权给直播间
└── closePip()                   → 完全销毁

FloatingVideoPlayer (浮窗 UI, ~230 行)
├── GestureDetector.onPanUpdate  → 可拖拽，边界约束
├── 自适应尺寸: 120~150px 宽 × 16:9
├── 顶部: 房间标题 + 关闭按钮
└── 底部: "返回直播间"

main.dart (全局挂载点)
└── MaterialApp.router.builder → Stack 顶层 → if (pipActive) FloatingVideoPlayer

LiveRoomPage (4 个 PiP 入口)
├── 1. PopScope.onPopInvokedWithResult (系统返回键)
├── 2. 购物车按钮 → enterPip → go('/cart')
├── 3. 商品"立即购买" → enterPip → pushNamed('orderConfirm')
└── 4. 左上角返回箭头 → enterPip → context.pop()
```

### 5.2 核心实现

**进入 PiP**：
```dart
void enterPip(VideoPlayerController controller, LiveRoomInfo room) {
  state = PipState(isActive: true, videoController: controller, roomInfo: room);
}
```

**返回直播间 — 无缝续播**：
```dart
// 1. 浮窗点击 → main.dart
onTap: () {
  ref.read(pipProvider.notifier).exitPip();  // isActive=false，保留 controller
  router.pushNamed('liveRoom', {roomId});
}

// 2. LiveRoomPage.initState 检测 PiP controller — 直接复用！
if (!pipState.isActive && pipState.videoController != null) {
  _videoController = pipState.videoController;
  _videoReady = true;
  _videoController!.play();
  ref.read(pipProvider.notifier).releaseController();  // 转移所有权
  return;  // ← 不重新下载视频！
}
```

**Controller 生命周期保护**：
```dart
void dispose() {
  final pipActive = ref.read(pipProvider).isActive;
  if (!pipActive) {
    _videoController?.pause();
    _videoController?.dispose();  // 仅在非 PiP 时销毁
  }
  super.dispose();
}
```

### 5.3 重难点问题

**问题：PiP 返回直播间 → 视频黑屏 / 不播放**

- **根因（三层嵌套）**：
  1. `build()` 中 `state.room == null` 提前 return error/loading → `initState` 的 PiP 复用永远不执行
  2. PiP 入口检查 `room != null` 才保存 → API 未完成时 room 为 null → PiP 未创建 → controller 被 dispose
  3. `displayRooms` fallback 链不含 `pipState.roomInfo`
- **解决（7 处修改）**：
  1. 引入 `effectiveRoom = state.room ?? widget.room`，不再因 room null 提前 return
  2. 仅 `!hasVideo` 时显示错误/loading（而非 `state.room == null`）
  3. `_currentRoom` getter 统一 PiP 入口 fallback → `state.room ?? widget.room`
  4. `initState` 中检测 PiP controller → 立即跳过 loading，不等待 API
  5. `displayRooms` 新增 `pipState.roomInfo` 第三级 fallback
  6. 4 个 PiP 入口全部去掉 `room != null` 前置检查

---

## 六、商品讲解片段定位：seek 跳转 + 高亮闪烁 + 边界 clamp 保护

### 6.1 跳转触发路径

**两条跳转路径**：

```
路径 A: Feed 页商品卡
  onSeekToTime(time) → _seekTrigger.value = time
    → _onSeekTriggered()
      → clamped = time.clamp(0, (durSec - 0.5))
      → controller.seekTo()
      → 金色边框高亮 1.2s

路径 B: 收藏页商品弹窗 → 跨页面跳转
  onSeekToTime(time) → Navigator.pop() → await 200ms
    → pushNamed('singleVideo', {seek: time})
      → SingleVideoPlayerPage._applySeek()
```

### 6.2 核心实现

**高亮闪烁反馈**：
```dart
void _onSeekTriggered() {
  final durMs = _controller!.value.duration.inMilliseconds;
  final clampedMs = (seekTo * 1000).clamp(0, (durMs - 500).clamp(0, durMs));
  _controller!.seekTo(Duration(milliseconds: clampedMs));
  _controller!.play();
  setState(() => _highlightActive = true);    // 金色边框 + 光晕
  Future.delayed(1200ms, () => _highlightActive = false);
}
```

**边界 clamp**：`(seekTo * 1000).clamp(0, (durationMs - 500).clamp(0, durationMs))` — 双重 clamp 保证不 seek 到视频尾帧之外

**讲解按钮 UI**（`_SegmentSeekButton`）：
- 0 段 + `highlightTime > 0` → 单跳转按钮（兼容旧数据）
- 1 段 → 单按钮 + 片段标签
- 2+ 段 → 按钮 → 弹窗列表供选择

### 6.3 重难点问题

**问题 1：收藏页跳转后视频不播放 / 路由冲突**

- **根因**：`Navigator.pop()`（关闭弹窗）+ `pushNamed()`（推新页面）同步执行，弹窗退出动画未完就 push → Navigator 状态冲突 → push 被忽略
- **解决**：`onSeekToTime` 改为 async → `pop()` 后 `await Future.delayed(200ms)` → `pushNamed()`

**问题 2：讲解时间超出视频时长**

- **根因**：种子 `highlightTime` 设为 5-35 秒，但演示视频仅 7 秒
- **解决**：种子数据修正为 1-6 秒；客户端增加双重 clamp 保护

---

## 七、收藏页独立播放：SingleVideoPlayerPage 与 Feed 页完全解耦

### 7.1 架构演进

| 版本 | 方案 | 致命问题 |
|------|------|---------|
| v1 | 复用 FeedPage → `pendingJumpVideoId` | `loadVideos()` 竞态覆盖 |
| v2 | FeedPage + `insertVideoAtFront()` | `_pendingJumpVideoId` 提前清空（死代码） |
| v3 | FeedPage + API fallback | 竞态仍在 |
| v4 | **独立 SingleVideoPlayerPage** + 自建 controller | 不与 PlayerPool 共享缓存 |
| v5 | 独立页 + `_urlCache` 全局缓存 | 与 PlayerPool 重复/资源竞争 |
| v6 | **独立页 + 完全隔离**（最终方案） | 自建 controller，独立生命周期 |

**最终架构**：
```
Feed 页 (IndexedStack)
├── PlayerPool (3 槽位，引用计数复用)
├── VideoPreloadManager (1 预加载，串行)
└── FeedNotifier (列表/索引/分页)

收藏页 → SingleVideoPlayerPage
├── 自建 VideoPlayerController
├── 独立生命周期: init → play → dispose
├── 不触碰 FeedState / PlayerPool
└── 自有 UI: 封面、播放/暂停、进度条、作者面板、商品卡
```

### 7.2 核心实现

```dart
// 1. 自建 controller — 不走 PlayerPool
final controller = VideoPlayerController.networkUrl(Uri.parse(url));
controller.addListener(_onChanged);
await controller.initialize().timeout(Duration(seconds: 20));
controller.setLooping(true);
controller.play();

// 2. dispose 立即释放资源
void dispose() {
  _controller?.removeListener(_onChanged);
  _controller?.pause();
  _controller?.dispose();  // 立即释放 ExoPlayer 硬件解码器
  _controller = null;
  super.dispose();
}

// 3. catch(e) 全捕获 — 不只是 on Exception
try { ... } catch (e) {
  setState(() { _loading = false; _videoError = true; });
}

// 4. 监听 controller 内建错误
void _onChanged() {
  if (v.hasError) setState(() => _videoError = true);
}
```

**可拖拽进度条**：
```dart
Slider(
  value: _dragValue >= 0 ? _dragValue : progress,
  onChanged: (v) => setState(() => _dragValue = v),
  onChangeEnd: (v) {
    controller.seekTo(Duration(milliseconds: (v * durationMs).toInt()));
    setState(() => _dragValue = -1);
  },
)
```

**作者面板**：`_AuthorSheet` — 点击头像/作者名弹出底部弹窗（头像/昵称/ID/关注按钮），关注按钮使用 `ref.watch(followProvider)` 响应式更新

**点赞按钮**：使用本地 `_liked`/`_likeCount` 状态跟踪，先乐观更新 UI → API 调用 → 失败时回滚。用户 ID 从 `authProvider.userId` 获取（而非硬编码 `'u1'`）

### 7.3 重难点问题

**问题 1：`TypeError` 被 `on Exception` 漏掉 → 永久 loading**

- **根因**：种子重建后 UUID 变化，API 返回 `data: null` → `as Map` 抛出 `TypeError extends Error`（非 `Exception`）
- **解决**：API 层主动 null 检查 + 抛出 `ClientException`；所有 catch 用 `catch(e)` 全捕获

**问题 2：ExoPlayer 解码器达到上限（inputFps=0）**

- **根因**：Feed 页 IndexedStack 中 PlayerPool 保留 3 个播放器，独立页创建第 4 个 → MediaTek 芯片限制 3-4 个并发
- **解决**：独立页 dispose 立即 `pause()+dispose()` 释放解码器；重试按钮先 dispose 旧 controller 再创建新的

**问题 3：`navigator.pop` + `pushNamed` 时序冲突**

- **根因**：弹窗未完全关闭就 push 新路由
- **解决**：`pop()` 后 `await Future.delayed(200ms)` 再 push

**问题 4：点赞按钮无响应**

- **根因**：`isLiked` 从 API 返回的 `VideoModel` 读取，API 调用后不更新本地状态；用户 ID 硬编码 'u1'
- **解决**：改为 `ConsumerStatefulWidget` 本地追踪 `_liked`/`_likeCount`，乐观更新 + 失败回滚

**问题 5：收藏页视频收藏后图标不变色**

- **根因**：`ProductDetailSheet` 的 `isFavorited` 是外部一次性快照 `ref.read()`，不响应变化
- **解决**：sheet 内部改用 `ref.watch(favoriteProvider).isFavorited(product.id)` 响应式监听

---

## 总结

### 关键架构决策

| 决策 | 选择 | 理由 |
|------|------|------|
| Feed 播放器管理 | PlayerPool 引用计数 | 平衡内存/解码器资源与滑动流畅度 |
| 收藏页播放器 | 独立 controller，不走 Pool | 避免与 Feed 页 IndexedStack 竞争解码器 |
| 直播视频 | 自建 controller（也不走 Pool） | 直播是持续流，不应被池化 |
| WebSocket 生命周期 | `_active` 标志位 + `leaveRoom` 同步 cancel | 解决 microtask 队列竞态 |
| PiP 无缝续播 | controller 所有权转移（不 dispose） | 避免重新下载/解码视频 |
| 预加载策略 | 串行 + WiFi 感知 + 延迟启动 | 优先保证当前视频流畅 |

### 关键 Bug 解决方案汇总

| 问题 | 根因类别 | 解决方案 |
|------|---------|---------|
| 直播页 crash（defunct widget） | 异步竞态 | `_active` flag 同步清除 |
| Feed 滑动红屏/卡顿 | 资源上限 | Pool 降容 + 防并发 + 超时 |
| 弹幕不显示 | URL 配置 | wsUrl 去掉 /api 后缀 |
| PiP 返回黑屏 | 状态竞态 | 三级 fallback + effectiveRoom |
| 连续视频画面相同 | 逻辑遗漏 | URL 别名 seekTo(0) |
| Dart Error vs Exception | 语言特性 | catch(e) 全类型捕获 |
| Navigator 时序冲突 | 路由竞态 | pop 后 await 200ms |
| 收藏页图标不更新 | 非响应式读取 | ref.read → ref.watch |
