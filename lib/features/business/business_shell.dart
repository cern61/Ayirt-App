import 'package:flutter/material.dart';

import '../../core/session_controller.dart';
import '../../data/models/my_business.dart';
import '../../data/repositories/my_business_repository.dart';
import '../../shared/ui_parts.dart';
import 'business_bookings_screen.dart';
import 'business_profile_screen.dart';
import 'calendar_settings_screen.dart';

/// İşletme: 2.1 Rezervasyon planı (Rezervasyonlar + Takvim ayarları)  |  2.2 Profilim
///
/// İşletme bilgisi burada bir kez yüklenir ve alt ekranlara verilir.
/// Bir ekran bilgiyi değiştirince [_load] ile hepsi tazelenir.
class BusinessShell extends StatefulWidget {
  const BusinessShell({super.key});

  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  final _repo = MyBusinessRepository();
  MyBusiness? _business;
  String? _error;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await _repo.fetchMyBusiness();
      if (mounted) setState(() {
        _business = b;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _business;

    if (b == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : EmptyState(
                  icon: Icons.error_outline,
                  message: 'İşletme bilgisi yüklenemedi:\n$_error',
                  action: OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
                ),
        ),
      );
    }

    return Scaffold(
      body: Column(children: [
        // Admin işletmeyi askıya aldıysa uyarı göster
        if (!b.isActive)
          MaterialBanner(
            backgroundColor: Colors.red.shade50,
            leading: Icon(Icons.block, color: Colors.red.shade700),
            content: const Text('İşletmen şu an askıda. Müşteriler seni aramada göremez. Destek için yöneticiyle iletişime geç.'),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              _PlanTab(business: b, onChanged: _load),
              BusinessProfileScreen(business: b, onChanged: _load),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Profilim'),
        ],
      ),
    );
  }
}

/// 2.1 Rezervasyon planı: üstte iki sekme
class _PlanTab extends StatelessWidget {
  const _PlanTab({required this.business, required this.onChanged});
  final MyBusiness business;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(business.name),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.event_note), text: 'Rezervasyonlar'),
            Tab(icon: Icon(Icons.tune), text: 'Takvim ayarları'),
          ]),
        ),
        body: TabBarView(children: [
          BusinessBookingsScreen(business: business),
          CalendarSettingsScreen(business: business, onSaved: onChanged),
        ]),
      ),
    );
  }
}
