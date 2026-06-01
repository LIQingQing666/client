import 'package:dio/dio.dart';
import 'dio_client.dart';

final class UploadApi {
  const UploadApi({required this.client});

  final DioClient client;

  Future<String> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await client.post<Map<String, dynamic>>(
      '/upload/image',
      data: formData,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  Future<List<String>> uploadImages(List<String> filePaths) async {
    final formData = FormData();
    for (final path in filePaths) {
      formData.files.add(
        MapEntry('files', await MultipartFile.fromFile(path)),
      );
    }
    final response = await client.post<Map<String, dynamic>>(
      '/upload/images',
      data: formData,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return (data['urls'] as List<dynamic>)
        .map((e) => e as String)
        .toList();
  }
}
