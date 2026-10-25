import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/background_task.dart';
import '../core/constants.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import '../models/pickup_slot_model.dart';
import 'notification_service.dart';

class PickupSlotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection(FirestoreCollections.pickupSlots);

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirestoreCollections.orders);

  Future<String> createSlot({
    required String farmerId,
    required DateTime slotTime,
    required int capacity,
  }) async {
    final slot = PickupSlotModel(
      slotId: '',
      farmerId: farmerId,
      slotTime: slotTime,
      capacity: capacity,
      booked: 0,
      isActive: true,
    );
    final ref = await _slots.add(slot.toMap());
    return ref.id;
  }

  Stream<List<PickupSlotModel>> watchFarmerSlots(String farmerId) {
    return _slots
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('slotTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PickupSlotModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<PickupSlotModel>> watchAvailableSlots(String farmerId) {
    final now = Timestamp.now();
    return _slots
        .where('farmerId', isEqualTo: farmerId)
        .where('isActive', isEqualTo: true)
        .where('slotTime', isGreaterThan: now)
        .orderBy('slotTime')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PickupSlotModel.fromMap(d.id, d.data()))
            .where((slot) => !slot.isFull)
            .toList());
  }

  Future<void> setActive(String slotId, bool isActive) async {
    await _slots.doc(slotId).update({'isActive': isActive});
  }

  Future<List<OrderModel>> getOpenBookings(
      String slotId, String farmerId) async {
    final snap = await _orders
        .where('farmerId', isEqualTo: farmerId)
        .where('pickupSlotId', isEqualTo: slotId)
        .get();
    return snap.docs
        .map((d) => OrderModel.fromMap(d.id, d.data()))
        .where((order) =>
            order.status != OrderStatus.completed &&
            order.status != OrderStatus.cancelled)
        .toList();
  }

  Future<int> cancelSlot(
      {required String slotId, required String farmerId}) async {
    final bookings = await getOpenBookings(slotId, farmerId);
    final drafts = bookings
        .map((order) => NotificationDraft(
              userId: order.customerId,
              type: NotificationType.slotCancelled,
              message:
                  'The farmer cancelled your pickup slot. Please choose a new one.',
              relatedId: order.orderId,
            ))
        .toList();
    await _slots.doc(slotId).delete();
    runInBackground('Slot cancellation alerts failed',
        () => _notificationService.sendDrafts(drafts));
    return bookings.length;
  }
}
