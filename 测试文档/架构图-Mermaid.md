# 项目架构图（Mermaid）

> 涵盖 7 个核心模块：内容流浏览、直播间实时互动、播放器池、视频预加载、商品讲解片段定位、收藏页独立播放、小窗播放（PiP）

---

## ⚠️ 修正记录

| # | 位置 | 原错误 | 修正 |
|---|------|--------|------|
| 1 | 系统架构图 | `PlayerPool 播放器池(4)` | → `PlayerPool (上限3)`，池大小按实际代码为 3 |
| 2 | 内容流数据流 | `Notifier->>Pool: preload/acquire` | → FeedNotifier 不直接调 PlayerPool；acquire 由 VideoPlayerWidget 调用，preload 由 VideoPreloadManager 中转 |
| 3 | 直播间通信 | `API` 参与者未声明 | → `Notifier->>API` 行中 API 未在 participant 列表中声明，补充 `participant API as LiveApi` |
| 4 | 直播间通信 | 无消息去重流程 | → 补充 `sendMessage`/`sendGift` 的 `_pendingMsgFingerprints` 乐观添加 + 去重逻辑 |
| 5 | 直播间通信 | `sendGift(icon, name)` | → 实际为 3 个参数：`sendGift(userName, giftIcon, giftName)` |
| 6 | 数据持久化 | `MySQL / PostgreSQL` | → 实际为 **SQLite (better-sqlite3, WAL 模式)**，这是 Node.js 后端的实际数据库 |
| 7 | 组件树 | 缺 `DanmakuOverlay` | → LiveRoom 组件树补充弹幕层，PiP 补充 `MaterialApp.builder` 挂载方式 |

---

## 一、整体模块交互总览

```mermaid
graph TB
    subgraph UI["📱 UI 层"]
        FP["FeedPage<br/>视频流上下滑"]
        LR["LiveRoomPage<br/>直播间"]
        SVP["SingleVideoPlayerPage<br/>收藏页独立播放"]
    end

    subgraph Widget["🧩 组件层"]
        VW["VideoPlayerWidget"]
        DM["DanmakuOverlay"]
        FL["FloatingVideoPlayer<br/>PiP 浮窗"]
    end

    subgraph State["🧠 状态层 (Riverpod)"]
        FN["FeedNotifier"]
        LN["LiveNotifier"]
        PIP["PipProvider"]
    end

    subgraph Service["⚙️ 服务层"]
        POOL["PlayerPool<br/>上限3/引用计数/URL去重"]
        PRE["VideoPreloadManager<br/>优先级队列/WiFi感知/串行"]
        WS["WebSocketService<br/>指数退避重连"]
    end

    subgraph Net["🌐 网络层"]
        Dio["DioClient (REST)"]
        Socket["Socket.IO (WebSocket)"]
    end

    subgraph Backend["🖥️ 后端 (Fastify)"]
        REST["REST API"]
        WSSvr["Socket.IO Server"]
        DB["SQLite"]
    end

    UI        == 调用 ==>     Widget
    UI        == 读写 ==>     State
    Widget    == 使用 ==>     Service
    State     == 调度 ==>     Service
    State     == 请求 ==>     Net
    Service   == 请求 ==>     Net

    Dio       --- REST
    Socket    --- WSSvr
    REST      --- DB
    WSSvr     --- DB
```

> **说明**：粗箭头 `==>` 为层间依赖方向，细连线 `---` 为网络协议连接。不绘制层内组件的细粒度交叉连线，保持整体结构清晰。

---

## 二、内容流浏览（短视频Feed）

```mermaid
sequenceDiagram
    actor User
    participant FeedPage as FeedPage
    participant Notifier as FeedNotifier
    participant VW as VideoPlayerWidget
    participant Pool as PlayerPool
    participant Preload as VideoPreloadManager
    participant API as VideoApi
    participant Server as Backend

    User->>FeedPage: 打开App
    FeedPage->>Notifier: loadVideos()
    Notifier->>API: getRecommend(page=1)
    API->>Server: GET /api/videos/recommend
    Server-->>API: {list:[Video], hasMore}
    API-->>Notifier: VideoListResponse
    Notifier-->>FeedPage: state.videos = list

    User->>FeedPage: 上下滑动 PageView
    FeedPage->>Notifier: setCurrentIndex(index)
    Notifier-->>FeedPage: currentIndex 更新

    Note over FeedPage,VW: 当前可见视频 isActive=true
    FeedPage->>VW: VideoPlayerWidget(isActive:true)
    VW->>Pool: acquire(videoId, url)
    Pool->>Pool: URL去重 → seekTo(0)
    Pool-->>VW: VideoPlayerController
    VW->>VW: initialize() → play()
    VW->>VW: 封面淡出 (300ms)

    Note over FeedPage,VW: 非当前视频 isActive=false
    VW->>Pool: release(videoId)
    VW->>VW: pause() + 释放引用

    Note over Notifier,Preload: 预加载下一个视频
    Notifier->>Preload: enqueue(nextVideoId, url, priority)
    Preload->>Preload: 优先级队列排序
    Preload->>Pool: preload(nextId, nextUrl)
    Pool->>Pool: acquire → release(refCount=0)
    Note over Pool: 仅 pause 不 dispose<br/>保留首帧加速下次打开

    Note over FeedPage: 滑到倒数第3个
    Notifier->>API: getRecommend(page=2)
    API-->>Notifier: 追加下一页数据

    Note over Notifier: 切换到"关注"Tab
    Notifier->>Notifier: switchTab(follow)<br/>强制 isLoading=false
    Notifier->>API: getFollow(userId=u1)
    API->>Server: SELECT JOIN follows 表
    Server-->>API: 关注者的视频列表
```

---

## 三、直播间实时互动（WebSocket + REST）

```mermaid
sequenceDiagram
    actor User
    participant LiveRoom as LiveRoomPage
    participant Notifier as LiveNotifier
    participant API as LiveApi
    participant WS as WebSocketService
    participant Server as Backend

    User->>LiveRoom: 进入直播间
    LiveRoom->>Notifier: enterRoom(roomId)
    Notifier->>Notifier: _active = true (同步标记)

    Note over Notifier,API: 步骤1：HTTP 拉取房间数据
    Notifier->>API: getRoomDetail(roomId)
    API->>Server: GET /api/live/rooms/:id
    Server-->>API: {room, products, coupons}
    API-->>Notifier: LiveRoomDetail
    Notifier->>LiveRoom: state.room + state.products 更新

    Note over Notifier,WS: 步骤2：WebSocket 连接
    Notifier->>WS: connect(roomId)
    WS->>Server: Socket.IO handshake
    Server-->>WS: connected
    Notifier->>WS: joinRoom(roomId)
    Notifier->>WS: eventStream.listen(_handleEvent)

    Note over Server,Notifier: 实时事件推送
    Server-->>WS: event: room_state {online_count, current_product}
    WS-->>Notifier: _handleEvent()
    Notifier->>LiveRoom: 同步在线人数/当前商品

    Server-->>WS: event: online_count {count:128}
    WS-->>Notifier: _handleEvent()
    Notifier->>LiveRoom: state.onlineCount 更新

    Server-->>WS: event: danmaku {user_name, content, type}
    WS-->>Notifier: _handleEvent()
    Notifier->>Notifier: 指纹去重检查<br/>_pendingMsgFingerprints?
    Notifier->>LiveRoom: DanmakuOverlay + 评论列表

    Server-->>WS: event: explaining_product {product}
    WS-->>Notifier: _handleEvent()
    Notifier->>LiveRoom: currentProduct → 商品卡更新

    Server-->>WS: event: stock_update {product_id, stock}
    WS-->>Notifier: _handleEvent()
    Notifier->>LiveRoom: 库存实时更新

    Note over User,Notifier: 用户发评论 (带去重)
    User->>LiveRoom: 发送评论
    LiveRoom->>Notifier: sendMessage(content)
    Notifier->>Notifier: 指纹 = "user|我|content"<br/>_pendingMsgFingerprints.add()
    Notifier->>WS: emit('send_message', data)
    Notifier->>Notifier: _addMessage(乐观版本)

    Note over Server,Notifier: WS 回显 → 命中指纹 → 跳过
    Server-->>WS: event: new_comment (回显)
    WS-->>Notifier: _handleEvent()
    Notifier->>Notifier: 指纹匹配 → remove + return

    Note over User,Notifier: 用户送礼物 (带去重)
    User->>LiveRoom: 送礼物 🎁
    LiveRoom->>Notifier: sendGift(userName, giftIcon, giftName)
    Notifier->>Notifier: 服务端回显指纹<br/>"system|赠送礼物|giftName"<br/>_pendingMsgFingerprints.add()
    Notifier->>Notifier: _addMessage(乐观: 送出了🎁火箭)

    Server-->>WS: event: danmaku (礼物回显)
    WS-->>Notifier: _handleEvent()
    Notifier->>Notifier: 指纹匹配 → remove + return

    Note over User,Notifier: 离开直播间
    User->>LiveRoom: 返回
    LiveRoom->>Notifier: leaveRoom()
    Notifier->>Notifier: _active = false (同步！)
    Notifier->>Notifier: _eventSub?.cancel()
    Notifier->>WS: leaveRoom(roomId)
    Note over Notifier: microtask残留事件<br/>被 _active=false 拦截
```

---

## 四、播放器池 (PlayerPool)

```mermaid
flowchart TB
    A["acquire(videoId, url)"] --> B{videoId<br/>已存在?}
    B -->|是| C["refCount++<br/>直接返回"]
    B -->|否| D{URL<br/>匹配?}
    D -->|是| E["refCount++<br/>别名指向<br/>seekTo(Duration.zero)"]
    D -->|否| F{正在<br/>初始化?}
    F -->|是| G["等待 200ms<br/>重试"]
    F -->|否| H["_initializing.add()"]
    H --> I{池满?<br/>length ≥ 3}
    I -->|是| J["淘汰 refCount 最小<br/>的空闲播放器"]
    I -->|否| K["创建新 controller"]
    J --> K
    K --> L["controller.initialize()<br/>超时 15s"]
    L --> M["setLooping(true)<br/>setVolume(1.0)"]
    M --> N["存入 _players<br/>refCount=1"]
    N --> C

    O["release(videoId, dispose)"] --> P["refCount--"]
    P --> Q{refCount ≤ 0?}
    Q -->|否| R["结束"]
    Q -->|是| S["controller.pause()"]
    S --> T{dispose?}
    T -->|是| U["controller.dispose()<br/>_players.remove()"]
    T -->|否| R

    style A fill:#4CAF50,color:#fff
    style O fill:#FF9800,color:#fff
    style E fill:#2196F3,color:#fff
    style J fill:#F44336,color:#fff
```

---

## 五、视频预加载 (VideoPreloadManager)

```mermaid
flowchart TB
    A["FeedNotifier.setCurrentIndex(n)"] --> B["_preloadAround(n)"]
    B --> C["_cancelStalePreloads(n)<br/>取消 n 之前和 n+1 之后"]
    B --> D["预加载 n+1 (仅1个)"]
    D --> E["enqueue(videoId, url, priority)"]
    E --> F["_queue 按 priority 降序排列"]
    F --> G{"_currentTask<br/>进行中?"}
    G -->|是| H["等待当前完成<br/>(maxConcurrent=1)"]
    G -->|否| I{"WiFi 检查<br/>wifiOnly=true?"}
    I -->|非WiFi| J["暂停，等待<br/>网络切换恢复"]
    I -->|WiFi| K["_processQueue()"]
    H --> I
    K --> L["_preloadOne(task)"]
    L --> M["PlayerPool.preload(videoId, url)"]
    M --> N["Pool.acquire()<br/>→ release(refCount=0)"]
    N --> O["pause 不 dispose<br/>保留首帧缓冲"]
    N --> P{超时 20s?}
    P -->|是| Q["取消该任务<br/>继续下一个"]

    R["_onNetworkChanged()"] --> S{"切换到 WiFi?"}
    S -->|是| T["恢复 _processQueue()"]
    S -->|否| U["cancelAll()<br/>清空队列"]

    style A fill:#4CAF50,color:#fff
    style D fill:#2196F3,color:#fff
    style J fill:#FF9800,color:#fff
    style N fill:#2196F3,color:#fff
```

---

## 六、商品讲解片段定位

```mermaid
flowchart TB
    subgraph 数据模型
        PM["ProductModel<br/>highlightTime: int<br/>segments: List~ProductSegment~<br/>videoId: String"]
    end

    subgraph 路径A ["路径A: Feed页商品卡"]
        A1["用户点击 FloatingProductCard"] --> A2["showProductDetailSheet()"]
        A2 --> A3{"有讲解片段?"}
        A3 -->|0段+highlightTime| A4["单按钮<br/>跳转到讲解 (MM:SS)"]
        A3 -->|1段| A5["单按钮<br/>片段标签"]
        A3 -->|2+段| A6["按钮 → 片段选择弹窗"]
        A4 & A5 & A6 --> A7["onSeekToTime(time)"]
        A7 --> A8["_seekTrigger.value = time"]
        A8 --> A9["VideoPlayerWidget._onSeekTriggered()"]
        A9 --> A10["双重 clamp:<br/>clamp(0, durMs-500)"]
        A10 --> A11["controller.seekTo() + play()"]
        A11 --> A12["金色边框高亮 1.2s"]
    end

    subgraph 路径B ["路径B: 收藏页商品弹窗"]
        B1["FavoritesPage 点击商品"] --> B2["showProductDetailSheet()"]
        B2 --> B3["onSeekToTime(time)"]
        B3 --> B4["Navigator.pop() 关闭弹窗"]
        B4 --> B5["await 200ms<br/>(等退出动画完成)"]
        B5 --> B6["pushNamed('singleVideo',<br/>{seek: time})"]
        B6 --> B7["SingleVideoPlayerPage._applySeek()"]
        B7 --> B8["双重 clamp + seekTo"]
    end

    style A12 fill:#FFD700,color:#000
    style B5 fill:#FF9800,color:#fff
```

---

## 七、收藏页独立播放 (SingleVideoPlayerPage)

```mermaid
flowchart TB
    subgraph 入口["导航入口"]
        E1["FavoritesPage<br/>点击收藏视频"] --> E2["pushNamed('singleVideo',<br/>{videoId})"]
        E1 --> E3["点击商品'跳转到讲解'"] --> E4["pop + await 200ms<br/>+ pushNamed({seek})"]
    end

    E2 --> Load
    E4 --> Load

    Load["_load()"] --> API["VideoApi.getVideoDetail(id)<br/>timeout 10s"]
    API -->|成功| Create["创建 controller<br/>VideoPlayerController.networkUrl"]
    API -->|失败| Err1["_videoError=true<br/>显示错误+重试"]

    Create --> Init["controller.initialize()<br/>timeout 20s"]
    Init -->|成功| Play["setLooping + play()<br/>_videoReady=true"]
    Init -->|失败| Err2["_videoError=true<br/>catch(e) 全捕获"]

    Play --> UI["渲染 UI"]
    UI --> Video["ValueListenableBuilder<br/>+ VideoPlayer"]
    UI --> Progress["_VideoProgressBar<br/>ValueListenableBuilder<br/>可拖拽 Slider"]
    UI --> Author["_AuthorSheet<br/>头像可点击 → 作者面板"]
    UI --> Like["_Actions<br/>本地 _liked 乐观更新<br/>失败回滚"]
    UI --> Product["FloatingProductCard<br/>→ 商品详情半屏"]

    Note1["关键设计"]
    Note1 --> N1["不走 PlayerPool<br/>自建 controller"]
    Note1 --> N2["立即 dispose 释放<br/>ExoPlayer 硬件资源"]
    Note1 --> N3["与 Feed IndexedStack<br/>完全解耦"]
    Note1 --> N4["catch(e) 全捕获<br/>(Error + Exception)"]

    style Note1 fill:#FF9800,color:#fff
    style N1 fill:#F44336,color:#fff
    style N3 fill:#F44336,color:#fff
```

---

## 八、小窗播放 (PiP)

```mermaid
sequenceDiagram
    actor User
    participant LR as LiveRoomPage
    participant PIP as PipProvider
    participant Float as FloatingVideoPlayer
    participant Main as main.dart (builder)

    Note over User,Main: === 进入 PiP (4个入口) ===

    User->>LR: 返回键 / 购物车 / 立即购买 / ←箭头
    LR->>PIP: enterPip(controller, roomInfo)
    PIP->>PIP: isActive=true<br/>保存 controller + roomInfo
    Note over PIP,Float: controller 所有权转给 PipProvider<br/>LR 不在 dispose 时销毁它

    LR->>LR: dispose() → pipActive? → 不 dispose controller

    Main->>Main: MaterialApp.router.builder
    Main->>Float: if (isActive) → FloatingVideoPlayer
    Float->>Float: 渲染浮窗<br/>可拖拽 120~150px宽 16:9<br/>顶部标题+关闭 / 底部返回

    Note over User,Main: === 返回直播间 (无缝续播) ===

    User->>Float: 点击"返回直播间"
    Float->>PIP: exitPip() → isActive=false
    Note over PIP: ⚠️ controller 保留，不 dispose！
    Float->>Main: router.pushNamed('liveRoom', {roomId})

    Main->>LR: LiveRoomPage.initState()
    LR->>PIP: ref.read(pipProvider)
    LR->>LR: 检测到 Pip controller → 直接复用
    LR->>LR: _videoReady=true, play()
    LR->>PIP: releaseController() → 转移所有权
    Note over LR: ⚠️ 不重新下载视频！

    Note over User,Main: === 关闭浮窗 ===

    User->>Float: 点击 ✕ 按钮
    Float->>PIP: closePip()
    PIP->>PIP: isActive=false<br/>controller.dispose()
    Note over PIP: 彻底销毁播放器
```

---

## 九、组件树（Widget Tree — 视频流+直播）

```mermaid
graph TD
    MaterialApp["MaterialApp.router"]
    MaterialApp --> Router["GoRouter"]
    Router --> Shell["StatefulShellRoute<br/>indexedStack 保活"]

    Shell --> FeedTab["/feed 📹"]
    Shell --> LiveTab["/live 📺"]

    Router --> LiveRoom["/live/:roomId 🔴"]
    Router --> SingleVideo["/video/:videoId"]
    Router --> Favorites["/favorites ⭐"]

    MaterialApp --> Builder["builder 回调"]
    Builder --> PipOverlay["FloatingVideoPlayer<br/>PiP 浮窗 (顶层)"]

    FeedTab --> FeedPage["FeedPage"]
    FeedPage --> PageView["PageView.builder (垂直)"]
    PageView --> VW["VideoPlayerWidget"]
    VW --> VideoLayer["FittedBox + VideoPlayer"]
    VW --> Cover["CachedNetworkImage 封面"]
    VW --> InfoSection["作者头像+关注+标题+标签"]
    VW --> ActionBar["静音/♥点赞/💬评论/📤分享/⭐收藏"]
    VW --> ProgressBar["_VideoProgressBar<br/>ValueListenableBuilder+Slider"]
    VW --> FloatCard["FloatingProductCard"]

    LiveRoom --> LRContent["_LiveRoomActiveContent"]
    LRContent --> LRVideo["ValueListenableBuilder<br/>+ VideoPlayer (IgnorePointer)"]
    LRContent --> DanmakuLayer["DanmakuOverlay<br/>IgnorePointer 不拦截触摸"]
    LRContent --> LRTopBar["顶部栏: ←返回 头像 关注 热度 人数"]
    LRContent --> LRComments["_CommentList 最近10条"]
    LRContent --> LRFloatCard["FloatingProductCard"]
    LRContent --> LRCoupon["CouponCountdown 优惠券"]
    LRContent --> LRBottom["底栏: 输入框 购物车 ♥ 礼物 分享"]

    SingleVideo --> SVPContent["单视频播放"]
    SVPContent --> SVPVideo["ValueListenableBuilder + VideoPlayer"]
    SVPContent --> SVPProgress["_VideoProgressBar (可拖拽)"]
    SVPContent --> SVPAuthor["_AuthorSheet (作者面板)"]
    SVPContent --> SVPLike["_Actions (乐观更新喜欢)"]
    SVPContent --> SVPFloat["FloatingProductCard"]

    Favorites --> FavVideo["_FavoriteVideoTile<br/>作者头像+♡+🔖"]
```

---

## 十、数据持久化架构

```mermaid
graph TB
    subgraph Client["📱 客户端存储"]
        direction TB
        SharedPrefs["SharedPreferences<br/>━━━━━━━━━━<br/>• auth_token<br/>• user_id<br/>• user_role"]
        HiveBox["Hive Box<br/>━━━━━━━━━━<br/>• favorites (JSON)<br/>• cart_items (JSON)<br/>• browsing_history (JSON)<br/>• user_profile (JSON)"]
    end

    subgraph Server["🖥️ 服务端存储"]
        SQLiteDB["SQLite (better-sqlite3)<br/>━━━━━━━━━━<br/>WAL 模式 / 15张表<br/>• users • videos • products<br/>• cart_items • orders<br/>• comments • coupons<br/>• live_rooms • live_messages<br/>• user_likes • follows<br/>• gift_records • gifts<br/>• recharge_records • refund_records<br/>• customer_service_messages"]
    end

    subgraph Cache["⚡ 客户端内存 (Riverpod)"]
        Riverpod["Riverpod State<br/>━━━━━━━━━━<br/>• FeedState (videos[])<br/>• LiveState (room+messages+_active)<br/>• CartState (items[])<br/>• OrderState (orders[])<br/>• PipState (controller+roomInfo)<br/>• FavoriteState (items[])<br/>• FollowState (followingIds Set)<br/>• AuthState (token+role)"]
    end

    SharedPrefs --> Riverpod
    HiveBox --> Riverpod
    Riverpod --> SQLiteDB : via Dio REST API
    SQLiteDB --> Riverpod : via Dio REST API

    style Client fill:#1a1a2e,color:#fff
    style Server fill:#16213e,color:#fff
    style Cache fill:#0f3460,color:#fff
```

---

## 十一、API路由总览

```mermaid
graph LR
    subgraph "REST API (Fastify 路由)"
        Videos["/api/videos<br/>GET /recommend<br/>GET /follow?user_id<br/>GET /:id<br/>POST /:id/like<br/>GET /search?keyword"]
        Products["/api/products<br/>GET /:id<br/>GET /recommend<br/>GET /:id/ai-sales-point"]
        Cart["/api/cart<br/>GET /:userId<br/>POST /<br/>PUT /:itemId<br/>DELETE /:itemId"]
        Orders["/api/orders<br/>GET /:userId<br/>POST /<br/>POST /:id/pay"]
        Comments["/api/comments<br/>GET /?video_id&page<br/>POST /"]
        Live["/api/live<br/>GET /rooms<br/>GET /rooms/:id<br/>GET /rooms/mine<br/>POST /rooms<br/>POST /rooms/:id/start<br/>POST /rooms/:id/end<br/>POST /rooms/:id/product<br/>POST /gift"]
        Upload["/api/upload<br/>POST /image (multipart)<br/>POST /video (multipart)"]
        Admin["/api/admin<br/>GET /dashboard (商家)"]
    end
```
