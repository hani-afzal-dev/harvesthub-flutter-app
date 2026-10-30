import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import 'push_notification_service.dart';

class NotificationDraft {
  final String userId;
  final NotificationType type;
  final String message;
  final String? relatedId;

  NotificationDraft({
    required this.userId,
    required this.type,
    required this.message,
    this.relatedId,
  });
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PushNotificationService _push = PushNotificationService();

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestoreCollections.notifications);

  Map<String, dynamic> _payload(NotificationDraft draft) {
    return NotificationModel(
      notifId: '',
      userId: draft.userId,
      type: draft.type,
      message: draft.message,
      relatedId: draft.relatedId,
      isRead: false,
      createdAt: DateTime.now(),
    ).toMap();
  }

  Future<bool> send({
    required String userId,
    required NotificationType type,
    required String message,
    String? relatedId,
    String? docId,
  }) async {
    final draft = NotificationDraft(
        userId: userId, type: type, message: message, relatedId: relatedId);
    try {
      final ref =
          docId != null ? _notifications.doc(docId) : _notifications.doc();
      await ref.set(_payload(draft));
      await _push.sendForNotifications([ref.id], drafts: [NotificationDraftInfo(userId: draft.userId, type: draft.type, message: draft.message, relatedId: draft.relatedId)]);
      return true;
    } on FirebaseException {
      return false;
    }
  }

  Future<bool> sendDrafts(List<NotificationDraft> drafts) async {
    if (drafts.isEmpty) return true;
    var allSent = true;
    const chunkSize = PagingRules.notificationBatchSize;
    for (var i = 0; i < drafts.length; i += chunkSize) {
      final end = i + chunkSize > drafts.length ? drafts.length : i + chunkSize;
      final batch = _firestore.batch();
      final ids = <String>[];
      for (final draft in drafts.sublist(i, end)) {
        final ref = _notifications.doc();
        ids.add(ref.id);
        batch.set(ref, _payload(draft));
      }
      try {
        await batch.commit();
        await _push.sendForNotifications(ids, drafts: drafts.sublist(i, end).map((d) => NotificationDraftInfo(userId: d.userId, type: d.type, message: d.message, relatedId: d.relatedId)).toList());
      } on FirebaseException {
        allSent = false;
      }
    }
    return allSent;
  }

  Future<bool> sendToMany({
    required List<String> userIds,
    required NotificationType type,
    required String message,
    String? relatedId,
  }) {
    final drafts = userIds
        .map((userId) => NotificationDraft(
            userId: userId, type: type, message: message, relatedId: relatedId))
        .toList();
    return sendDrafts(drafts);
  }

  Stream<List<NotificationModel>> watchForUser(String userId,
      {int limit = PagingRules.pageSize}) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<int> watchUnreadCount(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String notifId) async {
    await _notifications.doc(notifId).update({'isRead': true});
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
