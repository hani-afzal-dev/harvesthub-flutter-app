import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/notification_model.dart';
import '../../models/push_target.dart';
import '../../providers/navigation_providers.dart';
import '../../providers/push_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/email_verify_banner.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/unread_badge.dart';
import 'assistant/ai_assistant_panel.dart';
import 'cart/cart_screen.dart';
import 'home/home_catalog_screen.dart';
import 'home/product_details_screen.dart';
import 'orders/order_history_screen.dart';
import 'profile/profile_screen.dart';
import 'wishlist/wishlist_screen.dart';
import '../../widgets/animated_chat_launcher.dart';
import '../../widgets/exit_confirm.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  static const int _ordersTab = 3;

  int _index = 0;

  late final List<Widget> _screens = [
    const HomeCatalogScreen(),
    WishlistScreen(onBack: () => setState(() => _index = 0)),
    CartScreen(onBack: () => setState(() => _index = 0)),
    OrderHistoryScreen(onBack: () => setState(() => _index = 0)),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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
      case NotificationType.restockAlert:
        final productId = target.relatedId;
        if (productId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ProductDetailsScreen(productId: productId)),
        );
      case NotificationType.orderStatus:
      case NotificationType.slotCancelled:
        setState(() => _index = _ordersTab);
      case NotificationType.newOrder:
      case NotificationType.bookingModified:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PushTarget?>(
        pendingPushTargetProvider, (previous, next) => _openPushTarget(next));
    ref.listen<int?>(customerTabRequestProvider, (previous, next) {
      if (next == null) return;
      setState(() => _index = next);
      Future.microtask(
          () => ref.read(customerTabRequestProvider.notifier).state = null);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // other tab par ho to pehle home par jao
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        askExit(context);
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(index: _index, children: _screens),
            if (_index == CustomerTabs.home)
              AnimatedChatLauncher(
                  icon: Icons.smart_toy_outlined,
                  panelBuilder: (_) => const AiAssistantPanel()),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OfflineBanner(),
            const EmailVerifyBanner(),
            AppBottomNav(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.favorite_border),
                    selectedIcon: Icon(Icons.favorite),
                    label: 'Wishlist'),
                NavigationDestination(
                    icon: Icon(Icons.shopping_cart_outlined),
                    selectedIcon: Icon(Icons.shopping_cart),
                    label: 'Cart'),
                NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Orders'),
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
  }
}