import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/session_controller.dart';
import '../../data/models/business.dart';
import '../../data/models/category.dart';
import '../../data/models/my_business.dart';
import '../../data/repositories/business_repository.dart';
import '../../data/repositories/my_business_repository.dart';
import '../../shared/image_upload.dart';
import '../../shared/password_dialog.dart';
import '../../shared/ui_parts.dart';
import '../../shared/widgets.dart';

/// 2.2 İşletme profili: logo, isim, iletişim/adres, hizmetler, puan/yorumlar,
/// rezervasyon geçmişi, şifre
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key, required this.business, required this.onChanged});
  final MyBusiness business;
  final Future<void> Function() onChanged;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _repo = MyBusinessRepository();
  final _publicRepo = BusinessRepository();
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.business.name);
  late final _description = TextEditingController(text: widget.business.description);
  late final _phone = TextEditingController(text: widget.business.phone ?? '');
  late final _email = TextEditingController(text: widget.business.email ?? '');
  late final _city = TextEditingController(text: widget.business.city ?? '');
  late final _address = TextEditingController(text: widget.business.address ?? '');
  late int? _categoryId = widget.business.categoryId;

  List<BusinessCategory> _categories = [];
  List<Service> _services = [];
  List<Review> _reviews = [];
  double _ratingAvg = 0;
  int _ratingCount = 0;

  bool _saving = false;
  bool _uploading = false;

  MyBusiness get b => widget.business;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _phone, _email, _city, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExtras() async {
    try {
      final results = await Future.wait([
        _publicRepo.fetchCategories(),
        _repo.fetchAllServices(b.id),
        _publicRepo.fetchReviews(b.id),
        _publicRepo.fetchBusiness(b.id),
      ]);
      if (!mounted) return;
      final card = results[3] as BusinessCard?;
      setState(() {
        _categories = results[0] as List<BusinessCategory>;
        _services = results[1] as List<Service>;
        _reviews = results[2] as List<Review>;
        _ratingAvg = card?.ratingAvg ?? 0;
        _ratingCount = card?.ratingCount ?? 0;
      });
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _saveInfo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.updateInfo(
        b.id,
        name: _name.text,
        categoryId: _categoryId,
        description: _description.text,
        phone: _phone.text,
        email: _email.text,
        city: _city.text,
        address: _address.text,
      );
      await widget.onChanged();
      if (mounted) showMessage(context, 'İşletme bilgileri kaydedildi ✅');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeLogo() async {
    setState(() => _uploading = true);
    final url = await pickAndUploadImage(context, fileName: 'logo');
    if (url != null) {
      try {
        await _repo.setLogo(b.id, url);
        await widget.onChanged();
      } catch (e) {
        if (mounted) showMessage(context, friendlyError(e), error: true);
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _editService([Service? s]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ServiceDialog(businessId: b.id, service: s, repo: _repo),
    );
    if (saved == true) _loadExtras();
  }

  Future<void> _deleteService(Service s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${s.name}" silinsin mi?'),
        content: const Text('Bu hizmetle alınmış eski rezervasyonlar silinmez.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteService(s.id);
      _loadExtras();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('İşletme profilim')),
      body: RefreshIndicator(
        onRefresh: _loadExtras,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Logo + puan ----
            Center(
              child: Stack(children: [
                BusinessAvatar(name: b.name, logoUrl: b.logoUrl, size: 96),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    onPressed: _uploading ? null : _changeLogo,
                    icon: _uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.camera_alt, size: 18),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Center(child: RatingBadge(avg: _ratingAvg, count: _ratingCount)),
            const SizedBox(height: 24),

            // ---- Bilgiler ----
            _title('🏪 İşletme bilgileri'),
            Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'İşletme adı', prefixIcon: Icon(Icons.store_outlined)),
                  validator: (v) => Validators.notEmpty(v, 'İşletme adı'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  // Kategoriler yüklenince doğru değeri göstermesi için key
                  key: ValueKey('cat-${_categories.length}'),
                  initialValue: _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                  decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category_outlined)),
                  items: [
                    for (final c in _categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [Icon(c.iconData, size: 20), const SizedBox(width: 8), Text(c.name)]),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Müşterilere kendini tanıt: ne yapıyorsun, neden seni seçmeliler?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'İletişim e-postası', prefixIcon: Icon(Icons.mail_outline)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'Şehir', prefixIcon: Icon(Icons.location_city)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Adres', prefixIcon: Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: 16),
                LoadingButton(label: 'Bilgileri kaydet', loading: _saving, onPressed: _saveInfo),
              ]),
            ),
            const SizedBox(height: 28),

            // ---- Hizmetler ----
            Row(children: [
              Expanded(child: _title('💈 Hizmetler')),
              TextButton.icon(onPressed: () => _editService(), icon: const Icon(Icons.add), label: const Text('Ekle')),
            ]),
            if (_services.isEmpty)
              const Text('Henüz hizmet eklemedin. Müşteriler hizmetlerini ve fiyatlarını burada görecek.',
                  style: TextStyle(color: Colors.grey))
            else
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  for (final s in _services)
                    ListTile(
                      title: Text(s.name,
                          style: TextStyle(
                            decoration: s.isActive ? null : TextDecoration.lineThrough,
                            color: s.isActive ? null : Colors.grey,
                          )),
                      subtitle: Text('${s.durationMin} dk${s.price != null ? ' · ${fmtPrice(s.price)}' : ''}'
                          '${s.isActive ? '' : ' · gizli'}'),
                      onTap: () => _editService(s),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteService(s)),
                    ),
                ]),
              ),
            const SizedBox(height: 28),

            // ---- Yorumlar ----
            _title('⭐ Puan ve yorumlar'),
            if (_reviews.isEmpty)
              const Text('Henüz yorum yok. Tamamlanan rezervasyonlardan sonra müşteriler yorum yazabilir.',
                  style: TextStyle(color: Colors.grey))
            else
              for (final r in _reviews)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Row(children: [
                      Expanded(child: Text(r.customerName)),
                      for (var i = 1; i <= 5; i++)
                        Icon(i <= r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 16, color: Colors.amber),
                    ]),
                    subtitle: Text([if (r.comment?.isNotEmpty ?? false) r.comment!, fmtDateTime(r.createdAt)].join('\n')),
                  ),
                ),
            const SizedBox(height: 28),

            // ---- Diğer ----
            Card(
              margin: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Rezervasyon geçmişi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/business/history'),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );
}

/// Hizmet ekleme / düzenleme penceresi
class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog({required this.businessId, required this.repo, this.service});
  final String businessId;
  final MyBusinessRepository repo;
  final Service? service;

  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _duration = TextEditingController(text: '${widget.service?.durationMin ?? 30}');
  late final _price = TextEditingController(
    text: widget.service?.price == null ? '' : widget.service!.price!.toStringAsFixed(widget.service!.price! % 1 == 0 ? 0 : 2),
  );
  late bool _active = widget.service?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveService(
        widget.businessId,
        id: widget.service?.id,
        name: _name.text,
        durationMin: int.parse(_duration.text.trim()),
        price: _price.text.trim().isEmpty ? null : double.parse(_price.text.trim().replaceAll(',', '.')),
        isActive: _active,
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
      title: Text(widget.service == null ? 'Yeni hizmet' : 'Hizmeti düzenle'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Hizmet adı', hintText: 'Örn: Saç kesimi'),
              validator: (v) => Validators.notEmpty(v, 'Hizmet adı'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Süre (dakika)'),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return (n == null || n <= 0) ? 'Geçerli bir süre gir' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fiyat (₺, isteğe bağlı)'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                final n = double.tryParse(t.replaceAll(',', '.'));
                return (n == null || n < 0) ? 'Geçerli bir fiyat gir' : null;
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Müşterilere göster'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
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
