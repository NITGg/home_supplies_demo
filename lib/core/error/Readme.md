# Custom Global Error & Restart Screen for Flutter

A production-ready error handling system that replaces Flutter's default error screens with a
polished, customizable interface.

## Features

✅ **Global Error Interception** - Catches all Flutter framework, widget build, and async errors  
✅ **Custom Error Screen** - User-friendly design with proper spacing and typography  
✅ **App Restart** - Safely resets the entire widget tree without process termination  
✅ **Visual Asset Support** - Display images, SVGs, or Lottie animations  
✅ **Debug/Release Modes** - Shows detailed errors in debug, sanitized messages in release  
✅ **Error Logging** - Hook for external logging (Sentry, Supabase, etc.)  
✅ **Fully Responsive** - Works on phones, tablets, web, and all orientations  
✅ **Zero Unsafe Operations** - Error handler itself never throws exceptions  
✅ **Pure Dart Solution** - No platform-specific code or plugins required

## Installation

### Add Dependencies

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_svg: ^2.0.9
  lottie: ^3.0.0
```

### Add Files to Your Project

Copy these files to your project:

- `error_config.dart`
- `error_handler.dart`
- `error_screen.dart`
- `restart_widget.dart`

## Quick Start

### Basic Setup

In your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'error_config.dart';
import 'error_handler.dart';
import 'restart_widget.dart';

Future<void> main() async {
  // Initialize error handler FIRST (before ensureInitialized)
  GlobalErrorHandler.initialize(
    config: const ErrorScreenConfig(
      title: 'Oops! Something went wrong',
      fallbackMessage: 'Please restart the app to continue.',
      buttonText: 'Restart App',
    ),
  );

  // Run app with error handling
  // All initialization happens inside onBeforeRunApp
  GlobalErrorHandler.runAppWithErrorHandling(
    RestartWidget(
      child: const MyApp(),
    ),
    onBeforeRunApp: () async {
      // All your initialization code goes here
      // This runs inside the error-handling zone
    },
  );
}
```

### Advanced Configuration

```dart
Future<void> main() async {
  GlobalErrorHandler.initialize(
    config: const ErrorScreenConfig(
      // Text customization
      title: 'Oops! Something went wrong',
      fallbackMessage: 'We encountered an unexpected error. Don\'t worry, your data is safe.',
      buttonText: 'Restart App',

      // Visual asset (optional)
      assetPath: 'assets/error_illustration.svg',
      assetType: ErrorAssetType.svg,

      // Colors
      backgroundColor: Color(0xFFFAFAFA),
      textColor: Color(0xFF1A1A1A),
      buttonColor: Color(0xFF6200EE),
      buttonTextColor: Colors.white,

      // Behavior
      showDetailsInDebug: true,
    ),

    // Error logging (optional)
    errorLogger: (error, stackTrace) {
      // Send to your analytics service
      print('Error: $error');
      // Sentry.captureException(error, stackTrace: stackTrace);
    },
  );

  GlobalErrorHandler.runAppWithErrorHandling(
    RestartWidget(
      child: BlocProvider(
        create: (context) => LocaleCubit(),
        child: const MyApp(),
      ),
    ),
    onBeforeRunApp: () async {
      await init(); // Your dependency injection

      // Google Sign-In initialization
      if (kIsWeb) {
        await GoogleSignIn.instance.initialize();
      } else {
        await GoogleSignIn.instance.initialize(
          serverClientId: 'your-client-id',
        );
      }

      // Set preferred orientations
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Initialize API client
      ApiClient.instance.init();
    },
  );
}
```

## Visual Assets

### Supported Asset Types

```dart
enum ErrorAssetType {
  image, // PNG, JPG, etc.
  svg, // SVG vector graphics
  lottie, // Lottie animations
}
```

### Adding Assets

1. Add assets to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/error_illustration.svg
    - assets/error_animation.json
    - assets/error_image.png
```

2. Configure in error handler:

```
ErrorScreenConfig(
  assetPath: 'assets/error_illustration.svg',
  assetType: ErrorAssetType.svg,
)
```

### Asset Fallback

If an asset fails to load, the error screen automatically shows a default icon. The error screen
itself will never crash.

## Error Handling Scopes

The system handles three types of errors:

### 1. Framework Errors

Caught by `FlutterError.onError` - includes framework-level exceptions from button clicks, gestures,
etc.

### 2. Widget Build Errors

Caught by `ErrorWidget.builder` - includes errors during widget build phase.

### 3. Async Errors

Caught by `runZonedGuarded` - includes uncaught async/Future errors.

## Restart Mechanism

### How It Works

The restart mechanism uses a `RestartWidget` with a global key that:

1. Wraps your entire app at the root level
2. Maintains a unique key for the app tree
3. Can show/hide the error screen by changing internal state
4. Rebuilds the entire widget tree with a new key on restart

### Automatic Restart

The error screen includes a restart button that automatically resets the app:

```
// Handled automatically when user clicks "Restart App"
```

### Manual Restart (Optional)

You can also trigger restart from anywhere in your app:

```
RestartWidget.restartApp();
```

### What Gets Reset

- ✅ All widget state
- ✅ Navigation stack
- ✅ Bloc/Cubit instances (if created in the tree)
- ✅ Provider instances (if created in the tree)
- ❌ Global singletons (unless recreated)
- ❌ Platform-level state

## Important Setup Notes

### Zone Mismatch Prevention

**CRITICAL**: Initialize the error handler **before** `WidgetsFlutterBinding.ensureInitialized()`:

```
// ✅ CORRECT
Future<void> main() async {
  GlobalErrorHandler.initialize(...);  // First
  
  GlobalErrorHandler.runAppWithErrorHandling(
    RestartWidget(...),
    onBeforeRunApp: () async {
      // ensureInitialized is called automatically inside here
      await init();
    },
  );
}

// ❌ WRONG - Causes zone mismatch
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Don't call this
  GlobalErrorHandler.initialize(...);
  GlobalErrorHandler.runAppWithErrorHandling(...);
}
```

### RestartWidget Placement

Always wrap your **entire app** with `RestartWidget` at the root level:

```
GlobalErrorHandler.runAppWithErrorHandling(
  RestartWidget(  // ✅ At the root
    child: BlocProvider(
      create: (context) => LocaleCubit(),
      child: const MyApp(),
    ),
  ),
);
```

## Logging Integration

### Basic Logging

```
GlobalErrorHandler.initialize(
  errorLogger: (error, stackTrace) {
    print('Error: $error');
  },
);
```

### Sentry Integration

```
import 'package:sentry_flutter/sentry_flutter.dart';

GlobalErrorHandler.initialize(
  errorLogger: (error, stackTrace) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
    );
  },
);
```

### Supabase Integration

```
import 'package:supabase_flutter/supabase_flutter.dart';

GlobalErrorHandler.initialize(
  errorLogger: (error, stackTrace) async {
    await Supabase.instance.client
      .from('error_logs')
      .insert({
        'error': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
  },
);
```

## Customization Examples

### Dark Theme

```
ErrorScreenConfig(
  backgroundColor: Color(0xFF121212),
  textColor: Colors.white,
  buttonColor: Color(0xFFBB86FC),
)
```

### Minimal Style

```
ErrorScreenConfig(
  title: 'Error',
  fallbackMessage: 'Something went wrong.',
  buttonText: 'Retry',
  showDetailsInDebug: false,
)
```

### Brand Colors

```
ErrorScreenConfig(
  backgroundColor: Color(0xFFF5F5F5),
  buttonColor: Color(0xFFFF6B6B), // Your brand color
  titleStyle: TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1A1A1A),
  ),
)
```

## Testing

### Create a Test Page

```dart
import 'package:flutter/material.dart';

class ErrorTestPage extends StatelessWidget {
  const ErrorTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error Handler Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Test 1: Synchronous Exception
            ElevatedButton(
              onPressed: () {
                throw Exception('Test synchronous exception!');
              },
              child: const Text('Throw Exception'),
            ),

            const SizedBox(height: 16),

            // Test 2: Widget Build Error
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const _ErrorWidget(),
                  ),
                );
              },
              child: const Text('Trigger Build Error'),
            ),

            const SizedBox(height: 16),

            // Test 3: Async Error
            ElevatedButton(
              onPressed: () async {
                await Future.delayed(const Duration(seconds: 1));
                throw Exception('Async error after 1 second!');
              },
              child: const Text('Throw Async Error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          throw Exception('Widget build error!');
        },
      ),
    );
  }
}
```

### What to Verify

- [ ] Custom error screen shows (not red Flutter error)
- [ ] SVG/image/Lottie asset displays correctly (or fallback icon)
- [ ] Title and message appear correctly
- [ ] Colors match your configuration
- [ ] Debug mode shows error details (if enabled)
- [ ] Release mode shows sanitized message
- [ ] Restart button works and returns to initial route
- [ ] All error types are caught (sync, async, build)

## Build Modes

### Debug Mode

- Shows full error details (if `showDetailsInDebug: true`)
- Displays exception messages in scrollable container
- Shows stack traces
- Useful for development

### Release Mode

- Shows sanitized user-friendly messages
- Hides technical details
- Production-ready appearance

### Profile Mode

- Behaves like release mode
- Safe for performance testing

## Troubleshooting

### Error screen doesn't appear

- ✅ Check that `GlobalErrorHandler.initialize()` is called first
- ✅ Verify `RestartWidget` wraps your entire app
- ✅ Check console logs for error messages
- ✅ Ensure you're using `GlobalErrorHandler.runAppWithErrorHandling()`

### Restart button doesn't work

- ✅ Ensure `RestartWidget` is at the root level
- ✅ Check that `RestartWidget` has a global key (done automatically)
- ✅ Verify no duplicate `runApp()` calls

### Zone mismatch warning

- ✅ Move all initialization into `onBeforeRunApp` callback
- ✅ Don't call `WidgetsFlutterBinding.ensureInitialized()` manually

### Async errors not showing

- ✅ Check console logs for retry attempts
- ✅ Verify `RestartWidget` is initialized before async error occurs
- ✅ Error screen should appear within 1-2 seconds maximum

## Best Practices

1. **Initialize Early** - Call `GlobalErrorHandler.initialize()` as the first line in `main()`
2. **Wrap at Root** - Always wrap your root widget with `RestartWidget`
3. **Test Thoroughly** - Test error handling in all build modes (debug, release, profile)
4. **Log Errors** - Always implement error logging for production
5. **Sanitize Messages** - Never expose sensitive data in error messages
6. **Provide Context** - Give users clear guidance on what to do
7. **Use onBeforeRunApp** - Put all initialization code in the callback to avoid zone mismatches

## Limitations

- Cannot recover from truly fatal errors (e.g., out of memory)
- Restart clears in-memory state (use persistence for critical data)
- Web hot restart may behave differently than mobile
- Asset loading errors are gracefully handled but the asset won't display
- Some platform-specific crashes may not be caught

## Architecture

```
main.dart
  ↓
GlobalErrorHandler.initialize()
  ↓
GlobalErrorHandler.runAppWithErrorHandling()
  ↓ (creates error-handling zone)
  ↓
RestartWidget (with global key)
  ↓
Your App (MaterialApp, providers, etc.)
```

When an error occurs:

1. Error is caught by `FlutterError.onError`, `ErrorWidget.builder`, or `runZonedGuarded`
2. Error is logged via your `errorLogger` callback
3. `RestartWidget.showError()` is called via global key
4. Error screen replaces app content
5. User clicks "Restart App"
6. `RestartWidget.restartApp()` rebuilds tree with new key
7. App returns to initial state

## FAQ

**Q: Does this work on web?**  
A: Yes, fully responsive and works on Flutter web.

**Q: Will this catch ALL errors?**  
A: It catches Flutter framework, widget build, and async errors. Some platform-specific crashes may
not be caught.

**Q: Does restart close and reopen the app?**  
A: No, it rebuilds the widget tree without terminating the process. It's like a "hot restart" within
your app.

**Q: Can I customize the error screen layout?**  
A: Yes, you can modify `error_screen.dart` or create your own implementation.

**Q: Is this production-ready?**  
A: Yes, designed for production use with proper error handling, logging, and state management.

**Q: Do I need platform-specific setup?**  
A: No! This is a pure Dart solution with no platform channels or native code.

**Q: What about state management?**  
A: Works with any state management solution (Bloc, Provider, Riverpod, GetX, etc.). Just ensure
providers are inside `RestartWidget`.

## License

MIT License - feel free to use in any project.

## Support

For issues or questions, please refer to the implementation files or create an issue in your project
repository.