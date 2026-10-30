import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_model.dart';
import '../models/smart_basket.dart';
import '../services/cart_service.dart';
import '../services/smart_basket_service.dart';
import 'service_providers.dart';

enum SmartBasketStatus {
  idle,
  processing,
  ready,
  failed,
}

class SmartBasketState {
  final SmartBasketStatus status;
  final SmartBasketResult? result;
  final String? errorMessage;
  final bool isAddingToCart;
  final bool addedToCart;

  const SmartBasketState({
    this.status = SmartBasketStatus.idle,
    this.result,
    this.errorMessage,
    this.isAddingToCart = false,
    this.addedToCart = false,
  });

  bool get isProcessing => status == SmartBasketStatus.processing;

  SmartBasketState copyWith({
    SmartBasketStatus? status,
    SmartBasketResult? result,
    String? errorMessage,
    bool? isAddingToCart,
    bool? addedToCart,
  }) {
    return SmartBasketState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      isAddingToCart: isAddingToCart ?? this.isAddingToCart,
      addedToCart: addedToCart ?? this.addedToCart,
    );
  }
}

class SmartBasketNotifier extends StateNotifier<SmartBasketState> {
  final SmartBasketService _service;
  final CartService _cartService;

  SmartBasketNotifier(this._service, this._cartService)
      : super(const SmartBasketState());

  Future<void> buildBasket(
    String query, {
    required List<ProductModel> catalogProducts,
    Map<String, String> farmerNames = const {},
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || state.isProcessing) return;

    state = state.copyWith(
      status: SmartBasketStatus.processing,
      errorMessage: null,
      addedToCart: false,
    );

    final aiReq = await _service.parseWithGemini(trimmed);
    if (aiReq != null && aiReq.items.isNotEmpty) {
      final res = _service.buildBasket(
        request: aiReq,
        availableProducts: catalogProducts,
        farmerNames: farmerNames,
        isFallback: false,
      );
      state = state.copyWith(
        status: SmartBasketStatus.ready,
        result: res,
        errorMessage: null,
      );
      return;
    }

    final fallbackReq = _service.parseWithFallback(trimmed);
    if (fallbackReq != null && fallbackReq.items.isNotEmpty) {
      final res = _service.buildBasket(
        request: fallbackReq,
        availableProducts: catalogProducts,
        farmerNames: farmerNames,
        isFallback: true,
        message: 'AI is not available, using simple search.',
      );
      state = state.copyWith(
        status: SmartBasketStatus.ready,
        result: res,
        errorMessage: null,
      );
      return;
    }

    final lower = trimmed.toLowerCase();
    final isHouseholdOnly = (lower.contains('log') || lower.contains('person') || lower.contains('family')) &&
        (lower.contains('hafta') || lower.contains('week') || lower.contains('mahina') || lower.contains('month'));

    state = state.copyWith(
      status: SmartBasketStatus.failed,
      errorMessage: isHouseholdOnly
          ? "Please type items like '2 kg tomato, 1 dozen banana'."
          : "Could not find items in your request. Please try typing like '2 kg tomato, 1 dozen banana'.",
    );
  }

  void updateLineQuantity(int index, int newQty) {
    final currentRes = state.result;
    if (currentRes == null || index < 0 || index >= currentRes.lines.length) {
      return;
    }

    final line = currentRes.lines[index];
    final maxStock = line.product.stockQty;
    var clamped = newQty;
    if (clamped < 1) clamped = 1;
    if (clamped > maxStock) clamped = maxStock;

    line.quantity = clamped;
    state = state.copyWith(
      result: SmartBasketResult(
        lines: List.from(currentRes.lines),
        notFoundItems: currentRes.notFoundItems,
        budget: currentRes.budget,
        budgetAdjustments: currentRes.budgetAdjustments,
        isFallback: currentRes.isFallback,
        message: currentRes.message,
      ),
    );
  }

  void removeLine(int index) {
    final currentRes = state.result;
    if (currentRes == null || index < 0 || index >= currentRes.lines.length) {
      return;
    }

    final updatedLines = List<SmartBasketLine>.from(currentRes.lines)..removeAt(index);
    state = state.copyWith(
      result: SmartBasketResult(
        lines: updatedLines,
        notFoundItems: currentRes.notFoundItems,
        budget: currentRes.budget,
        budgetAdjustments: currentRes.budgetAdjustments,
        isFallback: currentRes.isFallback,
        message: currentRes.message,
      ),
    );
  }

  Future<bool> addAllToCart(String uid) async {
    final currentRes = state.result;
    if (currentRes == null || currentRes.lines.isEmpty || state.isAddingToCart) {
      return false;
    }

    state = state.copyWith(isAddingToCart: true);
    try {
      for (final line in currentRes.lines) {
        await _cartService.addOrIncrement(
          userId: uid,
          productId: line.product.productId,
          quantity: line.quantity,
        );
      }
      state = state.copyWith(
        isAddingToCart: false,
        addedToCart: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isAddingToCart: false,
        errorMessage: 'Could not add items to cart. Please try again.',
      );
      return false;
    }
  }

  void cancel() {
    state = state.copyWith(
      status: state.result != null ? SmartBasketStatus.ready : SmartBasketStatus.idle,
      errorMessage: null,
    );
  }

  void reset() {
    state = const SmartBasketState();
  }
}

final smartBasketServiceProvider = Provider<SmartBasketService>((ref) {
  return SmartBasketService();
});

final smartBasketProvider =
    StateNotifierProvider.autoDispose<SmartBasketNotifier, SmartBasketState>(
        (ref) {
  return SmartBasketNotifier(
    ref.watch(smartBasketServiceProvider),
    ref.watch(cartServiceProvider),
  );
});
