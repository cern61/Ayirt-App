import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/models/booking.dart';
import '../../shared/ui_parts.dart';

/// Admin sayfalarının üst başlığı
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(color: Colors.grey.shade600)),
          ]),
        ),
        if (action != null) action!,
      ]),
    );
  }
}

/// Arama kutusu (admin listeleri için)
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({super.key, required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search), isDense: true),
    );
  }
}

/// Rezervasyonları alt alta gösteren bottom sheet (müşteri / işletme detayında)
Future<void> showBookingsSheet(
  BuildContext context, {
  required String title,
  required Future<List<Booking>> Function() loader,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _BookingsSheet(title: title, loader: loader),
  );
}

class _BookingsSheet extends StatefulWidget {
  const _BookingsSheet({required this.title, required this.loader});
  final String title;
  final Future<List<Booking>> Function() loader;

  @override
  State<_BookingsSheet> createState() => _BookingsSheetState();
}

class _BookingsSheetState extends State<_BookingsSheet> {
  // Veriyi bir kez çek (sayfa sürüklenip yeniden çizildiğinde tekrar istek atmasın)
  late final Future<List<Booking>> _future = widget.loader();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: EmptyState(icon: Icons.error_outline, message: '${snap.error}'));
          }
          final items = snap.data ?? [];
          return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const EmptyState(icon: Icons.event_busy, message: 'Rezervasyon yok.')
            else
              for (final b in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${b.businessName} · ${b.customerName ?? 'Müşteri'}'),
                  subtitle: Text('${fmtDayLong(b.start)} · ${fmtTime(b.start)}'
                      '${b.serviceName != null ? ' · ${b.serviceName}' : ''}'),
                  trailing: StatusChip(status: b.status),
                ),
          ]);
        },
      ),
    );
  }
}
