import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
// import 'package:lottie/lottie.dart';

import 'config.dart';
import 'restart_widget.dart';

/// Custom error screen widget
class ErrorScreen extends StatelessWidget {
  final FlutterErrorDetails? errorDetails;
  final ErrorScreenConfig config;
  final VoidCallback? onRestart;
  final VoidCallback? onClearOverlay;

  const ErrorScreen({
    super.key,
    this.errorDetails,
    required this.config,
    this.onRestart,
    this.onClearOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final isDebug = kDebugMode && config.showDetailsInDebug;
    final errorMessage = _buildErrorMessage(isDebug);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: config.backgroundColor,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 600;
              final padding = isSmallScreen ? 24.0 : 48.0;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAsset(),
                        SizedBox(height: isSmallScreen ? 24 : 32),
                        _buildTitle(),
                        SizedBox(height: isSmallScreen ? 16 : 24),
                        _buildMessage(errorMessage, isDebug),
                        SizedBox(height: isSmallScreen ? 32 : 48),
                        _buildRestartButton(context),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAsset() {
    if (config.assetPath == null || config.assetType == null) {
      return _buildDefaultIcon();
    }

    try {
      switch (config.assetType!) {
        case ErrorAssetType.image:
          return Image.asset(
            config.assetPath!,
            width: 120,
            height: 120,
            errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
          );
        case ErrorAssetType.svg:
          return SvgPicture.asset(
            config.assetPath!,
            width: 120,
            height: 120,
            placeholderBuilder: (context) => _buildDefaultIcon(),
          );
        case ErrorAssetType.lottie:
          return SizedBox.shrink();
        //   Lottie.asset(
        //   config.assetPath!,
        //   width: 120,
        //   height: 120,
        //   errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
        // );
      }
    } catch (e) {
      return _buildDefaultIcon();
    }
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: config.buttonColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.error_outline, size: 64, color: config.buttonColor),
    );
  }

  Widget _buildTitle() {
    return Text(
      config.title,
      style:
          config.titleStyle ??
          TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: config.textColor,
          ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildMessage(String message, bool isDebug) {
    return Column(
      children: [
        Text(
          message,
          style:
              config.messageStyle ??
              TextStyle(
                fontSize: 16,
                color: config.textColor.withOpacity(0.8),
                height: 1.5,
              ),
          textAlign: TextAlign.center,
        ),
        if (isDebug && errorDetails != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black.withOpacity(0.1)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                errorDetails!.exceptionAsString(),
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: config.textColor,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRestartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (onRestart != null) {
            onRestart!();
          } else {
            // Use RestartWidget's static method
            RestartWidget.restartApp();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: config.buttonColor,
          foregroundColor: config.buttonTextColor,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          config.buttonText,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _buildErrorMessage(bool isDebug) {
    if (!isDebug) {
      return config.fallbackMessage;
    }

    if (errorDetails != null) {
      return config.fallbackMessage;
    }

    return config.fallbackMessage;
  }
}
