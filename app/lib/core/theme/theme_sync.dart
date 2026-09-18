import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// WP-838: tema tercihlerinin sunucudaki kopyasına açılan ince kapı.
///
/// `ThemeSettingsNotifier` yalnız bu arayüzü tanır; böylece uzlaşma kuralı
/// (son-yazan-kazanır) Supabase olmadan test edilebilir. Kapı hatayı kendisi
/// yutmaz — yutma sözünü çağıran taraf tutar; burada sadece ağ işi yapılır.
abstract class ThemePrefsGateway {
  const ThemePrefsGateway();

  /// Oturum açık mı? `false` iken hiçbir ağ çağrısı yapılmaz.
  bool get isSignedIn;

  /// WP-860: oturumdaki hesabın kimliği; oturum yoksa `null`. Yerel damga bu
  /// kimlikle etiketlenir — aynı cihazda hesap değişince bir hesabın teması
  /// ötekinin sunucu kopyasıyla yarışmasın. Kimliği bilmeyen kapı `null`
  /// döner; o zaman damga sahipsiz kalır (WP-838 davranışı).
  String? get userId => null;

  /// Her oturum açılışında (kalıcı oturumun geri yüklenmesi dahil) bir olay.
  Stream<void> get signIns;

  /// Sunucudaki tam tercih kümesi; kayıt yoksa `null`.
  Future<Map<String, dynamic>?> fetch();

  /// Tam tercih kümesini sunucuya yazar (alan alan birleştirme YOK).
  Future<void> push(Map<String, dynamic> prefs);
}

/// Supabase kurulmamış (bellek-içi/demo mod, testler) veya anahtar verilmemiş
/// kurulum. Tema tamamen yerelde kalır; tek satır ağ trafiği olmaz.
class DisabledThemePrefsGateway extends ThemePrefsGateway {
  const DisabledThemePrefsGateway();

  @override
  bool get isSignedIn => false;

  @override
  Stream<void> get signIns => const Stream<void>.empty();

  @override
  Future<Map<String, dynamic>?> fetch() async => null;

  @override
  Future<void> push(Map<String, dynamic> prefs) async {}
}

/// `public.user_theme_prefs` (migration `0143`) üzerinden okur/yazar. Tablo
/// RLS ile sahibine kilitlidir; istemci yine de `user_id`yi açıkça yazar,
/// çünkü `with check (user_id = auth.uid())` bunu bekler.
class SupabaseThemePrefsGateway extends ThemePrefsGateway {
  const SupabaseThemePrefsGateway(this._client);

  static const String table = 'user_theme_prefs';

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentUser != null;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Stream<void> get signIns => _client.auth.onAuthStateChange
      .where(
        (state) =>
            state.session != null &&
            (state.event == AuthChangeEvent.signedIn ||
                state.event == AuthChangeEvent.initialSession),
      )
      .map((_) {});

  @override
  Future<Map<String, dynamic>?> fetch() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from(table)
        .select('prefs')
        .eq('user_id', userId)
        .maybeSingle();
    final prefs = row?['prefs'];
    return prefs is Map ? Map<String, dynamic>.from(prefs) : null;
  }

  @override
  Future<void> push(Map<String, dynamic> prefs) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from(table).upsert({
      'user_id': userId,
      'prefs': prefs,
    }, onConflict: 'user_id');
  }
}

/// Supabase hiç kurulmadıysa `Supabase.instance` **fırlatır** (bellek-içi mod,
/// widget testleri). Temanın sunucu kopyası bir yedektir; yokluğu uygulamayı
/// düşürmemeli — o durumda kapı kapalı döner.
final themePrefsGatewayProvider = Provider<ThemePrefsGateway>((ref) {
  try {
    return SupabaseThemePrefsGateway(Supabase.instance.client);
  } catch (_) {
    return const DisabledThemePrefsGateway();
  }
});
