import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tawreedat_go/core/error/screen.dart';
import 'config.dart';
import 'restart_widget.dart';

/// Callback for external error logging
typedef ErrorLogger = void Function(Object error, StackTrace? stackTrace);

/// Global error handler that intercepts all Flutter errors
class GlobalErrorHandler {
  static ErrorScreenConfig _config = const ErrorScreenConfig();
  static ErrorLogger? _errorLogger;
  static bool _initialized = false;
  static bool _isShowingError = false;

  /// Initialize the global error handler
  static void initialize({
    ErrorScreenConfig? config,
    ErrorLogger? errorLogger,
  }) {
    if (_initialized) {
      debugPrint('GlobalErrorHandler already initialized');
      return;
    }

    _config = config ?? const ErrorScreenConfig();
    _errorLogger = errorLogger;
    _initialized = true;

    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _logError(details.exception, details.stack);

      if (_shouldIgnore(details.exception)) {
        debugPrint('⚠️ Ignored framework error: ${details.exception}');
        return;
      }

      _showErrorScreen(details);
    };

    // Handle widget build errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      _logError(details.exception, details.stack);

      // For build errors, show inline error widget
      // but also trigger the full error screen
      _showErrorScreen(details);

      return ErrorScreen(
        errorDetails: details,
        config: _config,
        onRestart: _handleRestart,
      );
    };

    debugPrint('GlobalErrorHandler initialized successfully');
  }

  /// Show error screen by replacing the app content
  static void _showErrorScreen(FlutterErrorDetails details) {
    // Allow async errors to show even if another error is showing
    // (but not duplicate framework errors)
    if (_isShowingError && details.library != 'async error handler') {
      debugPrint('⚠️ Error screen already showing, ignoring duplicate');
      return;
    }

    _isShowingError = true;

    debugPrint('🔴 Showing error screen for: ${details.exceptionAsString()}');

    // Try multiple times with delays to ensure RestartWidget is ready
    _tryShowError(details, 0);
  }

  static void _tryShowError(FlutterErrorDetails details, int attemptCount) {
    if (attemptCount > 20) {
      debugPrint('❌ Failed to show error screen after 20 attempts');
      debugPrint('RestartWidget may not be in the widget tree');
      return;
    }

    // Use schedulerBinding for better frame scheduling
    final binding = SchedulerBinding.instance;

    // Wait for the current frame to complete
    binding.addPostFrameCallback((_) {
      final state = RestartWidget.restartKey.currentState;
      if (state != null && state.mounted) {
        debugPrint('✅ Showing error screen (attempt ${attemptCount + 1})');
        state.showError(
          ErrorScreen(
            errorDetails: details,
            config: _config,
            onRestart: _handleRestart,
          ),
        );
      } else {
        debugPrint(
          '⏳ RestartWidget not ready (mounted: ${state?.mounted}), retrying... (attempt ${attemptCount + 1})',
        );
        // Schedule next frame
        binding.scheduleFrame();
        // Try again after next frame
        Future.delayed(const Duration(milliseconds: 100), () {
          _tryShowError(details, attemptCount + 1);
        });
      }
    });

    // Ensure a frame is scheduled
    binding.scheduleFrame();
  }

  /// Handle restart action using RestartWidget
  static void _handleRestart() {
    debugPrint('🔄 Restarting app...');
    _isShowingError = false;
    RestartWidget.restartApp();
  }

  /// Reset error state
  static void resetErrorState() {
    _isShowingError = false;
  }

  /// Run the app with error handling for async errors
  static void runAppWithErrorHandling(
    Widget app, {
    Future<void> Function()? onBeforeRunApp,
  }) {
    if (!_initialized) {
      throw StateError(
        'GlobalErrorHandler must be initialized before running the app. '
        'Call GlobalErrorHandler.initialize() first.',
      );
    }

    runZonedGuarded(
      () async {
        // Initialize Flutter bindings inside the zone
        WidgetsFlutterBinding.ensureInitialized();

        // Run any pre-initialization code
        if (onBeforeRunApp != null) {
          await onBeforeRunApp();
        }

        runApp(app);
      },
      (error, stackTrace) {
        _logError(error, stackTrace);

        if (_shouldIgnore(error)) {
          debugPrint('⚠️ Ignored async error: $error');
          return;
        }

        debugPrint('🔴 Async error caught: $error');

        final details = FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'async error handler',
          context: ErrorDescription('Uncaught async error'),
        );

        _showErrorScreen(details);
      },
    );
  }

  /// Update configuration at runtime
  static void updateConfig(ErrorScreenConfig config) {
    _config = config;
  }

  /// Get current configuration
  static ErrorScreenConfig get config => _config;

  /// Log error using the provided logger
  static void _logError(Object error, StackTrace? stackTrace) {
    try {
      _errorLogger?.call(error, stackTrace);
    } catch (e) {
      // Ensure logging errors don't crash the error handler
      debugPrint('Error in error logger: $e');
    }
  }

  /// Manually trigger error screen (useful for testing)
  static Widget createErrorScreen({
    FlutterErrorDetails? errorDetails,
    ErrorScreenConfig? config,
    VoidCallback? onRestart,
  }) {
    return ErrorScreen(
      errorDetails: errorDetails,
      config: config ?? _config,
      onRestart: onRestart,
    );
  }

  /// Check if handler is initialized
  static bool get isInitialized => _initialized;

  /// Reset handler (useful for testing)
  @visibleForTesting
  static void reset() {
    _initialized = false;
    _config = const ErrorScreenConfig();
    _errorLogger = null;
  }

  static bool _shouldIgnore(Object error) {
    final message = error.toString();

    // RenderFlex overflow
    if (message.contains('A RenderFlex overflowed')) return true;

    // Image network/socket errors
    if (message.contains(
      'ClientException with SocketException: Connection refused',
    )) {
      return true;
    }if (message.contains(
      'ClientException with SocketException: Connection timed out',
    )) {
      return true;
    }

    if (message.contains(
      'ClientException with SocketException: Connection reset by peer',
    )) {
      return true;
    }
    if (message.contains('HttpException: Invalid')) return true;
    if (message.contains('Failed host lookup')) return true;
    if (message.contains('Image provider')) return true;
    if (message.contains('HTTP request failed')) return true;
    if (message.contains('Invalid argument(s): No host specified in URI')) {
      return true;
    }
    // Cubit closed before async operation completed
    if (message.contains('Cannot emit new states after calling close')) {
      return true;
    }

    // You can add more harmless ones here
    return false;
  }
}
