final class LiveMessage {
  const LiveMessage({
    required this.id,
    required this.userName,
    required this.content,
    required this.type,
    this.userAvatar = '',
    this.timestamp = '',
  });

  factory LiveMessage.fromJson(Map<String, dynamic> json) {
    return LiveMessage(
      id: (json['id'] as String?) ?? '',
      userName: (json['user_name'] as String?) ?? '',
      userAvatar: (json['user_avatar'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'user',
      timestamp: (json['timestamp'] as String?) ?? '',
    );
  }

  final String id;
  final String userName;
  final String userAvatar;
  final String content;
  final String type;
  final String timestamp;

  bool get isSystem => type == 'system';
}

final class LiveRoomInfo {
  const LiveRoomInfo({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.videoUrl,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.onlineCount,
    required this.tags,
  });

  factory LiveRoomInfo.fromJson(Map<String, dynamic> json) {
    final rawTags = (json['tags'] as List<dynamic>?) ?? [];
    return LiveRoomInfo(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      coverUrl: (json['cover_url'] as String?) ?? '',
      videoUrl: (json['video_url'] as String?) ?? '',
      authorId: (json['author_id'] as String?) ?? '',
      authorName: (json['author_name'] as String?) ?? '',
      authorAvatar: (json['author_avatar'] as String?) ?? '',
      onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
      tags: rawTags.cast<String>(),
    );
  }

  final String id;
  final String title;
  final String coverUrl;
  final String videoUrl;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final int onlineCount;
  final List<String> tags;

  String get onlineCountText {
    if (onlineCount >= 10000) {
      return '${(onlineCount / 10000).toStringAsFixed(1)}万';
    }
    return onlineCount.toString();
  }
}
