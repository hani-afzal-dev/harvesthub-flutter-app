import 'dart:async';

import 'app_logger.dart';

void runInBackground(String label, Future<void> Function() task) {
  unawaited(Future<void>(() async {
    try {
      await task();
    } catch (e, stack) {
      AppLogger.error(label, e, stack);
    }
  }));
}
