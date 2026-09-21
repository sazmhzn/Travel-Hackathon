/// Low-level exceptions thrown by data sources. Repositories translate these
/// into [Failure]s before they reach the UI — raw exception text must never be
/// shown to a user.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode, this.code});

  final int? statusCode;
  final String? code;
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection.']);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Could not read local data.']);
}

class AuthException extends AppException {
  const AuthException([super.message = 'Unauthorized.']);
}

class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  final int? statusCode;
  final Map<String, String> fieldErrors;
}
