import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pickup_slot_model.dart';
import 'service_providers.dart';

final availableSlotsProvider = StreamProvider.autoDispose
    .family<List<PickupSlotModel>, String>((ref, farmerId) {
  return ref.watch(pickupSlotServiceProvider).watchAvailableSlots(farmerId);
});

final farmerSlotsProvider = StreamProvider.autoDispose
    .family<List<PickupSlotModel>, String>((ref, farmerId) {
  return ref.watch(pickupSlotServiceProvider).watchFarmerSlots(farmerId);
});
