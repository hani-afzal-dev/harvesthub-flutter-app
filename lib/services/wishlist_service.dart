import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class WishlistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _wishlists =>
      _firestore.collection(FirestoreCollections.wishlists);

  String _itemId(String userId, String productId) => '${userId}_$productId';

  Stream<List<String>> watchWishlist(String userId) {
    return _wishlists
        .where('customerId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.toList();
      docs.sort((a, b) {
        final aTime =
            (a.data()['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime =
            (b.data()['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return docs.map((d) => (d.data()['productId'] ?? '').toString()).toList();
    });
  }

  Stream<bool> watchIsWishlisted(String userId, String productId) {
    return _wishlists
        .doc(_itemId(userId, productId))
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<void> add(String userId, String productId) async {
    await _wishlists.doc(_itemId(userId, productId)).set({
      'customerId': userId,
      'productId': productId,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String userId, String productId) async {
    await _wishlists.doc(_itemId(userId, productId)).delete();
  }

  Future<List<String>> getUsersWhoWishlisted(String productId) async {
    final snap =
        await _wishlists.where('productId', isEqualTo: productId).get();
    return snap.docs
        .map((d) => (d.data()['customerId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
