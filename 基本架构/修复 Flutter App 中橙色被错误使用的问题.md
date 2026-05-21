# 任务：修复 Flutter App 中橙色被错误使用的问题

## 修改规则

| 错误用法                                    | 正确用法                                |
| ------------------------------------------- | --------------------------------------- |
| `backgroundColor: AppColors.primary`        | `backgroundColor: AppColors.background` |
| `color: AppColors.primary`（容器/卡片背景） | `color: AppColors.surface`              |
| `Border.all(color: AppColors.primary)`      | `Border.all(color: AppColors.divider)`  |
| `color: AppColors.primary.withAlpha(25)`    | `Colors.black.withOpacity(0.1)`         |

## 需要修改的文件

1. `lib/pages/order/payment_result_page.dart`
2. `lib/pages/order/order_confirm_page.dart`
3. `lib/pages/order/order_page.dart`
4. `lib/pages/cart/cart_page.dart`
5. `lib/pages/live/live_room_page.dart`
6. `lib/pages/auth/login_page.dart`
7. `lib/widgets/coupon_countdown.dart`
8. `lib/widgets/product_detail_sheet.dart`

## 正确用法（保留）

以下用法**不要修改**：

- `CircularProgressIndicator(color: AppColors.primary)` - 加载指示器
- `primaryColor: AppColors.primary` - 主题主色
- `selectedItemColor: AppColors.primary` - 选中项颜色
- `indicatorColor: AppColors.primary` - Tab 指示器
- `iconColor: isLiked ? AppColors.primary : null` - 点赞图标
- `Text("关注", style: TextStyle(color: AppColors.primary))` - 关注按钮文字
- `color: AppColors.primary`（价格、按钮文字）- 需要手动判断

## 执行步骤

1. 打开上述文件
2. 搜索 `AppColors.primary`
3. 判断用途：
   - 如果是背景 → 改为 `AppColors.background` 或 `AppColors.surface`
   - 如果是边框 → 改为 `AppColors.divider`
   - 如果是文字/图标/指示器 → 保留
4. 保存文件
5. 热重启（按 R）

请按顺序修改，每完成一个文件告诉我。