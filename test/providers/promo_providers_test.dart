import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvesthub/models/promo_code_model.dart';
import 'package:harvesthub/providers/promo_providers.dart';

PromoCodeModel promo(String code) => PromoCodeModel(
      code: code,
      type: 'flat',
      value: 20,
      minOrder: 200,
      maxDiscount: 50,
      active: true,
      expiresAt: DateTime(2100),
      createdAt: DateTime(2026),
    );

void main() {
  group('availablePromoOffersProvider', () {
    test('drops a code the user has already redeemed', () async {
      final container = ProviderContainer(overrides: [
        activePromoCodesProvider.overrideWith(
            (ref) => Stream.value([promo('FRESH20'), promo('FARM100')])),
        redeemedPromoCodesProvider('user1')
            .overrideWith((ref) => Stream.value({'FRESH20'})),
      ]);
      addTearDown(container.dispose);

      container.listen(activePromoCodesProvider, (_, __) {});
      container.listen(redeemedPromoCodesProvider('user1'), (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final codes = container
          .read(availablePromoOffersProvider('user1'))
          .valueOrNull
          ?.map((c) => c.code);
      expect(codes, ['FARM100']);
    });

    test('keeps every code when nothing has been redeemed yet', () async {
      final container = ProviderContainer(overrides: [
        activePromoCodesProvider.overrideWith(
            (ref) => Stream.value([promo('FRESH20'), promo('FARM100')])),
        redeemedPromoCodesProvider('user1')
            .overrideWith((ref) => Stream.value(<String>{})),
      ]);
      addTearDown(container.dispose);

      container.listen(activePromoCodesProvider, (_, __) {});
      container.listen(redeemedPromoCodesProvider('user1'), (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final codes = container
          .read(availablePromoOffersProvider('user1'))
          .valueOrNull
          ?.map((c) => c.code);
      expect(codes, ['FRESH20', 'FARM100']);
    });

    test('one user redeeming a code never hides it for another user', () async {
      final container = ProviderContainer(overrides: [
        activePromoCodesProvider
            .overrideWith((ref) => Stream.value([promo('FRESH20')])),
        redeemedPromoCodesProvider('user1')
            .overrideWith((ref) => Stream.value({'FRESH20'})),
        redeemedPromoCodesProvider('user2')
            .overrideWith((ref) => Stream.value(<String>{})),
      ]);
      addTearDown(container.dispose);

      container.listen(activePromoCodesProvider, (_, __) {});
      container.listen(redeemedPromoCodesProvider('user1'), (_, __) {});
      container.listen(redeemedPromoCodesProvider('user2'), (_, __) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
          container
              .read(availablePromoOffersProvider('user1'))
              .valueOrNull
              ?.map((c) => c.code),
          <String>[]);
      expect(
          container
              .read(availablePromoOffersProvider('user2'))
              .valueOrNull
              ?.map((c) => c.code),
          ['FRESH20']);
    });
  });
}
