import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/secure_store.dart';
import '../../core/validators.dart';
import '../../models/user_model.dart';
import '../../providers/service_providers.dart';
import '../../widgets/animated_auth_button.dart';
import '../../widgets/animated_auth_field.dart';
import '../../widgets/auth_page_shell.dart';
import 'google_sign_in_flow.dart';
import 'signup_screen.dart';
import '../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _errorText = Color(0xFFB3261E);

class LoginScreen extends ConsumerStatefulWidget {
  final UserRole role;

  const LoginScreen({super.key, required this.role});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _formError;
  UserModel? _loggedInUser;
  Timer? _lockTimer;
  int _lockSecondsLeft = 0;
  bool _googleBusy = false;

  bool get _isLocked => _lockSecondsLeft > 0;

  void _startLock() {
    _lockTimer?.cancel();
    setState(() => _lockSecondsLeft = 60);
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockSecondsLeft--;
        if (_lockSecondsLeft <= 0) {
          timer.cancel();
          _formError = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      Validators.isValidEmail(_emailController.text) &&
      Validators.isPasswordProvided(_passwordController.text);

  Future<bool> _handleLogin() async {
    if (_isLocked) return false;
    if (!_canSubmit) {
      setState(() => _formError = 'Enter a valid email and password.');
      return false;
    }
    setState(() => _formError = null);

    final authService = ref.read(authServiceProvider);
    try {
      final user = await authService.login(
        email: _emailController.text,
        password: _passwordController.text,
        expectedRole: widget.role,
      );
      _loggedInUser = user;
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;
      setState(() => _formError = authService.mapAuthError(e));
      if (e.code == 'too-many-requests') _startLock();
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _formError = 'Something went wrong. Please try again.');
      return false;
    }
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    final user = _loggedInUser;
    if (user == null) return;

    switch (user.role) {
      case UserRole.customer:
        unawaited(SecureStore.saveLastRole(userRoleToString(user.role)));
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/home', (route) => false);
        return;
      case UserRole.admin:
        unawaited(SecureStore.saveLastRole(userRoleToString(user.role)));
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/admin-home', (route) => false);
        return;
      case UserRole.farmer:
        final farmer =
            await ref.read(farmerServiceProvider).getByUserId(user.userId);
        if (!mounted) return;
        if (farmer == null) {
          await ref.read(authServiceProvider).logout();
          if (!mounted) return;
          setState(() => _formError =
              'Your farm profile is not set up yet. Please contact an administrator.');
        } else {
          unawaited(SecureStore.saveLastRole(userRoleToString(user.role)));
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/farmer-home', (route) => false);
        }
        return;
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_googleBusy || _isLocked) return;
    setState(() {
      _googleBusy = true;
      _formError = null;
    });
    final error = await continueWithGoogle(context, ref);
    if (!mounted) return;
    setState(() {
      _googleBusy = false;
      _formError = error;
    });
  }

  Future<void> _showForgotPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ForgotPasswordDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(appSnackBar('Sending reset link to $email...'));

    final authService = ref.read(authServiceProvider);
    String? error;
    try {
      await authService.sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') error = authService.mapAuthError(e);
    } catch (_) {
      error = 'Could not send the reset link. Please try again.';
    }

    messenger.hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(appSnackBar(error, tone: SnackTone.error));
      return;
    }
    messenger.showSnackBar(appSnackBar(
      'If an account exists for $email, a reset link is on its way. '
      'Check your inbox and the Spam folder.',
      tone: SnackTone.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = userRoleLabel(widget.role).toLowerCase();

    var subtitle = 'Log in to continue shopping fresh';
    if (widget.role == UserRole.farmer) subtitle = 'Log in to manage your farm';
    if (widget.role == UserRole.admin) subtitle = 'Log in to manage HarvestHub';

    return AuthPageShell(
      pillLabel: 'Log in as $roleLabel',
      title: 'Welcome back',
      subtitle: subtitle,
      children: [
        AnimatedAuthField(
          key: const ValueKey('login_email_field'),
          controller: _emailController,
          label: 'Email',
          icon: Icons.mail_outline,
          accentColor: _brand,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.isValidEmail,
          errorText: 'Enter a valid email address',
        ),
        const SizedBox(height: 12),
        AnimatedAuthField(
          key: const ValueKey('login_password_field'),
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          accentColor: _brand,
          obscureText: true,
          validator: Validators.isPasswordProvided,
          errorText: 'Enter your password',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('login_forgot_password_button'),
            onPressed: _showForgotPassword,
            style: TextButton.styleFrom(
                foregroundColor: _brand, minimumSize: const Size(48, 44)),
            child: const Text('Forgot password?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
        if (_formError != null) ...[
          Text(_formError!,
              style: const TextStyle(color: _errorText, fontSize: 13)),
          const SizedBox(height: 4),
        ],
        if (_isLocked)
          Text(
            'You can try again in $_lockSecondsLeft seconds.',
            key: const ValueKey('login_lock_countdown'),
            style: const TextStyle(color: _errorText, fontSize: 13),
          ),
        if (widget.role == UserRole.farmer) ...[
          const SizedBox(height: 4),
          const Text(
            'Farmer accounts are created by an administrator. Use the details you were given.',
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => AnimatedAuthButton(
            key: const ValueKey('login_submit_button'),
            label: 'Log in',
            icon: Icons.lock,
            transitionIcon: Icons.lock_open,
            accentColor: _brand,
            width: constraints.maxWidth,
            height: 52,
            onPressedAsync: _isLocked || _googleBusy ? null : _handleLogin,
            onSuccess: _goHome,
            onError: (msg) => setState(() => _formError = msg),
          ),
        ),
        if (widget.role == UserRole.customer) ...[
          const SizedBox(height: 8),
          const AuthOrDivider(),
          const SizedBox(height: 12),
          GoogleAuthButton(
            key: const ValueKey('login_google_button'),
            busy: _googleBusy,
            onPressed: _googleBusy || _isLocked ? null : _signInWithGoogle,
          ),
          const SizedBox(height: 8),
          AuthSwitchLink(
            key: const ValueKey('login_signup_button'),
            prompt: "Don't have an account?",
            action: 'Sign up',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialEmail);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final email = _controller.text.trim().toLowerCase();
    if (!Validators.isValidEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your account email and we will send you a reset link.',
            style: TextStyle(fontSize: 14, color: _textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('forgot_password_email_field'),
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: _error,
              errorMaxLines: 2,
              filled: true,
              fillColor: const Color(0xFFEFF3EA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _brand, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('forgot_password_send_button'),
          onPressed: _send,
          style: FilledButton.styleFrom(backgroundColor: _brand),
          child: const Text('Send link'),
        ),
      ],
    );
  }
}
