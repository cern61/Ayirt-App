import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/session_controller.dart';
import '../../data/models/my_business.dart';
import '../../data/repositories/my_business_repository.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';

/// "İşletmenin ihtiyacına göre ayarlanabilir takvim":
///   • Rezervasyon süresi (slot)   • Aynı saatte kaç rezervasyon (kapasite)
///   • Haftalık çalışma saatleri   • Kapalı günler (tatil vb.)
class CalendarSettingsScreen extends StatefulWidget {
  const CalendarSettingsScreen({super.key, required this.business, required this.onSaved});
  final MyBusiness business;
  final Future<void> Function() onSaved;

  @override
  State<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends State<CalendarSettingsScreen> {
  static const _slotOptions = [15, 20, 30, 45, 60, 90, 120];

  final _repo = MyBusinessRepository();
  late int _slotMinutes;
  late int _capacity;
  List<WorkingHour> _hours = [];
  List<ClosedDate> _closed = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _slotMinutes = widget.business.slotMinutes;
    _capacity = widget.business.capacityPerSlot;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hours = await _repo.fetchWorkingHours(widget.business.id);
      final closed = await _repo.fetchClosedDates(widget.business.id);
      if (mounted) setState(() {
        _hours = hours;
        _closed = closed;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickTime(WorkingHour h, {required bool isOpen}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? h.open : h.close,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() => isOpen ? h.open = picked : h.close = picked);
  }

  Future<void> _save() async {
    final invalid = _hours.where((h) => !h.isValid).toList();
    if (invalid.isNotEmpty) {
      showMessage(context, '${invalid.first.dayName}: kapanış saati açılıştan sonra olmalı.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.updateCalendarSettings(widget.business.id, slotMinutes: _slotMinutes, capacity: _capacity);
      await _repo.saveWorkingHours(widget.business.id, _hours);
      await widget.onSaved();
      if (mounted) showMessage(context, 'Takvim ayarları kaydedildi ✅');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addClosedDate() async {
    final today = todayTr();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Kapalı olacağın günü seç',
    );
    if (picked == null || !mounted) return;

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sebep (isteğe bağlı)'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'Örn: Bayram tatili')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, reasonCtrl.text), child: const Text('Ekle')),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null) return; // vazgeçti

    try {
      await _repo.addClosedDate(widget.business.id, picked, reason);
      _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _removeClosedDate(ClosedDate c) async {
    try {
      await _repo.removeClosedDate(widget.business.id, c.day);
      _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ---- Rezervasyon süresi ----
          _section('⏱️ Rezervasyon süresi', 'Her rezervasyon takvimde kaç dakika yer kaplasın?'),
          DropdownButtonFormField<int>(
            initialValue: _slotOptions.contains(_slotMinutes) ? _slotMinutes : 30,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.timelapse)),
            items: [for (final m in _slotOptions) DropdownMenuItem(value: m, child: Text('$m dakika'))],
            onChanged: (v) => setState(() => _slotMinutes = v ?? 30),
          ),
          const SizedBox(height: 24),

          // ---- Kapasite ----
          _section('👥 Aynı saatte kaç rezervasyon?',
              'Kuaför/berber tek koltuksa 1 · 3 çalışanlı salon 3 · 10 masalı restoran 10 · 8 kişilik pilates dersi 8'),
          Row(children: [
            IconButton.filledTonal(
              onPressed: _capacity > 1 ? () => setState(() => _capacity--) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 64,
              child: Text('$_capacity',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            IconButton.filledTonal(
              onPressed: _capacity < 500 ? () => setState(() => _capacity++) : null,
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_capacity == 1 ? 'Her saate tek müşteri' : 'Her saate $_capacity kişiye kadar',
                  style: const TextStyle(color: Colors.grey)),
            ),
          ]),
          const SizedBox(height: 24),

          // ---- Haftalık saatler ----
          _section('📅 Haftalık çalışma saatleri', 'Kapalı olduğun günlerin anahtarını kapat.'),
          Card(
            margin: EdgeInsets.zero,
            child: Column(children: [
              for (final h in _hours) ...[
                _HourRow(
                  hour: h,
                  onToggle: (v) => setState(() => h.isOpen = v),
                  onPickOpen: () => _pickTime(h, isOpen: true),
                  onPickClose: () => _pickTime(h, isOpen: false),
                ),
                if (h.weekday != 7) const Divider(height: 1),
              ],
            ]),
          ),
          const SizedBox(height: 24),

          // ---- Kapalı günler ----
          Row(children: [
            Expanded(child: _section('🚫 Kapalı günler', 'Tatil, bayram gibi özel günler')),
            TextButton.icon(onPressed: _addClosedDate, icon: const Icon(Icons.add), label: const Text('Ekle')),
          ]),
          if (_closed.isEmpty)
            const Text('Eklenmiş kapalı gün yok.', style: TextStyle(color: Colors.grey))
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                for (final c in _closed)
                  ListTile(
                    leading: const Icon(Icons.event_busy),
                    title: Text(fmtDayLong(c.day.add(const Duration(hours: 12)))),
                    subtitle: c.reason == null ? null : Text(c.reason!),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeClosedDate(c),
                    ),
                  ),
              ]),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: LoadingButton(label: 'Ayarları kaydet', loading: _saving, onPressed: _save),
        ),
      ),
    );
  }

  Widget _section(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ]),
      );
}

class _HourRow extends StatelessWidget {
  const _HourRow({required this.hour, required this.onToggle, required this.onPickOpen, required this.onPickClose});
  final WorkingHour hour;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOpen;
  final VoidCallback onPickClose;

  @override
  Widget build(BuildContext context) {
    final h = hour;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        SizedBox(width: 92, child: Text(h.dayName, style: const TextStyle(fontWeight: FontWeight.w500))),
        Switch(value: h.isOpen, onChanged: onToggle),
        const Spacer(),
        if (h.isOpen) ...[
          _timeButton(context, formatTime(h.open), onPickOpen, h.isValid),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
          _timeButton(context, formatTime(h.close), onPickClose, h.isValid),
        ] else
          const Text('Kapalı', style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Widget _timeButton(BuildContext context, String text, VoidCallback onTap, bool valid) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: valid ? null : Colors.red,
          side: valid ? null : const BorderSide(color: Colors.red),
        ),
        child: Text(text),
      );
}
