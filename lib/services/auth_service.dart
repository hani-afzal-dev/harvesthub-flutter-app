import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../core/app_logger.dart';
import '../core/constants.dart';
import '../core/local_db.dart';
import '../models/user_model.dart';
import 'push_token_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PushTokenService _pushToken = PushTokenService();

  static bool _googleReady = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String address,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw FirebaseAuthException(
          code: 'unknown', message: 'Account could not be created.');
    }

    final uid = firebaseUser.uid;
    final newUser = UserModel(
      userId: uid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      address: address.trim(),
      role: UserRole.customer,
      isActive: true,
      createdAt: DateTime.now(),
    );

    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(newUser.toMap());
    } catch (_) {
      try {
        await firebaseUser.delete();
      } catch (_) {
        await _auth.signOut();
      }
      rethrow;
    }

    await _sendVerificationQuietly(firebaseUser);
    unawaited(_linkPushIdentity(uid));
    return newUser;
  }

  Future<void> _linkPushIdentity(String uid) async {
    try {
      await OneSignal.login(uid);
    } catch (e, stack) {
      AppLogger.error('Push link failed', e, stack);
    }
    await _pushToken.saveCurrent();
  }

  Future<void> _sendVerificationQuietly(User user) async {
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (_) {
      return;
    }
  }

  bool get hasPasswordLogin {
    final user = _auth.currentUser;
    if (user == null) return false;
    for (final info in user.providerData) {
      if (info.providerId == EmailAuthProvider.PROVIDER_ID) return true;
    }
    return false;
  }

  bool get usesGoogleLogin {
    final user = _auth.currentUser;
    if (user == null) return false;
    for (final info in user.providerData) {
      if (info.providerId == GoogleAuthProvider.PROVIDER_ID) return true;
    }
    return false;
  }

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? true;

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.sendEmailVerification();
  }

  Future<bool> reloadEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return true;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return true;
    if (refreshed.emailVerified) {
      final tokenResult = await refreshed.getIdTokenResult();
      if (tokenResult.claims?['email_verified'] != true) {
        await refreshed.getIdToken(true);
      }
    }
    return refreshed.emailVerified;
  }

  Future<UserModel> login({
    required String email,
    required String password,
    UserRole? expectedRole,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(credential.user!.uid)
        .get();

    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'profile-missing',
        message: 'No profile found for this account.',
      );
    }

    final user = UserModel.fromMap(doc.id, doc.data()!);
    if (!user.isActive) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'account-disabled',
        message: 'This account has been disabled. Please contact support.',
      );
    }

    if (expectedRole != null && user.role != expectedRole) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'wrong-role',
        message:
            'This is not a ${userRoleLabel(expectedRole).toLowerCase()} account. Go back and pick the right role.',
      );
    }

    unawaited(_linkPushIdentity(user.userId));
    return user;
  }

  Future<UserModel?> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }

    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'google-token-missing',
        message: 'Google sign-in did not complete. Please try again.',
      );
    }

    final result = await _auth
        .signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
    final firebaseUser = result.user;
    if (firebaseUser == null) {
      throw FirebaseAuthException(
          code: 'unknown',
          message: 'Google sign-in did not complete. Please try again.');
    }

    final profile = await getUserProfile(firebaseUser.uid);
    if (profile == null) return null;

    if (!profile.isActive) {
      await logout();
      throw FirebaseAuthException(
        code: 'account-disabled',
        message: 'This account has been disabled. Please contact support.',
      );
    }
    if (profile.role != UserRole.customer) {
      await logout();
      throw FirebaseAuthException(
        code: 'wrong-role',
        message:
            'Google sign-in is only for customer accounts. Log in with your email and password.',
      );
    }

    unawaited(_linkPushIdentity(profile.userId));
    return profile;
  }

  Future<UserModel> completeGoogleProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    final firebaseUser = _auth.currentUser;
    final email = firebaseUser?.email;
    if (firebaseUser == null || email == null) {
      throw FirebaseAuthException(
          code: 'no-user',
          message: 'Your Google session ended. Please sign in again.');
    }

    final newUser = UserModel(
      userId: firebaseUser.uid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      address: address.trim(),
      role: UserRole.customer,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(firebaseUser.uid)
        .set(newUser.toMap());
    unawaited(_linkPushIdentity(firebaseUser.uid));
    return newUser;
  }

  Stream<UserModel?> watchUserProfile(String userId) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .snapshots()
        .where((snap) => snap.exists || !snap.metadata.isFromCache)
        .map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return UserModel.fromMap(snap.id, data);
    });
  }

  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.id, doc.data()!);
  }

  Future<UserModel?> getCachedUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .get(const GetOptions(source: Source.cache));
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    } on FirebaseException {
      return null;
    }
  }

  Future<void> updateProfile(
    String userId, {
    required String name,
    required String phone,
    required String address,
  }) async {
    await _firestore.collection(FirestoreCollections.users).doc(userId).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
    });
  }

  Future<void> logout() async {
    await _pushToken.clearCurrent();
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
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e, stack) {
        AppLogger.error('Google sign out failed', e, stack);
      }
    }
    await _auth.signOut();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
          code: 'no-user',
          message: 'You need to be logged in to change your password.');
    }
    final credential =
        EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  String mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password must be at least 8 characters';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many login attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No connection. Please check your internet and try again.';
      case 'requires-recent-login':
        return 'Please log in again and retry.';
      case 'account-exists-with-different-credential':
        return 'This email already has a password login. Log in with your email and password.';
      case 'account-disabled':
      case 'wrong-role':
      case 'no-user':
      case 'google-token-missing':
        return e.message ?? 'This account cannot be used here.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
