import '../models/video_model.dart';
import 'dio_client.dart';

final class VideoApi {
  const VideoApi({required this.client});

  final DioClient client;

  Future<VideoListResponse> getVideos({int page = 1, int pageSize = 10}) async {
    final response = await client.get<Map<String, dynamic>>(
      '/videos',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      },
    );

    final data = response.data!;
    return VideoListResponse.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<VideoDetailResponse> getVideoDetail(String id) async {
    final response = await client.get<Map<String, dynamic>>('/videos/$id');
    final data = response.data!;
    return VideoDetailResponse.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<VideoListResponse> getRecommend({int page = 1, int pageSize = 10}) async {
    final response = await client.get<Map<String, dynamic>>(
      '/videos/recommend',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data!;
    return VideoListResponse.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<VideoListResponse> getFollow({required String userId, int page = 1, int pageSize = 10}) async {
    final response = await client.get<Map<String, dynamic>>(
      '/videos/follow',
      queryParameters: <String, dynamic>{
        'user_id': userId,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data!;
    return VideoListResponse.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<VideoListResponse> search({required String keyword, int page = 1, int pageSize = 20}) async {
    final response = await client.get<Map<String, dynamic>>(
      '/videos/search',
      queryParameters: <String, dynamic>{
        'keyword': keyword,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data!;
    return VideoListResponse.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<bool> toggleLike(String videoId, String userId) async {
    final response = await client.post<Map<String, dynamic>>(
      '/videos/$videoId/like',
      data: <String, dynamic>{'user_id': userId},
    );
    final data = response.data!;
    final result = data['data'] as Map<String, dynamic>;
    return result['liked'] as bool;
  }
}

final class VideoListResponse {
  const VideoListResponse({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory VideoListResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'] as List<dynamic>;
    return VideoListResponse(
      list: rawList
          .map((e) => VideoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }

  final List<VideoModel> list;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
}

final class VideoDetailResponse {
  const VideoDetailResponse({
    required this.video,
    required this.products,
  });

  factory VideoDetailResponse.fromJson(Map<String, dynamic> json) {
    final rawProducts = (json['products'] as List<dynamic>?) ?? [];
    return VideoDetailResponse(
      video: VideoModel.fromJson(json),
      products: rawProducts
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  final VideoModel video;
  final List<Map<String, dynamic>> products;
}
