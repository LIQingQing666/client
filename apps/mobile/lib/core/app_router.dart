import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/admin/admin_dashboard_page.dart';
import '../pages/admin/category_analysis_page.dart';
import '../pages/admin/category_product_list_page.dart';
import '../pages/admin/category_sales_list_page.dart';
import '../pages/admin/gmv_ranking_page.dart';
import '../pages/admin/product_detail_page.dart';
import '../pages/admin/video_detail_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/cart/cart_page.dart';
import '../pages/feed/feed_page.dart';
import '../pages/live/live_page.dart';
import '../pages/live/live_room_page.dart';
import '../pages/message/message_detail_page.dart';
import '../pages/message/message_page.dart';
import '../pages/mine/edit_profile_page.dart';
import '../pages/mine/following_page.dart';
import '../pages/mine/mine_page.dart';
import '../pages/mine/settings_page.dart';
import '../pages/recharge/coin_recharge_page.dart';
import '../pages/recharge/recharge_result_page.dart';
import '../pages/order/order_confirm_page.dart';
import '../pages/order/order_detail_page.dart';
import '../pages/order/order_page.dart';
import '../pages/order/payment_detail_page.dart';
import '../pages/order/payment_result_page.dart';
import '../pages/search/search_page.dart';
import '../provider/auth_provider.dart';
import '../provider/service_providers.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final class AppRouter {
  AppRouter._();

  static const String feed = 'feed';
  static const String live = 'live';
  static const String cart = 'cart';
  static const String order = 'order';
  static const String mine = 'mine';

  static String? _guardAdmin(BuildContext context, GoRouterState state) {
    final auth = authStateNotifier.value;
    if (auth == null || !auth.isLoggedIn || auth.role != 'merchant') {
      return '/feed';
    }
    return null;
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/feed',
    refreshListenable: authStateNotifier,
    routes: [
      GoRoute(
        path: '/order/confirm',
        name: 'orderConfirm',
        builder: (context, state) => OrderConfirmPage(
          total: double.parse(state.uri.queryParameters['total'] ?? '0'),
          count: int.parse(state.uri.queryParameters['count'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin',
        name: 'adminDashboard',
        redirect: _guardAdmin,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/admin/product/:id',
        name: 'adminProductDetail',
        redirect: _guardAdmin,
        builder: (context, state) => ProductDetailPage(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/admin/video/:id',
        name: 'adminVideoDetail',
        redirect: _guardAdmin,
        builder: (context, state) => VideoDetailPage(
          videoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/admin/gmv-ranking',
        name: 'gmvRanking',
        redirect: _guardAdmin,
        builder: (context, state) => const GmvRankingPage(),
      ),
      GoRoute(
        path: '/admin/category-analysis',
        name: 'categoryAnalysis',
        redirect: _guardAdmin,
        builder: (context, state) => const CategoryAnalysisPage(),
      ),
      GoRoute(
        path: '/category/products/:category',
        name: 'categoryProducts',
        builder: (context, state) => CategoryProductListPage(
          category: state.pathParameters['category']!,
        ),
      ),
      GoRoute(
        path: '/category/sales/:category',
        name: 'categorySales',
        builder: (context, state) => CategorySalesListPage(
          category: state.pathParameters['category']!,
        ),
      ),
      GoRoute(
        path: '/play/:videoId',
        name: 'playVideo',
        builder: (context, state) => FeedPage(
          initialVideoId: state.pathParameters['videoId'],
        ),
      ),
      GoRoute(
        path: '/live/:roomId',
        name: 'liveRoom',
        builder: (context, state) => LiveRoomPage(
          roomId: state.pathParameters['roomId']!,
        ),
      ),
      GoRoute(
        path: '/payment/detail/:orderId',
        name: 'paymentDetail',
        builder: (context, state) => PaymentDetailPage(
          orderId: state.pathParameters['orderId']!,
          amount: double.parse(state.uri.queryParameters['amount'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/payment/:orderId',
        name: 'paymentResult',
        builder: (context, state) => PaymentResultPage(
          orderId: state.pathParameters['orderId']!,
          status: state.uri.queryParameters['status'] ?? 'pending',
          amount: double.parse(state.uri.queryParameters['amount'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/order/detail/:orderId',
        name: 'orderDetail',
        builder: (context, state) => OrderDetailPage(
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: '/product/:id',
        name: 'productDetail',
        builder: (context, state) => ProductDetailPage(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/messages',
        name: 'messages',
        builder: (context, state) => const MessagePage(),
      ),
      GoRoute(
        path: '/message/:id',
        name: 'messageDetail',
        builder: (context, state) => MessageDetailPage(
          messageId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/following',
        name: 'following',
        builder: (context, state) => const FollowingPage(),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'editProfile',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/recharge',
        name: 'coinRecharge',
        builder: (context, state) => const CoinRechargePage(),
      ),
      GoRoute(
        path: '/recharge/result',
        name: 'rechargeResult',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return RechargeResultPage(
            amount: double.parse(query['amount'] ?? '0'),
            bonus: double.parse(query['bonus'] ?? '0'),
            total: double.parse(query['total'] ?? '0'),
            newBalance: double.parse(query['new_balance'] ?? '0'),
          );
        },
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                name: feed,
                builder: (context, state) => const FeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                name: live,
                builder: (context, state) => const LivePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/cart',
                name: cart,
                builder: (context, state) => const CartPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/order',
                name: order,
                builder: (context, state) => const OrderPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mine',
                name: mine,
                builder: (context, state) => const MinePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

final class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

final class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  bool _branchesSeeded = false;

  @override
  void initState() {
    super.initState();
    _seedBranches();
  }

  void _seedBranches() {
    if (_branchesSeeded) return;
    _branchesSeeded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shell = widget.navigationShell;
      // Pre-navigate all branches so IndexedStack has pages to show
      for (int i = 0; i < 5; i++) {
        shell.goBranch(i, initialLocation: true);
      }
      shell.goBranch(0, initialLocation: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    final index = shell.currentIndex;

    // Schedule microtask to avoid "provider modified during build" error.
    // This fires after the current frame completes.
    Future.microtask(() {
      if (mounted) {
        ref.read(currentTabIndexProvider.notifier).state = index;
      }
    });

    return Scaffold(
      body: shell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        onTap: (index) {
          shell.goBranch(index, initialLocation: true);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_filled),
            label: '视频',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv_outlined),
            activeIcon: Icon(Icons.live_tv),
            label: '直播',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: '购物车',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: '订单',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
