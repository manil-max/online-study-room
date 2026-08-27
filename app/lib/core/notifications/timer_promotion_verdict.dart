/// 🔴 WP-760 — "dinamik panel neden çıkmıyor?" sorusunun **okunabilir** cevabı.
///
/// Native taraf (`TimerPromotionCapability.kt` içindeki `TimerPromotion`)
/// sistemin terfiyi (promoted ongoing / Android 16 Live Update çipi) gerçekten
/// verip vermediğini **gönderilmiş bildirimin** `FLAG_PROMOTED_ONGOING`
/// bayrağından ölçüp kalıcı yazıyor. Ön koşullar ("isteyebilir miyiz?") ile
/// sonuç ("verildi mi?") ayrı şeylerdir; v71 tam olarak bu ikisi aynı sanıldığı
/// için çıktı.
///
/// Ama o ölçümün sonucunu bu dosyaya kadar **hiç kimse okuyamıyordu** — ne
/// sahip, ne biz. Altı tur boyunca "dinamik panel yine çıkmadı" denip
/// cihazda ne olduğu görülemedi; döner döngünün sebebi buydu.
///
/// Bu dosya ölçümün **okuyucusudur**. Değeri yalnız native yazar; burada
/// hiçbir şey yazılmaz.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';

/// Native'in yazdığı anahtarın Dart'tan görünen adı.
///
/// 🔴 `flutter.` öneki TAŞIMAZ. `shared_preferences` Android'de her anahtarı
/// `flutter.` ile önekleyerek yazar/okur; native taraf bu yüzden tam adı
/// (`flutter.timer_promotion_verdict_v1`) kullanır, Dart tarafı öneki soyulmuş
/// halini görür. Aynı tuzağın önceki kurbanı `timer_panel_preference.dart`.
const kTimerPromotionVerdictKey = 'timer_promotion_verdict_v1';

/// Sistemin terfi kararı.
///
/// 🔴 Değerin **yokluğu** üçüncü bir durumdur: *henüz ölçülmedi*. Bu, RED
/// DEĞİLDİR ve ikisini birbirine karıştırmak "cihaz desteklemiyor" diye yanlış
/// teşhis üretir — oysa sayaç bir kez başlatılmamış olabilir.
enum TimerPromotionVerdict {
  /// İstendi, sistem VERDİ (`FLAG_PROMOTED_ONGOING` ölçüldü).
  granted,

  /// İstendi, sistem VERMEDİ.
  denied,
}

/// Verdict ile yapı damgasını ayıran işaret; `Build.FINGERPRINT` içinde geçmez.
const String _verdictSeparator = '|';

/// Diskteki ham değeri çözer. **Saf** — cihaz gerekmez, testi cihazsız koşar.
///
/// Biçim: `"<VERDICT>|<Build.FINGERPRINT>"`, örn. `"DENIED|samsung/dm1q/.../U1"`.
///
/// Damga neden şart: damgasız bir `DENIED`, kullanıcı ileride terfiyi açan bir
/// sistem güncellemesi alsa bile sonsuza kadar yapışırdı — tek ölçüm kalıcı bir
/// tavana dönüşürdü. Damgasız kayıt bu yüzden "henüz ölçülmedi" sayılır.
///
/// @return `null` = henüz ölçülmedi (**red değil**).
TimerPromotionVerdict? parseTimerPromotionVerdict(String? raw) {
  if (raw == null) return null;

  // 🔴 `split('|')` DEĞİL: damgada beklenmedik bir ayraç çıkarsa verdict yine
  // okunabilsin diye yalnız İLK ayraç böler. Kotlin tarafındaki
  // `split(VERDICT_SEPARATOR, limit = 2)` davranışının birebir karşılığı.
  final separator = raw.indexOf(_verdictSeparator);

  // Ayraç yok (damgasız) ya da damga boş → hangi yapıda ölçüldüğü bilinmiyor.
  if (separator < 0 || separator == raw.length - 1) return null;

  return switch (raw.substring(0, separator)) {
    'GRANTED' => TimerPromotionVerdict.granted,
    'DENIED' => TimerPromotionVerdict.denied,
    // Tanınmayan verdict = bozuk kayıt = ölçüm yok. Uydurma yapılmaz.
    _ => null,
  };
}

/// Diskteki son ölçüm. `null` = henüz ölçülmedi.
///
/// 🔴 **Salt okunur.** Değeri native yazar, yani Dart'ın `SharedPreferences`
/// belleği (`getInstance()` anında dolar) bayat kalabilir: sayaç bu oturumda
/// çalışıp verdict yazılsa bile bu sağlayıcı eski değeri döndürür. Okuyan ekran
/// göstermeden önce `SharedPreferences.reload()` çağırmak zorundadır — bkz.
/// `about_screen.dart` içindeki `_refreshPromotionVerdict`.
final timerPromotionVerdictProvider = Provider<TimerPromotionVerdict?>(
  (ref) => parseTimerPromotionVerdict(
    ref.watch(sharedPreferencesProvider).getString(kTimerPromotionVerdictKey),
  ),
);
