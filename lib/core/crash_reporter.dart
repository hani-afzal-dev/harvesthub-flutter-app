import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'app_logger.dart';

class CrashReporter {
  static Future<void> init() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.error('Flutter error', details.exception, details.stack,
          fatal: true);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('Uncaught error', error, stack, fatal: true);
      return true;
    };

    const enabled = !kDebugMode;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    } catch (e, stack) {
      AppLogger.error('Analytics setup failed', e, stack);
    }
  }
}