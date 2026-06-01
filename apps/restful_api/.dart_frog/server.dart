// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/api/videos/index.dart' as api_videos_index;
import '../routes/api/videos/[videoId]/like.dart' as api_videos_$video_id_like;
import '../routes/api/videos/[videoId]/index.dart' as api_videos_$video_id_index;
import '../routes/api/videos/[videoId]/comments.dart' as api_videos_$video_id_comments;
import '../routes/api/users/register.dart' as api_users_register;
import '../routes/api/users/profile.dart' as api_users_profile;
import '../routes/api/users/login.dart' as api_users_login;
import '../routes/api/products/index.dart' as api_products_index;
import '../routes/api/products/[productId].dart' as api_products_$product_id;
import '../routes/api/orders/index.dart' as api_orders_index;
import '../routes/api/orders/[orderId]/pay.dart' as api_orders_$order_id_pay;
import '../routes/api/orders/[orderId]/index.dart' as api_orders_$order_id_index;
import '../routes/api/comments/index.dart' as api_comments_index;
import '../routes/api/comments/[commentId].dart' as api_comments_$comment_id;
import '../routes/api/cart/index.dart' as api_cart_index;
import '../routes/api/cart/items/selected.dart' as api_cart_items_selected;
import '../routes/api/cart/items/index.dart' as api_cart_items_index;
import '../routes/api/cart/items/[itemId].dart' as api_cart_items_$item_id;

import '../routes/_middleware.dart' as middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/api/videos', (context) => buildApiVideosHandler()(context))
    ..mount('/api/videos/<videoId>', (context,videoId,) => buildApiVideos$videoIdHandler(videoId,)(context))
    ..mount('/api/users', (context) => buildApiUsersHandler()(context))
    ..mount('/api/products', (context) => buildApiProductsHandler()(context))
    ..mount('/api/orders', (context) => buildApiOrdersHandler()(context))
    ..mount('/api/orders/<orderId>', (context,orderId,) => buildApiOrders$orderIdHandler(orderId,)(context))
    ..mount('/api/comments', (context) => buildApiCommentsHandler()(context))
    ..mount('/api/cart', (context) => buildApiCartHandler()(context))
    ..mount('/api/cart/items', (context) => buildApiCartItemsHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildApiVideosHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => api_videos_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiVideos$videoIdHandler(String videoId,) {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/comments', (context) => api_videos_$video_id_comments.onRequest(context,videoId,))..all('/like', (context) => api_videos_$video_id_like.onRequest(context,videoId,))..all('/', (context) => api_videos_$video_id_index.onRequest(context,videoId,));
  return pipeline.addHandler(router);
}

Handler buildApiUsersHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/login', (context) => api_users_login.onRequest(context,))..all('/profile', (context) => api_users_profile.onRequest(context,))..all('/register', (context) => api_users_register.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiProductsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<productId>', (context,productId,) => api_products_$product_id.onRequest(context,productId,))..all('/', (context) => api_products_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiOrdersHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => api_orders_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiOrders$orderIdHandler(String orderId,) {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/pay', (context) => api_orders_$order_id_pay.onRequest(context,orderId,))..all('/', (context) => api_orders_$order_id_index.onRequest(context,orderId,));
  return pipeline.addHandler(router);
}

Handler buildApiCommentsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<commentId>', (context,commentId,) => api_comments_$comment_id.onRequest(context,commentId,))..all('/', (context) => api_comments_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiCartHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => api_cart_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildApiCartItemsHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/selected', (context) => api_cart_items_selected.onRequest(context,))..all('/<itemId>', (context,itemId,) => api_cart_items_$item_id.onRequest(context,itemId,))..all('/', (context) => api_cart_items_index.onRequest(context,));
  return pipeline.addHandler(router);
}

