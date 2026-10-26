import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'service_providers.dart';
import 'session_providers.dart';

class EmailVerificationNotifier extends StateNotifier<bool> {
  final AuthService _authService;

  EmailVerificationNotifier(this._authService)
      : super(_authService.isEmailVerified);

  Future<void> refresh() async {
    try {
      final verified = await _authService.reloadEmailVerified();
      if (mounted) state = verified;
    } catch (_) {
      return;
    }
  }
}

final emailVerifiedProvider =
    StateNotifierProvider<EmailVerificationNotifier, bool>((ref) {
  ref.watch(currentUidProvider);
  return EmailVerificationNotifier(ref.watch(authServiceProvider));
});
