import 'package:dio/dio.dart';
import 'app_exception.dart';

/// Maps a [DioException] (or any raw [Exception]) to a typed [AppException].
///
/// Usage – in a data source:
/// ```dart
/// } on DioException catch (e) {
///   throw ApiExceptionMapper.fromDio(e);
/// } catch (e) {
///   throw ApiExceptionMapper.fromUnknown(e);
/// }
/// ```
///
/// Usage – in a cubit (if you need the message string):
/// ```dart
/// } on AppException catch (e) {
///   emit(SomeError(e.message));
/// }
/// ```
abstract final class ApiExceptionMapper {
  ApiExceptionMapper._();

  // ─── Primary entry-point ──────────────────────────────────────────────────

  /// Convert a [DioException] to the most specific [AppException] possible.
  ///
  /// Priority order:
  ///   1. Connection / timeout errors  → [NetworkException]
  ///   2. HTTP status code             → typed 4xx / 5xx exception
  ///   3. Anything else                → [UnknownException]
  static AppException fromDio(DioException e) {
    // ── 1. Network-level errors (no response) ────────────────────────────────
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          'The request timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.cancel:
        return const NetworkException('The request was cancelled.');
      case DioExceptionType.badCertificate:
        return const NetworkException('SSL certificate error.');
      case DioExceptionType.badResponse:
        break; // handled below by status code
      case DioExceptionType.unknown:
        // Could still be a connectivity problem wrapped in an unknown type.
        if (e.message?.toLowerCase().contains('socket') == true ||
            e.message?.toLowerCase().contains('connection') == true) {
          return const NetworkException();
        }
        return UnknownException(e.message);
    }

    // ── 2. HTTP status codes ──────────────────────────────────────────────────
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;

    // Extract the server's own error message when available.
    final serverMessage = _extractServerMessage(body);

    return switch (statusCode) {
      400 => BadRequestException(serverMessage),
      401 => UnauthorizedException(serverMessage),
      403 => ForbiddenException(serverMessage),
      404 => NotFoundException(serverMessage),
      409 => ConflictException(serverMessage),
      422 => ValidationException(
        message: serverMessage,
        errors: body is Map<String, dynamic>
            ? body['errors'] as Map<String, dynamic>?
            : null,
      ),
      429 => TooManyRequestsException(serverMessage),
      500 => ServerException(serverMessage),
      _ => UnknownException(serverMessage ?? 'Unexpected status $statusCode'),
    };
  }

  /// Wraps any non-[AppException] throwable into an [AppException].
  ///
  /// If [e] is already an [AppException] it is returned unchanged, so this is
  /// safe to call unconditionally in a catch-all block.
  static AppException fromUnknown(Object e) {
    if (e is AppException) return e;
    if (e is DioException) return fromDio(e);
    return UnknownException(e.toString());
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  /// Tries several common server response shapes to extract a message string.
  ///
  /// Supports:
  /// * `{ "message": "..." }`
  /// * `{ "error": "..." }`
  /// * `{ "errors": { "field": ["msg"] } }` → first error string
  /// * Plain string body
  static String? _extractServerMessage(dynamic body) {
    if (body == null) return null;
    if (body is String && body.isNotEmpty) return body;
    if (body is Map<String, dynamic>) {
      // Prefer explicit "message" key.
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;

      // Fallback to "error" key.
      final error = body['error'];
      if (error is String && error.isNotEmpty) return error;

      // Flatten validation errors to a single string.
      final errors = body['errors'];
      if (errors is Map<String, dynamic>) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value is String) return value;
        }
      }
    }
    return null;
  }
}
