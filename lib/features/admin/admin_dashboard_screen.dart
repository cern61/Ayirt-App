import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/session_controller.dart';
import '../../data/models/booking.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/ui_parts.dart';
import 'admin_widgets.dart';

/// 3.1 Dashboard: genel sayılar + son rezervasyonlar
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _repo = AdminRepository();
  AdminStats? _stats;
  List<Booking> _recent = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _repo.fetchStats();
      final recent = await _repo.fetchRecentBookings();
      if (mounted) setState(() {
        _stats = stats;
        _recent = recent;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = SessionScope.of(context).profile?.fullName ?? '';
    final s = _stats;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminPageHeader(
        title: 'Dashboard',
        subtitle: name.isEmpty ? 'Hoş geldin' : 'Hoş geldin, $name 👋',
        action: IconButton(tooltip: 'Yenile', onPressed: _load, icon: const Icon(Icons.refresh)),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: EmptyState(icon: Icons.error_outline, message: _error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ---- Sayı kartları (ekran genişliğine göre 2–3 sütun) ----
                        LayoutBuilder(builder: (context, c) {
                          final cols = c.maxWidth >= 700 ? 3 : 2;
                          final w = (c.maxWidth - (cols - 1) * 12) / cols;
                          final tiles = [
                            _StatTile(icon: Icons.people, label: 'Müşteri', value: s!.customers, color: Colors.blue),
                            _StatTile(
                              icon: Icons.store,
                              label: 'İşletme',
                              value: s.businesses,
                              color: Colors.deepOrange,
                              footer: '${s.activeBusinesses} aktif · ${s.businesses - s.activeBusinesses} askıda',
                            ),
                            _StatTile(icon: Icons.event_note, label: 'Toplam rezervasyon', value: s.bookingsTotal, color: Colors.purple),
                            _StatTile(icon: Icons.today, label: 'Bugünkü rezervasyon', value: s.bookingsToday, color: Colors.green),
                            _StatTile(icon: Icons.hourglass_top, label: 'Onay bekleyen', value: s.bookingsPending, color: Colors.amber.shade800),
                          ];
                          return Wrap(spacing: 12, runSpacing: 12, children: [
                            for (final t in tiles) SizedBox(width: w, child: t),
                          ]);
                        }),
                        const SizedBox(height: 24),
                        Text('Son rezervasyonlar',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_recent.isEmpty)
                          const EmptyState(icon: Icons.event_busy, message: 'Henüz rezervasyon yok.')
                        else
                          Card(
                            margin: EdgeInsets.zero,
                            child: Column(children: [
                              for (final b in _recent)
                                ListTile(
                                  leading: BusinessAvatar(name: b.businessName, logoUrl: b.businessLogo, size: 40),
                                  title: Text('${b.businessName} ← ${b.customerName ?? 'Müşteri'}'),
                                  subtitle: Text('${fmtDayLong(b.start)} · ${fmtTime(b.start)}'),
                                  trailing: StatusChip(status: b.status),
                                ),
                            ]),
                          ),
                      ],
                    ),
                  ),
      ),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color, this.footer});
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          if (footer != null) ...[
            const SizedBox(height: 4),
            Text(footer!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ]),
      ),
    );
  }
}
