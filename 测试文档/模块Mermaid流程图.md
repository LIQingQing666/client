# 模块详细设计 — Mermaid 流程图

---

## 7.1 FeedPage 滑动切换

```mermaid
flowchart TD
    A["App 启动"] --> B["FeedPage.initState"]
    B --> C["FeedNotifier.loadVideos()"]
    C --> D["API: /api/videos/recommend"]
    D --> E["返回视频列表"]
    E --> F["PageView.builder<br/>scrollDirection: vertical"]

    F --> G{"当前页 = currentIndex?"}
    G -->|"是 (isActive=true)"| H["VideoPlayerWidget"]
    G -->|"否 (isActive=false)"| I["VideoPlayerWidget<br/>暂停 + release"]

    H --> H1["PlayerPool.acquire(videoId, url)"]
    H1 --> H2["_syncPlayState: play()"]
    H2 --> H3["视频播放中"]

    F --> J["用户滑动"]
    J --> K["onPageChanged(index)"]
    K --> L["notifier.setCurrentIndex(index)"]
    L --> M["_preloadAround(index)"]
    M --> N["VideoPreloadManager.enqueue()"]
    L --> O{"index >= length - 3?"}
    O -->|"是"| P["loadMore() 分页"]
    O -->|"否"| Q["继续"]

    P --> D
```

---

## 7.2 FeedNotifier 状态管理

```mermaid
stateDiagram-v2
    [*] --> Loading: loadVideos()
    Loading --> Loaded: API 成功
    Loading --> Error: API 失败
    Error --> Loading: 重试

    state Loaded {
        [*] --> Playing: setCurrentIndex(0)
        Playing --> Preloading: _preloadAround(index)
        Preloading --> Playing: 预加载完成
        Playing --> LoadingMore: index >= length-3
        LoadingMore --> Playing: loadMore() 完成

        state TabSwitch {
            Recommend --> Follow: switchTab(follow)
            Follow --> Recommend: switchTab(recommend)
        }
    }

    note right of Loaded
        FeedState {
          videos: List<VideoModel>
          currentIndex: int
          hasMore: bool
          page: int
          tab: FeedTab
        }
    end note
```

---

## 7.3 PlayerPool 播放器池

```mermaid
flowchart TD
    A["acquire(videoId, url)"] --> B{"_players[videoId] 存在?"}
    B -->|"是 ①"| C["refCount++ → 返回 controller"]
    B -->|"否"| D{"URL 去重<br/>同 URL 已缓存?"}
    D -->|"是 ②"| E["refCount++ → 别名指向<br/>返回已有 controller"]
    D -->|"否"| F{"_initializing<br/>含 videoId?"}
    F -->|"是 ③"| G["等待 200ms<br/>重试"]
    G --> B
    F -->|"否"| H{"_players.length<br/>>= poolSize(3)?"}
    H -->|"是 ④"| I["_evictIfNeeded()<br/>淘汰 refCount 最小的"]
    H -->|"否"| J["创建新 controller ⑤"]
    I --> J
    J --> K["VideoPlayerController<br/>.networkUrl(url)"]
    K --> L["await initialize()<br/>timeout: 15s"]
    L --> M["setLooping(true)"]
    M --> N["存入 _players<br/>refCount=1"]
    N --> O["返回 controller"]

    P["release(videoId)"] --> Q["refCount--"]
    Q --> R{"refCount <= 0?"}
    R -->|"是"| S["controller.pause()<br/>⚠️ 不 dispose"]
    R -->|"否"| T["保持活跃"]

    U["dispose(videoId)"] --> V["controller.dispose()<br/>从 _players 移除"]
```

---

## 7.4 VideoPreloadManager 预加载

```mermaid
flowchart TD
    A["FeedNotifier.setCurrentIndex(index)"] --> B["_preloadAround(index)"]
    B --> C["预加载 index + 1"]
    B --> D["_cancelStalePreloads(index)<br/>取消 < index 和 > index+1"]

    C --> E["VideoPreloadManager<br/>.enqueue(videoId, url, priority)"]
    E --> F["加入优先级队列<br/>_queue.sort by priority desc"]
    F --> G["_processQueue()"]

    G --> H{"WiFi?"}
    H -->|"蜂窝网络"| I["暂停所有预加载"]
    H -->|"WiFi"| J{"_loadingCount <br/>< maxConcurrent(1)?"}
    J -->|"否"| K["等待"]
    J -->|"是"| L["_preloadOne(task)"]

    L --> M["PlayerPool.preload(videoId, url)"]
    M --> N["Pool.acquire → 下载首帧 → Pool.release"]
    N --> O{"成功?"}
    O -->|"是"| P["task.status = done"]
    O -->|"超时 20s"| Q["task.status = failed"]
    O -->|"异常"| R["task.status = failed"]

    P --> G
    Q --> G
    R --> G

    S["网络切换事件"] --> T{"切换到 WiFi?"}
    T -->|"是"| G
    T -->|"否"| U["cancelAll()"]
```

---

## 7.5 VideoPlayerWidget 视频播放器

```mermaid
flowchart TD
    A["VideoPlayerWidget 创建"] --> B["initState → _initPlayer()"]
    B --> C["PlayerPool.acquire(videoId, url)"]
    C --> D{"controller 已初始化?"}
    D -->|"是"| E["_onReady()"]
    D -->|"否"| F["_waitForInit() 监听"]

    E --> G["setState: _isInitialized=true"]
    G --> H["_syncPlayState()"]
    H --> I{"isActive?"}
    I -->|"是"| J["controller.play() + _applyMuteState()"]
    I -->|"否"| K["controller.pause() + _releasePlayer()"]

    J --> L["_fadeController.forward()<br/>封面淡入过渡 300ms"]

    F --> M["controller 初始化完成"]
    M --> E

    N["didUpdateWidget"] --> O{"video.id 变了?"}
    O -->|"是"| P["_releasePlayer → _initPlayer"]
    O -->|"否"| Q{"isMuted 变了?"}
    Q -->|"是"| R["_applyMuteState()"]
    Q -->|"否"| H

    S["_onSeekTriggered"] --> T["clamp(seek, 0, dur-0.5s)"]
    T --> U["controller.seekTo() + play()"]
    U --> V["高亮闪烁 1.2s"]
```

---

## 7.6 LiveRoomPage 直播间页面

```mermaid
flowchart TD
    A["进入直播间"] --> B["LiveRoomPage.initState"]
    B --> C["Future.microtask"]
    C --> D["LiveNotifier.enterRoom(roomId)"]
    D --> E["API: /api/live/rooms/:id"]
    E --> F["WebSocketService.connect()"]

    F --> G["渲染 _LiveRoomActiveContent"]

    G --> H["Stack 层级结构"]
    H --> H1["① VideoPlayer<br/>(IgnorePointer 包裹)"]
    H --> H2["② GestureDetector<br/>(tap→暂停, drag→穿透)"]
    H --> H3["③ 渐变遮罩"]
    H --> H4["④ DanmakuOverlay 弹幕层"]
    H --> H5["⑤ 顶部信息栏<br/>返回+作者+关注+热度+人数"]
    H --> H6["⑥ WS 连接状态"]
    H --> H7["⑦ 评论列表+商品卡"]
    H --> H8["⑧ 底部操作栏<br/>输入+购物车+点赞+礼物+分享"]

    G --> I["用户交互"]
    I --> I1["发送消息 → WS.emit('send_message')"]
    I --> I2["发送礼物 → WS.emit('send_gift')"]
    I --> I3["点赞 → toggleLike()"]
    I --> I4["点击人数 → _showAudienceList()"]
    I --> I5["点击作者 → _AuthorInfoSheet"]
    I --> I6["点击商品 → showProductDetailSheet"]
```

---

## 7.7 DanmakuOverlay 弹幕系统

```mermaid
flowchart TD
    A["WebSocket: 'danmaku' 事件"] --> B["LiveNotifier._handleEvent()"]
    B --> C["_addMessage(message)"]
    C --> D["LiveState.messages 更新"]
    D --> E["DanmakuOverlay ref.listen 检测变化"]
    E --> F{"新消息数 > _lastMessageCount?"}
    F -->|"是"| G["遍历新消息 → _spawnDanmaku()"]
    F -->|"否"| H["无操作"]

    G --> I{"_activeItems.length >= 12?"}
    I -->|"是"| J["移除最旧 → dispose"]
    I -->|"否"| K["_pickLane() 选择空闲轨道"]

    K --> L["创建 AnimationController<br/>duration: 4~7s"]
    L --> M["controller.forward()"]
    M --> N["controller.addListener:<br/>更新 _laneProgress[lane]"]

    N --> O["渲染: _DanmakuSlide<br/>xOffset = screenW*(1-t) - t*200"]
    O --> P["_DanmakuBubble<br/>半透明底+文字"]

    M --> Q["动画结束"]
    Q --> R["_activeItems.remove + dispose"]
    R --> S["_laneProgress[lane] = 0<br/>轨道标记为空闲"]
```

---

## 7.8 PiP 小窗播放

```mermaid
stateDiagram-v2
    [*] --> FullScreen: 进入直播间
    FullScreen --> PiPActive: enterPip(ctrl, room)<br/>4个入口触发
    FullScreen --> Disposed: dispose()<br/>pipActive=false

    PiPActive --> FullScreen: exitPip()→pushNamed<br/>复用 controller
    PiPActive --> Disposed: closePip()<br/>用户点×关闭

    note right of PiPActive
        PipState {
          isActive: true
          controller: ctrl
          roomInfo: room
        }
        浮窗显示在 main.dart Stack 顶层
    end note

    note left of FullScreen
        initState 检测:
        !isActive && ctrl≠null
        → 直接复用，不重新加载
    end note
```

### PiP 进出时序

```mermaid
sequenceDiagram
    participant User as 用户
    participant Live as LiveRoomPage
    participant Pip as PipProvider
    participant Floating as FloatingVideoPlayer
    participant Main as main.dart

    User->>Live: 按返回键/购物车
    Live->>Live: _currentRoom (fallback 保护)
    Live->>Pip: enterPip(controller, room)
    Pip->>Pip: isActive=true, 保存 ctrl
    Live->>Live: context.pop()
    Live->>Live: dispose() → pipActive=true → 不 dispose ctrl

    Main->>Main: 检测 isActive=true
    Main->>Floating: 渲染浮窗 (Stack 顶层)
    Floating->>Floating: ctrl.play() 继续播放

    User->>Floating: 点击浮窗
    Floating->>Pip: exitPip()
    Pip->>Pip: isActive=false, 保留 ctrl
    Floating->>Main: pushNamed('liveRoom')

    Main->>Live: 创建新 LiveRoomPage
    Live->>Pip: 读取: !isActive && ctrl≠null
    Live->>Live: 复用 ctrl, play()
    Live->>Pip: releaseController() 清空
```

---

## 7.9 SingleVideoPlayerPage 收藏页独立播放

```mermaid
flowchart TD
    A["收藏页点击视频/跳转讲解"] --> B["FavoritesPage"]
    B --> C{"点击类型?"}
    C -->|"视频"| D["pushNamed('singleVideo')"]
    C -->|"商品→跳转讲解"| E["pop 弹窗 → delay 200ms"]
    E --> D

    D --> F["SingleVideoPlayerPage.initState"]
    F --> G["_load()"]
    G --> H["API: /api/videos/:id<br/>timeout: 10s"]
    H --> I{"API 成功?"}
    I -->|"否"| J["catch(e) → _videoError=true<br/>显示错误+重试按钮"]
    I -->|"是"| K["VideoPlayerController<br/>.networkUrl(url)"]

    K --> L["await initialize()<br/>timeout: 20s"]
    L --> M{"初始化成功?"}
    M -->|"否"| N["dispose → _videoError"]
    M -->|"是"| O["_onReady()"]

    O --> P["setLooping(true) + play()"]
    O --> Q{"seekTo > 0?"}
    Q -->|"是"| R["_applySeek: clamp(seek, 0, dur-0.5s)"]
    Q -->|"否"| S["从头播放"]

    R --> T["_videoReady=true<br/>渲染 VideoPlayer"]
    S --> T

    T --> U["用户操作"]
    U --> U1["点击暂停/播放"]
    U --> U2["点击商品卡 → 详情弹窗"]
    U --> U3["点返回 → context.pop()"]

    U3 --> V["dispose()"]
    V --> W["pause() + dispose()<br/>立即释放 ExoPlayer"]
```

### 收藏页与 Feed 页解耦架构

```mermaid
graph TB
    subgraph Feed["Feed 页 (IndexedStack 常驻)"]
        FP["FeedPage"]
        FS["FeedState<br/>videos/currentIndex/hasMore"]
        PP["PlayerPool<br/>3 槽位 + URL 去重"]
        PM["VideoPreloadManager<br/>1 预加载 + WiFi 感知"]
    end

    subgraph Favorites["收藏页"]
        FV["FavoritesPage<br/>视频 Tab / 商品 Tab"]
    end

    subgraph Single["独立播放页 (push 路由)"]
        SP["SingleVideoPlayerPage"]
        SC["自建 VideoPlayerController"]
        SL["独立生命周期<br/>init → play → dispose"]
    end

    FV -->|"点击视频/跳转讲解"| SP
    SP -->|"dispose 立即释放"| SC

    FP --> FS
    FS --> PP
    FS --> PM
    PP -->|"完全不共享"| SC

    style SC fill:#f96,stroke:#333
    style SL fill:#f96,stroke:#333
    style PP fill:#6f9,stroke:#333
    style PM fill:#6f9,stroke:#333

    linkStyle 9 stroke:red,stroke-width:3px
```

---

## 整体模块交互总览

```mermaid
graph TB
    subgraph UI["UI 层"]
        FP["FeedPage<br/>PageView 滑动"]
        LR["LiveRoomPage<br/>直播间"]
        FAV["FavoritesPage<br/>收藏页"]
    end

    subgraph State["状态层"]
        FN["FeedNotifier"]
        LN["LiveNotifier"]
        PIP["PipProvider"]
        FOL["FollowProvider"]
    end

    subgraph Service["服务层"]
        POOL["PlayerPool<br/>引用计数+URL去重"]
        PRE["VideoPreloadManager<br/>优先级+WiFi感知+串行"]
        WS["WebSocketService<br/>指数退避重连"]
    end

    subgraph Widget["组件层"]
        VW["VideoPlayerWidget"]
        DM["DanmakuOverlay<br/>轨道分配系统"]
        FL["FloatingVideoPlayer<br/>PiP 浮窗"]
        SVP["SingleVideoPlayerPage<br/>独立播放"]
    end

    subgraph Net["网络层"]
        Dio["DioClient (REST)"]
        Socket["Socket.IO (WebSocket)"]
    end

    FP --> FN
    LR --> LN
    FAV --> SVP

    FN --> POOL
    FN --> PRE
    LN --> WS

    VW --> POOL
    PRE --> POOL
    WS --> Socket

    PIP --> FL
    LR --> PIP
    LR --> DM
    LR --> VW

    Socket -->|":3000/socket.io"| Server["Fastify Server"]
    Dio -->|":3000/api"| Server
```

> **关键路径**：
> - **红色虚线**：Feed PlayerPool 与 SingleVideoPlayerPage **完全隔离**，互不干扰
> - **绿色实线**：PlayerPool 同时服务 FeedPage 和 VideoPreloadManager，共享缓存
> - **蓝色虚线**：PiP 状态通过 PipProvider 在 LiveRoomPage ↔ FloatingVideoPlayer 间传递
