import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static final RegExp _emailPattern =
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
  static final RegExp _tokenPattern = RegExp(r'[A-Za-z0-9_\-]{20,}');

  static String scrub(String text) {
    return text
        .replaceAll(_emailPattern, '[email]')
        .replaceAll(_tokenPattern, '[id]');
  }

  static void info(String message) {
    if (!kDebugMode) return;
    debugPrint(scrub(message));
  }

  static void error(String context, Object error, StackTrace? stack,
      {bool fatal = false}) {
    final message = scrub('$context: $error');
    if (kDebugMode) {
      debugPrint(message);
      if (stack != null) {
        debugPrint(scrub(stack.toString()));
      }
      return;
    }
    if (Firebase.apps.isEmpty) return;
    // Crashlytics removed — errors are only logged locally in debug mode for now.
  }
}