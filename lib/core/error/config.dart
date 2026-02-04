import 'package:flutter/material.dart';

/// Asset type for error screen visual
enum ErrorAssetType { image, svg, lottie }

/// Configuration for custom error screen
class ErrorScreenConfig {
  final String title;
  final String fallbackMessage;
  final String buttonText;
  final String? assetPath;
  final ErrorAssetType? assetType;
  final Color backgroundColor;
  final Color textColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final bool showDetailsInDebug;

  const ErrorScreenConfig({
    this.title = 'Something went wrong',
    this.fallbackMessage =
        'We encountered an unexpected error. Please restart the app to continue.',
    this.buttonText = 'Restart App',
    this.assetPath,
    this.assetType,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.textColor = const Color(0xFF333333),
    this.buttonColor = Colors.orange,
    this.buttonTextColor = Colors.black,
    this.titleStyle,
    this.messageStyle,
    this.showDetailsInDebug = true,
  });

  ErrorScreenConfig copyWith({
    String? title,
    String? fallbackMessage,
    String? buttonText,
    String? assetPath,
    ErrorAssetType? assetType,
    Color? backgroundColor,
    Color? textColor,
    Color? buttonColor,
    Color? buttonTextColor,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    bool? showDetailsInDebug,
  }) {
    return ErrorScreenConfig(
      title: title ?? this.title,
      fallbackMessage: fallbackMessage ?? this.fallbackMessage,
      buttonText: buttonText ?? this.buttonText,
      assetPath: assetPath ?? this.assetPath,
      assetType: assetType ?? this.assetType,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      buttonColor: buttonColor ?? this.buttonColor,
      buttonTextColor: buttonTextColor ?? this.buttonTextColor,
      titleStyle: titleStyle ?? this.titleStyle,
      messageStyle: messageStyle ?? this.messageStyle,
      showDetailsInDebug: showDetailsInDebug ?? this.showDetailsInDebug,
    );
  }
}
