import 'package:flutter/material.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'customers/admin_customers_screen.dart';
import 'farmers/admin_farmers_screen.dart';
import 'catalog/admin_catalog_screen.dart';
import 'orders/admin_orders_screen.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/exit_confirm.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  late final List<Widget> _screens = [
    AdminDashboardScreen(onOpenFarmers: () => setState(() => _index = 2)),
    const AdminCustomersScreen(),
    const AdminFarmersScreen(),
    const AdminCatalogScreen(),
    const AdminOrdersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // other tab par ho to pehle overview par jao
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        askExit(context);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OfflineBanner(),
            AppBottomNav(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Overview'),
                NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: 'Customers'),
                NavigationDestination(
                    icon: Icon(Icons.agriculture_outlined),
                    selectedIcon: Icon(Icons.agriculture),
                    label: 'Farmers'),
                NavigationDestination(
                    icon: Icon(Icons.eco_outlined),
                    selectedIcon: Icon(Icons.eco),
                    label: 'Catalog'),
                NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Orders'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}