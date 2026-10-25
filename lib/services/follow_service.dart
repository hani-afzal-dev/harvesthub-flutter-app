import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/farmer_model.dart';
import '../models/followed_farmer_model.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection(FirestoreCollections.followedFarmers);

  Stream<bool> watchIsFollowing(String customerId, String farmerId) {
    return _follows
        .doc(FollowedFarmerModel.idFor(customerId, farmerId))
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<void> toggleFollow(String customerId, String farmerId) async {
    final followId = FollowedFarmerModel.idFor(customerId, farmerId);
    final ref = _follows.doc(followId);
    DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get(const GetOptions(source: Source.cache));
    } on FirebaseException {
      snap = await ref.get();
    }
    if (snap.exists) {
      await ref.delete();
      return;
    }
    final follow = FollowedFarmerModel(
      followId: followId,
      customerId: customerId,
      farmerId: farmerId,
      followedAt: DateTime.now(),
    );
    try {
      await ref.set(follow.toCreateMap());
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      final fresh = await ref.get(const GetOptions(source: Source.server));
      if (!fresh.exists) rethrow;
      await ref.delete();
    }
  }

  List<FollowedFarmerModel> _toFollows(
      QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map((d) => FollowedFarmerModel.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<List<String>> watchFollowedFarmerIds(String customerId) {
    return _follows.where('customerId', isEqualTo: customerId).snapshots().map(
        (snap) => _toFollows(snap).map((follow) => follow.farmerId).toList());
  }

  Future<List<FarmerModel>> getFollowedFarmers(String customerId) async {
    final snap =
        await _follows.where('customerId', isEqualTo: customerId).get();
    final farmerIds =
        _toFollows(snap).map((follow) => follow.farmerId).toList();
    if (farmerIds.isEmpty) return [];

    final farmers = <FarmerModel>[];
    for (final chunk in _chunk(farmerIds, 10)) {
      final farmerSnap = await _firestore
          .collection(FirestoreCollections.farmers)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      farmers.addAll(
          farmerSnap.docs.map((d) => FarmerModel.fromMap(d.id, d.data())));
    }
    return farmers;
  }

  Future<List<String>> getFollowerUserIds(String farmerId) async {
    final snap = await _follows.where('farmerId', isEqualTo: farmerId).get();
    return _toFollows(snap).map((follow) => follow.customerId).toList();
  }

  List<List<String>> _chunk(List<String> items, int size) {
    final chunks = <List<String>>[];
    for (var i = 0; i < items.length; i += size) {
      chunks.add(
          items.sublist(i, i + size > items.length ? items.length : i + size));
    }
    return chunks;
  }
}
