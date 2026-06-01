# 项目架构图（Mermaid）

> 涵盖：内容流浏览、RESTful API、实时通信、数据持久化

---

## 一、核心类图（Models + Providers + Services）

```mermaid
classDiagram
    direction TB

    %% Models
    class VideoModel {
        +String id
        +String title
        +String videoUrl
        +String coverUrl
        +String authorName
        +int likeCount
        +bool isLiked
        +String likeCountText()
    }

    class ProductModel {
        +String id
        +String name
        +String coverUrl
        +double price
        +double originalPrice
        +int stock
        +int highlightTime
        +List~ProductSegment~ segments
        +ProductModel copyWith()
        +int effectiveSeekTime()
    }

    class CartItemModel {
        +String id
        +String productId
        +String productName
        +double productPrice
        +int quantity
        +bool selected
    }

    class OrderModel {
        +String id
        +String status
        +double payAmount
        +OrderAddress address
    }

    class CouponModel {
        +String id
        +CouponType type
        +double discountAmount
        +double conditionAmount
        +CouponStatus status
        +bool isUsable()
    }

    class LiveRoomInfo {
        +String id
        +String videoUrl
        +int onlineCount
        +int heatCount
    }

    class LiveMessage {
        +String userName
        +String content
        +String type
    }

    class ProductSegment {
        +String label
        +int startTime
        +int endTime
    }

    %% Providers
    class FeedNotifier {
        -List~VideoModel~ videos
        -int currentIndex
        +loadVideos()
        +loadMore()
        +toggleLike()
        -_preloadAround()
    }

    class CartNotifier {
        -List~CartItemModel~ items
        +loadCart()
        +addToCart()
        +updateQuantity()
        +deleteItem()
        -_persist()
    }

    class OrderNotifier {
        -List~OrderModel~ orders
        +loadOrders()
        +createOrder()
        +payOrder()
        +confirmOrder()
    }

    class LiveNotifier {
        -LiveRoomInfo room
        -List~LiveMessage~ messages
        +enterRoom()
        +leaveRoom()
        +sendMessage()
        +sendGift()
        -_handleEvent()
    }

    class PipNotifier {
        -bool isActive
        -VideoPlayerController controller
        +enterPip()
        +exitPip()
        +closePip()
    }

    %% Services
    class PlayerPool {
        -Map~_PooledPlayer~ _players
        +acquire(videoId, url)
        +release(videoId)
        +preload(videoId, url)
        -_evictIfNeeded()
    }

    class VideoPreloadManager {
        -List~VideoPreloadTask~ _queue
        +enqueue(videoId, url)
        +cancel(videoId)
        -_processQueue()
        -_onNetworkChanged()
    }

    class WebSocketService {
        -Socket _socket
        +connect(namespace)
        +emit(event, data)
        +joinRoom(roomId)
        +leaveRoom(roomId)
        -_scheduleReconnect()
    }

    class StorageService {
        +getToken()
        +getCartItems()
        +saveCartItems()
        +getFavorites()
        +saveFavorites()
    }

    %% Relationships
    VideoModel "1" --> "*" ProductModel : associated products
    ProductModel "1" --> "*" ProductSegment : segments
    FeedNotifier --> VideoModel : manages
    FeedNotifier --> PlayerPool : uses
    FeedNotifier --> VideoPreloadManager : uses
    CartNotifier --> CartItemModel : manages
    CartNotifier --> StorageService : persists
    OrderNotifier --> OrderModel : manages
    LiveNotifier --> LiveRoomInfo : holds
    LiveNotifier --> WebSocketService : listens
    LiveNotifier --> LiveMessage : produces
    PipNotifier --> LiveRoomInfo : references
```

---

## 二、系统架构图（分层框架）

```mermaid
graph TB
    subgraph UI["📱 UI Layer (Widgets)"]
        direction LR
        FeedPage["FeedPage<br/>短视频上下滑"]
        LiveRoomPage["LiveRoomPage<br/>直播间"]
        CartPage["CartPage<br/>购物车"]
        OrderPage["OrderPage<br/>订单列表"]
        ProductSheet["ProductDetailSheet<br/>商品详情半屏"]
        VideoWidget["VideoPlayerWidget<br/>视频播放组件"]
        FloatCard["FloatingProductCard<br/>浮层商品卡"]
        PIP["FloatingVideoPlayer<br/>小窗播放"]
        Comments["VideoCommentsSheet<br/>评论区"]
    end

    subgraph State["🧠 State Management (Riverpod)"]
        direction LR
        FeedProvider["feedProvider<br/>FeedNotifier"]
        CartProvider["cartProvider<br/>CartNotifier"]
        OrderProvider["orderProvider<br/>OrderNotifier"]
        LiveProvider["liveProvider<br/>LiveNotifier"]
        PipProvider["pipProvider<br/>PipNotifier"]
        FavProvider["favoriteProvider"]
        CouponProvider["couponProvider"]
    end

    subgraph Services["⚙️ Services Layer"]
        direction LR
        PlayerPool["PlayerPool<br/>播放器池(4)"]
        PreloadMgr["VideoPreloadManager<br/>预加载队列"]
        WSService["WebSocketService<br/>Socket.IO连接"]
        StorageSvc["StorageService<br/>SharedPrefs+Hive"]
    end

    subgraph API["🌐 API Layer (Dio)"]
        direction LR
        VideoAPI["VideoApi"]
        ProductAPI["ProductApi"]
        CartAPI["CartApi"]
        OrderAPI["OrderApi"]
        LiveAPI["LiveApi"]
    end

    subgraph Backend["🖥️ Backend (Node.js)"]
        REST["REST API<br/>Express/Fastify"]
        WS["Socket.IO Server<br/>实时推送"]
    end

    UI --> State
    State --> Services
    State --> API
    Services --> WS
    API --> REST

    FeedPage --> FeedProvider
    FeedPage --> VideoWidget
    LiveRoomPage --> LiveProvider
    LiveRoomPage --> PIP
    LiveRoomPage --> FloatCard
    CartPage --> CartProvider
    OrderPage --> OrderProvider

    FeedProvider --> PlayerPool
    FeedProvider --> PreloadMgr
    LiveProvider --> WSService
    CartProvider --> StorageSvc
```

---

## 三、内容流浏览数据流（短视频Feed + 直播）

```mermaid
sequenceDiagram
    actor User
    participant FeedPage as FeedPage
    participant Notifier as FeedNotifier
    participant Pool as PlayerPool
    participant API as VideoApi
    participant Server as Backend

    User->>FeedPage: 打开App
    FeedPage->>Notifier: loadVideos()
    Notifier->>API: getRecommend(page=1)
    API->>Server: GET /api/videos/recommend
    Server-->>API: {list:[Video], hasMore:true}
    API-->>Notifier: VideoListResponse
    Notifier->>Pool: preload(videoId, url)

    User->>FeedPage: 上下滑动(PageView)
    FeedPage->>Notifier: setCurrentIndex(index)
    Notifier->>Pool: acquire(videoId, url)
    Pool-->>FeedPage: VideoPlayerController
    FeedPage->>FeedPage: play() + 显示视频

    Notifier->>Notifier: _preloadAround(index)
    Notifier->>PreloadMgr: enqueue(nextVideo)
    PreloadMgr->>Pool: preload(nextId, nextUrl)

    Note over FeedPage: 滑到倒数第3个
    Notifier->>API: getRecommend(page=2)
    API-->>Notifier: 下一页数据追加
```

---

## 四、直播间实时通信数据流（WebSocket）

```mermaid
sequenceDiagram
    actor User
    participant LiveRoom as LiveRoomPage
    participant Notifier as LiveNotifier
    participant WS as WebSocketService
    participant Server as Socket.IO Server

    User->>LiveRoom: 进入直播间
    LiveRoom->>Notifier: enterRoom(roomId)
    Notifier->>API: GET /api/live/:roomId (详情+商品)
    API-->>Notifier: {room, products, coupons}

    Notifier->>WS: connect(namespace)
    WS->>Server: socket.io connection
    Server-->>WS: connected
    Notifier->>WS: joinRoom(roomId)
    Notifier->>WS: eventStream.listen()

    Server-->>WS: event: online_count {count:128}
    WS-->>Notifier: _handleEvent()
    Notifier->>LiveRoom: state.onlineCount = 128

    Server-->>WS: event: danmaku {user, content}
    WS-->>Notifier: _handleEvent()
    Notifier->>Notifier: _addMessage(msg)
    Notifier->>LiveRoom: 评论区滚动显示

    Server-->>WS: event: explaining_product {product}
    WS-->>Notifier: _handleEvent()
    Notifier->>LiveRoom: currentProduct = product
    LiveRoom->>LiveRoom: 浮层商品卡更新

    Server-->>WS: event: stock_update {product_id, stock}
    WS-->>Notifier: _handleEvent()
    Notifier->>LiveRoom: products副本更新库存

    User->>LiveRoom: 发送评论
    LiveRoom->>Notifier: sendMessage(content)
    Notifier->>WS: emit('send_message', data)
    Notifier->>Notifier: _addMessage(乐观添加)

    User->>LiveRoom: 送礼物
    LiveRoom->>Notifier: sendGift(icon, name)
    Notifier->>Notifier: _addMessage(system: "送出🎁")
    Notifier->>LiveRoom: 评论区滚动显示礼物

    User->>LiveRoom: 离开直播间
    LiveRoom->>Notifier: leaveRoom()
    Notifier->>WS: leaveRoom(roomId)
    WS->>Server: emit('leave')
```

---

## 五、购物链路完整数据流

```mermaid
sequenceDiagram
    actor User
    participant Feed as FeedPage/直播间
    participant Sheet as ProductDetailSheet
    participant CartProv as CartNotifier
    participant CartAPI as CartApi
    participant OrderProv as OrderNotifier
    participant Server as Backend

    User->>Feed: 点击浮层商品卡
    Feed->>Sheet: showProductDetailSheet(product)
    User->>Sheet: 选择规格 + 数量
    User->>Sheet: 点击"加入购物车"
    Sheet->>CartProv: addToCart(productId, spec, qty)
    CartProv->>CartAPI: POST /api/cart
    CartAPI->>Server: 创建/更新购物车项
    Server-->>CartAPI: success
    CartProv->>CartProv: loadCart() + _persist()
    CartProv->>Sheet: Toast "已加入购物车"

    User->>Sheet: 点击"立即购买"
    Sheet->>Feed: Navigator.pop()
    Note over Feed: 进入PIP模式
    Feed->>OrderProv: 跳转 orderConfirm
    OrderProv->>OrderProv: createOrder(items, address)
    OrderProv->>Server: POST /api/orders
    Server-->>OrderProv: {orderId, payAmount}
    OrderProv->>User: 跳转 paymentDetail

    User->>User: 模拟支付
    User->>Server: payOrder(orderId)
    Server-->>User: payment success
    OrderProv->>OrderProv: loadOrders(force:true)
    OrderProv->>User: 跳转 paymentResult(成功)
```

---

## 六、数据持久化架构

```mermaid
graph TB
    subgraph Client["📱 Client Storage"]
        direction TB
        SharedPrefs["SharedPreferences<br/>━━━━━━━━━━<br/>• auth_token<br/>• user_id<br/>• user_role"]
        HiveBox["Hive Box<br/>━━━━━━━━━━<br/>• favorites (JSON)<br/>• cart_items (JSON)<br/>• browsing_history (JSON)<br/>• user_profile (JSON)<br/>• coupons (JSON)"]
    end

    subgraph Server["🖥️ Server Storage"]
        MySQL["MySQL / PostgreSQL<br/>━━━━━━━━━━<br/>• users<br/>• videos<br/>• products<br/>• cart_items<br/>• orders<br/>• comments<br/>• coupons<br/>• live_rooms<br/>• gifts"]
    end

    subgraph Cache["⚡ Client Memory"]
        Riverpod["Riverpod State<br/>━━━━━━━━━━<br/>• FeedState (videos[])<br/>• CartState (items[])<br/>• OrderState (orders[])<br/>• LiveState (room+messages)<br/>• PipState (controller)<br/>• FavoriteState<br/>• AuthState"]
    end

    SharedPrefs --> Riverpod
    HiveBox --> Riverpod
    Riverpod --> MySQL : via REST API
    MySQL --> Riverpod : via REST API

    style Client fill:#1a1a2e,color:#fff
    style Server fill:#16213e,color:#fff
    style Cache fill:#0f3460,color:#fff
```

---

## 七、组件树（Widget Tree）

```mermaid
graph TD
    MaterialApp["MaterialApp.router"]
    MaterialApp --> Router["GoRouter"]
    Router --> Shell["StatefulShellRoute"]
    Shell --> FeedTab["/feed 📹"]
    Shell --> LiveTab["/live 📺"]
    Shell --> CartTab["/cart 🛒"]
    Shell --> OrderTab["/order 📋"]
    Shell --> MineTab["/mine 👤"]
    Router --> LiveRoom["/live/:roomId 🔴"]
    Router --> OrderConfirm["/order/confirm"]
    Router --> Payment["/payment/:orderId"]
    Router --> Search["/search"]
    Router --> Login["/login"]

    MaterialApp --> PipOverlay["PIP浮窗Overlay"]

    FeedTab --> FeedPage["FeedPage"]
    FeedPage --> PageView["PageView.builder"]
    PageView --> VideoWidget["VideoPlayerWidget"]
    VideoWidget --> VideoPlayer["VideoPlayer"]
    VideoWidget --> FloatCard["FloatingProductCard"]
    VideoWidget --> ActionBar["_VideoActionBar<br/>♥ 💬 📤 ⭐"]
    VideoWidget --> InfoSection["_VideoInfoSection<br/>头像+标题+标签"]
    VideoWidget --> ProgressBar["_VideoProgressBar"]

    LiveRoom --> LiveContent["_LiveRoomActiveContent"]
    LiveContent --> LiveVideo["ValueListenableBuilder<br/>+ VideoPlayer"]
    LiveContent --> TopBar["顶部栏: ← 主播 热度"]
    LiveContent --> CommentList["_CommentList<br/>滚动评论区"]
    LiveContent --> BottomRow["底栏: 输入(1/2) 🛒♥🎁📤"]
    LiveContent --> LiveFloatCard["FloatingProductCard<br/>右下1/3"]

    CartTab --> CartPage["CartPage"]
    CartPage --> CartList["ListView.builder"]
    CartPage --> BottomBar["_CartBottomBar<br/>合计+结算"]
```

---

## 八、API路由总览

```mermaid
graph LR
    subgraph "REST API 路由"
        Videos["/api/videos<br/>• GET /recommend<br/>• GET /follow<br/>• GET /:id<br/>• POST /:id/like"]
        Products["/api/products<br/>• GET /:id<br/>• GET /:id/ai-point"]
        Cart["/api/cart<br/>• GET /:userId<br/>• POST /<br/>• PUT /:itemId<br/>• DELETE /:itemId"]
        Orders["/api/orders<br/>• GET /:userId<br/>• POST /<br/>• POST /:id/pay<br/>• POST /:id/confirm"]
        Comments["/api/comments<br/>• GET /?video_id&page<br/>• POST /"]
        Live["/api/live<br/>• GET /rooms<br/>• GET /rooms/:id"]
        Coupons["/api/coupons<br/>• GET /:userId<br/>• POST /claim"]
    end
```

