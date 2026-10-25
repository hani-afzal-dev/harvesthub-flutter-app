import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../core/local_db.dart';

class ActiveOrdersException implements Exception {
  final int count;
  ActiveOrdersException(this.count);

  @override
  String toString() => count == 1
      ? 'You have 1 order in progress. Cancel it or wait until it is picked up, then try again.'
      : 'You have $count orders in progress. Cancel them or wait until they are picked up, then try again.';
}

class AccountDeletionService {
  static const String removedAddress = 'Account deleted';
  static const int _batchLimit = 400;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get usesPassword {
    final user = _auth.currentUser;
    if (user == null) return false;
    for (final info in user.providerData) {
      if (info.providerId == EmailAuthProvider.PROVIDER_ID) return true;
    }
    return false;
  }

  Future<void> _reauthenticate(User user, String? password) async {
    if (usesPassword) {
      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw FirebaseAuthException(
            code: 'missing-password',
            message: 'Enter your password to confirm.');
      }
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password));
      return;
    }

    final google = GoogleSignIn.instance;
    await google.initialize();
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
          code: 'google-token-missing',
          message: 'Google confirmation did not complete. Please try again.');
    }
    await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken));
  }

  Future<void> _deleteWhere(String collection, String field, String uid) async {
    final snap = await _firestore
        .collection(collection)
        .where(field, isEqualTo: uid)
        .get();
    for (var i = 0; i < snap.docs.length; i += _batchLimit) {
      final end = i + _batchLimit > snap.docs.length
          ? snap.docs.length
          : i + _batchLimit;
      final batch = _firestore.batch();
      for (final doc in snap.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteCustomerAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-user', message: 'You need to be logged in.');
    }
    final uid = user.uid;

    final orders = await _firestore
        .collection(FirestoreCollections.orders)
        .where('customerId', isEqualTo: uid)
        .get();
    var active = 0;
    for (final doc in orders.docs) {
      final status = doc.data()['status'];
      if (status == OrderStatusValues.pending ||
          status == OrderStatusValues.confirmed ||
          status == OrderStatusValues.readyForPickup) {
        active++;
      }
    }
    if (active > 0) throw ActiveOrdersException(active);

    await _reauthenticate(user, password);

    await _deleteWhere(FirestoreCollections.cartItems, 'customerId', uid);
    await _deleteWhere(FirestoreCollections.wishlists, 'customerId', uid);
    await _deleteWhere(FirestoreCollections.followedFarmers, 'customerId', uid);
    await _deleteWhere(FirestoreCollections.notifications, 'userId', uid);
    await _deleteWhere(FirestoreCollections.aiChatSessions, 'userId', uid);

    for (var i = 0; i < orders.docs.length; i += _batchLimit) {
      final end = i + _batchLimit > orders.docs.length
          ? orders.docs.length
          : i + _batchLimit;
      final batch = _firestore.batch();
      for (final doc in orders.docs.sublist(i, end)) {
        if (doc.data()['deliveryAddr'] == removedAddress) continue;
        batch.update(doc.reference, {
          'deliveryAddr': removedAddress,
          'customerName': 'Deleted customer',
        });
      }
      await batch.commit();
    }

    await _firestore.collection(FirestoreCollections.users).doc(uid).delete();

    try {
      await OneSignal.logout();
    } catch (e, stack) {
      AppLogger.error('Push unlink failed', e, stack);
    }
    try {
      await LocalDb.clearAll();
    } catch (e, stack) {
      AppLogger.error('Local cache clear failed', e, stack);
    }

    await user.delete();
  }
}
