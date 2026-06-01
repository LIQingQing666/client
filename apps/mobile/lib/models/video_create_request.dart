// lib/models/video_create_request.dart

final class VideoCreateRequest {
  const VideoCreateRequest({
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.videoUrl,
    required this.authorName,
    this.authorId = '',
    this.tags = const [],
    this.linkedProductIds = const [],
    this.duration = 0,
    this.status = 'draft',
  });

  final String title;
  final String description;
  final String coverUrl;
  final String videoUrl;
  final String authorName;
  final String authorId;
  final List<String> tags;
  final List<String> linkedProductIds;
  final int duration;
  final String status;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'cover_url': coverUrl,
    'video_url': videoUrl,
    'author_name': authorName,
    'author_id': authorId,
    'tags': tags,
    'linked_product_ids': linkedProductIds,
    'duration': duration,
    'status': status,
  };
}
