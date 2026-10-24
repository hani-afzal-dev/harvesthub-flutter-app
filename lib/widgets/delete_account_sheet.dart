import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_logger.dart';
import '../providers/service_providers.dart';
import '../services/account_deletion_service.dart';
import 'panel_ui.dart';

Future<void> showDeleteAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _DeleteAccountSheet(),
  );
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final service = ref.read(accountDeletionServiceProvider);
    if (service.usesPassword && _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      await service.deleteCustomerAccount(password: _passwordController.text);
      if (!navigator.mounted) return;
      navigator.pushNamedAndRemoveUntil('/roles', (route) => false,
          arguments: 'Your account has been deleted.');
    } on ActiveOrdersException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _deleting = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      var message = 'Could not delete your account. Please try again.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'That password is not correct.';
      } else if (e.code == 'missing-password') {
        message = 'Enter your password to confirm.';
      } else if (e.code == 'network-request-failed') {
        message = 'No connection. Check your internet and try again.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Wait a few minutes and try again.';
      }
      setState(() {
        _error = message;
        _deleting = false;
      });
    } catch (e, stack) {
      AppLogger.error('Account deletion failed', e, stack);
      if (!mounted) return;
      setState(() {
        _error =
            'Could not delete your account. Check your connection and try again.';
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usesPassword = ref.read(accountDeletionServiceProvider).usesPassword;
    final error = _error;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: PanelColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PanelColors.dangerBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_forever_outlined,
                        color: PanelColors.danger),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Delete your account?',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: PanelColors.textMain)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _Point(
                icon: Icons.remove_circle_outline_rounded,
                color: PanelColors.danger,
                text:
                    'Your profile, login, cart, wishlist, followed farmers, notifications and chat history are removed for good.',
              ),
              const _Point(
                icon: Icons.receipt_long_outlined,
                color: PanelColors.textMuted,
                text:
                    'Past orders stay with the farmers for their records, with your address removed.',
              ),
              const _Point(
                icon: Icons.info_outline_rounded,
                color: PanelColors.textMuted,
                text:
                    'Orders still in progress must be picked up or cancelled first.',
              ),
              const SizedBox(height: 12),
              if (usesPassword)
                TextField(
                  key: const ValueKey('delete_account_password_field'),
                  controller: _passwordController,
                  enabled: !_deleting,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: panelInputDecoration(
                    'Password',
                    icon: Icons.lock_outline_rounded,
                    helper: 'Enter your password to confirm.',
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip:
                          _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: PanelColors.textMuted),
                    ),
                  ),
                )
              else
                const Text(
                  'You will be asked to confirm with your Google account.',
                  style: TextStyle(fontSize: 13, color: PanelColors.textMuted),
                ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error,
                    style: const TextStyle(
                        fontSize: 13, color: PanelColors.danger)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('delete_account_confirm_button'),
                  onPressed: _deleting ? null : _delete,
                  style: FilledButton.styleFrom(
                    backgroundColor: PanelColors.danger,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PanelColors.danger),
                        )
                      : const Text('Delete my account',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _deleting ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Keep my account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Point({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: PanelColors.textBody)),
          ),
        ],
      ),
    );
  }
}
