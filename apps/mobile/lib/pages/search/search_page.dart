import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/video_api.dart';
import '../../core/app_constants.dart';
import '../../models/video_model.dart';
import '../../provider/service_providers.dart';

final class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

final class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<VideoModel> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final client = ref.read(dioClientProvider);
      final api = VideoApi(client: client);
      final result = await api.search(keyword: keyword);
      if (!mounted) return;
      setState(() {
        _results = result.list;
        _isSearching = false;
        _hasSearched = true;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: AppTextStyles.bodyLarge,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: '搜索视频...',
            hintStyle: AppTextStyles.bodyMedium,
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, color: AppColors.primary),
              onPressed: _search,
            ),
          ),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : !_hasSearched
              ? const Center(child: Text('输入关键词搜索视频', style: AppTextStyles.bodyMedium))
              : _results.isEmpty
                  ? const Center(child: Text('未找到相关视频', style: AppTextStyles.bodyMedium))
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppDimens.paddingLg),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final video = _results[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppDimens.paddingSm),
                          padding: const EdgeInsets.all(AppDimens.paddingSm),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                child: CachedNetworkImage(
                                  imageUrl: video.coverUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: AppColors.card),
                                  errorWidget: (_, __, ___) => Container(color: AppColors.card),
                                ),
                              ),
                              const SizedBox(width: AppDimens.paddingMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(video.title, style: AppTextStyles.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(video.authorName, style: AppTextStyles.bodySmall),
                                    const SizedBox(height: 2),
                                    Text('${video.playCountText} 次播放', style: AppTextStyles.bodySmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
