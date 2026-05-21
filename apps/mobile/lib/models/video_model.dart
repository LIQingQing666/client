final class VideoModel {
  const VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.videoUrl,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.duration,
    required this.tags,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.playCount,
    required this.createdAt,
    this.isLiked = false,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      coverUrl: (json['cover_url'] as String?) ?? '',
      videoUrl: (json['video_url'] as String?) ?? '',
      authorId: (json['author_id'] as String?) ?? '',
      authorName: (json['author_name'] as String?) ?? '',
      authorAvatar: (json['author_avatar'] as String?) ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      shareCount: (json['share_count'] as num?)?.toInt() ?? 0,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }

  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final String videoUrl;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final int duration;
  final List<String> tags;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int playCount;
  final String createdAt;
  final bool isLiked;

  String get playCountText => _formatCount(playCount);
  String get likeCountText => _formatCount(likeCount);
  String get commentCountText => _formatCount(commentCount);

  static String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
