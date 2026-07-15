// lib/core/utils/debug_toast.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../utils/logger.dart';

class DebugToast {
  // Toggle this to silence toasts in production
  static const bool _enabled = true;

  static void show(String message, {bool isError = false}) {
    dLog(message); // Always log
    if (!_enabled) return;

    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: isError ? Colors.red.shade800 : Colors.black87,
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }
}