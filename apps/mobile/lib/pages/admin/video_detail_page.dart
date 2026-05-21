import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/video_api.dart';
import '../../core/app_constants.dart';
import '../../models/video_model.dart';
import '../../provider/service_providers.dart';

final class VideoDetailPage extends ConsumerStatefulWidget {
  const VideoDetailPage({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

final class _VideoDetailPageState extends ConsumerState<VideoDetailPage> {
  VideoModel? _video;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = ref.read(dioClientProvider);
      final api = VideoApi(client: client);
      final result = await api.getVideoDetail(widget.videoId);
      setState(() {
        _video = result.video;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('视频详情'), backgroundColor: AppColors.background),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: AppDimens.paddingMd),
                      Text(_error!, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: AppDimens.paddingMd),
                      ElevatedButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final v = _video!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            child: CachedNetworkImage(
              imageUrl: v.coverUrl,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 180, color: AppColors.card),
              errorWidget: (_, __, ___) => Container(height: 180, color: AppColors.card),
            ),
          ),
          const SizedBox(height: AppDimens.paddingLg),
          _InfoRow(label: '标题', value: v.title),
          if (v.description.isNotEmpty) ...[
            const SizedBox(height: AppDimens.paddingMd),
            _InfoRow(label: '描述', value: v.description),
          ],
          const SizedBox(height: AppDimens.paddingMd),
          Row(
            children: [
              Expanded(child: _InfoRow(label: '作者', value: v.authorName)),
              Expanded(child: _InfoRow(label: '时长', value: '${v.duration}s')),
            ],
          ),
          const SizedBox(height: AppDimens.paddingMd),
          Row(
            children: [
              _StatChip(label: '播放', value: v.playCount.toString()),
              const SizedBox(width: AppDimens.paddingMd),
              _StatChip(label: '点赞', value: v.likeCount.toString()),
              const SizedBox(width: AppDimens.paddingMd),
              _StatChip(label: '评论', value: v.commentCount.toString()),
              const SizedBox(width: AppDimens.paddingMd),
              _StatChip(label: '分享', value: v.shareCount.toString()),
            ],
          ),
          if (v.tags.isNotEmpty) ...[
            const SizedBox(height: AppDimens.paddingLg),
            const Text('标签', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppDimens.paddingSm),
            Wrap(
              spacing: AppDimens.paddingSm,
              runSpacing: AppDimens.paddingSm,
              children: v.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingSm, vertical: AppDimens.paddingXs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Text(t, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimens.paddingMd),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          ),
          child: Text(value, style: AppTextStyles.bodyLarge),
        ),
      ],
    );
  }
}

final class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.paddingSm),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.titleMedium),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
