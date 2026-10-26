import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/promo_code_model.dart';
import 'service_providers.dart';

final appliedPromoProvider =
    StateProvider.family<PromoCodeModel?, String>((ref, uid) => null);

final activePromoCodesProvider =
    StreamProvider.autoDispose<List<PromoCodeModel>>((ref) {
  return ref.watch(promoServiceProvider).watchActiveCodes();
});

final redeemedPromoCodesProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, uid) {
  return ref.watch(promoServiceProvider).watchRedeemedCodes(uid);
});

final availablePromoOffersProvider =
    Provider.autoDispose.family<AsyncValue<List<PromoCodeModel>>, String>(
        (ref, uid) {
  final active = ref.watch(activePromoCodesProvider);
  final redeemed = ref.watch(redeemedPromoCodesProvider(uid));
  return active.whenData((codes) {
    final used = redeemed.valueOrNull ?? const <String>{};
    return codes.where((c) => !used.contains(c.code)).toList();
  });
});

final adminPromoLimitProvider = StateProvider.autoDispose<int>((ref) => 20);

final adminPromoCodesProvider =
    StreamProvider.autoDispose<List<PromoCodeModel>>((ref) {
  final limit = ref.watch(adminPromoLimitProvider);
  return ref.watch(promoServiceProvider).watchAllCodes(limit: limit);
});
