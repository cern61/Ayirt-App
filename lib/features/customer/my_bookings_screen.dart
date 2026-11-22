import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/session_controller.dart';
import '../../data/models/booking.dart';
import '../../data/repositories/booking_repository.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';

/// Müşterinin rezervasyon geçmişi: Yaklaşan / Geçmiş sekmeleri
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _repo = BookingRepository();
  List<Booking> _all = [];
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
      final list = await _repo.fetchMyBookings();
      if (mounted) setState(() => _all = list);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezervasyon iptal edilsin mi?'),
        content: Text('${b.businessName}\n${fmtDayLong(b.start)} · ${fmtTime(b.start)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('İptal et')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancel(b.id);
      if (mounted) showMessage(context, 'Rezervasyon iptal edildi.');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _review(Booking b) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReviewSheet(booking: b, repo: _repo),
    );
    if (saved == true) {
      if (mounted) showMessage(context, 'Yorumun için teşekkürler! ⭐');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Yaklaşanlar: en yakın tarih en üstte. Geçmişler: en yeni en üstte.
    final upcoming = _all.where((b) => b.isUpcoming && b.status != BookingStatus.cancelled).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final past = _all.where((b) => !b.isUpcoming || b.status == BookingStatus.cancelled).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rezervasyonlarım'),
          bottom: TabBar(tabs: [
            Tab(text: 'Yaklaşan (${upcoming.length})'),
            Tab(text: 'Geçmiş (${past.length})'),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: EmptyState(
                      icon: Icons.error_outline,
                      message: _error!,
                      action: OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
                    ),
                  )
                : TabBarView(children: [
                    _list(upcoming, 'Yaklaşan rezervasyonun yok.\nKeşfet sekmesinden bir işletme seçerek başlayabilirsin.'),
                    _list(past, 'Geçmiş rezervasyonun yok.'),
                  ]),
      ),
    );
  }

  Widget _list(List<Booking> items, String emptyText) {
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(children: [EmptyState(icon: Icons.event_note, message: emptyText)])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _BookingCard(
                booking: items[i],
                onCancel: () => _cancel(items[i]),
                onReview: () => _review(items[i]),
              ),
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel, required this.onReview});
  final Booking booking;
  final VoidCallback onCancel;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            BusinessAvatar(name: b.businessName, logoUrl: b.businessLogo, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.businessName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text('${fmtDayLong(b.start)} · ${fmtTime(b.start)}–${fmtTime(b.end)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              ]),
            ),
            StatusChip(status: b.status),
          ]),
          if (b.serviceName != null || b.partySize > 1 || (b.note?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              if (b.serviceName != null) _info(Icons.design_services_outlined, b.serviceName!),
              if (b.partySize > 1) _info(Icons.group_outlined, '${b.partySize} kişi'),
              if (b.note?.isNotEmpty ?? false) _info(Icons.notes, b.note!),
            ]),
          ],
          if (b.canCancel || b.canReview) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: b.canCancel
                  ? TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('İptal et'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: onReview,
                      icon: const Icon(Icons.star_outline_rounded, size: 18),
                      label: const Text('Değerlendir'),
                    ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
      ]);
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.booking, required this.repo});
  final Booking booking;
  final BookingRepository repo;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repo.addReview(booking: widget.booking, rating: _rating, comment: _comment.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Klavye açılınca içerik yukarı kaysın
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${widget.booking.businessName} nasıldı?',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        StarRatingInput(value: _rating, onChanged: (v) => setState(() => _rating = v)),
        const SizedBox(height: 8),
        TextField(
          controller: _comment,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Deneyimini birkaç cümleyle anlat (isteğe bağlı)'),
        ),
        const SizedBox(height: 8),
        LoadingButton(label: 'Gönder', loading: _saving, onPressed: _save),
      ]),
    );
  }
}
