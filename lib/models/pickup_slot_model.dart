import 'package:cloud_firestore/cloud_firestore.dart';

class PickupSlotModel {
  final String slotId;
  final String farmerId;
  final DateTime slotTime;
  final int capacity;
  final int booked;
  final bool isActive;

  PickupSlotModel({
    required this.slotId,
    required this.farmerId,
    required this.slotTime,
    required this.capacity,
    required this.booked,
    required this.isActive,
  });

  bool get isFull => booked >= capacity;
  int get remaining => capacity - booked;

  factory PickupSlotModel.fromMap(String id, Map<String, dynamic> map) {
    return PickupSlotModel(
      slotId: id,
      farmerId: map['farmerId'] ?? '',
      slotTime: (map['slotTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      capacity: ((map['capacity'] ?? 0) as num).toInt(),
      booked: ((map['booked'] ?? 0) as num).toInt(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'farmerId': farmerId,
      'slotTime': Timestamp.fromDate(slotTime),
      'capacity': capacity,
      'booked': booked,
      'isActive': isActive,
    };
  }
}
