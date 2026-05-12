import 'dart:developer';

import 'package:flutter/foundation.dart';

void dLog(String message) {
  if (kDebugMode) log(message);
}
