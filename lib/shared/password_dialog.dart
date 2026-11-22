import 'package:flutter/material.dart';

import '../core/session_controller.dart';
import '../data/repositories/profile_repository.dart';
import 'widgets.dart';

/// Şifre değiştirme penceresi (müşteri ve işletme profilinde ortak).
/// Başarılıysa true döner.
class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ProfileRepository().changePassword(_pass.text);
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
      title: const Text('Şifre değiştir'),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre'),
            validator: Validators.password,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pass2,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)'),
            validator: (v) => v != _pass.text ? 'Şifreler aynı değil' : null,
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
