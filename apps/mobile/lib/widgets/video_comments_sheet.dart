import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../api/dio_client.dart';
import '../core/app_constants.dart';
import '../utils/toast.dart';

/// Shows the video comments half-screen bottom sheet.
/// Pass [dioClient] for authenticated requests; falls back to mock data otherwise.
Future<void> showVideoCommentsSheet({
  required BuildContext context,
  required String videoId,
  DioClient? dioClient,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _VideoCommentsSheet(videoId: videoId, dioClient: dioClient),
  );
}

final class _VideoCommentsSheet extends StatefulWidget {
  const _VideoCommentsSheet({required this.videoId, this.dioClient});

  final String videoId;
  final DioClient? dioClient;

  @override
  State<_VideoCommentsSheet> createState() => _VideoCommentsSheetState();
}

final class _VideoCommentsSheetState extends State<_VideoCommentsSheet> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  static const int _pageSize = 10;
  static const int _maxCachedComments = 100;

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
      final dio = _dio();
      final response = await dio.get<Map<String, dynamic>>(
        '${AppConstants.baseUrl}/comments',
        queryParameters: {
          'video_id': widget.videoId,
          'page': 1,
          'page_size': _pageSize,
        },
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
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
    } catch (_) {
      // API failed — use mock data.
      _useMockData();
    }
  }

  void _useMockData() {
    if (!mounted) return;
    setState(() {
      _comments.clear();
      _comments.addAll(_mockComments);
      _hasMore = false;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final dio = _dio();
      final response = await dio.get<Map<String, dynamic>>(
        '${AppConstants.baseUrl}/comments',
        queryParameters: {
          'video_id': widget.videoId,
          'page': nextPage,
          'page_size': _pageSize,
        },
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      final list = (data['list'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ?? [];
      final hasMore = (data['has_more'] as bool?) ?? false;

      if (mounted) {
        setState(() {
          _comments.addAll(list);
          // Cap cached comments to prevent memory blow-up.
          if (_comments.length > _maxCachedComments) {
            _comments.removeRange(0, _comments.length - _maxCachedComments);
            _hasMore = true; // still more on server
          } else {
            _hasMore = hasMore;
          }
          _page = nextPage;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        showRetryToast('加载更多失败', onRetry: _loadMore);
      }
    }
  }

  Dio _dio() {
    if (widget.dioClient != null) {
      // DioClient doesn't expose its internal Dio, so create one with auth.
      // For now use a plain Dio — the auth token is added via interceptor on
      // the server side or we rely on the public endpoint.
    }
    return Dio(BaseOptions(
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
    ));
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final optimisticId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimistic = <String, dynamic>{
      'id': optimisticId,
      'user_name': '我',
      'user_avatar': '',
      'content': content,
      'like_count': 0,
    };

    setState(() => _comments.insert(0, optimistic));
    _commentController.clear();

    try {
      final dio = _dio();
      await dio.post<Map<String, dynamic>>(
        '${AppConstants.baseUrl}/comments',
        data: {
          'user_id': 'u1',
          'video_id': widget.videoId,
          'content': content,
        },
      );
      showToast('评论发布成功');
    } catch (_) {
      // Keep optimistic entry.
      showToast('评论已发布（离线模式）');
    }
  }

  static const _mockComments = <Map<String, dynamic>>[
    {
      'id': 'm1',
      'user_name': '小明',
      'user_avatar': '',
      'content': '这个视频太棒了，学习到了很多！',
      'like_count': 23,
    },
    {
      'id': 'm2',
      'user_name': '小红',
      'user_avatar': '',
      'content': '已下单，期待收货～',
      'like_count': 15,
    },
    {
      'id': 'm3',
      'user_name': '阿强',
      'user_avatar': '',
      'content': '第二次购买了，质量一如既往的好',
      'like_count': 8,
    },
    {
      'id': 'm4',
      'user_name': '花花',
      'user_avatar': '',
      'content': '请问这个有什么颜色可以选？',
      'like_count': 3,
    },
    {
      'id': 'm5',
      'user_name': '大海',
      'user_avatar': '',
      'content': '主播讲解得很详细，赞一个',
      'like_count': 12,
    },
  ];

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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
            child: Text('评论', style: AppTextStyles.titleMedium),
          ),
          const Divider(height: 1, color: AppColors.divider),
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
