/// WP-595: makul olmayan koşu süresine karşı korkuluk.
///
/// 🔴 Varlık sebebi ölçüldü, tahmin edilmedi. Gerçek kullanıcı (sahibin
/// kardeşi) 2026-08-08 22:40'ta sayacı **başlattı**, kapattığını sandı ve
/// sabah 10:02'de durdurdu: tek parça **11 sa 22 dk** "çalışma" kaydedildi,
/// XP verildi, başarım açıldı. Sayaç günlüğü (240 satır) o gece boyunca yalnız
/// `lease_heartbeat` / `snapshot_reconciled` içeriyor — yani kod açısından
/// her şey "yolunda" idi.
///
/// O gece hiçbir katman "11 saat kesintisiz çalışma fizyolojik olarak imkânsız"
/// diyemedi, çünkü kodun hiçbir yerinde bir üst sınır, hareketsizlik algısı ya
/// da "hâlâ orada mısın?" sorusu YOKTU. `kMaxTimerMinutes` (180) yalnız geri
/// sayım/pomodoro **ayarını** sınırlar; kronometrenin sınırı yoktur ve
/// kronometrede tick zamanlayıcısı bile kurulmaz
/// (`study_providers.dart` `_startTick`).
///
/// Bu dosya saf ve **zaman enjekteli**dir: `DateTime.now()` çağırmaz. Sayaç
/// hatalarının bu repodaki geçmişi (WP-245/250/373/542) gösterdi ki duvar
/// saatini içeriden okuyan bir kural test edilemez, test edilemeyen kural da
/// sessizce ölür.
library;

/// Tek bir **kesintisiz** koşunun artık "çalışma" sayılamayacağı eşik.
///
/// 6 saat seçildi çünkü:
///   * Ürünün kendi ödül sözlüğünde `day_hero` kademe 3 = tek **günde** 6 saat.
///     Burada ölçülen ise tek **oturumda**, hiç ara vermeden 6 saat — kimse
///     bunu yapmaz.
///   * `steel_will` en üst kademesi 480 dk (8 saat). Eşiği 8'e koymak, ürünün
///     kendi zirve ödülünü alan kişiyi hiç uyarmamak demekti; 6 saat uyarır
///     ama **engellemez**.
///
/// Uyarı bloke edici değildir: yanlış pozitifin bedeli bir cümle, yanlış
/// negatifin bedeli bu olayın kendisidir.
const Duration kImplausibleRunThreshold = Duration(hours: 6);

/// Koşu eşiği aştıysa geçen süreyi, aşmadıysa `null` döner.
///
/// [now] **zorunlu** olarak dışarıdan verilir; varsayılanı yoktur. Varsayılan
/// koymak, bu fonksiyonu duvar saatine bağlar ve testi gece yarısı flake'ine
/// açardı (bu repoda iki kez sürüm koşumunu kırdı).
///
/// Saat geriye giderse ([now] < [startedAt]) fark negatif olur ve eşiğin
/// altında kalır → uyarı çıkmaz. Bu bilinçlidir: WP-542'de görüldüğü gibi
/// geriye giden saat ayrı bir arızadır, onu bu uyarıyla karıştırmak yanlış
/// teşhis üretir.
Duration? implausibleRunElapsed({
  required bool isRunning,
  required DateTime? startedAt,
  required DateTime now,
  Duration threshold = kImplausibleRunThreshold,
}) {
  if (!isRunning) return null;
  if (startedAt == null) return null;
  final elapsed = now.difference(startedAt);
  if (elapsed < threshold) return null;
  return elapsed;
}
