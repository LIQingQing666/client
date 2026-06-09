# 客户端内容流模块 — 核心亮点

> 答辩人负责：Feed 滑动浏览、直播间实时互动、播放器池、预加载、PiP 小窗、讲解定位、收藏页独立播放

---

## 一、PlayerPool 播放器池：四级策略 + 引用计数生命周期

**亮点**：设计了 `acquire` 的四级回退策略，在 ~130 行代码中实现完整的播放器复用体系。

```
acquire(videoId, url)
  ├─ ① videoId 命中 → O(1) 直接返回
  ├─ ② URL 去重命中 → 别名复用，不创建新 ExoPlayer
  ├─ ③ 正在初始化中 → 等待 200ms 防并发
  └─ ④ 池满 → 淘汰 refCount 最小的 + 创建新实例（15s 超时保护）
```

**关键技术决策**：
- **引用计数归零后 pause 不 dispose**：保留首帧和缓冲数据，下次 acquire 瞬时返回——实现视频"秒切"
- **URL 去重**：所有演示视频共享同一个 butterfly.mp4 URL，池中永远只有 1 个 ExoPlayer 实例（其余为别名），从根源上避免 Android 硬件解码器超限
- **防并发初始化**：`_initializing` 集合跟踪正在初始化的 videoId，快速滑动时不会创建重复 controller

## 二、PiP 小窗播放：跨页面 controller 所有权转移

**亮点**：4 个文件协同实现"退出→小窗播放→返回→无缝续播"闭环，controller 在页面间零开销转移。

```
退出直播间                   返回直播间
    │                            │
    ├─ enterPip(ctrl, room)      ├─ exitPip() → isActive=false, 保留 ctrl
    ├─ dispose() 检测 isActive   ├─ initState() 检测 !isActive && ctrl≠null
    │   → 不 dispose controller  │   → 直接复用，play()
    └─ 浮窗接管播放              └─ releaseController() 转移所有权
```

**关键技术决策**：
- `PipState` 三层字段：`isActive` 控制显示，`videoController` 保持播放器存活，`roomInfo` 保存返回上下文
- `exitPip()` vs `closePip()` 语义分离：退出小窗保留 controller，关闭小窗才销毁
- `dispose()` 中条件判断 `pipState.isActive`——保护正在小窗中使用的 controller 不被销毁
- `_currentRoom` getter：`liveState.room ?? widget.room`——API 未完成时也有 fallback，所有 4 个 PiP 入口统一使用

## 三、DanmakuOverlay 弹幕系统：独立动画层 + 并发控制

**亮点**：基于 `AnimationController` 的自研弹幕引擎，与 Flutter Widget 树解耦。

- **独立动画层**：每条弹幕一个 `AnimationController`（4~7s），从右向左平移，随机 Y 坐标（屏幕上方 40% 区域）、随机字号
- **并发上限 12 条**：超出移除最旧的 + dispose AnimationController，内存可控
- **IgnorePointer 包裹**：弹幕不响应触摸，不影响底层交互
- **与评论列表互补**：弹幕（飘屏动画）+ 评论列表（静态滚动），两套渲染通道

## 四、VideoPreloadManager 预加载：WiFi 感知 + 串行执行

**亮点**：在"不影响当前视频"的前提下实现智能预加载。

- **启动延迟 1.5s**：当前视频优先完成初始缓冲，然后才开始预加载
- **串行执行（maxConcurrent=1）**：一次只下载一个，不抢带宽
- **WiFi 感知**：蜂窝网络自动暂停所有预加载，切回 WiFi 自动恢复
- **优先级队列**：距当前索引越近优先级越高
- **取消策略**：只预加载下一个（index+1），其余立即取消，避免无效下载

## 五、LiveRoomPage 直播间：Android SurfaceView 触摸穿透

**亮点**：解决了 Android 平台视图（SurfaceView）与 Flutter 手势系统的冲突。

**问题**：`VideoPlayer` 底层使用 Android `SurfaceView` 渲染视频，该视图位于 Flutter Widget 树之上，**吸收所有触摸事件**，导致外层 `PageView`（上下滑切换直播间）无法接收滚动手势。

**方案**：
```dart
// ① IgnorePointer 包裹 VideoPlayer → 触摸穿透到 PageView
IgnorePointer(child: VideoPlayer(controller))

// ② 独立 GestureDetector 处理点击暂停/播放
GestureDetector(
  behavior: HitTestBehavior.translucent,  // 不阻挡拖拽
  onTap: () => togglePlayPause(),
)
```

`HitTestBehavior.translucent` 是关键——它让 `GestureDetector` 参与 hit test 但不阻挡事件继续传递：tap 被捕获用于暂停/播放，垂直 drag 透传到 PageView 触发切换房间。

## 六、SingleVideoPlayerPage 收藏页独立播放：六版迭代最终解耦

**亮点**：从复用 FeedPage → 完全独立播放页，历经 6 版迭代，最终实现零耦合。

| 版本 | 方案 | 核心问题 |
|------|------|----------|
| v1 | 复用 FeedPage + pendingJumpVideoId | `loadVideos()` 覆盖插入的视频 |
| v2 | FeedPage + insertVideoAtFront | `_pendingJumpVideoId` 提前清空的死代码 bug |
| v3 | FeedPage + API fallback | 竞态仍存在 |
| v4 | 独立页 + 自建 controller | 每次从网络下载，不走缓存 |
| v5 | 独立页 + _urlCache | 与 Feed PlayerPool 资源竞争 |
| v6 | 独立页 + 完全隔离 + 防御式编程 | ✅ 最终方案 |

**v6 核心设计**：
- 自建 `VideoPlayerController`——不碰 PlayerPool
- `dispose()` 立即 `pause() + dispose()`——释放 ExoPlayer 硬件解码器
- `catch(e)` 全捕获（非 `on Exception`）——`TypeError` 等 Error 类型也不放过
- `_onChanged` 监听 `hasError`——平台层异常即时反馈
- 重试按钮先 dispose 旧 controller 再创建新的

## 七、跨模块的深度调试能力

**亮点**：调试过程中深入到 Android 系统层、Dart 语言特性、Flutter 渲染管线的边界问题。

| 问题 | 涉及层次 | 关键发现 |
|------|----------|----------|
| 弹幕不显示 | 网络层 | `wsUrl` 与 `baseUrl` 路径独立性——REST 需要 `/api`，Socket.IO 不能带 |
| 红屏 crash | Dart 类型系统 | `Error` ≠ `Exception`——`TypeError` extends `Error`，`on Exception` 无法捕获 |
| 视频卡顿 | Android 系统 | MediaTek `c2.mtk.avc.decoder` 仅支持 3-4 个并发，ExoPlayer 超限导致 `inputFps=0` |
| 无法滑动 | Flutter 渲染 | `SurfaceView` 平台视图位于 Flutter Widget 树之上，吸收所有触摸 |
| BufferPool 驱逐 | Android 图形 | BufferPool 总量有限，多个 ExoPlayer 同时申请 → `evictor expired` → 缓冲区被强制回收 |
| 导航跳转失败 | Flutter 路由 | `Navigator.pop()` 和 `pushNamed()` 同步执行 → Navigator 状态机冲突 → 新路由未创建 |

---

## 总结一句话

> 从 Dart 类型系统的 `Error`/`Exception` 差异，到 Android `SurfaceView` 的触摸层级，再到 MediaTek 芯片的硬件解码器上限——**每一层抽象边界的问题都被定位并解决**，最终交付了一个稳定流畅的电商直播视频体验。
