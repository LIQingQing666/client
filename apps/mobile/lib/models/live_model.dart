import 'product_model.dart';

final class LiveMessage {
  const LiveMessage({
    required this.id,
    required this.userName,
    required this.content,
    required this.type,
    this.userAvatar = '',
    this.timestamp = '',
    this.productId,
  });

  factory LiveMessage.fromJson(Map<String, dynamic> json) {
    return LiveMessage(
      id: (json['id'] as String?) ?? '',
      userName: (json['user_name'] as String?) ?? '',
      userAvatar: (json['user_avatar'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'user',
      timestamp: (json['timestamp'] as String?) ?? '',
      productId: json['product_id'] as String?,
    );
  }

  final String id;
  final String userName;
  final String userAvatar;
  final String content;
  final String type;
  final String timestamp;
  final String? productId;

  bool get isSystem => type == 'system';
  bool get isProductMessage => type == 'product';
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
    this.status = 'preview',
    this.productIds = const [],
    this.currentProductId,
    this.heatCount = 0,
    this.likeCount = 0,
    this.startedAt,
    this.endedAt,
  });

  factory LiveRoomInfo.fromJson(Map<String, dynamic> json) {
    final rawTags = (json['tags'] as List<dynamic>?) ?? [];
    final rawProductIds = (json['product_ids'] as List<dynamic>?) ?? [];
    return LiveRoomInfo(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      coverUrl: (json['cover_url'] as String?) ?? '',
      videoUrl: (json['video_url'] as String?) ?? '',
      authorId: (json['author_id'] as String?) ?? '',
      authorName: (json['author_name'] as String?) ?? '',
      authorAvatar: (json['author_avatar'] as String?) ?? '',
      onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
      heatCount: (json['heat_count'] as num?)?.toInt() ?? 0,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      tags: rawTags.cast<String>(),
      status: (json['status'] as String?) ?? 'preview',
      productIds: rawProductIds.cast<String>(),
      currentProductId: json['current_product_id'] as String?,
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
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
  final int heatCount;
  final int likeCount;
  final List<String> tags;
  final String status;
  final List<String> productIds;
  final String? currentProductId;
  final String? startedAt;
  final String? endedAt;

  bool get isLive => status == 'live';
  bool get isPreview => status == 'preview';
  bool get isEnded => status == 'ended';

  String get onlineCountText {
    if (onlineCount >= 10000) {
      return '${(onlineCount / 10000).toStringAsFixed(1)}万';
    }
    return onlineCount.toString();
  }

  String get heatCountText {
    if (heatCount >= 10000) {
      return '${(heatCount / 10000).toStringAsFixed(1)}万热度';
    }
    return '$heatCount热度';
  }

  String get statusText {
    switch (status) {
      case 'live': return '直播中';
      case 'ended': return '已结束';
      case 'preview':
      default: return '预告';
    }
  }
}

extension LiveRoomInfoCopyWith on LiveRoomInfo {
  LiveRoomInfo copyWith({
    String? status,
    String? currentProductId,
    String? videoUrl,
    int? onlineCount,
    int? likeCount,
    int? heatCount,
  }) {
    return LiveRoomInfo(
      id: id,
      title: title,
      coverUrl: coverUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      onlineCount: onlineCount ?? this.onlineCount,
      tags: tags,
      status: status ?? this.status,
      productIds: productIds,
      currentProductId: currentProductId ?? this.currentProductId,
      heatCount: heatCount ?? this.heatCount,
      likeCount: likeCount ?? this.likeCount,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }
}
