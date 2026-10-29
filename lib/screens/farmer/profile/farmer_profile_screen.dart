import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/farmer_model.dart';
import '../../../providers/farmer_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/change_password_dialog.dart';
import '../../../widgets/image_upload_field.dart';
import '../../../widgets/unread_badge.dart';
import '../../common/about_us_screen.dart';
import '../../common/contact_us_screen.dart';
import '../../customer/notifications/notifications_screen.dart';
import '../../../widgets/panel_ui.dart';

class FarmerProfileScreen extends ConsumerStatefulWidget {
  const FarmerProfileScreen({super.key});

  @override
  ConsumerState<FarmerProfileScreen> createState() =>
      _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends ConsumerState<FarmerProfileScreen> {
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _imageUrl;
  bool _editing = false;
  bool _saving = false;
  bool _submitted = false;
  bool _loggingOut = false;
  String? _error;

  @override
  void dispose() {
    _businessNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startEditing(FarmerModel farmer) {
    setState(() {
      _businessNameController.text = farmer.businessName;
      _descriptionController.text = farmer.description;
      _imageUrl = farmer.imageUrl;
      _editing = true;
      _submitted = false;
      _error = null;
    });
  }

  String? get _nameError {
    final name = _businessNameController.text.trim();
    if (name.isEmpty) return 'Enter your farm or business name.';
    if (name.length < 2 || name.length > 80) {
      return 'Use 2 to 80 characters.';
    }
    return null;
  }

  String? get _descriptionError {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return 'Tell customers a little about your farm.';
    if (description.length > 500) return 'Keep it under 500 characters.';
    return null;
  }

  Future<void> _save(FarmerModel farmer) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (_nameError != null || _descriptionError != null) return;

    setState(() => _saving = true);
    try {
      await ref.read(farmerServiceProvider).updateProfile(
            farmerId: farmer.farmerId,
            businessName: _businessNameController.text.trim(),
            description: _descriptionController.text.trim(),
            imageUrl: _imageUrl,
          );
      ref.invalidate(currentFarmerProvider);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar('Farm profile updated', tone: SnackTone.success));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save changes. Check your connection and try again.';
        _saving = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will stop getting new order alerts until you log in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: PanelColors.danger),
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
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not log out. Check your connection and try again.',
          tone: SnackTone.error));
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final farmerAsync = ref.watch(currentFarmerProvider);
    final farmer = farmerAsync.valueOrNull;

    if (farmer == null) {
      return Scaffold(
        backgroundColor: PanelColors.pageBg,
        body: SafeArea(
          child: farmerAsync.hasError
              ? AsyncErrorView(
                  title: 'Profile did not load',
                  message: 'Check your connection and try again.',
                  onRetry: () => ref.invalidate(currentFarmerProvider),
                )
              : const Center(
                  child: CircularProgressIndicator(color: PanelColors.brand)),
        ),
      );
    }

    final productCount =
        ref.watch(farmerProductsProvider(farmer.farmerId)).valueOrNull?.length;
    final canChangePassword = ref.read(authServiceProvider).hasPasswordLogin;
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const PanelHeader(
              title: 'Farm profile',
              subtitle: 'How customers see your farm',
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _ProfileHero(farmer: farmer, productCount: productCount),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                              child: PanelSectionLabel('Farm details')),
                          if (!_editing)
                            TextButton.icon(
                              key: const ValueKey('farmer_profile_edit_button'),
                              onPressed: () => _startEditing(farmer),
                              style: TextButton.styleFrom(
                                  foregroundColor: PanelColors.brand,
                                  minimumSize: const Size(48, 44)),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                        ],
                      ),
                      _editing
                          ? _buildEditCard(farmer)
                          : _buildDetailsCard(farmer),
                      const SizedBox(height: 20),
                      const PanelSectionLabel('Account'),
                      PanelCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _MenuTile(
                              icon: Icons.notifications_none_rounded,
                              iconWidget: const UnreadBadge(
                                child: Icon(Icons.notifications_none_rounded,
                                    color: PanelColors.brand, size: 20),
                              ),
                              title: 'Notifications',
                              subtitle: 'New orders, bookings and stock alerts',
                              onTap: uid == null
                                  ? null
                                  : () =>
                                      _open(NotificationsScreen(userId: uid)),
                            ),
                            if (canChangePassword) ...[
                              const Divider(height: 1, indent: 64),
                              _MenuTile(
                                icon: Icons.lock_reset_rounded,
                                title: 'Change password',
                                subtitle: 'Keep your farm account secure',
                                onTap: () => showChangePasswordDialog(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const PanelSectionLabel('Help'),
                      PanelCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _MenuTile(
                              icon: Icons.info_outline_rounded,
                              title: 'About HarvestHub',
                              onTap: () => _open(const AboutUsScreen()),
                            ),
                            const Divider(height: 1, indent: 64),
                            _MenuTile(
                              icon: Icons.support_agent_rounded,
                              title: 'Contact support',
                              onTap: () => _open(const ContactUsScreen()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          key: const ValueKey('farmer_logout_button'),
                          onPressed: _loggingOut ? null : _logout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PanelColors.danger,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFF0B4B4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _loggingOut
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: PanelColors.danger),
                                )
                              : const Icon(Icons.logout_rounded, size: 20),
                          label: const Text('Log out',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
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
    );
  }

  Widget _buildDetailsCard(FarmerModel farmer) {
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Business name',
              style: TextStyle(fontSize: 12, color: PanelColors.textMuted)),
          const SizedBox(height: 2),
          Text(farmer.businessName,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PanelColors.textMain)),
          const SizedBox(height: 14),
          const Text('About your farm',
              style: TextStyle(fontSize: 12, color: PanelColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            farmer.description.trim().isEmpty
                ? 'No description yet. Tap Edit to tell customers about your farm.'
                : farmer.description.trim(),
            style: const TextStyle(
                fontSize: 14, height: 1.5, color: PanelColors.textBody),
          ),
        ],
      ),
    );
  }

  Widget _buildEditCard(FarmerModel farmer) {
    final error = _error;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImageUploadField(
                size: 88,
                initialImageUrl: _imageUrl,
                onUploaded: (url) => setState(() => _imageUrl = url),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'A photo of you or your farm helps customers trust your shop.',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: PanelColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('farmer_business_name_field'),
            controller: _businessNameController,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            onChanged: (_) => setState(() {}),
            decoration: panelInputDecoration(
              'Business name',
              icon: Icons.storefront_outlined,
              error: _submitted ? _nameError : null,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('farmer_description_field'),
            controller: _descriptionController,
            enabled: !_saving,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: panelInputDecoration(
              'About your farm',
              hint: 'What you grow, how, and where',
              error: _submitted ? _descriptionError : null,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(error,
                style:
                    const TextStyle(fontSize: 13, color: PanelColors.danger)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving ? null : () => setState(() => _editing = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PanelColors.textBody,
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: PanelColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('farmer_profile_save_button'),
                  onPressed: _saving ? null : () => _save(farmer),
                  style: FilledButton.styleFrom(
                    backgroundColor: PanelColors.brand,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: PanelColors.brand),
                        )
                      : const Text('Save changes',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final FarmerModel farmer;
  final int? productCount;

  const _ProfileHero({required this.farmer, required this.productCount});

  @override
  Widget build(BuildContext context) {
    final imageUrl = farmer.imageUrl;
    var ratingValue = 'New';
    var ratingLabel = 'No ratings yet';
    if (farmer.ratingCount > 0) {
      ratingValue = farmer.rating.toStringAsFixed(1);
      ratingLabel =
          '${farmer.ratingCount} ${farmer.ratingCount == 1 ? 'rating' : 'ratings'}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F8A1A), PanelColors.brand, PanelColors.brandDark],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: CloudinaryService.optimizedUrl(imageUrl,
                            width: 200),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                            Icons.agriculture_rounded,
                            color: Colors.white,
                            size: 30),
                      )
                    : const Icon(Icons.agriculture_rounded,
                        color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmer.businessName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            farmer.isVerified
                                ? Icons.verified_rounded
                                : Icons.pending_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              farmer.isVerified
                                  ? 'Verified farmer'
                                  : 'Awaiting verification',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    icon: Icons.star_rounded,
                    value: ratingValue,
                    label: ratingLabel,
                  ),
                ),
                Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.25)),
                Expanded(
                  child: _HeroStat(
                    icon: Icons.inventory_2_outlined,
                    value: productCount == null ? '–' : '$productCount',
                    label: 'Products',
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

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeroStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFF3CF8C)),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ],
          ),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Widget? iconWidget;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconWidget,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final caption = subtitle;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PanelColors.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: iconWidget ??
                      Icon(icon, color: PanelColors.brand, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PanelColors.textMain)),
                    if (caption != null)
                      Text(caption,
                          style: const TextStyle(
                              fontSize: 12, color: PanelColors.textMuted)),
                  ],
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
