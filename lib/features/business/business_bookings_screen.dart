import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/session_controller.dart';
import '../../data/models/booking.dart';
import '../../data/models/my_business.dart';
import '../../data/repositories/my_business_repository.dart';
import '../../shared/day_strip.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';

/// Gelen rezervasyonlar: günlük görünüm veya "onay bekleyenler"
class BusinessBookingsScreen extends StatefulWidget {
  const BusinessBookingsScreen({super.key, required this.business});
  final MyBusiness business;

  @override
  State<BusinessBookingsScreen> createState() => _BusinessBookingsScreenState();
}

enum _Mode { daily, pending }

class _BusinessBookingsScreenState extends State<BusinessBookingsScreen> {
  final _repo = MyBusinessRepository();

  _Mode _mode = _Mode.daily;
  late List<DateTime> _days;
  late DateTime _selectedDay;
  List<Booking> _bookings = [];
  int _pendingCount = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setDays(todayTr());
    _load();
  }

  /// Seçilen günden itibaren 30 gün göster
  void _setDays(DateTime start) {
    _days = List.generate(30, (i) => start.add(Duration(days: i)));
    _selectedDay = start;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await _repo.fetchPending(widget.business.id);
      final list = _mode == _Mode.pending ? pending : await _repo.fetchBookingsForDay(widget.business.id, _selectedDay);
      if (!mounted) return;
      setState(() {
        _pendingCount = pending.length;
        _bookings = list;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final today = todayTr();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _setDays(DateTime(picked.year, picked.month, picked.day)));
    _load();
  }

  Future<void> _changeStatus(Booking b, BookingStatus to) async {
    // İptal/red için onay iste
    if (to == BookingStatus.cancelled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(b.status == BookingStatus.pending ? 'Rezervasyon reddedilsin mi?' : 'Rezervasyon iptal edilsin mi?'),
          content: Text('${b.customerName ?? 'Müşteri'} · ${fmtDayLong(b.start)} ${fmtTime(b.start)}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet')),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await _repo.setStatus(b.id, to);
      if (mounted) showMessage(context, 'Durum güncellendi: ${to.label}');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SegmentedButton<_Mode>(
          segments: [
            const ButtonSegment(value: _Mode.daily, label: Text('Günlük'), icon: Icon(Icons.today)),
            ButtonSegment(
              value: _Mode.pending,
              icon: const Icon(Icons.hourglass_top),
              label: Text(_pendingCount > 0 ? 'Onay bekleyen ($_pendingCount)' : 'Onay bekleyen'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) {
            setState(() => _mode = s.first);
            _load();
          },
        ),
      ),
      if (_mode == _Mode.daily)
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Row(children: [
            Expanded(
              child: DayStrip(
                days: _days,
                selected: _selectedDay,
                onSelect: (d) {
                  setState(() => _selectedDay = d);
                  _load();
                },
              ),
            ),
            IconButton(tooltip: 'Başka bir tarih seç', onPressed: _pickDate, icon: const Icon(Icons.calendar_month)),
          ]),
        ),
      Expanded(child: _buildList()),
    ]);
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline,
          message: _error!,
          action: OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _bookings.isEmpty
          ? ListView(children: [
              EmptyState(
                icon: Icons.event_available,
                message: _mode == _Mode.pending
                    ? 'Onay bekleyen rezervasyon yok. 🎉'
                    : '${fmtDayLong(_selectedDay.add(const Duration(hours: 12)))} için rezervasyon yok.',
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _bookings.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) => BusinessBookingCard(
                booking: _bookings[i],
                showDate: _mode == _Mode.pending,
                onStatus: (to) => _changeStatus(_bookings[i], to),
              ),
            ),
    );
  }
}

/// İşletmenin gördüğü rezervasyon kartı (müşteri bilgisi + aksiyonlar)
class BusinessBookingCard extends StatelessWidget {
  const BusinessBookingCard({super.key, required this.booking, this.onStatus, this.showDate = false});
  final Booking booking;
  final ValueChanged<BookingStatus>? onStatus; // null → sadece görüntüle
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final faded = b.status == BookingStatus.cancelled;

    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Saat kutusu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text(fmtTime(b.start), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(fmtTime(b.end), style: const TextStyle(fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.customerName?.isNotEmpty == true ? b.customerName! : 'Müşteri',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  if (showDate) Text(fmtDayLong(b.start), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  if (b.customerPhone != null)
                    Text(b.customerPhone!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ]),
              ),
              StatusChip(status: b.status),
            ]),
            if (b.serviceName != null || b.partySize > 1 || (b.note?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              if (b.serviceName != null) _info(Icons.design_services_outlined, b.serviceName!),
              if (b.partySize > 1) _info(Icons.group_outlined, '${b.partySize} kişi'),
              if (b.note?.isNotEmpty ?? false) _info(Icons.notes, b.note!),
            ],
            if (onStatus != null) _actions(),
          ]),
        ),
      ),
    );
  }

  Widget _actions() {
    final b = booking;
    final buttons = <Widget>[
      if (b.status == BookingStatus.pending) ...[
        TextButton(onPressed: () => onStatus!(BookingStatus.cancelled), child: const Text('Reddet')),
        FilledButton.icon(
          onPressed: () => onStatus!(BookingStatus.confirmed),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Onayla'),
        ),
      ],
      if (b.status == BookingStatus.confirmed) ...[
        TextButton(onPressed: () => onStatus!(BookingStatus.cancelled), child: const Text('İptal et')),
        FilledButton.tonalIcon(
          onPressed: () => onStatus!(BookingStatus.completed),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Tamamlandı'),
        ),
      ],
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        for (final w in buttons) Padding(padding: const EdgeInsets.only(left: 8), child: w),
      ]),
    );
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade800, fontSize: 13))),
        ]),
      );
}
