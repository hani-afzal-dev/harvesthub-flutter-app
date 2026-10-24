import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E4A0F).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: const Color(0xFFDDEBCB),
          indicatorShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? const Color(0xFF2E4A0F)
                  : const Color(0xFF6B7A5E),
            );
          }),
        ),
        child: NavigationBar(
          height: 68,
          elevation: 0,
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index != selectedIndex) HapticFeedback.selectionClick();
            onDestinationSelected(index);
          },
          backgroundColor: Colors.white,
          destinations: destinations,
        ),
      ),
    );
  }
}
