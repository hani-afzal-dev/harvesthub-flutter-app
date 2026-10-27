import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/secure_store.dart';
import '../../models/user_model.dart';
import '../../providers/service_providers.dart';
import 'complete_profile_screen.dart';

Future<String?> continueWithGoogle(BuildContext context, WidgetRef ref) async {
  final authService = ref.read(authServiceProvider);
  try {
    final user = await authService.signInWithGoogle();
    if (!context.mounted) return null;
    if (user == null) {
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
      );
      if (completed != true || !context.mounted) return null;
    }
    unawaited(SecureStore.saveLastRole(userRoleToString(UserRole.customer)));
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    return null;
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
        e.code == GoogleSignInExceptionCode.providerConfigurationError) {
      return 'Google sign-in is not available right now. Use your email instead.';
    }
    return 'Google sign-in failed. Please try again.';
  } on FirebaseAuthException catch (e) {
    return authService.mapAuthError(e);
  } catch (_) {
    return 'Google sign-in failed. Please try again.';
  }
}
