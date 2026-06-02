import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../models/customer_service_model.dart';
import '../../provider/customer_service_provider.dart';
import '../../provider/service_providers.dart';

/// 售后客服对话页面
final class CustomerServicePage extends ConsumerStatefulWidget {
  const CustomerServicePage({
    super.key,
    required this.orderId,
    required this.orderItemsJson,
    required this.payAmount,
  });

  final String orderId;
  final String orderItemsJson;
  final double payAmount;

  @override
  ConsumerState<CustomerServicePage> createState() => _CustomerServicePageState();
}

final class _CustomerServicePageState extends ConsumerState<CustomerServicePage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasSentOrderCard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _userId => ref.read(storageServiceProvider).userId ?? 'u1';

  void _loadHistory() {
    ref.read(customerServiceProvider.notifier).loadMessages(
      orderId: widget.orderId,
      userId: _userId,
    );
  }

  Future<void> _sendOrderCard() async {
    if (_hasSentOrderCard) return;
    _hasSentOrderCard = true;

    await ref.read(customerServiceProvider.notifier).sendMessage(
      orderId: widget.orderId,
      userId: _userId,
      content: widget.orderItemsJson,
      msgType: 'order_card',
    );

    _scrollToBottom();
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();

    if (!_hasSentOrderCard) {
      await _sendOrderCard();
    }

    await ref.read(customerServiceProvider.notifier).sendMessage(
      orderId: widget.orderId,
      userId: _userId,
      content: text,
      msgType: 'text',
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerServiceProvider);

    if (state.messages.isEmpty && !state.isLoading && !_hasSentOrderCard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sendOrderCard();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('售后客服'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.messages.isEmpty
                    ? const Center(
                        child: Text('暂无消息', style: AppTextStyles.bodyMedium),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppDimens.paddingMd),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg = state.messages[index];
                          return _MessageBubble(message: msg);
                        },
                      ),
          ),

          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            padding: EdgeInsets.fromLTRB(
              AppDimens.paddingMd,
              AppDimens.paddingSm,
              AppDimens.paddingMd,
              AppDimens.paddingSm + MediaQuery.of(context).padding.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: '请输入您的问题...',
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textHint,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.paddingMd,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                      ),
                      style: const TextStyle(fontSize: 14),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: AppDimens.paddingSm),
                  GestureDetector(
                    onTap: state.isSending ? null : _sendText,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: state.isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 消息气泡组件
final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final CsMessageModel message;

  @override
  Widget build(BuildContext context) {
    if (message.msgType == 'order_card') {
      return _OrderCardBubble(message: message);
    }
    return _TextBubble(message: message);
  }
}

/// 文字消息气泡
final class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message});

  final CsMessageModel message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.paddingSm),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '客',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.paddingSm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingMd,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppDimens.radiusMd),
                  topRight: const Radius.circular(AppDimens.radiusMd),
                  bottomLeft: Radius.circular(
                    isUser ? AppDimens.radiusMd : 4,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? 4 : AppDimens.radiusMd,
                  ),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: AppDimens.paddingSm),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 订单卡片消息气泡 — 图片化展示
final class _OrderCardBubble extends StatelessWidget {
  const _OrderCardBubble({required this.message});

  final CsMessageModel message;

  @override
  Widget build(BuildContext context) {
    // 尝试解析 JSON 字符串为列表
    final List<dynamic> items;
    try {
      final decoded = jsonDecode(message.content);
      items = decoded as List<dynamic>;
    } catch (_) {
      // 如果解析失败，回退显示文本气泡
      return _TextBubble(message: message);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.paddingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppDimens.paddingMd),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部标题栏
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.paddingSm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          '订单信息',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimens.paddingMd),
                  // 商品列表
                  ...items.take(3).map((item) {
                    final itemMap = item as Map<String, dynamic>;
                    final name = (itemMap['product_name'] ?? '').toString();
                    final cover = (itemMap['product_cover'] ?? '').toString();
                    final price = (itemMap['product_price'] as num?)?.toDouble() ?? 0;
                    final qty = (itemMap['quantity'] as num?)?.toInt() ?? 1;
                    final spec = (itemMap['spec'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 商品图片（56x56 较大尺寸）
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                            child: CachedNetworkImage(
                              imageUrl: cover,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: AppColors.card,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.card,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.paddingMd),
                          // 商品详情
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (spec.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    spec,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  '¥${price.toStringAsFixed(2)}  x$qty',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                      child: Text(
                        '等${items.length}件商品',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  // 分割线
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: AppDimens.paddingSm),
                  // 商品总数 & 总价
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '共${items.fold<int>(0, (sum, item) {
                          final m = item as Map<String, dynamic>;
                          return sum + ((m['quantity'] as num?)?.toInt() ?? 1);
                        })}件商品',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                      // 若有 payAmount 传入，可取消下面注释展示实付金额
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
