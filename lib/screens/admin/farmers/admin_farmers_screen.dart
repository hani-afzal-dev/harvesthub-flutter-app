import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/farmer_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/panel_ui.dart';
import 'add_farmer_screen.dart';

class AdminFarmersScreen extends ConsumerStatefulWidget {
  const AdminFarmersScreen({super.key});

  @override
  ConsumerState<AdminFarmersScreen> createState() => _AdminFarmersScreenState();
}

class _AdminFarmersScreenState extends ConsumerState<AdminFarmersScreen> {
  static const _filterLabels = ['All', 'Unverified', 'No profile', 'Disabled'];

  final _searchController = TextEditingController();
  final Set<String> _busy = {};
  String _query = '';
  int _filter = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(UserModel account, FarmerModel? profile, int filter) {
    switch (filter) {
      case 1:
        return profile != null && !profile.isVerified;
      case 2:
        return profile == null;
      case 3:
        return !account.isActive;
      default:
        return true;
    }
  }

  void _retry() {
    ref.invalidate(adminUsersByRoleProvider(UserRole.farmer));
    ref.invalidate(adminFarmerProfilesProvider);
  }

  void _openAdd() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddFarmerScreen()));
  }

  String _displayName(UserModel account, FarmerModel? profile) {
    if (profile != null && profile.businessName.isNotEmpty) {
      return profile.businessName;
    }
    return account.name;
  }

  Future<void> _toggleVerified(UserModel account, FarmerModel profile) async {
    if (_busy.contains(account.userId)) return;
    final name = _displayName(account, profile);
    if (profile.isVerified) {
      final confirmed = await showPanelConfirm(
        context,
        title: 'Remove verification?',
        message: 'Customers will no longer see the verified badge on $name.',
        confirmLabel: 'Unverify',
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busy.add(account.userId));
    try {
      await ref
          .read(adminServiceProvider)
          .setFarmerVerified(profile.farmerId, !profile.isVerified);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        profile.isVerified ? '$name is no longer verified' : '$name verified',
        tone: SnackTone.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update $name. Try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(account.userId));
    }
  }

  Future<void> _toggleActive(UserModel account, FarmerModel? profile) async {
    if (_busy.contains(account.userId)) return;
    final adminService = ref.read(adminServiceProvider);
    final name = _displayName(account, profile);
    setState(() => _busy.add(account.userId));

    try {
      if (account.isActive) {
        final activeOrders =
            await adminService.getActiveOrderCount(account.userId);
        if (!mounted) return;
        var message =
            '$name will be signed out right away and cannot log in until you enable the account again.';
        if (activeOrders > 0) {
          message =
              '$name has $activeOrders active ${activeOrders == 1 ? 'order' : 'orders'}. Disabling will not cancel them, but the farmer will be signed out and cannot handle them.';
        }
        final confirmed = await showPanelConfirm(
          context,
          title: 'Disable this farmer?',
          message: message,
          confirmLabel: 'Disable',
        );
        if (!confirmed || !mounted) return;
      }
      await adminService.setUserActive(account.userId, !account.isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
        account.isActive ? '$name disabled' : '$name enabled',
        tone: SnackTone.success,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(appSnackBar(
          'Could not update the account. Please try again.',
          tone: SnackTone.error));
    } finally {
      if (mounted) setState(() => _busy.remove(account.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(adminUsersByRoleProvider(UserRole.farmer));
    final profilesAsync = ref.watch(adminFarmerProfilesProvider);
    final accounts = accountsAsync.valueOrNull;
    final profileList = profilesAsync.valueOrNull;

    Widget body;
    if ((accountsAsync.hasError && accounts == null) ||
        (profilesAsync.hasError && profileList == null)) {
      body =
          AsyncErrorView(message: 'Could not load farmers.', onRetry: _retry);
    } else if (accounts == null || profileList == null) {
      body = const Center(
          child: CircularProgressIndicator(color: PanelColors.brand));
    } else if (accounts.isEmpty) {
      body = PanelEmptyState(
        icon: Icons.agriculture_outlined,
        title: 'No farmers yet',
        message:
            'Farmers cannot sign up on their own. Create their account to get them selling.',
        actionLabel: 'Add farmer',
        onAction: _openAdd,
      );
    } else {
      final profiles = {for (final f in profileList) f.userId: f};
      final searched = accounts.where((a) {
        final profile = profiles[a.userId];
        return matchesSearch(
            _query, [a.name, a.email, profile?.businessName ?? '']);
      }).toList();
      final counts = List<int>.generate(
        _filterLabels.length,
        (i) => searched
            .where((a) => _matchesFilter(a, profiles[a.userId], i))
            .length,
      );
      final visible = searched
          .where((a) => _matchesFilter(a, profiles[a.userId], _filter))
          .toList();

      body = CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: PanelSearchField(
              controller: _searchController,
              hint: 'Search by farm, name or email',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          SliverToBoxAdapter(
            child: FilterChipBar(
              labels: _filterLabels,
              counts: counts,
              selected: _filter,
              onSelected: (i) => setState(() => _filter = i),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: PanelEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matches',
                message: 'Try a different search or filter.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final account = visible[index];
                  final profile = profiles[account.userId];
                  return _FarmerCard(
                    key: ValueKey('admin_farmer_${account.userId}'),
                    account: account,
                    profile: profile,
                    busy: _busy.contains(account.userId),
                    onToggleVerified: profile == null
                        ? null
                        : () => _toggleVerified(account, profile),
                    onToggleActive: () => _toggleActive(account, profile),
                  );
                },
              ),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_farmer_button'),
        backgroundColor: PanelColors.brand,
        foregroundColor: Colors.white,
        onPressed: _openAdd,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add farmer',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PanelHeader(
              title: 'Farmers',
              subtitle: accounts == null
                  ? 'Farms selling on HarvestHub'
                  : '${accounts.length} farm ${accounts.length == 1 ? 'account' : 'accounts'}',
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  final UserModel account;
  final FarmerModel? profile;
  final bool busy;
  final VoidCallback? onToggleVerified;
  final VoidCallback onToggleActive;

  const _FarmerCard({
    super.key,
    required this.account,
    required this.profile,
    required this.busy,
    required this.onToggleVerified,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final farm = profile;
    final imageUrl = farm?.imageUrl;
    final title = farm != null && farm.businessName.isNotEmpty
        ? farm.businessName
        : account.name;
    final toggleVerified = onToggleVerified;

    Widget avatar = PanelAvatar(
      name: title,
      icon: Icons.agriculture_rounded,
      muted: !account.isActive,
    );
    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: CachedNetworkImage(
            imageUrl: CloudinaryService.optimizedUrl(imageUrl, width: 160),
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => avatar,
          ),
        ),
      );
    }

    var ratingText = 'No ratings yet';
    if (farm != null && farm.ratingCount > 0) {
      ratingText =
          '${farm.rating.toStringAsFixed(1)} (${farm.ratingCount} ${farm.ratingCount == 1 ? 'rating' : 'ratings'})';
    }

    return PanelCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PanelColors.textMain),
                    ),
                    if (farm != null && account.name != title)
                      Text(account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: PanelColors.textBody)),
                    Text(account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: PanelColors.textMuted)),
                    if (farm != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            farm.ratingCount > 0
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 15,
                            color: const Color(0xFFEF9F27),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(ratingText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: PanelColors.textMuted)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (farm == null)
                const StatusPill(
                  label: 'No farm profile',
                  icon: Icons.report_gmailerrorred_rounded,
                  color: PanelColors.amber,
                  background: PanelColors.amberBg,
                )
              else if (farm.isVerified)
                const StatusPill(
                  label: 'Verified',
                  icon: Icons.verified_rounded,
                  color: PanelColors.brand,
                  background: PanelColors.tint,
                )
              else
                const StatusPill(
                  label: 'Awaiting verification',
                  icon: Icons.pending_outlined,
                  color: PanelColors.amber,
                  background: PanelColors.amberBg,
                ),
              if (!account.isActive)
                const StatusPill(
                  label: 'Disabled',
                  icon: Icons.block_rounded,
                  color: PanelColors.danger,
                  background: PanelColors.dangerBg,
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: PanelColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: PanelColors.brand),
                  ),
                ),
              if (toggleVerified != null && farm != null)
                TextButton.icon(
                  key: ValueKey('admin_farmer_verify_${account.userId}'),
                  onPressed: busy ? null : toggleVerified,
                  style: TextButton.styleFrom(
                    foregroundColor: farm.isVerified
                        ? PanelColors.textBody
                        : PanelColors.brand,
                    minimumSize: const Size(0, 44),
                  ),
                  icon: Icon(
                      farm.isVerified
                          ? Icons.remove_moderator_outlined
                          : Icons.verified_outlined,
                      size: 18),
                  label: Text(farm.isVerified ? 'Unverify' : 'Verify'),
                ),
              TextButton.icon(
                key: ValueKey('admin_farmer_toggle_${account.userId}'),
                onPressed: busy ? null : onToggleActive,
                style: TextButton.styleFrom(
                  foregroundColor:
                      account.isActive ? PanelColors.danger : PanelColors.brand,
                  minimumSize: const Size(0, 44),
                ),
                icon: Icon(
                    account.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 18),
                label: Text(account.isActive ? 'Disable' : 'Enable'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
