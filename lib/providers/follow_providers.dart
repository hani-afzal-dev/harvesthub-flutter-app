import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/farmer_model.dart';
import 'service_providers.dart';

final followedFarmerIdsProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, uid) {
  return ref.watch(followServiceProvider).watchFollowedFarmerIds(uid);
});

final followedFarmersProvider = FutureProvider.autoDispose
    .family<List<FarmerModel>, String>((ref, uid) async {
  await ref.watch(followedFarmerIdsProvider(uid).future);
  return ref.watch(followServiceProvider).getFollowedFarmers(uid);
});
