import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../core/app_logger.dart';

Future<bool> askForPushPermission() async {
  if ((dotenv.env['ONESIGNAL_APP_ID'] ?? '').isEmpty) return false;
  try {
    final hasPermission = OneSignal.Notifications.permission;
    if (hasPermission) return true;
    final granted = await OneSignal.Notifications.requestPermission(true);
    AppLogger.info('Push notification permission granted: $granted');
    return granted;
  } catch (e, stack) {
    AppLogger.error('Push permission request failed', e, stack);
    return false;
  }
}
