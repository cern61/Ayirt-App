import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session_controller.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';
import 'admin_widgets.dart';

/// 3.1 Müşteriler: listele, ara, bilgilerini düzenle, rezervasyonlarını gör
class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  final _repo = AdminRepository();
  final _search = TextEditingController();
  Timer? _debounce;
  List<Profile> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      final list = await _repo.fetchCustomers(query: _search.text);
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

  Future<void> _edit(Profile p) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EditCustomerDialog(profile: p, repo: _repo),
    );
    if (saved == true) {
      if (mounted) showMessage(context, 'Müşteri bilgileri güncellendi.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminPageHeader(title: 'Müşteriler', subtitle: '${_items.length} kayıt'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: AdminSearchField(controller: _search, hint: 'Ad, e-posta veya telefon ara…', onChanged: _onSearch),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: EmptyState(icon: Icons.error_outline, message: _error!))
                : _items.isEmpty
                    ? const Center(child: EmptyState(icon: Icons.people_outline, message: 'Müşteri bulunamadı.'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _items.length,
                          separatorBuilder: (context, i) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final p = _items[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      (p.avatarUrl?.isNotEmpty ?? false) ? NetworkImage(p.avatarUrl!) : null,
                                  child: (p.avatarUrl?.isNotEmpty ?? false)
                                      ? null
                                      : Text(p.fullName.isEmpty ? '?' : p.fullName[0].toUpperCase()),
                                ),
                                title: Text(p.fullName.isEmpty ? '(isimsiz)' : p.fullName),
                                subtitle: Text([p.email, if (p.phone != null) p.phone!].join(' · ')),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    tooltip: 'Rezervasyonları',
                                    icon: const Icon(Icons.event_note),
                                    onPressed: () => showBookingsSheet(
                                      context,
                                      title: '${p.fullName} · rezervasyonlar',
                                      loader: () => _repo.fetchCustomerBookings(p.id),
                                    ),
                                  ),
                                  IconButton(tooltip: 'Düzenle', icon: const Icon(Icons.edit), onPressed: () => _edit(p)),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }
}

class _EditCustomerDialog extends StatefulWidget {
  const _EditCustomerDialog({required this.profile, required this.repo});
  final Profile profile;
  final AdminRepository repo;

  @override
  State<_EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<_EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repo.updateCustomer(widget.profile.id, fullName: _name.text, phone: _phone.text);
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
      title: const Text('Müşteriyi düzenle'),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            initialValue: widget.profile.email,
            enabled: false,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Ad soyad'),
            validator: (v) => Validators.notEmpty(v, 'Ad soyad'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon'),
          ),
        ]),
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
