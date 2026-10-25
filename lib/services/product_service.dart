import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/background_task.dart';
import '../core/constants.dart';
import '../core/product_search.dart';
import '../core/retry.dart';
import '../models/notification_model.dart';
import '../models/product_model.dart';
import 'follow_service.dart';
import 'notification_service.dart';
import 'product_cache_service.dart';
import 'wishlist_service.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();
  final WishlistService _wishlistService = WishlistService();
  final NotificationService _notificationService = NotificationService();
  final ProductCacheService _cacheService = ProductCacheService();

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection(FirestoreCollections.products);

  List<ProductModel> _toProducts(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList();
  }

  Stream<List<ProductModel>> watchAllProducts(
      {int limit = PagingRules.pageSize, bool availableOnly = true}) {
    Query<Map<String, dynamic>> query = _products;
    if (availableOnly) {
      query = query.where('isAvailable', isEqualTo: true);
    }
    return query.orderBy('itemName').limit(limit).snapshots().map((snap) {
      final products = _toProducts(snap);
      if (availableOnly) {
        _cacheService.cacheProducts(products);
      }
      return products;
    });
  }

  Future<List<ProductModel>> getCachedProductsFallback() {
    return _cacheService.getCachedProducts();
  }

  Stream<List<ProductModel>> watchByCategory(String categoryId,
      {int limit = PagingRules.pageSize}) {
    return _products
        .where('categoryId', isEqualTo: categoryId)
        .where('isAvailable', isEqualTo: true)
        .orderBy('itemName')
        .limit(limit)
        .snapshots()
        .map(_toProducts);
  }

  static const int _searchPoolSize = 300;
  static const Duration _searchPoolTtl = Duration(minutes: 2);
  static List<ProductModel>? _searchPool;
  static DateTime? _searchPoolAt;

  Future<List<ProductModel>> _loadSearchPool() async {
    final cached = _searchPool;
    final cachedAt = _searchPoolAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _searchPoolTtl) {
      return cached;
    }
    final poolQuery = _products
        .where('isAvailable', isEqualTo: true)
        .orderBy('itemNameLower')
        .limit(_searchPoolSize);
    final snap = await retryWithBackoff(() => poolQuery.get());
    final products = _toProducts(snap);
    _searchPool = products;
    _searchPoolAt = DateTime.now();
    return products;
  }

  Future<List<ProductModel>> searchByName(String query,
      {int limit = PagingRules.pageSize}) async {
    if (query.trim().isEmpty) return [];
    final pool = await _loadSearchPool();
    return matchProductsByName(pool, query, limit);
  }

  Future<ProductModel?> getById(String productId) async {
    try {
      final doc = await _products.doc(productId).get();
      if (!doc.exists) return null;
      return ProductModel.fromMap(doc.id, doc.data()!);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  Stream<List<ProductModel>> watchByFarmer(String farmerId) {
    return _products
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('itemName')
        .snapshots()
        .map(_toProducts);
  }

  Stream<List<ProductModel>> watchAvailableByFarmer(String farmerId,
      {int limit = 20}) {
    return _products
        .where('farmerId', isEqualTo: farmerId)
        .where('isAvailable', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final products = _toProducts(snap);
      products.sort((a, b) =>
          a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
      return products;
    });
  }

  Future<String> createProduct(ProductModel product) async {
    final ref = await _products.add(product.toCreateMap());
    return ref.id;
  }

  Future<void> updateProduct(ProductModel product) async {
    final previous = await _products.doc(product.productId).get();
    final previousStock = ((previous.data()?['stockQty'] ?? 0) as num).toInt();
    await _products.doc(product.productId).update(product.toUpdateMap());
    runInBackground(
        'Restock alert failed',
        () => _notifyRestock(
              productId: product.productId,
              itemName: product.itemName,
              farmerId: product.farmerId,
              previousStock: previousStock,
              newStock: product.stockQty,
            ));
  }

  Future<void> deleteProduct(String productId) async {
    await _products.doc(productId).delete();
  }

  Future<void> setAvailability(String productId, bool isAvailable) async {
    await _products.doc(productId).update({
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setStock(String productId, int stockQty) async {
    final doc = await _products.doc(productId).get();
    final previousStock = ((doc.data()?['stockQty'] ?? 0) as num).toInt();
    final itemName = (doc.data()?['itemName'] ?? 'An item').toString();
    final farmerId = (doc.data()?['farmerId'] ?? '').toString();
    await _products.doc(productId).update({
      'stockQty': stockQty,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    runInBackground(
        'Restock alert failed',
        () => _notifyRestock(
              productId: productId,
              itemName: itemName,
              farmerId: farmerId,
              previousStock: previousStock,
              newStock: stockQty,
            ));
  }

  Future<void> _notifyRestock({
    required String productId,
    required String itemName,
    required String farmerId,
    required int previousStock,
    required int newStock,
  }) async {
    if (previousStock != 0 || newStock <= 0) return;
    try {
      final wishlistUserIds =
          await _wishlistService.getUsersWhoWishlisted(productId);
      final followerIds = farmerId.isNotEmpty
          ? await _followService.getFollowerUserIds(farmerId)
          : <String>[];
      final interestedUserIds = {...wishlistUserIds, ...followerIds}.toList();
      await _notificationService.sendToMany(
        userIds: interestedUserIds,
        type: NotificationType.restockAlert,
        message: '$itemName is back in stock.',
        relatedId: productId,
      );
    } on FirebaseException {
      return;
    }
  }
}
