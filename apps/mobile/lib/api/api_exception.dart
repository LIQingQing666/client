sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() => 'ApiException: $message (code: $statusCode)';
}

final class NetworkException extends ApiException {
  const NetworkException(super.message, {super.statusCode, super.data});
}

final class TimeoutException extends ApiException {
  const TimeoutException(super.message, {super.statusCode, super.data});
}

final class ServerException extends ApiException {
  const ServerException(super.message, {super.statusCode, super.data});
}

final class ClientException extends ApiException {
  const ClientException(super.message, {super.statusCode, super.data});
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message, {super.statusCode, super.data});
}

final class BusinessException extends ApiException {
  const BusinessException(super.message, {super.statusCode, super.data});
}
