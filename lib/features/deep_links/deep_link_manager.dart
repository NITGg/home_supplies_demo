import 'dart:developer';
import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

class DeepLinkManager {
  DeepLinkManager._internal();
  static final DeepLinkManager instance = DeepLinkManager._internal();

  late final AppLinks _appLinks;
  bool initialized = false;

  /// Call this once in main() or inside your root widget initState()
  Future<void> init({
    required Function(Uri uri) onLink,
    required Function(Uri uri) onInitialLink,
  }) async {
    if (initialized) return;
    initialized = true;

    _appLinks = AppLinks();

    // Handle initial deep link (app killed)
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onInitialLink(initialUri);
        });
      }
    } catch (e) {
      log("DeepLinkManager: Failed to read initial link: $e");
    }

    // Handle deep links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      onLink(uri);
    });
  }
}
