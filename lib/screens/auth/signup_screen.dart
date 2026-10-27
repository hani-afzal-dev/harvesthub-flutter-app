import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/secure_store.dart';
import '../../core/phone_numbers.dart';
import '../../core/validators.dart';
import '../../providers/service_providers.dart';
import '../../widgets/animated_auth_button.dart';
import '../../widgets/animated_auth_field.dart';
import '../../widgets/phone_number_field.dart';
import '../../widgets/auth_page_shell.dart';
import 'google_sign_in_flow.dart';

const Color _brand = Color(0xFF3B6D11);

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  String? _formError;
  bool _emailTaken = false;
  bool _googleBusy = false;
  DialCountry _phoneCountry = defaultDialCountry;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _emailController,
      _phoneController,
      _passwordController,
      _addressController
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      Validators.isValidName(_nameController.text) &&
      Validators.isValidEmail(_emailController.text) &&
      Validators.isValidLocalPhone(_phoneCountry, _phoneController.text) &&
      Validators.isValidPassword(_passwordController.text) &&
      Validators.isValidAddress(_addressController.text);

  Future<bool> _handleSignup() async {
    if (!_canSubmit) {
      setState(() =>
          _formError = 'Please fill every field correctly before continuing.');
      return false;
    }
    setState(() {
      _formError = null;
      _emailTaken = false;
    });

    final authService = ref.read(authServiceProvider);
    try {
      await authService.signUp(
        name: _nameController.text,
        email: _emailController.text,
        phone: toE164(_phoneCountry, _phoneController.text),
        password: _passwordController.text,
        address: _addressController.text,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return false;
      setState(() {
        _formError = authService.mapAuthError(e);
        _emailTaken = e.code == 'email-already-in-use';
      });
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _formError = 'Something went wrong. Please try again.');
      return false;
    }
  }

  void _goHome() {
    if (!mounted) return;
    unawaited(SecureStore.saveLastRole('customer'));
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Future<void> _signUpWithGoogle() async {
    if (_googleBusy) return;
    setState(() {
      _googleBusy = true;
      _formError = null;
      _emailTaken = false;
    });
    final error = await continueWithGoogle(context, ref);
    if (!mounted) return;
    setState(() {
      _googleBusy = false;
      _formError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      pillLabel: 'Sign up as customer',
      title: 'Create your account',
      subtitle: 'Join to order fresh from local farms',
      children: [
        AnimatedAuthField(
          key: const ValueKey('signup_name_field'),
          controller: _nameController,
          label: 'Full name',
          icon: Icons.person_outline,
          accentColor: _brand,
          validator: Validators.isValidName,
          errorText: 'Name should only contain letters and spaces',
        ),
        const SizedBox(height: 12),
        AnimatedAuthField(
          key: const ValueKey('signup_email_field'),
          controller: _emailController,
          label: 'Email',
          icon: Icons.mail_outline,
          accentColor: _brand,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.isValidEmail,
          errorText: 'Enter a valid email address',
        ),
        const SizedBox(height: 12),
        PhoneNumberField(
          fieldKey: const ValueKey('signup_phone_field'),
          controller: _phoneController,
          country: _phoneCountry,
          label: 'Mobile number',
          onCountryChanged: (country) =>
              setState(() => _phoneCountry = country),
        ),
        const SizedBox(height: 12),
        AnimatedAuthField(
          key: const ValueKey('signup_password_field'),
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          accentColor: _brand,
          obscureText: true,
          validator: Validators.isValidPassword,
          errorText: 'Password must be at least 8 characters',
          errorMessage: Validators.passwordError,
        ),
        const SizedBox(height: 12),
        AnimatedAuthField(
          key: const ValueKey('signup_address_field'),
          controller: _addressController,
          label: 'Address',
          icon: Icons.home_outlined,
          accentColor: _brand,
          validator: Validators.isValidAddress,
          errorText: 'Address is required',
          errorMessage: Validators.addressError,
        ),
        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(_formError!,
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13)),
        ],
        if (_emailTaken)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('signup_go_to_login_button'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                  foregroundColor: _brand, minimumSize: const Size(48, 44)),
              child: const Text('Log in instead',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => AnimatedAuthButton(
            key: const ValueKey('signup_submit_button'),
            label: 'Sign up',
            icon: Icons.person_add_alt_1,
            transitionIcon: Icons.person_add,
            accentColor: _brand,
            width: constraints.maxWidth,
            height: 52,
            onPressedAsync: _canSubmit && !_googleBusy ? _handleSignup : null,
            onSuccess: _goHome,
            onError: (msg) => setState(() => _formError = msg),
          ),
        ),
        const SizedBox(height: 8),
        const AuthOrDivider(),
        const SizedBox(height: 12),
        GoogleAuthButton(
          key: const ValueKey('signup_google_button'),
          busy: _googleBusy,
          onPressed: _googleBusy ? null : _signUpWithGoogle,
        ),
        const SizedBox(height: 8),
        AuthSwitchLink(
          key: const ValueKey('signup_login_link'),
          prompt: 'Already have an account?',
          action: 'Log in',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
