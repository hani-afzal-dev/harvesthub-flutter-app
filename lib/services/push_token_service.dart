import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';

class PushTokenService {
  static const Duration _saveTimeout = Duration(seconds: 5);
  static const Duration _clearTimeout = Duration(seconds: 2);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>>? get _currentUserDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection(FirestoreCollections.users).doc(uid);
  }

  Future<String?> _readSubscriptionId() async {
    final Object? raw = OneSignal.User.pushSubscription.id;
    final Object? resolved = raw is Future ? await raw : raw;
    if (resolved is String && resolved.isNotEmpty) return resolved;
    return null;
  }

  Future<void> saveCurrent([String? knownId]) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await OneSignal.login(uid);
      } catch (e, stack) {
        AppLogger.error('OneSignal login failed', e, stack);
      }
    }

    final doc = _currentUserDoc;
    if (doc == null) return;
    try {
      final id = knownId ?? await _readSubscriptionId();
      if (id == null) return;
      await doc.update({'fcmToken': id}).timeout(_saveTimeout);
    } catch (e, stack) {
      AppLogger.error('Push id save failed', e, stack);
    }
  }

  Future<void> clearCurrent() async {
    final doc = _currentUserDoc;
    if (doc == null) return;
    try {
      await doc.update({'fcmToken': null}).timeout(_clearTimeout);
    } catch (e, stack) {
      AppLogger.error('Push id clear failed', e, stack);
    }
  }

  void listenForChanges() {
    OneSignal.User.pushSubscription.addObserver((state) {
      final id = state.current.id;
      if (id == null || id.isEmpty) return;
      unawaited(saveCurrent(id));
    });
  }
}
