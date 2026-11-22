import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/profile.dart';
import 'supabase_client.dart';

/// Uygulamanın "kim giriş yaptı, rolü ne?" bilgisinin tek kaynağı.
/// Router bunu dinler; profil değişince doğru ana sayfaya yönlendirir.
class SessionController extends ChangeNotifier {
  Profile? _profile;
  Profile? get profile => _profile;
  bool get isLoggedIn => _profile != null;

  StreamSubscription<AuthState>? _authSub;

  Future<void> init() async {
    if (supabase.auth.currentSession != null) {
      await _loadProfile();
    }
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
          await _loadProfile();
        case AuthChangeEvent.signedOut:
          _profile = null;
          notifyListeners();
        default:
          break;
      }
    });
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final row = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      _profile = row == null ? null : Profile.fromMap(row);
    } catch (e) {
      debugPrint('Profil yüklenemedi: $e');
      _profile = null;
    }
    notifyListeners();
  }

  /// Profil ekranında bilgiler güncellenince çağrılır
  Future<void> refreshProfile() => _loadProfile();

  // ---------------- Auth işlemleri ----------------

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email.trim(), password: password);
    await _loadProfile();
  }

  /// Dönen değer: true → oturum açıldı, false → e-posta onayı bekleniyor
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
    String? businessName,
    int? categoryId,
  }) async {
    final res = await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      // Bu bilgileri veritabanındaki handle_new_user trigger'ı okur
      data: {
        'full_name': fullName.trim(),
        'role': role.name, // 'customer' veya 'business' (admin kayıtla OLUŞMAZ)
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (businessName != null) 'business_name': businessName.trim(),
        if (categoryId != null) 'category_id': categoryId.toString(),
      },
    );
    if (res.session != null) {
      await _loadProfile();
      return true;
    }
    return false;
  }

  Future<void> signOut() => supabase.auth.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// Widget ağacında SessionController'a erişim: SessionScope.of(context)
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({super.key, required SessionController controller, required super.child})
      : super(notifier: controller);

  static SessionController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

/// Supabase hatalarını kullanıcıya gösterilecek Türkçe mesaja çevirir
String friendlyError(Object error) {
  if (error is AuthException) {
    return switch (error.code) {
      'invalid_credentials' => 'E-posta veya şifre hatalı.',
      'email_not_confirmed' => 'Önce e-postana gelen onay linkine tıklamalısın.',
      'user_already_exists' || 'email_exists' => 'Bu e-posta ile zaten bir hesap var.',
      'weak_password' => 'Şifre çok zayıf. En az 6 karakter kullan.',
      'over_email_send_rate_limit' => 'Çok fazla deneme yapıldı, biraz sonra tekrar dene.',
      _ => error.message,
    };
  }
  if (error is PostgrestException) {
    return error.message; // RPC'lerdeki "raise exception" mesajları Türkçe geliyor
  }
  return 'Beklenmeyen bir hata oluştu: $error';
}
