import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/promo_service.dart';
import 'service_providers.dart';

class CheckoutState {
  final bool placing;
  final String? error;
  final Map<String, PickupSelection> slots;
  final bool promoRejected;
  final bool pricesChanged;

  const CheckoutState(
      {this.placing = false,
      this.error,
      this.slots = const {},
      this.promoRejected = false,
      this.pricesChanged = false});

  CheckoutState copyWith({
    bool? placing,
    String? error,
    bool clearError = false,
    Map<String, PickupSelection>? slots,
    bool? promoRejected,
    bool? pricesChanged,
  }) {
    return CheckoutState(
      placing: placing ?? this.placing,
      error: clearError ? null : (error ?? this.error),
      slots: slots ?? this.slots,
      promoRejected: promoRejected ?? this.promoRejected,
      pricesChanged: pricesChanged ?? this.pricesChanged,
    );
  }
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final OrderService _orderService;
  final CartService _cartService;

  CheckoutNotifier(this._orderService, this._cartService)
      : super(const CheckoutState());

  void selectSlot(String farmerId, PickupSelection? selection) {
    final updated = Map<String, PickupSelection>.from(state.slots);
    if (selection == null) {
      updated.remove(farmerId);
    } else {
      updated[farmerId] = selection;
    }
    state = state.copyWith(slots: updated);
  }

  Future<List<String>?> placeOrder({
    required String uid,
    required String customerName,
    required List<CartLine> lines,
    required String address,
    required bool emailVerified,
    String? promoCode,
  }) async {
    if (state.placing) return null;

    if (!emailVerified) {
      state = state.copyWith(
          error: 'Please verify your email before placing an order.');
      return null;
    }

    if (address.trim().isEmpty) {
      state = state.copyWith(
          error:
              'Add a delivery address in your profile before placing an order.');
      return null;
    }

    state = state.copyWith(
        placing: true,
        clearError: true,
        promoRejected: false,
        pricesChanged: false);

    try {
      final orderIds = await _orderService.placeOrder(
        customerId: uid,
        customerName: customerName,
        lines: lines,
        deliveryAddr: address,
        pickupSelections: state.slots,
        promoCode: promoCode,
      );
      return orderIds;
    } on InsufficientStockException catch (e) {
      try {
        await _cartService.updateQuantity(uid, e.productId, e.available);
      } catch (_) {}
      if (mounted) state = state.copyWith(error: e.toString());
      return null;
    } on PromoCodeException catch (e) {
      if (mounted) {
        state = state.copyWith(
            error: '${e.message} The code was removed.', promoRejected: true);
      }
      return null;
    } on PriceChangedException catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString(), pricesChanged: true);
      }
      return null;
    } on SlotFullDuringCheckoutException catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      return null;
    } on TooManyItemsException catch (e) {
      if (mounted) state = state.copyWith(error: e.toString());
      return null;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
            error: 'Your order could not be placed. Please try again.');
      }
      return null;
    } finally {
      if (mounted) state = state.copyWith(placing: false);
    }
  }
}

final checkoutProvider =
    StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>((ref) {
  return CheckoutNotifier(
      ref.watch(orderServiceProvider), ref.watch(cartServiceProvider));
});
