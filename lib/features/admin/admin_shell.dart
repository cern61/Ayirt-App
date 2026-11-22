import 'package:flutter/material.dart';

import '../../core/session_controller.dart';
import '../../shared/widgets.dart';
import 'admin_businesses_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_settings_screen.dart';

/// Admin: tek ekran, solda panel → Dashboard | Müşteriler | İşletmeler | Ayarlar
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _pages = [
    AdminDashboardScreen(),
    AdminCustomersScreen(),
    AdminBusinessesScreen(),
    AdminSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Geniş ekranda (tablet/web) panel etiketli açılır, telefonda dar kalır
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SafeArea(
        child: Row(children: [
          NavigationRail(
            extended: wide,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AyirtLogo(size: wide ? 72 : 44),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: IconButton(
                tooltip: 'Çıkış yap',
                icon: const Icon(Icons.logout),
                onPressed: SessionScope.of(context).signOut,
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Müşteriler')),
              NavigationRailDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: Text('İşletmeler')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Ayarlar')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index])),
        ]),
      ),
    );
  }
}
