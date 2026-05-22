# 后端服务验证指南

项目提供两套后端实现，均可独立运行。

---

## 方案 A：Dart Frog 后端（严格按规范实现）

**位置**：`后端服务-RESTful API/`

**技术栈**：Dart Frog 1.2.6 + 内存数据存储

**响应格式**：`{code: 200, message: "success", data: {...}}`

### 启动步骤

**第一步：将 dart_frog 加入 PATH（仅首次需要）**

打开 **新的** PowerShell 或 CMD，执行：

```cmd
setx PATH "%PATH%;C:\Users\431\AppData\Local\Pub\Cache\bin"
```

然后**关闭当前终端，重新打开一个新终端**，验证：

```cmd
dart_frog --version
```

**第二步：启动服务**

```cmd
cd D:\lqq\client\后端服务-RESTful API
dart pub get
dart_frog dev
```

看到以下输出即启动成功：

```
✓ Running on http://localhost:8080
```

### 测试命令

```bash
# 1. 商品列表（分页）
curl "http://localhost:8080/api/products?page=1&pageSize=3"

# 2. 商品搜索
curl "http://localhost:8080/api/products?keyword=耳机&page=1&pageSize=5"

# 3. 用户注册
curl -X POST http://localhost:8080/api/users/register -H "Content-Type: application/json" -d "{\"username\":\"test\",\"password\":\"123456\",\"nickname\":\"测试用户\"}"

# 4. 用户登录
curl -X POST http://localhost:8080/api/users/login -H "Content-Type: application/json" -d "{\"username\":\"alice\",\"password\":\"123456\"}"

# 5. 获取购物车（需认证）
curl http://localhost:8080/api/cart -H "Authorization: Bearer token-u1-abc123"

# 6. 添加商品到购物车
curl -X POST http://localhost:8080/api/cart/items -H "Content-Type: application/json" -H "Authorization: Bearer token-u1-abc123" -d "{\"productId\":\"p4\",\"quantity\":1,\"spec\":{\"颜色\":\"黑色\"}}"

# 7. 修改购物车数量
curl -X PUT http://localhost:8080/api/cart/items/ci3 -H "Content-Type: application/json" -H "Authorization: Bearer token-u1-abc123" -d "{\"quantity\":3}"

# 8. 删除购物车项
curl -X DELETE http://localhost:8080/api/cart/items/ci3 -H "Authorization: Bearer token-u1-abc123"

# 9. 批量勾选
curl -X PUT http://localhost:8080/api/cart/items/selected -H "Content-Type: application/json" -H "Authorization: Bearer token-u1-abc123" -d "{\"itemIds\":[\"ci1\",\"ci2\"],\"selected\":true}"

# 10. 创建订单（从购物车选中项）
curl -X POST http://localhost:8080/api/orders -H "Content-Type: application/json" -H "Authorization: Bearer token-u1-abc123" -d "{\"addressId\":\"addr1\"}"

# 11. 订单列表（按状态筛选）
curl "http://localhost:8080/api/orders?status=pending_payment&page=1&pageSize=10" -H "Authorization: Bearer token-u1-abc123"

# 12. 支付订单
curl -X POST http://localhost:8080/api/orders/o3/pay -H "Authorization: Bearer token-u1-abc123"

# 13. 视频列表
curl "http://localhost:8080/api/videos?page=1&pageSize=3"

# 14. 视频详情（含关联商品）
curl "http://localhost:8080/api/videos/v1"

# 15. 点赞视频
curl -X POST http://localhost:8080/api/videos/v1/like -H "Authorization: Bearer token-u1-abc123"

# 16. 视频评论列表
curl "http://localhost:8080/api/videos/v1/comments?page=1&pageSize=5"

# 17. 发布评论
curl -X POST http://localhost:8080/api/comments -H "Content-Type: application/json" -H "Authorization: Bearer token-u1-abc123" -d "{\"targetType\":\"video\",\"targetId\":\"v1\",\"content\":\"非常好的视频！\"}"

# 18. 删除评论（仅自己的）
curl -X DELETE http://localhost:8080/api/comments/c5 -H "Authorization: Bearer token-u1-abc123"
```

### 预置测试账号

| 用户名 | 密码 | Token |
|--------|------|-------|
| alice | 123456 | `token-u1-abc123` |
| bob | 123456 | `token-u2-def456` |

### 注意事项

- 数据存储在内存中，重启后恢复为初始种子数据
- 所有需认证的端点必须在请求头携带 `Authorization: Bearer <token>`
- 响应格式统一为 `{code, message, data}`，code=200 表示成功
- 中文参数在 Windows CMD 的 curl 中可能乱码，建议用 PowerShell 或写入临时文件

---

## 方案 B：Node.js 后端（可直接使用）

**位置**：`apps/server/`

**技术栈**：Node.js + Fastify 5 + SQLite

**响应格式**：`{code: 0, data: {...}}`

### 启动步骤

```cmd
cd D:\lqq\client\apps\server
npm install
npm run dev
```

服务默认监听 `http://localhost:3000`（可能已在运行中）。

### 测试命令

```bash
# 1. 商品列表（分页 + 搜索）
curl "http://localhost:3000/api/products?page=1&page_size=2&keyword=耳机"

# 2. 获取购物车
curl "http://localhost:3000/api/cart/u1"

# 3. 添加商品到购物车
curl -X POST http://localhost:3000/api/cart -H "Content-Type: application/json" -d "{\"user_id\":\"u1\",\"product_id\":\"<真实商品ID>\",\"quantity\":1,\"spec\":\"黑色\"}"

# 4. 创建订单
curl -X POST http://localhost:3000/api/orders -H "Content-Type: application/json" -d "{\"user_id\":\"u1\",\"address\":\"北京市测试地址\",\"items\":[{\"product_id\":\"<商品ID>\",\"quantity\":1,\"spec\":\"标准版\"}]}"

# 5. 支付订单
curl -X POST http://localhost:3000/api/orders/<订单ID>/pay -H "Content-Type: application/json" -d "{}"

# 6. 视频列表
curl "http://localhost:3000/api/videos?page=1&page_size=3"

# 7. 视频详情
curl "http://localhost:3000/api/videos/<视频ID>"

# 8. 点赞视频
curl -X POST http://localhost:3000/api/videos/<视频ID>/like -H "Content-Type: application/json" -d "{\"user_id\":\"u1\"}"

# 9. 发布评论
curl -X POST http://localhost:3000/api/comments -H "Content-Type: application/json" -d "{\"user_id\":\"u1\",\"video_id\":\"<视频ID>\",\"content\":\"很好的内容！\"}"

# 10. 用户登录
curl -X POST http://localhost:3000/api/auth/login -H "Content-Type: application/json" -d "{\"nickname\":\"测试用户\",\"password\":\"123456\"}"
```

### 预置测试账号

| 用户ID | 昵称 | 密码 | 角色 |
|--------|------|------|------|
| u1 | 测试用户 | 123456 | user |
| u2 | 小明数码 | 123456 | merchant |
| u3 | 小红穿搭 | 123456 | merchant |
| u4 | 阿杰户外 | 123456 | merchant |
| u5 | 数码控小王 | 123456 | merchant |

> **注意**：商品 ID 和视频 ID 是 UUID 格式（如 `729e2c95-6954-4525-b90f-b869a5bd0388`），需先通过列表接口获取真实 ID。

### API 差异说明

| 特性 | 方案 A (Dart Frog) | 方案 B (Node.js) |
|------|-------------------|-------------------|
| 端口 | 8080 | 3000 |
| 注册端点 | `POST /api/users/register` | `POST /api/auth/register` |
| 登录端点 | `POST /api/users/login` | `POST /api/auth/login` |
| 购物车端点 | `GET /api/cart` (header token) | `GET /api/cart/:user_id` |
| 认证方式 | `Authorization: Bearer <token>` | 请求体中传 `user_id`（admin 接口用 JWT） |
| 商品ID格式 | `p1`, `p2`, `p3` | UUID |
| 成功 code | 200 | 0 |
| 分页参数 | `page`, `pageSize` | `page`, `page_size` |
| 数据持久化 | 无（内存） | SQLite 文件 |
| 订单状态 | `pending_payment`, `pending_delivery`, `completed` | `pending`, `paid`, `payment_failed` |

---

## 完整 API 端点清单

### 用户模块

| 端点 | 方法 | 方案 A | 方案 B | 认证 |
|------|------|--------|--------|------|
| `/api/users/register` | POST | 8080 | - | 否 |
| `/api/auth/register` | POST | - | 3000 | 否 |
| `/api/users/login` | POST | 8080 | - | 否 |
| `/api/auth/login` | POST | - | 3000 | 否 |
| `/api/users/profile` | GET/PUT | 8080 | - | 方案 A 需要 |
| `/api/users/:id` | GET/PUT | - | 3000 | 否 |

### 视频模块

| 端点 | 方法 | 方案 A | 方案 B | 说明 |
|------|------|--------|--------|------|
| `/api/videos` | GET | 8080 | 3000 | 分页列表 |
| `/api/videos/:id` | GET | 8080 | 3000 | 详情+关联商品 |
| `/api/videos/:id/like` | POST | 8080 | 3000 | 点赞切换 |
| `/api/videos/:id/comments` | GET | 8080 | - | 视频评论分页 |

### 商品模块

| 端点 | 方法 | 方案 A | 方案 B | 说明 |
|------|------|--------|--------|------|
| `/api/products` | GET | 8080 | 3000 | 分页+keyword+category |
| `/api/products/:id` | GET | 8080 | 3000 | 详情+评论 |

### 购物车模块

| 端点 | 方法 | 方案 A | 方案 B | 说明 |
|------|------|--------|--------|------|
| `/api/cart` | GET | 8080 | - | 当前用户购物车 |
| `/api/cart/:user_id` | GET | - | 3000 | 指定用户购物车 |
| `/api/cart/items` | POST | 8080 | /api/cart | 添加商品 |
| `/api/cart/items/:itemId` | PUT | 8080 | /api/cart/:id | 修改数量 |
| `/api/cart/items/:itemId` | DELETE | 8080 | /api/cart/:id | 删除 |
| `/api/cart/items/selected` | PUT | 8080 | /api/cart/:id | 批量勾选 |

### 订单模块

| 端点 | 方法 | 方案 A | 方案 B | 说明 |
|------|------|--------|--------|------|
| `/api/orders` | POST | 8080 | 3000 | 创建订单 |
| `/api/orders` | GET | 8080 | - | 订单列表 |
| `/api/orders/:user_id` | GET | - | 3000 | 用户订单列表 |
| `/api/orders/:id` | GET | 8080 | - | 订单详情 |
| `/api/orders/detail/:id` | GET | - | 3000 | 订单详情 |
| `/api/orders/:id/pay` | POST | 8080 | 3000 | 模拟支付 |

### 评论模块

| 端点 | 方法 | 方案 A | 方案 B | 认证 |
|------|------|--------|--------|------|
| `/api/comments` | POST | 8080 | 3000 | 方案 A 需要 |
| `/api/comments/:id` | DELETE | 8080 | - | 方案 A 需要 |
| `/api/comments` | GET | 8080 | 3000 | 筛选+分页 |

---

## 快速对比总结

| | 方案 A (Dart Frog) | 方案 B (Node.js) |
|---|---|---|
| **启动命令** | `dart_frog dev` (需先配置 PATH) | `npm run dev` |
| **端口** | 8080 | 3000 |
| **适合场景** | 严格遵循规范要求、Dart 技术栈 | 已稳定运行、可直接联调 Flutter 客户端 |
| **持久化** | 无，重启数据重置 | SQLite，数据持久 |
| **规范符合度** | 100% 按 RESTful API.md 实现 | 功能完整但部分路径/参数命名不同 |