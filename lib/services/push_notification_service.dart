import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../core/app_logger.dart';
import '../models/notification_model.dart';

class NotificationDraftInfo {
  final String userId;
  final NotificationType type;
  final String message;
  final String? relatedId;

  NotificationDraftInfo({
    required this.userId,
    required this.type,
    required this.message,
    this.relatedId,
  });
}

class PushNotificationService {
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxIdsPerRequest = 50;

  String get _relayUrl => dotenv.env['PUSH_RELAY_URL'] ?? '';
  String get _appId => dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  String get _restApiKey => dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  Future<void> sendForNotifications(
    List<String> notificationIds, {
    List<NotificationDraftInfo>? drafts,
  }) async {
    var relaySuccess = false;
    final user = FirebaseAuth.instance.currentUser;

    if (_relayUrl.isNotEmpty && notificationIds.isNotEmpty && user != null) {
      try {
        final token = await user.getIdToken();
        for (var i = 0; i < notificationIds.length; i += _maxIdsPerRequest) {
          final end = i + _maxIdsPerRequest > notificationIds.length
              ? notificationIds.length
              : i + _maxIdsPerRequest;
          final response = await http
              .post(
                Uri.parse('$_relayUrl/notify'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: jsonEncode(
                    {'notificationIds': notificationIds.sublist(i, end)}),
              )
              .timeout(_requestTimeout);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            relaySuccess = true;
          }
        }
      } catch (e, stack) {
        AppLogger.error('Push relay failed', e, stack);
      }
    }

    // Direct OneSignal fallback or send if relay did not succeed
    if (!relaySuccess &&
        drafts != null &&
        drafts.isNotEmpty &&
        _appId.isNotEmpty &&
        _restApiKey.isNotEmpty) {
      for (final draft in drafts) {
        await _sendDirectOneSignal(draft);
      }
    }
  }

  Future<void> _sendDirectOneSignal(NotificationDraftInfo draft) async {
    try {
      final heading = notificationHeading(draft.type);
      final data = {
        'userId': draft.userId,
        'type': notificationTypeToString(draft.type),
      };
      if (draft.relatedId != null) {
        data['relatedId'] = draft.relatedId!;
      }

      await http
          .post(
            Uri.parse('https://api.onesignal.com/notifications'),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Key $_restApiKey',
            },
            body: jsonEncode({
              'app_id': _appId,
              'include_aliases': {
                'external_id': [draft.userId]
              },
              'target_channel': 'push',
              'headings': {'en': heading},
              'contents': {'en': draft.message},
              'priority': 10,
              'android_accent_color': 'FF3B6D11',
              'android_visibility': 1,
              'data': data,
            }),
          )
          .timeout(_requestTimeout);
    } catch (e, stack) {
      AppLogger.error('Direct OneSignal send failed', e, stack);
    }
  }
}
