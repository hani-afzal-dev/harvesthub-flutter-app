import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/secure_store.dart';
import '../../models/user_model.dart';

const Color _brandDark = Color(0xFF2E4A0F);
const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _pageBg = Color(0xFFF6F8F3);

class RoleSelectionScreen extends StatefulWidget {
  final String? notice;

  const RoleSelectionScreen({super.key, this.notice});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _lastRole;

  @override
  void initState() {
    super.initState();
    _loadLastRole();
  }

  Future<void> _loadLastRole() async {
    final saved = await SecureStore.readLastRole();
    if (!mounted || saved == null) return;
    setState(() => _lastRole = userRoleFromString(saved));
  }

  void _showHowItWorks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _HowItWorksSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SingleChildScrollView(
          child: Column(
            children: [
              const _Header(),
              SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (notice != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF2E3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(notice,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF8A6A1F))),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _RoleCard(
                            key: const ValueKey('role_customer_card'),
                            role: UserRole.customer,
                            icon: Icons.shopping_basket_outlined,
                            subtitle: 'Browse fresh produce and place orders',
                            isLastUsed: _lastRole == UserRole.customer,
                          ),
                          const SizedBox(height: 12),
                          _RoleCard(
                            key: const ValueKey('role_farmer_card'),
                            role: UserRole.farmer,
                            icon: Icons.agriculture_outlined,
                            subtitle:
                                'Manage products, orders and pickup slots',
                            isLastUsed: _lastRole == UserRole.farmer,
                          ),
                          const SizedBox(height: 12),
                          _RoleCard(
                            key: const ValueKey('role_admin_card'),
                            role: UserRole.admin,
                            icon: Icons.verified_user_outlined,
                            subtitle: 'Manage users, catalog and orders',
                            isLastUsed: _lastRole == UserRole.admin,
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              key: const ValueKey('role_how_it_works_button'),
                              onPressed: _showHowItWorks,
                              style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48)),
                              child: const Text.rich(
                                TextSpan(
                                  text: 'New here? ',
                                  style: TextStyle(
                                      fontSize: 14, color: _textMuted),
                                  children: [
                                    TextSpan(
                                      text: 'See how it works',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _brand),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topInset + 28, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A9A1F), _brand, Color(0xFF2A4A0C)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                        width: 1.5),
                  ),
                ),
                Image.asset(
                  'assets/icon/app_icon_foreground.png',
                  width: 96,
                  height: 96,
                  semanticLabel: 'HarvestHub logo',
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.eco, size: 40, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'HarvestHub',
              maxLines: 1,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How would you like to continue?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final IconData icon;
  final String subtitle;
  final bool isLastUsed;

  const _RoleCard({
    super.key,
    required this.role,
    required this.icon,
    required this.subtitle,
    required this.isLastUsed,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    final label = userRoleLabel(role);
    final isAdmin = role == UserRole.admin;

    return Semantics(
      button: true,
      label: isLastUsed ? '$label, last used. $subtitle' : '$label. $subtitle',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: isLastUsed ? _brand : const Color(0xFFE3E9DA),
            width: isLastUsed ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _brandDark.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                Navigator.of(context).pushNamed('/login', arguments: role),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? const Color(0xFFEDEFEA)
                          : const Color(0xFFEFF3EA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon,
                        size: 26, color: isAdmin ? _textMuted : _brand),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _textMain,
                              ),
                            ),
                            if (isLastUsed)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDF2E3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Last used',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF8A5A00)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                              fontSize: 13, height: 1.35, color: _textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: _brand, size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  static const List<(IconData, String, String)> _steps = [
    (
      Icons.storefront_outlined,
      'Browse local farms',
      'See fresh produce listed directly by nearby farmers.'
    ),
    (
      Icons.shopping_cart_checkout_outlined,
      'Place your order',
      'Add items to your cart and choose a pickup slot that suits you.'
    ),
    (
      Icons.shopping_bag_outlined,
      'Pick it up fresh',
      'Collect your order at the chosen pickup point and track its status in the app.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
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
              const SizedBox(height: 20),
              const Text(
                'How HarvestHub works',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textMain),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < _steps.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE7F1DA),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(_steps[i].$1, color: _brand),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${_steps[i].$2}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textMain),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _steps[i].$3,
                            style: const TextStyle(
                                fontSize: 14, height: 1.4, color: _textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const ValueKey('how_it_works_close_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Got it',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
