import 'package:flutter/material.dart';

/// Widget that enables app restart without process termination
class RestartWidget extends StatefulWidget {
  final Widget child;

  // Global key to access the restart widget from anywhere
  static final GlobalKey<_RestartWidgetState> restartKey =
      GlobalKey<_RestartWidgetState>();

  RestartWidget({required this.child}) : super(key: restartKey);

  /// Restarts the app by rebuilding the entire widget tree
  static void restartApp() {
    restartKey.currentState?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();
  bool _showError = false;
  Widget? _errorWidget;

  @override
  void initState() {
    super.initState();
    debugPrint('✅ RestartWidget initialized');
  }

  void restartApp() {
    debugPrint('🔄 RestartWidget: Restarting app, clearing error state');
    setState(() {
      _showError = false;
      _errorWidget = null;
      _key = UniqueKey();
    });
  }

  void showError(Widget errorWidget) {
    debugPrint('🔴 RestartWidget: Showing error screen (mounted: $mounted)');
    if (!mounted) {
      debugPrint('⚠️ RestartWidget not mounted, cannot show error');
      return;
    }
    setState(() {
      _showError = true;
      _errorWidget = errorWidget;
    });
    // Force immediate rebuild
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    if (_showError && _errorWidget != null) {
      debugPrint('📱 RestartWidget: Rendering error screen');
      return _errorWidget!;
    }

    debugPrint('📱 RestartWidget: Rendering normal app (key: $_key)');
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
