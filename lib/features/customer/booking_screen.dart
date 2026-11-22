import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/session_controller.dart';
import '../../data/models/business.dart';
import '../../data/repositories/business_repository.dart';
import '../../shared/day_strip.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';

/// Rezervasyon: gün seç → saat seç → (hizmet, kişi sayısı, not) → onayla
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.businessId});
  final String businessId;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const _daysAhead = 14; // önümüzdeki kaç gün gösterilsin

  final _repo = BusinessRepository();
  final _noteCtrl = TextEditingController();

  BusinessCard? _business;
  List<Service> _services = [];
  late final List<DateTime> _days;
  late DateTime _selectedDay;

  List<Slot> _slots = [];
  Slot? _selectedSlot;
  String? _selectedServiceId;
  int _partySize = 1;

  bool _loadingInfo = true;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = todayTr();
    _days = List.generate(_daysAhead, (i) => today.add(Duration(days: i)));
    _selectedDay = _days.first;
    _loadInfo();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final results = await Future.wait([
        _repo.fetchBusiness(widget.businessId),
        _repo.fetchServices(widget.businessId),
      ]);
      if (!mounted) return;
      setState(() {
        _business = results[0] as BusinessCard?;
        _services = results[1] as List<Service>;
        if (_business == null) _error = 'İşletme bulunamadı.';
      });
      if (_business != null) await _loadSlots();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });
    try {
      final slots = await _repo.fetchSlots(widget.businessId, _selectedDay);
      if (mounted) setState(() => _slots = slots);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  void _selectDay(DateTime day) {
    if (day == _selectedDay) return;
    setState(() => _selectedDay = day);
    _loadSlots();
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    final b = _business;
    if (slot == null || b == null) return;

    setState(() => _submitting = true);
    try {
      await _repo.createBooking(
        businessId: b.id,
        slot: slot,
        serviceId: _selectedServiceId,
        partySize: _partySize,
        note: _noteCtrl.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Rezervasyon alındı!'),
          content: Text(
            '${b.name}\n${fmtDayLong(slot.start)} · ${fmtTime(slot.start)}\n\n'
            'İşletme onayladığında "Rezervasyonlarım" sayfasında durumu "Onaylandı" olarak göreceksin.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tamam')),
          ],
        ),
      );
      if (mounted) context.go('/customer/bookings');
    } catch (e) {
      if (!mounted) return;
      showMessage(context, friendlyError(e), error: true);
      _loadSlots(); // biri araya girip saati kaptıysa listeyi yenile
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _business;

    return Scaffold(
      appBar: AppBar(title: Text(b == null ? 'Rezervasyon' : '${b.name} · Rezervasyon')),
      body: _loadingInfo
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: EmptyState(icon: Icons.error_outline, message: _error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _label('1. Gün seç'),
                    DayStrip(days: _days, selected: _selectedDay, onSelect: _selectDay),
                    const SizedBox(height: 20),
                    _label('2. Saat seç'),
                    _buildSlots(b!),
                    if (_services.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _label('3. Hizmet (isteğe bağlı)'),
                      DropdownButtonFormField<String?>(
                        initialValue: _selectedServiceId,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.design_services_outlined)),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Belirtmek istemiyorum')),
                          for (final s in _services)
                            DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text('${s.name}  ${fmtPrice(s.price)}'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _selectedServiceId = v),
                      ),
                    ],
                    if (b.isMultiCapacity) ...[
                      const SizedBox(height: 20),
                      _label('Kişi sayısı'),
                      _PartySizePicker(
                        value: _partySize,
                        max: _selectedSlot?.remaining ?? b.capacityPerSlot,
                        onChanged: (v) => setState(() => _partySize = v),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _label('Not (isteğe bağlı)'),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      maxLength: 200,
                      decoration: const InputDecoration(hintText: 'İşletmeye iletmek istediğin bir not…'),
                    ),
                  ],
                ),
      bottomNavigationBar: b == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: LoadingButton(
                  label: _selectedSlot == null
                      ? 'Önce bir saat seç'
                      : '${fmtTime(_selectedSlot!.start)} için onayla',
                  loading: _submitting,
                  onPressed: _selectedSlot == null ? null : _submit,
                ),
              ),
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _buildSlots(BusinessCard b) {
    if (_loadingSlots) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (_slots.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        message: 'Bu gün için uygun saat yok.\n(İşletme kapalı olabilir ya da saatler geçmiş olabilir.)',
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in _slots)
          ChoiceChip(
            label: Text(b.isMultiCapacity && !s.isFull
                ? '${fmtTime(s.start)}  (${s.remaining} yer)'
                : fmtTime(s.start)),
            selected: _selectedSlot?.startRaw == s.startRaw,
            // Dolu saatler seçilemez
            onSelected: s.isFull
                ? null
                : (_) => setState(() {
                      _selectedSlot = s;
                      if (_partySize > s.remaining) _partySize = s.remaining;
                    }),
          ),
      ],
    );
  }
}

class _PartySizePicker extends StatelessWidget {
  const _PartySizePicker({required this.value, required this.max, required this.onChanged});
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton.filledTonal(
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 56,
        child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      IconButton.filledTonal(
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add),
      ),
      const SizedBox(width: 12),
      Text('en fazla $max', style: const TextStyle(color: Colors.grey)),
    ]);
  }
}
