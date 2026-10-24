import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/validators.dart';
import '../providers/service_providers.dart';
import 'animated_auth_field.dart';
import 'app_snackbar.dart';

Future<void> showChangePasswordDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validate() {
    final current = _currentController.text;
    final next = _newController.text;
    if (!Validators.isPasswordProvided(current)) {
      return 'Enter your current password';
    }
    final policyError = Validators.passwordError(next);
    if (policyError != null) return policyError;
    if (next == current) {
      return 'New password must be different from the current one';
    }
    if (next != _confirmController.text) {
      return 'The two new passwords do not match';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final authService = ref.read(authServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await authService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      navigator.pop();
      messenger.showSnackBar(
          appSnackBar('Password updated.', tone: SnackTone.success));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final wrongCurrent =
          e.code == 'wrong-password' || e.code == 'invalid-credential';
      setState(() {
        _error = wrongCurrent
            ? 'Current password is incorrect.'
            : authService.mapAuthError(e);
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _saving = false;
      });
    }
  }

  Future<void> _sendResetEmail() async {
    final authService = ref.read(authServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final email = authService.currentUser?.email;
    if (email == null || email.isEmpty) {
      messenger.showSnackBar(appSnackBar('No email is linked to this account.',
          tone: SnackTone.error));
      return;
    }

    Navigator.of(context).pop();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(appSnackBar('Sending reset link to $email...'));

    String? error;
    try {
      await authService.sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      error = authService.mapAuthError(e);
    } catch (_) {
      error = 'Could not send the reset link. Please try again.';
    }

    messenger.hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(appSnackBar(error, tone: SnackTone.error));
      return;
    }
    messenger.showSnackBar(appSnackBar(
      'Reset link sent to $email. Check your inbox and the Spam folder.',
      tone: SnackTone.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF3B6D11);
    final error = _error;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFD5DBCD),
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
                          color: const Color(0xFFEFF3EA),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.lock_reset_rounded, color: brand),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change password',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF22301A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Use 8+ characters with an uppercase letter, a number and a symbol.',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFF6B7A5E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AnimatedAuthField(
                  key: const ValueKey('current_password_field'),
                  controller: _currentController,
                  label: 'Current password',
                  icon: Icons.lock_outline_rounded,
                  accentColor: brand,
                  obscureText: true,
                  validator: Validators.isPasswordProvided,
                  errorText: 'Enter your current password',
                ),
                const SizedBox(height: 12),
                AnimatedAuthField(
                  key: const ValueKey('new_password_field'),
                  controller: _newController,
                  label: 'New password',
                  icon: Icons.password_rounded,
                  accentColor: brand,
                  obscureText: true,
                  validator: Validators.isValidPassword,
                  errorText: 'Password must be at least 8 characters',
                  errorMessage: Validators.passwordError,
                ),
                const SizedBox(height: 12),
                AnimatedAuthField(
                  key: const ValueKey('confirm_password_field'),
                  controller: _confirmController,
                  label: 'Confirm new password',
                  icon: Icons.check_circle_outline_rounded,
                  accentColor: brand,
                  obscureText: true,
                  validator: (value) =>
                      value.isNotEmpty && value == _newController.text,
                  errorText: 'The two new passwords do not match',
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error,
                      style: const TextStyle(
                          color: Color(0xFFB3261E), fontSize: 13)),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('change_password_reset_link'),
                    onPressed: _saving ? null : _sendResetEmail,
                    style: TextButton.styleFrom(
                        foregroundColor: brand,
                        minimumSize: const Size(48, 44)),
                    child: const Text(
                      'Forgot current password? Email me a reset link',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('change_password_submit'),
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: brand,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: brand),
                          )
                        : const Text('Update password',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7A5E),
                      minimumSize: const Size(48, 48)),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
