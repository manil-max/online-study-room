/// Supabase bağlantı ayarları.
///
/// Değerler derleme zamanında `--dart-define-from-file=env.json` ile verilir
/// (bkz. `app/env.example.json`). Repoya gerçek anahtar commit edilmez
/// (project.md §7). `anon key` istemcide bulunabilir; veriyi RLS korur.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Anahtarlar verilmişse true. Verilmemişse uygulama bellek-içi modda çalışır
  /// (Supabase'siz geliştirme/deneme için).
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
