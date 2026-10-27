import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_logger.dart';
import '../../core/phone_numbers.dart';
import '../../core/validators.dart';
import '../../providers/service_providers.dart';
import '../../widgets/animated_auth_field.dart';
import '../../widgets/auth_page_shell.dart';
import '../../widgets/phone_number_field.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;
  bool _leaving = false;
  DialCountry _phoneCountry = defaultDialCountry;
  String? _error;

  @override
  void initState() {
    super.initState();
    final displayName =
        ref.read(authServiceProvider).currentUser?.displayName ?? '';
    if (Validators.isValidName(displayName)) {
      _nameController.text = displayName.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _formValid =>
      Validators.isValidName(_nameController.text) &&
      Validators.isValidLocalPhone(_phoneCountry, _phoneController.text) &&
      Validators.isValidAddress(_addressController.text);

  Future<void> _cancel() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await ref.read(authServiceProvider).logout();
    } catch (e, stack) {
      AppLogger.error('Google profile cancel sign out failed', e, stack);
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formValid) {
      setState(() =>
          _error = 'Fill in your name, phone number and address to continue.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final authService = ref.read(authServiceProvider);
    try {
      await authService.completeGoogleProfile(
        name: _nameController.text,
        phone: toE164(_phoneCountry, _phoneController.text),
        address: _addressController.text,
      );
      if (!mounted) return;
      _leaving = true;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = authService.mapAuthError(e));
    } on FirebaseException catch (e, stack) {
      AppLogger.error('Google profile save failed', e, stack);
      var message =
          'Could not save your profile. Check your connection and try again.';
      if (e.code == 'permission-denied') {
        message =
            'This Google account cannot be used here. Sign up with email instead.';
      }
      if (mounted) setState(() => _error = message);
    } catch (e, stack) {
      AppLogger.error('Google profile save failed', e, stack);
      if (mounted) {
        setState(
            () => _error = 'Could not save your profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authServiceProvider).currentUser?.email ?? '';
    final emailUsable = Validators.isValidEmail(email);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: AuthPageShell(
        pillLabel: 'Google sign-up',
        title: 'One last step',
        subtitle: 'Farmers need your name and phone number to confirm pickups.',
        onBack: _cancel,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE6EEDC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline, size: 18, color: _brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: _textMain),
                  ),
                ),
              ],
            ),
          ),
          if (!emailUsable) ...[
            const SizedBox(height: 8),
            const Text(
              'This email has characters we do not accept. Cancel and sign up with email instead.',
              style: TextStyle(fontSize: 13, color: Color(0xFFB3261E)),
            ),
          ],
          const SizedBox(height: 16),
          AnimatedAuthField(
            key: const ValueKey('google_profile_name_field'),
            controller: _nameController,
            label: 'Full name',
            icon: Icons.person_outline,
            accentColor: _brand,
            validator: Validators.isValidName,
            errorText: 'Name should only contain letters and spaces',
          ),
          const SizedBox(height: 12),
          PhoneNumberField(
            fieldKey: const ValueKey('google_profile_phone_field'),
            controller: _phoneController,
            country: _phoneCountry,
            label: 'Mobile number',
            onCountryChanged: (country) =>
                setState(() => _phoneCountry = country),
          ),
          const SizedBox(height: 12),
          AnimatedAuthField(
            key: const ValueKey('google_profile_address_field'),
            controller: _addressController,
            label: 'Address',
            icon: Icons.home_outlined,
            accentColor: _brand,
            validator: Validators.isValidAddress,
            errorText: 'Address is required',
            errorMessage: Validators.addressError,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(fontSize: 13, color: Color(0xFFB3261E))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              key: const ValueKey('google_profile_save_button'),
              onPressed: _saving || !emailUsable ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save and continue',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
