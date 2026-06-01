import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../services/storage_service.dart';
import 'api_exception.dart';

final class DioClient {
  DioClient({required this._storage})
      : _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      // 移除默认 contentType，避免与请求头冲突
    ),
  ) {
    _dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      _ContentTypeInterceptor(), // 新增：智能处理 Content-Type
      _LogInterceptor(),
      RetryInterceptor(_dio),
    ]);
  }

  final Dio _dio;
  final StorageService _storage;

  String get baseUrl => _dio.options.baseUrl;

  Future<Response<T>> get<T>(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) {
    return _request(
          () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> post<T>(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) {
    return _request(
          () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _setContentType(options, data),
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> put<T>(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) {
    return _request(
          () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _setContentType(options, data),
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> delete<T>(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) {
    return _request(
          () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: _setContentType(options, data),
        cancelToken: cancelToken,
      ),
    );
  }

  /// 智能设置 Content-Type
  Options? _setContentType(Options? options, dynamic data) {
    if (data == null) return options;

    // FormData 不需要设置 application/json
    if (data is FormData) return options;

    final contentType = 'application/json';
    if (options != null) {
      return options.copyWith(contentType: contentType);
    }
    return Options(contentType: contentType);
  }

  Future<Response<T>> _request<T>(
      Future<Response<T>> Function() request,
      ) async {
    try {
      final response = await request();
      return response;
    } on DioException catch (e) {
      throw _handleDioException(e);
    }
  }

  ApiException _handleDioException(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException('请求超时，请检查网络', statusCode: statusCode);
      case DioExceptionType.connectionError:
        return NetworkException('网络连接失败', statusCode: statusCode);
      case DioExceptionType.badResponse:
        return _handleStatusCode(statusCode, data);
      default:
        return NetworkException('网络异常，请稍后重试', statusCode: statusCode);
    }
  }

  ApiException _handleStatusCode(int? statusCode, dynamic data) {
    final message = data is Map ? data['message'] as String? : null;

    switch (statusCode) {
      case 401:
        return UnauthorizedException(
          message ?? '未登录或登录已过期',
          statusCode: statusCode,
        );
      case 400:
        return ClientException(
          message ?? '请求参数错误',
          statusCode: statusCode,
          data: data,
        );
      case 404:
        return ClientException(
          message ?? '请求的资源不存在',
          statusCode: statusCode,
        );
      case 422:
        return BusinessException(
          message ?? '请求参数验证失败',
          statusCode: statusCode,
          data: data,
        );
      case 500:
      case 502:
      case 503:
        return ServerException(
          message ?? '服务器异常，请稍后重试',
          statusCode: statusCode,
        );
      default:
        if (statusCode != null && statusCode >= 400) {
          return ServerException(
            message ?? '请求失败',
            statusCode: statusCode,
          );
        }
        return const ServerException('未知错误');
    }
  }
}

// ========== 新增拦截器 ==========

/// 智能 Content-Type 拦截器
final class _ContentTypeInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 清除可能冲突的 header
    if (options.data == null) {
      options.headers.remove('content-type');
      options.headers.remove('Content-Type');
    }
    handler.next(options);
  }
}

// ========== 其他拦截器保持不变 ==========

final class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);

  final StorageService _storage;

  @override
  void onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) {
    final token = _storage.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      unawaited(_storage.clearAuth());
    }
    handler.next(err);
  }
}

final class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP] ${options.method} ${options.uri}');
      if (options.data != null) {
        debugPrint('[HTTP] body: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP] response ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[HTTP] error ${err.type} ${err.message}');
      debugPrint('[HTTP] error response: ${err.response?.data}');
    }
    handler.next(err);
  }
}

final class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2});

  final Dio _dio;
  final int maxRetries;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final extra = err.requestOptions.extra;
    final retryCount = (extra['retry_count'] as int?) ?? 0;

    if (!_shouldRetry(err) || retryCount >= maxRetries) {
      handler.next(err);
      return;
    }

    final newOptions = err.requestOptions.copyWith(
      extra: <String, dynamic>{...extra, 'retry_count': retryCount + 1},
    );

    unawaited(
      Future<void>.delayed(
        Duration(milliseconds: 500 * (retryCount + 1)),
      ).then((_) async {
        try {
          final response = await _dio.fetch<dynamic>(newOptions);
          handler.resolve(response);
        } on DioException catch (retryErr) {
          handler.next(retryErr);
        }
      }),
    );
  }

  bool _shouldRetry(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }
}
