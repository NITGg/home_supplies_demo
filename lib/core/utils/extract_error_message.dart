import 'package:dio/dio.dart';
import 'exception/api_exeption_mapper.dart';
import 'exception/app_exception.dart';

/// Returns a user-facing error string from any throwable.
///
/// Handles (in order):
///   1. [AppException]   → uses its `.message` directly
///   2. [DioException]   → maps via [ApiExceptionMapper] then reads `.message`
///   3. Anything else    → converts via `.toString()`
///
/// This function is the **only** place in the app that should convert an error
/// to a string for display.  Cubits call it inside their `catch` blocks:
///
/// ```dart
/// } catch (e) {
///   emit(SomeError(extractErrorMessage(e)));
/// }
/// ```
String extractErrorMessage(Object e) {
  if (e is AppException) return e.message;
  if (e is DioException) return ApiExceptionMapper.fromDio(e).message;
  return e.toString();
}