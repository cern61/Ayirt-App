/// Supabase bilgileri koda yazılmaz; çalıştırırken env.json dosyasından gelir:
///   flutter run --dart-define-from-file=env.json
/// (VS Code'da .vscode/launch.json bunu otomatik yapar.)
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static void assertValid() {
    if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_KEY bulunamadı.\n'
        'Proje kökünde env.json olduğundan ve uygulamayı '
        '"--dart-define-from-file=env.json" ile çalıştırdığından emin ol.',
      );
    }
  }
}
