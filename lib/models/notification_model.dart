import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

enum NotificationType {
  restockAlert,
  orderStatus,
  newOrder,
  slotCancelled,
  bookingModified
}

NotificationType notificationTypeFromString(String value) {
  switch (value) {
    case NotificationTypes.restockAlert:
      return NotificationType.restockAlert;
    case NotificationTypes.newOrder:
      return NotificationType.newOrder;
    case NotificationTypes.slotCancelled:
      return NotificationType.slotCancelled;
    case NotificationTypes.bookingModified:
      return NotificationType.bookingModified;
    default:
      return NotificationType.orderStatus;
  }
}

String notificationTypeToString(NotificationType type) {
  switch (type) {
    case NotificationType.restockAlert:
      return NotificationTypes.restockAlert;
    case NotificationType.newOrder:
      return NotificationTypes.newOrder;
    case NotificationType.slotCancelled:
      return NotificationTypes.slotCancelled;
    case NotificationType.bookingModified:
      return NotificationTypes.bookingModified;
    case NotificationType.orderStatus:
      return NotificationTypes.orderStatus;
  }
}

String notificationHeading(NotificationType type, {bool romanUrdu = false}) {
  if (romanUrdu) {
    switch (type) {
      case NotificationType.restockAlert:
        return 'Stock Wapas Aa Gaya';
      case NotificationType.newOrder:
        return 'Naya Order Mil Gaya';
      case NotificationType.slotCancelled:
        return 'Pickup Slot Cancel Hua';
      case NotificationType.bookingModified:
        return 'Pickup Booking Tabdeel Hui';
      case NotificationType.orderStatus:
        return 'Order Update';
    }
  }
  switch (type) {
    case NotificationType.restockAlert:
      return 'Back in stock';
    case NotificationType.newOrder:
      return 'New order received';
    case NotificationType.slotCancelled:
      return 'Pickup slot cancelled';
    case NotificationType.bookingModified:
      return 'Pickup booking changed';
    case NotificationType.orderStatus:
      return 'Order update';
  }
}

class NotificationModel {
  final String notifId;
  final String userId;
  final NotificationType type;
  final String message;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notifId,
    required this.userId,
    required this.type,
    required this.message,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      notifId: id,
      userId: map['userId'] ?? '',
      type: notificationTypeFromString(
          map['type'] ?? NotificationTypes.orderStatus),
      message: map['message'] ?? '',
      relatedId: map['relatedId'] as String?,
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': notificationTypeToString(type),
      'message': message,
      'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
