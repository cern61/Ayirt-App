import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session_controller.dart';
import '../../data/models/category.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';
import 'admin_widgets.dart';

/// 3.1 İşletmeler: listele, ara, filtrele, askıya al / aktifleştir, düzenle
class AdminBusinessesScreen extends StatefulWidget {
  const AdminBusinessesScreen({super.key});

  @override
  State<AdminBusinessesScreen> createState() => _AdminBusinessesScreenState();
}

enum _Filter { all, active, suspended }

class _AdminBusinessesScreenState extends State<AdminBusinessesScreen> {
  final _repo = AdminRepository();
  final _search = TextEditingController();
  Timer? _debounce;
  _Filter _filter = _Filter.all;
  List<AdminBusiness> _items = [];
  List<BusinessCategory> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  Future<void> _loadCategories() async {
    try {
      final c = await _repo.fetchCategories();
      if (mounted) setState(() => _categories = c);
    } catch (_) {/* düzenleme penceresinde kategori listesi boş kalır */}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchBusinesses(
        query: _search.text,
        active: switch (_filter) {
          _Filter.all => null,
          _Filter.active => true,
          _Filter.suspended => false,
        },
      );
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _toggleActive(AdminBusiness ab) async {
    final b = ab.business;
    final suspend = b.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suspend ? '"${b.name}" askıya alınsın mı?' : '"${b.name}" tekrar aktifleştirilsin mi?'),
        content: Text(suspend
            ? 'Askıdaki işletme aramada görünmez ve yeni rezervasyon alamaz. Mevcut rezervasyonlar silinmez.'
            : 'İşletme tekrar aramada görünecek ve rezervasyon alabilecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: suspend ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(suspend ? 'Askıya al' : 'Aktifleştir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.setBusinessActive(b.id, !suspend);
      if (mounted) showMessage(context, suspend ? 'İşletme askıya alındı.' : 'İşletme aktifleştirildi.');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _edit(AdminBusiness ab) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EditBusinessDialog(item: ab, categories: _categories, repo: _repo),
    );
    if (saved == true) {
      if (mounted) showMessage(context, 'İşletme güncellendi.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminPageHeader(title: 'İşletmeler', subtitle: '${_items.length} kayıt'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 320,
            child: AdminSearchField(controller: _search, hint: 'Ad, şehir veya e-posta ara…', onChanged: _onSearch),
          ),
          SegmentedButton<_Filter>(
            segments: const [
              ButtonSegment(value: _Filter.all, label: Text('Hepsi')),
              ButtonSegment(value: _Filter.active, label: Text('Aktif')),
              ButtonSegment(value: _Filter.suspended, label: Text('Askıda')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) {
              setState(() => _filter = s.first);
              _load();
            },
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: EmptyState(icon: Icons.error_outline, message: _error!))
                : _items.isEmpty
                    ? const Center(child: EmptyState(icon: Icons.store_outlined, message: 'İşletme bulunamadı.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _items.length,
                          separatorBuilder: (context, i) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _BusinessRow(
                            item: _items[i],
                            onToggle: () => _toggleActive(_items[i]),
                            onEdit: () => _edit(_items[i]),
                            onBookings: () => showBookingsSheet(
                              context,
                              title: '${_items[i].business.name} · rezervasyonlar',
                              loader: () => _repo.fetchBusinessBookings(_items[i].business.id),
                            ),
                          ),
                        ),
                      ),
      ),
    ]);
  }
}

class _BusinessRow extends StatelessWidget {
  const _BusinessRow({required this.item, required this.onToggle, required this.onEdit, required this.onBookings});
  final AdminBusiness item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onBookings;

  @override
  Widget build(BuildContext context) {
    final b = item.business;
    final details = [
      item.categoryName,
      b.city,
      if (item.ownerEmail != null) 'Sahibi: ${item.ownerName?.isNotEmpty == true ? item.ownerName : ''} ${item.ownerEmail}',
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          BusinessAvatar(name: b.name, logoUrl: b.logoUrl, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: b.isActive ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(b.isActive ? 'Aktif' : 'Askıda',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: b.isActive ? Colors.green.shade800 : Colors.red.shade700)),
                ),
              ]),
              if (details.isNotEmpty)
                Text(details, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ]),
          ),
          IconButton(tooltip: 'Rezervasyonları', icon: const Icon(Icons.event_note), onPressed: onBookings),
          IconButton(tooltip: 'Düzenle', icon: const Icon(Icons.edit), onPressed: onEdit),
          IconButton(
            tooltip: b.isActive ? 'Askıya al' : 'Aktifleştir',
            icon: Icon(b.isActive ? Icons.block : Icons.check_circle_outline,
                color: b.isActive ? Colors.red.shade700 : Colors.green.shade700),
            onPressed: onToggle,
          ),
        ]),
      ),
    );
  }
}

class _EditBusinessDialog extends StatefulWidget {
  const _EditBusinessDialog({required this.item, required this.categories, required this.repo});
  final AdminBusiness item;
  final List<BusinessCategory> categories;
  final AdminRepository repo;

  @override
  State<_EditBusinessDialog> createState() => _EditBusinessDialogState();
}

class _EditBusinessDialogState extends State<_EditBusinessDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item.business.name);
  late final _city = TextEditingController(text: widget.item.business.city ?? '');
  late final _phone = TextEditingController(text: widget.item.business.phone ?? '');
  late int? _categoryId = widget.item.business.categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repo.updateBusiness(
        widget.item.business.id,
        name: _name.text,
        categoryId: _categoryId,
        city: _city.text,
        phone: _phone.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('İşletmeyi düzenle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'İşletme adı'),
              validator: (v) => Validators.notEmpty(v, 'İşletme adı'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: widget.categories.any((c) => c.id == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [for (final c in widget.categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Şehir')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
