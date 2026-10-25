import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import '../core/firebase_secondary.dart';
import '../models/farmer_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class AdminDashboardStats {
  final int totalOrders;
  final double totalRevenue;
  final Map<String, double> revenueByMarket;
  final List<MapEntry<String, int>> topFarmers;

  AdminDashboardStats({
    required this.totalOrders,
    required this.totalRevenue,
    required this.revenueByMarket,
    required this.topFarmers,
  });
}

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);
  CollectionReference<Map<String, dynamic>> get _farmers =>
      _firestore.collection(FirestoreCollections.farmers);
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirestoreCollections.orders);
  CollectionReference<Map<String, dynamic>> get _markets =>
      _firestore.collection(FirestoreCollections.farmersMarkets);

  Stream<List<UserModel>> watchUsersByRole(UserRole role) {
    return _users
        .where('role', isEqualTo: userRoleToString(role))
        .orderBy('name')
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> setUserActive(String userId, bool isActive) async {
    await _users.doc(userId).update({'isActive': isActive});
  }

  Future<void> updateCustomer(
    String userId, {
    required String name,
    required String phone,
    required String address,
  }) async {
    await _users.doc(userId).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
    });
  }

  Future<int> getActiveOrderCount(String farmerId) async {
    final snap = await _orders.where('farmerId', isEqualTo: farmerId).get();
    var count = 0;
    for (final doc in snap.docs) {
      final status = orderStatusFromString(
          doc.data()['status'] ?? OrderStatusValues.pending);
      if (status != OrderStatus.completed && status != OrderStatus.cancelled) {
        count++;
      }
    }
    return count;
  }

  Future<void> createFarmer({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String businessName,
    required String description,
    String? marketId,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final helperAuth = await SecondaryAuth.instance();
    final credential = await helperAuth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final newUser = credential.user;
    if (newUser == null) {
      throw FirebaseAuthException(
          code: 'unknown', message: 'Farmer account could not be created.');
    }

    final uid = newUser.uid;
    final account = UserModel(
      userId: uid,
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      address: '',
      role: UserRole.farmer,
      isActive: true,
      createdAt: DateTime.now(),
    );
    final profile = FarmerModel(
      farmerId: uid,
      userId: uid,
      marketId: marketId,
      businessName: businessName.trim(),
      description: description.trim(),
      rating: 0,
      isVerified: false,
      createdAt: DateTime.now(),
    );

    try {
      final batch = _firestore.batch();
      batch.set(_users.doc(uid), account.toMap());
      batch.set(_farmers.doc(uid), profile.toMap());
      await batch.commit();
    } catch (_) {
      try {
        await newUser.delete();
      } catch (_) {
        await helperAuth.signOut();
      }
      rethrow;
    } finally {
      await helperAuth.signOut();
    }
  }

  Future<void> setFarmerVerified(String farmerId, bool isVerified) async {
    await _farmers.doc(farmerId).update({'isVerified': isVerified});
  }

  Stream<List<FarmerModel>> watchAllFarmers() {
    return _farmers.orderBy('businessName').snapshots().map(
          (snap) => snap.docs
              .map((d) => FarmerModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<OrderModel>> watchAllOrders({int limit = PagingRules.pageSize}) {
    return _orders
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<AdminDashboardStats> loadDashboardStats() async {
    final (ordersSnap, farmersSnap, marketsSnap) =
        await (_orders.get(), _farmers.get(), _markets.get()).wait;

    final farmerToMarket = <String, String>{};
    final farmerToName = <String, String>{};
    for (final doc in farmersSnap.docs) {
      final data = doc.data();
      farmerToMarket[doc.id] = data['marketId'] ?? '';
      farmerToName[doc.id] = data['businessName'] ?? 'Unnamed farmer';
    }

    final marketNames = <String, String>{};
    for (final doc in marketsSnap.docs) {
      marketNames[doc.id] = doc.data()['marketName'] ?? 'Unknown market';
    }

    var totalRevenue = 0.0;
    var totalOrders = 0;
    final revenueByMarket = <String, double>{};
    final ordersByFarmer = <String, int>{};

    for (final doc in ordersSnap.docs) {
      final order = OrderModel.fromMap(doc.id, doc.data());
      if (order.status == OrderStatus.cancelled) continue;

      totalOrders++;
      totalRevenue += order.totalPrice;
      ordersByFarmer[order.farmerId] =
          (ordersByFarmer[order.farmerId] ?? 0) + 1;

      final marketId = farmerToMarket[order.farmerId] ?? '';
      final marketName = marketNames[marketId] ?? 'Unknown market';
      revenueByMarket[marketName] =
          (revenueByMarket[marketName] ?? 0) + order.totalPrice;
    }

    final rankedFarmers = ordersByFarmer.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topFarmers = rankedFarmers
        .take(5)
        .map((e) => MapEntry(farmerToName[e.key] ?? 'Unknown farmer', e.value))
        .toList();

    return AdminDashboardStats(
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      revenueByMarket: revenueByMarket,
      topFarmers: topFarmers,
    );
  }
}
