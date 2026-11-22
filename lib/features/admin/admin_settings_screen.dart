import 'package:flutter/material.dart';

import '../../core/session_controller.dart';
import '../../data/models/category.dart';
import '../../data/repositories/admin_repository.dart';
import '../../shared/password_dialog.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';
import 'admin_widgets.dart';

/// 3.1 Ayarlar: işletme kategorileri + admin hesabı
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _repo = AdminRepository();
  List<BusinessCategory> _categories = [];
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
      final list = await _repo.fetchCategories();
      if (mounted) setState(() => _categories = list);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([BusinessCategory? c]) async {
    final nextOrder = _categories.isEmpty ? 1 : _categories.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CategoryDialog(category: c, repo: _repo, defaultOrder: nextOrder),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(BusinessCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${c.name}" silinsin mi?'),
        content: const Text('Bu kategorideki işletmeler silinmez, sadece kategorileri boş kalır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteCategory(c.id);
      _load();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final p = session.profile;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AdminPageHeader(title: 'Ayarlar'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Kategoriler ----
            Row(children: [
              const Expanded(
                child: Text('🗂️ İşletme kategorileri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              FilledButton.tonalIcon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Yeni')),
            ]),
            const SizedBox(height: 4),
            Text('Müşterilerin Keşfet ekranında ve işletmelerin kayıt formunda görünür.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              EmptyState(icon: Icons.error_outline, message: _error!)
            else
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  for (final c in _categories)
                    ListTile(
                      leading: CircleAvatar(child: Icon(c.iconData, size: 20)),
                      title: Text(c.name),
                      subtitle: Text('Sıra: ${c.sortOrder}'),
                      onTap: () => _edit(c),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(c)),
                    ),
                ]),
              ),
            const SizedBox(height: 32),

            // ---- Hesap ----
            const Text('👤 Admin hesabı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: Text(p?.fullName.isNotEmpty == true ? p!.fullName : 'Admin'),
                  subtitle: Text(p?.email ?? ''),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Şifre değiştir'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final ok = await showDialog<bool>(context: context, builder: (context) => const PasswordDialog());
                    if (ok == true && context.mounted) showMessage(context, 'Şifren güncellendi.');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red.shade700),
                  title: Text('Çıkış yap', style: TextStyle(color: Colors.red.shade700)),
                  onTap: session.signOut,
                ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.repo, required this.defaultOrder, this.category});
  final AdminRepository repo;
  final int defaultOrder;
  final BusinessCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _order = TextEditingController(text: '${widget.category?.sortOrder ?? widget.defaultOrder}');
  late String _icon = widget.category?.icon ?? 'store';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveCategory(
        id: widget.category?.id,
        name: _name.text,
        icon: _icon,
        sortOrder: int.parse(_order.text.trim()),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Aynı isimde kategori varsa veritabanı "unique" hatası verir
      final msg = friendlyError(e);
      if (mounted) {
        showMessage(context, msg.contains('duplicate') ? 'Bu isimde bir kategori zaten var.' : msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.category == null ? 'Yeni kategori' : 'Kategoriyi düzenle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Kategori adı', hintText: 'Örn: Veteriner'),
              validator: (v) => Validators.notEmpty(v, 'Kategori adı'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _order,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sıra (küçük olan önce görünür)'),
              validator: (v) => int.tryParse(v?.trim() ?? '') == null ? 'Sayı gir' : null,
            ),
            const SizedBox(height: 16),
            const Text('İkon', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in BusinessCategory.iconOptions.entries)
                InkWell(
                  onTap: () => setState(() => _icon = e.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _icon == e.key ? scheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _icon == e.key ? scheme.primary : Colors.grey.shade300),
                    ),
                    child: Icon(e.value, color: _icon == e.key ? Colors.white : Colors.grey.shade700),
                  ),
                ),
            ]),
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
