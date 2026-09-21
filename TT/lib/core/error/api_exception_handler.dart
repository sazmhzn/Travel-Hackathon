import 'package:dio/dio.dart';

import 'exceptions.dart';
import 'failures.dart';
import 'result.dart';

/// Wraps repository API calls so thrown exceptions become [Failure]s and the UI
/// never sees a raw stack trace.
///
/// ```dart
/// class FooRepositoryImpl with ApiExceptionHandler implements FooRepository {
///   FutureResult<Foo> getFoo() => safeApiCall(() => _remote.getFoo());
/// }
/// ```
mixin ApiExceptionHandler {
  FutureResult<T> safeApiCall<T>(Future<T> Function() call) async {
    try {
      return Ok(await call());
    } on DioException catch (e) {
      return Err(_fromDio(e));
    } on AppException catch (e) {
      return Err(_fromApp(e));
    } catch (_) {
      return const Err(UnknownFailure());
    }
  }

  Failure _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.badCertificate:
        return const NetworkFailure(
          'Could not establish a secure connection.',
        );
      case DioExceptionType.cancel:
        return const UnknownFailure('The request was cancelled.');
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.unknown:
        return const UnknownFailure();
    }
  }

  Failure _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final data = response?.data;
    String? serverMessage;
    String? code;
    if (data is Map) {
      final raw = data['message'] ?? data['error'];
      if (raw is String && raw.trim().isNotEmpty) serverMessage = raw;
      code = data['code']?.toString();
    }

    return switch (status) {
      400 || 422 => ValidationFailure(
          serverMessage ?? 'Please check the details you entered.',
        ),
      401 => AuthFailure(),
      403 => ForbiddenFailure(
          serverMessage ?? 'You do not have permission to do that.',
        ),
      404 => ServerFailure(
          serverMessage ?? 'That item could not be found.',
          statusCode: status,
          code: code,
        ),
      409 => ServerFailure(
          serverMessage ?? 'That conflicts with the current state.',
          statusCode: status,
          code: code,
        ),
      _ when status != null && status >= 500 => ServerFailure(
          serverMessage ?? 'The server is unavailable right now.',
          statusCode: status,
          code: code,
        ),
      _ => ServerFailure(
          serverMessage ?? 'Something went wrong. Please try again.',
          statusCode: status,
          code: code,
        ),
    };
  }

  Failure _fromApp(AppException e) => switch (e) {
        ServerException(:final message, :final statusCode, :final code) =>
          ServerFailure(message, statusCode: statusCode, code: code),
        ValidationException(:final message, :final fieldErrors) =>
          ValidationFailure(message, fieldErrors: fieldErrors),
        NetworkException(:final message) => NetworkFailure(message),
        CacheException(:final message) => CacheFailure(message),
        AuthException(:final message) => AuthFailure(message),
      };
}
