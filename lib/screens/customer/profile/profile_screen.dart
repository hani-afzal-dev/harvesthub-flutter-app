import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/phone_numbers.dart';
import '../../../core/validators.dart';
import '../../../models/user_model.dart';
import '../../../providers/follow_providers.dart';
import '../../../providers/order_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../providers/wishlist_providers.dart';
import '../../../widgets/animated_auth_field.dart';
import '../../../widgets/phone_number_field.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/change_password_dialog.dart';
import '../../../widgets/delete_account_sheet.dart';
import '../../../widgets/unread_badge.dart';
import '../../common/about_us_screen.dart';
import '../../common/contact_us_screen.dart';
import '../farmers/my_farmers_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../../widgets/app_snackbar.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);
const Color _tint = Color(0xFFEFF3EA);
const Color _pageBg = Color(0xFFF6F8F3);
const Color _danger = Color(0xFFD64545);

String _initials(String name) {
  final parts = <String>[];
  for (final part in name.trim().split(RegExp(r'\s+'))) {
    if (part.isNotEmpty) parts.add(part);
  }
  if (parts.isEmpty) return '?';
  var letters = parts.first[0];
  if (parts.length > 1) letters += parts.last[0];
  return letters.toUpperCase();
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _loggingOut = false;
  DialCountry _phoneCountry = defaultDialCountry;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<UserModel?>>(
      sessionProfileProvider,
      (_, next) => _fillFields(next.valueOrNull),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _fillFields(UserModel? user) {
    if (user == null) return;
    _nameController.text = user.name;
    final phone = splitStoredPhone(user.phone);
    _phoneCountry = phone.$1;
    _phoneController.text = phone.$2;
    _addressController.text = user.address;
  }

  void _toggleEditing(UserModel user) {
    if (ref.read(profileEditProvider).editing) {
      setState(() => _fillFields(user));
    }
    ref.read(profileEditProvider.notifier).toggleEditing();
  }

  Future<void> _save() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    FocusScope.of(context).unfocus();
    final saved = await ref.read(profileEditProvider.notifier).save(
          uid: uid,
          name: _nameController.text,
          phone: toE164(_phoneCountry, _phoneController.text),
          address: _addressController.text,
        );
    if (!saved || !mounted) return;
    ref.invalidate(sessionProfileProvider);
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(appSnackBar('Profile updated.', tone: SnackTone.success));
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to place orders.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await ref.read(authServiceProvider).logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/roles', (route) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar('Could not log out. Check your connection and try again.',
            tone: SnackTone.error),
      );
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(sessionProfileProvider);
    final user = userAsync.valueOrNull;

    if (user == null) {
      if (userAsync.isLoading) {
        return const Scaffold(
            backgroundColor: _pageBg,
            body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        backgroundColor: _pageBg,
        body: AsyncErrorView(
          message:
              'Could not load your profile. Check your connection and try again.',
          onRetry: () => ref.invalidate(sessionProfileProvider),
        ),
      );
    }

    final edit = ref.watch(profileEditProvider);
    final authService = ref.read(authServiceProvider);
    final usesGoogle = authService.usesGoogleLogin;
    final canChangePassword = authService.hasPasswordLogin;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 96),
          child: Column(
            children: [
              _ProfileHeader(user: user, usesGoogle: usesGoogle),
              Transform.translate(
                offset: const Offset(0, -36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StatsCard(uid: user.userId),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            title: 'PERSONAL DETAILS',
                            trailing: TextButton.icon(
                              key: const ValueKey('profile_edit_button'),
                              onPressed: edit.saving
                                  ? null
                                  : () => _toggleEditing(user),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    edit.editing ? _textMuted : _brand,
                                minimumSize: const Size(48, 40),
                              ),
                              icon: Icon(
                                  edit.editing
                                      ? Icons.close
                                      : Icons.edit_outlined,
                                  size: 18),
                              label: Text(
                                edit.editing ? 'Cancel' : 'Edit',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          _Card(
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              alignment: Alignment.topCenter,
                              child: edit.editing
                                  ? _buildEditForm(edit)
                                  : _buildDetails(user),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _SectionTitle(title: 'ACCOUNT'),
                          _Card(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _MenuTile(
                                  key: const ValueKey(
                                      'profile_notifications_tile'),
                                  icon: Icons.notifications_none_rounded,
                                  label: 'Notifications',
                                  badge: true,
                                  onTap: () => _open(
                                      NotificationsScreen(userId: user.userId)),
                                ),
                                const _TileDivider(),
                                _MenuTile(
                                  key: const ValueKey('profile_farmers_tile'),
                                  icon: Icons.agriculture_outlined,
                                  label: 'Farmers you follow',
                                  onTap: () => _open(const MyFarmersScreen()),
                                ),
                                if (canChangePassword) ...[
                                  const _TileDivider(),
                                  _MenuTile(
                                    key: const ValueKey(
                                        'profile_change_password_tile'),
                                    icon: Icons.lock_reset_rounded,
                                    label: 'Change password',
                                    onTap: () =>
                                        showChangePasswordDialog(context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _SectionTitle(title: 'SUPPORT'),
                          _Card(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _MenuTile(
                                  key: const ValueKey('profile_about_tile'),
                                  icon: Icons.info_outline_rounded,
                                  label: 'About us',
                                  onTap: () => _open(const AboutUsScreen()),
                                ),
                                const _TileDivider(),
                                _MenuTile(
                                  key: const ValueKey('profile_contact_tile'),
                                  icon: Icons.mail_outline_rounded,
                                  label: 'Contact us',
                                  onTap: () => _open(const ContactUsScreen()),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              key: const ValueKey('profile_logout_button'),
                              onPressed: _loggingOut ? null : _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _danger,
                                backgroundColor: Colors.white,
                                side:
                                    const BorderSide(color: Color(0xFFF0C4C4)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: _loggingOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: _danger),
                                    )
                                  : const Icon(Icons.logout_rounded, size: 20),
                              label: const Text('Log out',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              key: const ValueKey(
                                  'profile_delete_account_button'),
                              onPressed: _loggingOut
                                  ? null
                                  : () => showDeleteAccountSheet(context),
                              style: TextButton.styleFrom(
                                foregroundColor: _textMuted,
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Text('Delete my account',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline)),
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

  Widget _buildDetails(UserModel user) {
    return Column(
      key: const ValueKey('profile_details_view'),
      children: [
        _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Full name',
            value: user.name),
        const _TileDivider(indent: 44),
        _DetailRow(
            icon: Icons.phone_outlined, label: 'Phone', value: user.phone),
        const _TileDivider(indent: 44),
        _DetailRow(
          icon: Icons.home_outlined,
          label: 'Pickup address',
          value: user.address.isEmpty ? 'Add your address' : user.address,
          muted: user.address.isEmpty,
        ),
      ],
    );
  }

  Widget _buildEditForm(ProfileEditState edit) {
    final error = edit.error;
    return Column(
      key: const ValueKey('profile_edit_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedAuthField(
          key: const ValueKey('profile_name_field'),
          controller: _nameController,
          label: 'Full name',
          icon: Icons.person_outline_rounded,
          accentColor: _brand,
          validator: Validators.isValidName,
          errorText: 'Name should only contain letters and spaces',
        ),
        const SizedBox(height: 12),
        PhoneNumberField(
          fieldKey: const ValueKey('profile_phone_field'),
          controller: _phoneController,
          country: _phoneCountry,
          label: 'Mobile number',
          onCountryChanged: (country) =>
              setState(() => _phoneCountry = country),
        ),
        const SizedBox(height: 12),
        AnimatedAuthField(
          key: const ValueKey('profile_address_field'),
          controller: _addressController,
          label: 'Pickup address',
          icon: Icons.home_outlined,
          accentColor: _brand,
          validator: Validators.isValidAddress,
          errorText: 'Address is required (up to 200 characters)',
          errorMessage: Validators.addressError,
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error,
              style: const TextStyle(fontSize: 13, color: Color(0xFFB3261E))),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const ValueKey('profile_save_button'),
            onPressed: edit.saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: edit.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: _brand, strokeWidth: 2),
                  )
                : const Text('Save changes',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final bool usesGoogle;

  const _ProfileHeader({required this.user, required this.usesGoogle});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A9A1F), _brand, Color(0xFF2A4A0C)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white),
              child: Semantics(
                label: 'Profile picture',
                excludeSemantics: true,
                child: Text(
                  _initials(user.name),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: _brand),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14, color: Colors.white.withValues(alpha: 0.88)),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderPill(
                  icon: Icons.shopping_basket_outlined,
                  label: userRoleLabel(user.role)),
              if (usesGoogle)
                const _HeaderPill(
                    icon: Icons.verified_user_outlined,
                    label: 'Google account'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  final String uid;

  const _StatsCard({required this.uid});

  String _value(AsyncValue<int> async) {
    final count = async.valueOrNull;
    if (count != null) return '$count';
    if (async.isLoading) return '…';
    return '–';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(customerOrderCountProvider(uid));
    final wishlist =
        ref.watch(wishlistIdsProvider(uid)).whenData((ids) => ids.length);
    final following =
        ref.watch(followedFarmerIdsProvider(uid)).whenData((ids) => ids.length);

    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Stat(value: _value(orders), label: 'Orders'),
            const VerticalDivider(width: 1, color: Color(0xFFE6EBDF)),
            _Stat(value: _value(wishlist), label: 'Wishlist'),
            const VerticalDivider(width: 1, color: Color(0xFFE6EBDF)),
            _Stat(value: _value(following), label: 'Following'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _brand,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final action = trailing;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: _textMuted),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _brandDark.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _tint, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: _brand),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: _textMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: muted ? _textMuted : _textMain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool badge;

  const _MenuTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap,
      this.badge = false});

  @override
  Widget build(BuildContext context) {
    Widget leading = Icon(icon, size: 20, color: _brand);
    if (badge) leading = UnreadBadge(child: leading);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _tint, borderRadius: BorderRadius.circular(10)),
                child: leading,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textMain),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFA3AC9A)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  final double indent;

  const _TileDivider({this.indent = 64});

  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1,
        thickness: 1,
        indent: indent,
        color: const Color(0xFFEEF1EA));
  }
}
