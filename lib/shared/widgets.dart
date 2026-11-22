import 'package:flutter/material.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Logo (assets/logo.png). Dosya yoksa ikon gösterir, uygulama çökmez.
class AyirtLogo extends StatelessWidget {
  const AyirtLogo({super.key, this.size = 110});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stack) => Icon(
        Icons.event_available,
        size: size * 0.8,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Butonun içinde yükleniyor göstergesi
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.loading, this.onPressed});
  final String label;
  final bool loading;
  final VoidCallback? onPressed; // null → buton pasif

  @override
  Widget build(BuildContext context) {
    // Tam genişlikte buton
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Text(label),
      ),
    );
  }
}

/// Henüz yapılmamış ekranlar için geçici içerik
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, required this.step, this.icon = Icons.construction});
  final String title;
  final String step;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(step, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}

/// Form doğrulayıcıları
class Validators {
  static String? notEmpty(String? v, [String field = 'Bu alan']) =>
      (v == null || v.trim().isEmpty) ? '$field zorunlu' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'E-posta zorunlu';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Geçerli bir e-posta gir';
  }

  static String? password(String? v) =>
      (v == null || v.length < 6) ? 'Şifre en az 6 karakter olmalı' : null;
}
