import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/admin_service.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/async_error_view.dart';
import '../../../widgets/panel_ui.dart';
import '../farmers/add_farmer_screen.dart';
import '../markets/admin_markets_screen.dart';
import '../promos/admin_promo_codes_screen.dart';

final _money = NumberFormat('#,##0');

class AdminDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenFarmers;

  const AdminDashboardScreen({super.key, this.onOpenFarmers});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _loggingOut = false;

  Future<void> _refresh() async {
    ref.invalidate(adminDashboardStatsProvider);
    try {
      await ref.read(adminDashboardStatsProvider.future);
    } catch (_) {
      return;
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showPanelConfirm(
      context,
      title: 'Log out?',
      message: 'You will need to log in again to manage HarvestHub.',
      confirmLabel: 'Log out',
      cancelLabel: 'Stay',
    );
    if (!confirmed || !mounted) return;

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
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final customers =
        ref.watch(adminUsersByRoleProvider(UserRole.customer)).valueOrNull;
    final farmerAccounts =
        ref.watch(adminUsersByRoleProvider(UserRole.farmer)).valueOrNull;
    final farmerProfiles = ref.watch(adminFarmerProfilesProvider).valueOrNull;
    final products = ref.watch(adminProductsProvider).valueOrNull;

    var unverified = 0;
    for (final profile in farmerProfiles ?? const []) {
      if (!profile.isVerified) unverified++;
    }
    var missingProfiles = 0;
    if (farmerAccounts != null && farmerProfiles != null) {
      final withProfile = {for (final p in farmerProfiles) p.userId};
      for (final account in farmerAccounts) {
        if (!withProfile.contains(account.userId)) missingProfiles++;
      }
    }

    Widget statsSection;
    if (statsAsync.hasError && !statsAsync.hasValue) {
      statsSection = SizedBox(
        height: 260,
        child: AsyncErrorView(
          compact: true,
          message: 'Could not load the platform overview.',
          onRetry: () => ref.invalidate(adminDashboardStatsProvider),
        ),
      );
    } else if (!statsAsync.hasValue) {
      statsSection = Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEE3),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: PanelColors.brand)),
      );
    } else {
      statsSection = _RevenueHero(stats: statsAsync.value!);
    }

    final stats = statsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            PanelHeader(
              title: 'Overview',
              subtitle: DateFormat('EEEE, d MMMM').format(DateTime.now()),
            ),
            Expanded(
              child: RefreshIndicator(
                color: PanelColors.brand,
                onRefresh: _refresh,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        statsSection,
                        const SizedBox(height: 12),
                        PanelStatStrip(stats: [
                          (
                            customers == null ? '–' : '${customers.length}',
                            'Customers'
                          ),
                          (
                            farmerAccounts == null
                                ? '–'
                                : '${farmerAccounts.length}',
                            'Farmers'
                          ),
                          (
                            products == null ? '–' : '${products.length}',
                            'Products'
                          ),
                        ]),
                        if (unverified > 0 || missingProfiles > 0) ...[
                          const SizedBox(height: 16),
                          PanelCard(
                            borderColor: const Color(0xFFF1D7A8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: PanelColors.amberBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.priority_high_rounded,
                                      color: PanelColors.amber),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Needs attention',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: PanelColors.textMain)),
                                      const SizedBox(height: 4),
                                      if (unverified > 0)
                                        Text(
                                          '$unverified ${unverified == 1 ? 'farmer is' : 'farmers are'} waiting for verification',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: PanelColors.textBody),
                                        ),
                                      if (missingProfiles > 0)
                                        Text(
                                          '$missingProfiles farmer ${missingProfiles == 1 ? 'account has' : 'accounts have'} no farm profile',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: PanelColors.textBody),
                                        ),
                                      if (widget.onOpenFarmers != null)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            key: const ValueKey(
                                                'admin_review_farmers_button'),
                                            onPressed: widget.onOpenFarmers,
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  PanelColors.brand,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(48, 40),
                                            ),
                                            child:
                                                const Text('Review farmers ›'),
                                          ),
                                        )
                                      else
                                        const Text(
                                            'Open the Farmers tab to review.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: PanelColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        const PanelSectionLabel('Manage'),
                        PanelCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _ActionTile(
                                key: const ValueKey('admin_promo_codes_button'),
                                icon: Icons.local_offer_outlined,
                                title: 'Promo codes',
                                subtitle: 'Create and pause discount codes',
                                onTap: () =>
                                    _open(const AdminPromoCodesScreen()),
                              ),
                              const Divider(height: 1, indent: 64),
                              _ActionTile(
                                icon: Icons.person_add_alt_1_outlined,
                                title: 'Add a farmer',
                                subtitle: 'Create a login for a new farm',
                                onTap: () => _open(const AddFarmerScreen()),
                              ),
                              const Divider(height: 1, indent: 64),
                              _ActionTile(
                                key: const ValueKey('admin_markets_button'),
                                icon: Icons.storefront_outlined,
                                title: 'Farmers\' markets',
                                subtitle: 'Add markets, hours and locations',
                                onTap: () => _open(const AdminMarketsScreen()),
                              ),
                            ],
                          ),
                        ),
                        if (stats != null) ...[
                          const SizedBox(height: 22),
                          const PanelSectionLabel('Revenue by market'),
                          _MarketBars(revenueByMarket: stats.revenueByMarket),
                          const SizedBox(height: 22),
                          const PanelSectionLabel('Most active farmers'),
                          _TopFarmers(topFarmers: stats.topFarmers),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            key: const ValueKey('admin_logout_button'),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueHero extends StatelessWidget {
  final AdminDashboardStats stats;

  const _RevenueHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final average =
        stats.totalOrders == 0 ? 0.0 : stats.totalRevenue / stats.totalOrders;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F8A1A), PanelColors.brand, PanelColors.brandDark],
        ),
        boxShadow: [
          BoxShadow(
            color: PanelColors.brandDark.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text('Total sales',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9))),
              const Spacer(),
              Text('Excludes cancelled',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rs. ${_money.format(stats.totalRevenue.round())}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child:
                    _HeroFigure(value: '${stats.totalOrders}', label: 'Orders'),
              ),
              Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 14),
              Expanded(
                child: _HeroFigure(
                  value: 'Rs. ${_money.format(average.round())}',
                  label: 'Avg. order',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  final String value;
  final String label;

  const _HeroFigure({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _MarketBars extends StatelessWidget {
  final Map<String, double> revenueByMarket;

  const _MarketBars({required this.revenueByMarket});

  @override
  Widget build(BuildContext context) {
    if (revenueByMarket.isEmpty) {
      return const PanelCard(
        child: Text('No sales yet. Market totals appear after the first order.',
            style: TextStyle(fontSize: 13, color: PanelColors.textMuted)),
      );
    }

    final entries = revenueByMarket.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var maxValue = 1.0;
    for (final entry in entries) {
      if (entry.value > maxValue) maxValue = entry.value;
    }

    return PanelCard(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Semantics(
              label:
                  '${entries[i].key}, Rs. ${_money.format(entries[i].value.round())}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 16, color: PanelColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(entries[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: PanelColors.textMain)),
                      ),
                      Text(
                        'Rs. ${_money.format(entries[i].value.round())}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PanelColors.brand,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entries[i].value / maxValue,
                      minHeight: 8,
                      color: PanelColors.brand,
                      backgroundColor: PanelColors.tint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopFarmers extends StatelessWidget {
  final List<MapEntry<String, int>> topFarmers;

  const _TopFarmers({required this.topFarmers});

  @override
  Widget build(BuildContext context) {
    if (topFarmers.isEmpty) {
      return const PanelCard(
        child: Text('No orders placed yet.',
            style: TextStyle(fontSize: 13, color: PanelColors.textMuted)),
      );
    }
    return PanelCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < topFarmers.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: PanelColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? PanelColors.amberBg : PanelColors.tint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? PanelColors.amber : PanelColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(topFarmers[i].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PanelColors.textMain)),
                  ),
                  Text(
                    '${topFarmers[i].value} ${topFarmers[i].value == 1 ? 'order' : 'orders'}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PanelColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
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
                child: Icon(icon, color: PanelColors.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PanelColors.textMain)),
                    Text(subtitle,
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
