/// Typed exception hierarchy.
///
/// Every layer of the app should throw (or propagate) one of these instead of
/// a raw [Exception] or [String].  This makes [BLoC] error states predictable
/// and lets the UI render the right copy without string-matching.
library;

// ─── Base ─────────────────────────────────────────────────────────────────────

sealed class AppException implements Exception {
  const AppException({required this.message, this.statusCode});

  /// Human-readable message suitable for display.
  final String message;

  /// HTTP status code that produced this exception (may be null for network
  /// errors or locally-thrown exceptions).
  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

// ─── HTTP 4xx ────────────────────────────────────────────────────────────────

/// 400 – server rejected the request payload.
final class BadRequestException extends AppException {
  const BadRequestException([String? message])
      : super(
    message: message ?? 'Bad request. Please check your input.',
    statusCode: 400,
  );
}

/// 401 – missing or expired token.
final class UnauthorizedException extends AppException {
  const UnauthorizedException([String? message])
      : super(
    message: message ?? 'Your session has expired. Please log in again.',
    statusCode: 401,
  );
}

/// 403 – authenticated but not allowed.
final class ForbiddenException extends AppException {
  const ForbiddenException([String? message])
      : super(
    message: message ?? 'You do not have permission to do that.',
    statusCode: 403,
  );
}

/// 404 – resource not found.
final class NotFoundException extends AppException {
  const NotFoundException([String? message])
      : super(
    message: message ?? 'The requested resource was not found.',
    statusCode: 404,
  );
}

/// 409 – conflict (e.g. duplicate resource).
final class ConflictException extends AppException {
  const ConflictException([String? message])
      : super(
    message: message ?? 'A conflict occurred. Please try again.',
    statusCode: 409,
  );
}

/// 422 – validation errors from the server.
///
/// [errors] is the raw `errors` map from the response body; may be null when
/// the server only sends a top-level `message`.
final class ValidationException extends AppException {
  const ValidationException({String? message, this.errors})
      : super(
    message: message ?? 'Validation failed. Please check your input.',
    statusCode: 422,
  );

  final Map<String, dynamic>? errors;
}

/// 429 – rate limited.
final class TooManyRequestsException extends AppException {
  const TooManyRequestsException([String? message])
      : super(
    message: message ?? 'Too many requests. Please slow down.',
    statusCode: 429,
  );
}

// ─── HTTP 5xx ─────────────────────────────────────────────────────────────────

/// 500 / 502 / 503 – server-side failure.
final class ServerException extends AppException {
  const ServerException([String? message])
      : super(
    message: message ?? 'A server error occurred. Please try again later.',
    statusCode: 500,
  );
}

// ─── Network / Connectivity ───────────────────────────────────────────────────

/// No internet, DNS failure, connection refused, or timeout.
final class NetworkException extends AppException {
  const NetworkException([String? message])
      : super(
    message: message ??
        'No internet connection. Please check your network and try again.',
  );
}

// ─── Domain-specific ──────────────────────────────────────────────────────────

/// The API returned 200 but the `data` field was null or malformed.
final class ParseException extends AppException {
  const ParseException([String? message])
      : super(message: message ?? 'Failed to parse the server response.');
}

/// Something unexpected happened that doesn't fit any category above.
final class UnknownException extends AppException {
  const UnknownException([String? message])
      : super(message: message ?? 'An unexpected error occurred.');
}