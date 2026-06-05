import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../core/app_constants.dart';
import '../provider/auth_provider.dart';
import '../provider/service_providers.dart';
import '../utils/toast.dart';

/// Shows the video comments half-screen bottom sheet.
Future<void> showVideoCommentsSheet({
  required BuildContext context,
  required String videoId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _VideoCommentsSheet(videoId: videoId),
  );
}

final class _VideoCommentsSheet extends ConsumerStatefulWidget {
  const _VideoCommentsSheet({required this.videoId});

  final String videoId;

  @override
  ConsumerState<_VideoCommentsSheet> createState() => _VideoCommentsSheetState();
}

final class _VideoCommentsSheetState extends ConsumerState<_VideoCommentsSheet> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  static const int _pageSize = 10;

  DioClient get _client => ref.read(dioClientProvider);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadComments();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });

    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/comments',
        queryParameters: {
          'video_id': widget.videoId,
          'page': 1,
          'page_size': _pageSize,
        },
      );
      final data = (response.data!['data'] as Map<String, dynamic>?) ?? {};
      final list = (data['list'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ?? [];
      final hasMore = (data['has_more'] as bool?) ?? false;

      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll(list);
          _hasMore = hasMore;
          _page = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Comments] load failed: $e');
      if (mounted) {
        setState(() {
          _error = '加载失败';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final response = await _client.get<Map<String, dynamic>>(
        '/comments',
        queryParameters: {
          'video_id': widget.videoId,
          'page': nextPage,
          'page_size': _pageSize,
        },
      );
      final data = (response.data!['data'] as Map<String, dynamic>?) ?? {};
      final list = (data['list'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ?? [];
      final hasMore = (data['has_more'] as bool?) ?? false;

      if (mounted) {
        setState(() {
          _comments.addAll(list);
          _hasMore = hasMore;
          _page = nextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[Comments] loadMore failed: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
        showRetryToast('加载更多失败', onRetry: _loadMore);
      }
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final userId = ref.read(authProvider).userId;
    if (userId == null) {
      showToast('请先登录', type: ToastType.warning);
      return;
    }

    final optimisticId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimistic = <String, dynamic>{
      'id': optimisticId,
      'user_name': '我',
      'user_avatar': '',
      'content': content,
      'like_count': 0,
    };

    // Optimistic add — insert at the top.
    setState(() => _comments.insert(0, optimistic));
    _commentController.clear();

    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/comments',
        data: {
          'user_id': userId,
          'video_id': widget.videoId,
          'content': content,
        },
      );
      // Check server response code — avoid false-failure when the HTTP
      // call succeeds but the server returns a business-level error.
      final code = (response.data?['code'] as num?)?.toInt() ?? -1;
      if (code == 0) {
        showToast('评论发布成功');
      } else {
        final msg = response.data?['message'] as String? ?? '发布失败';
        throw Exception(msg);
      }
    } catch (e) {
      debugPrint('[Comments] post error: $e');
      // Rollback: remove the optimistic comment.
      if (mounted) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == optimisticId);
        });
      }
      showToast('评论发送失败，请重试', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isSmall = MediaQuery.of(context).size.width < 360;
    final sheetHeight = isSmall ? 0.6 : 0.7;

    return Container(
      height: MediaQuery.of(context).size.height * sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
            child: Text('评论', style: AppTextStyles.titleMedium),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off,
                                size: 36, color: AppColors.textHint),
                            const SizedBox(height: AppDimens.paddingSm),
                            Text(_error!, style: AppTextStyles.bodyMedium),
                            const SizedBox(height: AppDimens.paddingMd),
                            ElevatedButton(
                              onPressed: _loadComments,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                              child: const Text('重新加载'),
                            ),
                          ],
                        ),
                      )
                    : _comments.isEmpty
                        ? const Center(
                            child: Text('暂无评论，快来抢沙发吧',
                                style: AppTextStyles.bodyMedium),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            addAutomaticKeepAlives: false,
                            itemCount:
                                _comments.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _comments.length) {
                                return _LoadMoreIndicator(
                                  isLoading: _isLoadingMore,
                                  hasError: false,
                                  onRetry: _loadMore,
                                );
                              }
                              final comment = _comments[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.card,
                                  backgroundImage: (comment['user_avatar']
                                                      as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              comment['user_avatar']
                                                  as String)
                                          : null,
                                  child: const Icon(Icons.person,
                                      size: 16, color: AppColors.primary),
                                ),
                                title: Text(
                                  comment['user_name']?.toString() ?? '用户',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        comment['content']?.toString() ??
                                            '',
                                        style: AppTextStyles.bodyMedium),
                                    Text(
                                      '${comment['like_count'] ?? 0} 赞',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: AppDimens.paddingMd,
              right: AppDimens.paddingMd,
              top: AppDimens.paddingSm,
              bottom: AppDimens.paddingSm + bottomInset,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: '说点什么...',
                      hintStyle: const TextStyle(
                          color: AppColors.textHint, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusXl),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.paddingMd,
                        vertical: AppDimens.paddingSm,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: AppDimens.paddingSm),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    onPressed: _postComment,
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom loading / retry indicator for paginated lists.
final class _LoadMoreIndicator extends StatelessWidget {
  const _LoadMoreIndicator({
    required this.isLoading,
    required this.hasError,
    this.onRetry,
  });

  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimens.paddingLg),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingMd),
        child: Center(
          child: TextButton(
            onPressed: onRetry,
            child: const Text('加载失败，点击重试'),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
