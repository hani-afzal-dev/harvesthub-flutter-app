import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/phone_numbers.dart';
import '../../../core/validators.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/panel_ui.dart';
import '../../../widgets/phone_number_field.dart';

class AddFarmerScreen extends ConsumerStatefulWidget {
  const AddFarmerScreen({super.key});

  @override
  ConsumerState<AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends ConsumerState<AddFarmerScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  DialCountry _phoneCountry = defaultDialCountry;
  final _passwordController = TextEditingController();
  final _businessController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _marketId;
  bool _showPassword = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _emailController,
      _phoneController,
      _passwordController,
      _businessController,
      _descriptionController,
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
    _businessController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _businessValid {
    final length = _businessController.text.trim().length;
    return length >= 2 && length <= 80;
  }

  bool get _descriptionValid =>
      _descriptionController.text.trim().length <= 500;

  bool get _canSubmit =>
      Validators.isValidName(_nameController.text) &&
      Validators.isValidEmail(_emailController.text) &&
      Validators.isValidLocalPhone(_phoneCountry, _phoneController.text) &&
      Validators.isValidPassword(_passwordController.text) &&
      _businessValid &&
      _descriptionValid;

  String? _fieldError(TextEditingController controller, String? message) {
    if (controller.text.isEmpty) return null;
    return message;
  }

  Future<void> _submit() async {
    if (_saving || !_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final authService = ref.read(authServiceProvider);
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final business = _businessController.text.trim();

    try {
      await ref.read(adminServiceProvider).createFarmer(
            name: _nameController.text,
            email: _emailController.text,
            phone: toE164(_phoneCountry, _phoneController.text),
            password: password,
            businessName: _businessController.text,
            description: _descriptionController.text,
            marketId: _marketId,
          );
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CredentialsDialog(
            business: business, email: email, password: password),
      );
      navigator.pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == 'email-already-in-use'
            ? 'A user with this email already exists.'
            : authService.mapAuthError(e);
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'The farmer account could not be created. Please try again.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markets = ref.watch(adminMarketsProvider).valueOrNull ?? const [];
    final error = _error;

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PageHeader(title: 'Add farmer'),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: PanelColors.blueBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 20, color: PanelColors.blue),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Farmers cannot sign up on their own. Create the account here, then share the email and temporary password with them.',
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: PanelColors.textBody),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const PanelSectionLabel('Login details'),
                      PanelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const ValueKey('add_farmer_name_field'),
                              controller: _nameController,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.words,
                              decoration: panelInputDecoration(
                                'Full name',
                                icon: Icons.person_outline_rounded,
                                error: _fieldError(
                                  _nameController,
                                  Validators.isValidName(_nameController.text)
                                      ? null
                                      : 'Use letters and spaces only.',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('add_farmer_email_field'),
                              controller: _emailController,
                              enabled: !_saving,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: panelInputDecoration(
                                'Email',
                                icon: Icons.mail_outline_rounded,
                                error: _fieldError(
                                  _emailController,
                                  Validators.isValidEmail(_emailController.text)
                                      ? null
                                      : 'Enter a valid email address.',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            PhoneNumberField(
                              fieldKey:
                                  const ValueKey('add_farmer_phone_field'),
                              controller: _phoneController,
                              country: _phoneCountry,
                              label: 'Mobile number',
                              onCountryChanged: (country) =>
                                  setState(() => _phoneCountry = country),
                            ),
                            if (_phoneController.text.isNotEmpty &&
                                Validators.localPhoneError(
                                        _phoneCountry, _phoneController.text) !=
                                    null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(
                                    Validators.localPhoneError(
                                        _phoneCountry, _phoneController.text)!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: PanelColors.danger)),
                              ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('add_farmer_password_field'),
                              controller: _passwordController,
                              enabled: !_saving,
                              obscureText: !_showPassword,
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: panelInputDecoration(
                                'Temporary password',
                                icon: Icons.lock_outline_rounded,
                                helper:
                                    '8+ characters with an uppercase letter, a number and a symbol.',
                                error: _fieldError(
                                    _passwordController,
                                    Validators.passwordError(
                                        _passwordController.text)),
                              ).copyWith(
                                suffixIcon: IconButton(
                                  tooltip: _showPassword
                                      ? 'Hide password'
                                      : 'Show password',
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: PanelColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const PanelSectionLabel('Farm details'),
                      PanelCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const ValueKey('add_farmer_business_field'),
                              controller: _businessController,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(80)
                              ],
                              decoration: panelInputDecoration(
                                'Business name',
                                icon: Icons.storefront_outlined,
                                error: _fieldError(
                                  _businessController,
                                  _businessValid
                                      ? null
                                      : 'Use 2 to 80 characters.',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey(
                                  'add_farmer_description_field'),
                              controller: _descriptionController,
                              enabled: !_saving,
                              minLines: 2,
                              maxLines: 4,
                              maxLength: 500,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: panelInputDecoration(
                                'Short description (optional)',
                                error: _descriptionValid
                                    ? null
                                    : 'Keep it under 500 characters.',
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text('Market',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: PanelColors.textBody)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MarketChip(
                                  label: 'No market yet',
                                  selected: _marketId == null,
                                  onTap: _saving
                                      ? null
                                      : () => setState(() => _marketId = null),
                                ),
                                for (final market in markets)
                                  _MarketChip(
                                    label: market.marketName,
                                    selected: _marketId == market.marketId,
                                    onTap: _saving
                                        ? null
                                        : () => setState(
                                            () => _marketId = market.marketId),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: PanelColors.brandDark.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 16, color: PanelColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(error,
                                style: const TextStyle(
                                    fontSize: 13, color: PanelColors.danger)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('add_farmer_submit_button'),
                        onPressed: _saving || !_canSubmit ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: PanelColors.brand,
                          disabledBackgroundColor: const Color(0xFFDDE3D5),
                          disabledForegroundColor: const Color(0xFF7D8874),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: PanelColors.brand, strokeWidth: 2),
                              )
                            : const Text('Create farmer account',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _MarketChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      selectedColor: PanelColors.brand,
      backgroundColor: PanelColors.pageBg,
      showCheckmark: false,
      side:
          BorderSide(color: selected ? PanelColors.brand : PanelColors.border),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : PanelColors.textBody,
      ),
    );
  }
}

class _CredentialsDialog extends StatelessWidget {
  final String business;
  final String email;
  final String password;

  const _CredentialsDialog({
    required this.business,
    required this.email,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle_rounded,
          color: PanelColors.brand, size: 40),
      title: Text('$business is ready'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Share these login details with the farmer. They can change the password from their profile.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PanelColors.pageBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PanelColors.border),
            ),
            child: SelectableText(
              'Email: $email\nPassword: $password',
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: PanelColors.textMain),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
                ClipboardData(text: 'Email: $email\nPassword: $password'));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                appSnackBar('Login details copied', tone: SnackTone.success));
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: PanelColors.brand),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
