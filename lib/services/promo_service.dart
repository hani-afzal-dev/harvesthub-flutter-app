import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/promo_code_model.dart';

class PromoCodeException implements Exception {
  final String message;
  PromoCodeException(this.message);

  @override
  String toString() => message;
}

class PromoService {
  static final RegExp codePattern = RegExp(r'^[A-Z0-9]{4,15}$');

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _codes =>
      _firestore.collection(FirestoreCollections.promoCodes);

  CollectionReference<Map<String, dynamic>> get _redemptions =>
      _firestore.collection(FirestoreCollections.promoRedemptions);

  static String normalize(String raw) => raw.trim().toUpperCase();

  static String redemptionId(String uid, String code) => '${uid}_$code';

  DocumentReference<Map<String, dynamic>> codeRef(String code) =>
      _codes.doc(code);

  DocumentReference<Map<String, dynamic>> redemptionRef(
          String uid, String code) =>
      _redemptions.doc(redemptionId(uid, code));

  Stream<List<PromoCodeModel>> watchActiveCodes() {
    return _codes
        .where('active', isEqualTo: true)
        .limit(20)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final codes = <PromoCodeModel>[];
      for (final doc in snap.docs) {
        final promo = PromoCodeModel.fromMap(doc.id, doc.data());
        if (promo.isUsableAt(now)) codes.add(promo);
      }
      return codes;
    });
  }

  Stream<Set<String>> watchRedeemedCodes(String uid) {
    return _redemptions.where('customerId', isEqualTo: uid).snapshots().map(
        (snap) => snap.docs.map((d) => d.data()['code'] as String).toSet());
  }

  Stream<List<PromoCodeModel>> watchAllCodes(
      {int limit = PagingRules.pageSize}) {
    return _codes
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PromoCodeModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<PromoCodeModel> validateForCart({
    required String uid,
    required String rawCode,
    required double subtotal,
  }) async {
    final code = normalize(rawCode);
    if (!codePattern.hasMatch(code)) {
      throw PromoCodeException(
          'Promo codes use 4 to 15 letters and numbers only.');
    }

    final snap = await codeRef(code).get();
    final data = snap.data();
    if (data == null) {
      throw PromoCodeException('This promo code does not exist.');
    }

    final promo = PromoCodeModel.fromMap(snap.id, data);
    if (!promo.isUsableAt(DateTime.now())) {
      throw PromoCodeException('This promo code has expired.');
    }
    if (subtotal < promo.minOrder) {
      final shortBy = (promo.minOrder - subtotal).ceil();
      throw PromoCodeException('Add Rs. $shortBy more to use $code.');
    }

    final used = await redemptionRef(uid, code).get();
    if (used.exists) throw PromoCodeException('You have already used $code.');

    return promo;
  }

  Future<void> createCode(PromoCodeModel promo) async {
    final ref = codeRef(promo.code);
    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(ref);
      if (existing.exists) {
        throw PromoCodeException(
            'A promo code named ${promo.code} already exists.');
      }
      tx.set(ref, promo.toCreateMap());
    });
  }

  Future<void> setActive(String code, bool active) async {
    await codeRef(code).update({'active': active});
  }
}
