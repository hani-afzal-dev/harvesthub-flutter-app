import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';
import 'product_service.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductService _productService = ProductService();

  CollectionReference<Map<String, dynamic>> get _cartItems =>
      _firestore.collection(FirestoreCollections.cartItems);

  String _itemId(String userId, String productId) => '${userId}_$productId';

  Stream<List<CartLine>> watchCartLines(String userId) {
    var knownProducts = <String, ProductModel?>{};
    DateTime? fetchedAt;
    return _cartItems
        .where('customerId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snap) async {
      final items =
          snap.docs.map((d) => CartItem.fromMap(d.id, d.data())).toList();
      items.sort((a, b) => a.addedAt.compareTo(b.addedAt));

      final sameProducts = items.length == knownProducts.length &&
          items.every((item) => knownProducts.containsKey(item.productId));
      final lastFetch = fetchedAt;
      final stale = lastFetch == null ||
          DateTime.now().difference(lastFetch) > const Duration(seconds: 60);
      if (!sameProducts || stale) {
        final fetched = await Future.wait(
            items.map((item) => _productService.getById(item.productId)));
        final fresh = <String, ProductModel?>{};
        for (var i = 0; i < items.length; i++) {
          fresh[items[i].productId] = fetched[i];
        }
        knownProducts = fresh;
        fetchedAt = DateTime.now();
      }

      final lines = <CartLine>[];
      for (final item in items) {
        lines.add(CartLine(item: item, product: knownProducts[item.productId]));
      }
      return lines;
    });
  }

  Future<void> addOrIncrement({
    required String userId,
    required String productId,
    int quantity = 1,
  }) async {
    final ref = _cartItems.doc(_itemId(userId, productId));

    var existsLocally = false;
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      existsLocally = cached.exists;
    } on FirebaseException {
      existsLocally = false;
    }

    try {
      if (existsLocally) {
        await ref.update({'quantity': FieldValue.increment(quantity)});
      } else {
        await ref.set({
          'customerId': userId,
          'productId': productId,
          'quantity': quantity,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
    }

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final current = ((snap.data()?['quantity'] ?? 0) as num).toInt();
        tx.update(ref, {'quantity': current + quantity});
      } else {
        tx.set(ref, {
          'customerId': userId,
          'productId': productId,
          'quantity': quantity,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> updateQuantity(
      String userId, String productId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(userId, productId);
      return;
    }
    await _cartItems
        .doc(_itemId(userId, productId))
        .update({'quantity': quantity});
  }

  Future<void> removeItem(String userId, String productId) async {
    await _cartItems.doc(_itemId(userId, productId)).delete();
  }

  Future<void> clearCart(String userId) async {
    final snap = await _cartItems.where('customerId', isEqualTo: userId).get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
