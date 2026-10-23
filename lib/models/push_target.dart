import 'notification_model.dart';

class PushTarget {
  final String userId;
  final NotificationType type;
  final String? relatedId;

  const PushTarget({required this.userId, required this.type, this.relatedId});

  static PushTarget? fromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final userId = data['userId'];
    final type = data['type'];
    final relatedId = data['relatedId'];
    if (userId is! String || userId.isEmpty || type is! String) return null;
    return PushTarget(
      userId: userId,
      type: notificationTypeFromString(type),
      relatedId: relatedId is String && relatedId.isNotEmpty ? relatedId : null,
    );
  }

  Map<String, String> toData() {
    final data = {
      'userId': userId,
      'type': notificationTypeToString(type),
    };
    final id = relatedId;
    if (id != null) {
      data['relatedId'] = id;
    }
    return data;
  }
}
