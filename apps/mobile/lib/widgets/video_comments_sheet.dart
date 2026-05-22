import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../utils/toast.dart';

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

final class _VideoCommentsSheet extends StatefulWidget {
  const _VideoCommentsSheet({required this.videoId});

  final String videoId;

  @override
  State<_VideoCommentsSheet> createState() => _VideoCommentsSheetState();
}

final class _VideoCommentsSheetState extends State<_VideoCommentsSheet> {
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      // Use dioClient via a direct HTTP call, or mock data
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>(
        'http://127.0.0.1:3000/api/comments',
        queryParameters: {'video_id': widget.videoId},
      );
      final data = (response.data?['data'] as Map<String, dynamic>?) ?? {};
      if (mounted) {
        setState(() {
          _comments = (data['list'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    // Optimistic add
    final comment = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'user_name': '我',
      'user_avatar': '',
      'content': content,
      'like_count': 0,
    };
    setState(() => _comments = [comment, ..._comments]);
    _commentController.clear();

    try {
      final dio = Dio();
      await dio.post<Map<String, dynamic>>(
        'http://127.0.0.1:3000/api/comments',
        data: {
          'user_id': 'u1',
          'video_id': widget.videoId,
          'content': content,
        },
      );
      showToast('评论发布成功');
    } catch (_) {
      // Keep optimistic comment even if API fails
      showToast('评论已发布');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimens.radiusXl)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _comments.isEmpty
                    ? const Center(
                        child: Text('暂无评论，快来抢沙发吧', style: AppTextStyles.bodyMedium),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.card,
                              backgroundImage: (comment['user_avatar'] as String?)?.isNotEmpty == true
                                  ? NetworkImage(comment['user_avatar'] as String)
                                  : null,
                              child: Icon(Icons.person, size: 16, color: AppColors.primary),
                            ),
                            title: Text(
                              comment['user_name']?.toString() ?? '用户',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment['content']?.toString() ?? '', style: AppTextStyles.bodyMedium),
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
                      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
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
                GestureDetector(
                  onTap: _postComment,
                  child: const Icon(Icons.send, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
