import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_logger.dart';
import '../models/user_model.dart';
import '../providers/service_providers.dart';
import '../providers/session_providers.dart';

const String accountDisabledNotice =
    'Your account has been disabled. Please contact support.';

class AccountStatusGuard extends ConsumerStatefulWidget {
  final Widget child;

  const AccountStatusGuard({super.key, required this.child});

  @override
  ConsumerState<AccountStatusGuard> createState() => _AccountStatusGuardState();
}

class _AccountStatusGuardState extends ConsumerState<AccountStatusGuard> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    final navigator = Navigator.of(context);
    try {
      await ref.read(authServiceProvider).logout();
    } catch (e, stack) {
      AppLogger.error('Forced logout failed', e, stack);
    }
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil('/roles', (route) => false,
        arguments: accountDisabledNotice);
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<UserModel?>>(
      sessionProfileProvider,
      (previous, next) {
        final user = next.valueOrNull;
        if (user == null || user.isActive) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _signOut();
        });
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
