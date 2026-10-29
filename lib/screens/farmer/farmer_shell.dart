import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_model.dart';
import '../../models/push_target.dart';
import '../../providers/push_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/animated_chat_launcher.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/unread_badge.dart';
import 'guide/farmer_guide_panel.dart';
import 'orders/farmer_orders_screen.dart';
import 'pickup/farmer_pickup_slots_screen.dart';
import 'products/farmer_products_screen.dart';
import 'profile/farmer_profile_screen.dart';
import 'reports/farmer_reports_screen.dart';
import '../../widgets/panel_ui.dart';
import '../../services/push_permission.dart';
import '../../widgets/exit_confirm.dart';

class FarmerShell extends ConsumerStatefulWidget {
  const FarmerShell({super.key});

  @override
  ConsumerState<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends ConsumerState<FarmerShell> {
  static const int _productsTab = 0;
  static const int _ordersTab = 1;

  int _index = 0;

  @override
  void initState() {
    super.initState();
    askForPushPermission();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPushTarget(ref.read(pendingPushTargetProvider)));
  }

  void _openPushTarget(PushTarget? target) {
    if (target == null || !mounted) return;
    ref.read(pendingPushTargetProvider.notifier).state = null;
    if (target.userId != ref.read(currentUidProvider)) return;

    final shellRoute = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == shellRoute);

    switch (target.type) {
      case NotificationType.newOrder:
      case NotificationType.bookingModified:
        setState(() => _index = _ordersTab);
      case NotificationType.restockAlert:
        setState(() => _index = _productsTab);
      case NotificationType.orderStatus:
      case NotificationType.slotCancelled:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PushTarget?>(
        pendingPushTargetProvider, (previous, next) => _openPushTarget(next));

    final farmerAsync = ref.watch(currentFarmerProvider);

    return farmerAsync.when(
      loading: () => const Scaffold(
        backgroundColor: PanelColors.pageBg,
        body:
            Center(child: CircularProgressIndicator(color: PanelColors.brand)),
      ),
      error: (_, __) => const _FarmerMissingView(),
      data: (farmer) {
        if (farmer == null) {
          return const _FarmerMissingView();
        }

        final screens = [
          FarmerProductsScreen(farmerId: farmer.farmerId),
          FarmerOrdersScreen(farmerId: farmer.farmerId),
          FarmerPickupSlotsScreen(farmerId: farmer.farmerId),
          FarmerReportsScreen(farmerId: farmer.farmerId),
          const FarmerProfileScreen(),
        ];

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // other tab par ho to pehle products par jao
            if (_index != 0) {
              setState(() => _index = 0);
              return;
            }
            askExit(context);
          },
          child: Scaffold(
            body: Stack(
              children: [
                IndexedStack(index: _index, children: screens),
                AnimatedChatLauncher(
                  icon: Icons.help_outline_rounded,
                  alignment: Alignment.bottomLeft,
                  panelBuilder: (_) =>
                      FarmerGuidePanel(initialTopicIndex: _index),
                  openLabel: 'Open help guide',
                  closeLabel: 'Close help guide',
                  openTooltip: 'Need help? Open the guide',
                  closeTooltip: 'Close guide',
                ),
              ],
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OfflineBanner(),
                AppBottomNav(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.eco_outlined),
                        selectedIcon: Icon(Icons.eco),
                        label: 'Products'),
                    NavigationDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: 'Orders'),
                    NavigationDestination(
                        icon: Icon(Icons.event_outlined),
                        selectedIcon: Icon(Icons.event),
                        label: 'Slots'),
                    NavigationDestination(
                        icon: Icon(Icons.insert_chart_outlined),
                        selectedIcon: Icon(Icons.insert_chart),
                        label: 'Reports'),
                    NavigationDestination(
                      icon: UnreadBadge(child: Icon(Icons.person_outline)),
                      selectedIcon: UnreadBadge(child: Icon(Icons.person)),
                      label: 'Profile',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
class _FarmerMissingView extends ConsumerWidget {
  const _FarmerMissingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: PanelColors.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: PanelColors.amberBg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.agriculture_rounded,
                      size: 34, color: PanelColors.amber),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Farm profile not found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PanelColors.textMain),
                ),
                const SizedBox(height: 6),
                const Text(
                  'We could not load your farm. Check your connection, or contact an administrator if this keeps happening.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.45, color: PanelColors.textMuted),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref.invalidate(currentFarmerProvider),
                  style: FilledButton.styleFrom(
                    backgroundColor: PanelColors.brand,
                    minimumSize: const Size(180, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await ref.read(authServiceProvider).logout();
                    if (!context.mounted) return;
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/roles', (route) => false);
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: PanelColors.danger,
                      minimumSize: const Size(48, 48)),
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
