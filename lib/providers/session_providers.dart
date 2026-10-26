import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_logger.dart';
import '../models/farmer_model.dart';
import '../models/user_model.dart';
import 'service_providers.dart';

final firebaseUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(firebaseUserProvider).when(
        data: (user) => user?.uid,
        loading: () => ref.read(authServiceProvider).currentUser?.uid,
        error: (_, __) => null,
      );
});

final sessionProfileProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(authServiceProvider)
      .watchUserProfile(uid)
      .handleError((Object e, StackTrace stack) {
    AppLogger.error('Profile stream failed', e, stack);
    throw e;
  });
});

final currentFarmerProvider =
    FutureProvider.autoDispose<FarmerModel?>((ref) async {
  final user = await ref.watch(firebaseUserProvider.future);
  if (user == null) return null;
  return ref.watch(farmerServiceProvider).getByUserId(user.uid);
});
