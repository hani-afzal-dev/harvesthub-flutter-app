import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../core/retry.dart';
import '../models/farmer_model.dart';

class FarmerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _farmers =>
      _firestore.collection(FirestoreCollections.farmers);

  Future<FarmerModel?> getById(String farmerId) async {
    final doc = await _farmers.doc(farmerId).get();
    if (!doc.exists) return null;
    return FarmerModel.fromMap(doc.id, doc.data()!);
  }

  Future<FarmerModel?> getByUserId(String userId) => getById(userId);

  Future<List<FarmerModel>> getAllActive() async {
    final farmersQuery = _farmers.orderBy('businessName');
    final snap = await getWithCacheFallback(farmersQuery);
    return snap.docs.map((d) => FarmerModel.fromMap(d.id, d.data())).toList();
  }

  Future<void> updateProfile({
    required String farmerId,
    required String businessName,
    required String description,
    String? imageUrl,
  }) async {
    final changes = <String, dynamic>{
      'businessName': businessName.trim(),
      'description': description.trim(),
    };
    if (imageUrl != null) changes['imageUrl'] = imageUrl;
    await _farmers.doc(farmerId).update(changes);
  }
}
