import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session_controller.dart';
import '../../data/repositories/profile_repository.dart';
import '../../shared/image_upload.dart';
import '../../shared/password_dialog.dart';
import '../../shared/widgets.dart';

/// 1.2 Profilim: fotoğraf, ad soyad, e-posta, telefon, rezervasyon geçmişi, şifre
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _repo = ProfileRepository();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Form alanlarını profildeki bilgilerle bir kere doldur
    if (!_filled) {
      final p = SessionScope.of(context).profile;
      _name.text = p?.fullName ?? '';
      _phone.text = p?.phone ?? '';
      _filled = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = SessionScope.of(context);
    setState(() => _saving = true);
    try {
      await _repo.updateProfile(fullName: _name.text, phone: _phone.text);
      await session.refreshProfile();
      if (mounted) showMessage(context, 'Bilgilerin kaydedildi.');
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final session = SessionScope.of(context);
    setState(() => _uploading = true);
    final url = await pickAndUploadImage(context, fileName: 'avatar');
    if (url != null) {
      try {
        await _repo.setAvatarUrl(url);
        await session.refreshProfile();
      } catch (e) {
        if (mounted) showMessage(context, friendlyError(e), error: true);
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => const PasswordDialog(),
    );
    if (changed == true && mounted) showMessage(context, 'Şifren güncellendi.');
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final p = session.profile;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Fotoğraf ----
        Center(
          child: Stack(children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: (p?.avatarUrl?.isNotEmpty ?? false) ? NetworkImage(p!.avatarUrl!) : null,
              child: (p?.avatarUrl?.isNotEmpty ?? false) ? null : const Icon(Icons.person, size: 48),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                onPressed: _uploading ? null : _changePhoto,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt, size: 18),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Center(child: Text(p?.email ?? '', style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 24),

        // ---- Bilgiler ----
        Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad soyad', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => Validators.notEmpty(v, 'Ad soyad'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: p?.email ?? '',
              enabled: false, // e-posta değiştirilemez
              decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 16),
            LoadingButton(label: 'Kaydet', loading: _saving, onPressed: _save),
          ]),
        ),
        const SizedBox(height: 24),

        // ---- Diğer ----
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.event_note),
              title: const Text('Rezervasyonlarım'),
              subtitle: const Text('Yaklaşan ve geçmiş rezervasyonlar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/customer/bookings'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Şifre değiştir'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
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
    );
  }
}
