# WP-231 — İstatistik Dönemi ve Realtime Sözleşmesi

Bu sözleşme, Odak Kampı istatistiklerinin hangi veriyi ne zaman göstereceğini
tek yerde tanımlar. Tüm gün/dönem hesapları **Europe/Istanbul** duvar saatini
kullanır; cihazın yerel saat dilimi dönem sınırını değiştiremez.

## Dönemler

| Ad | Anlam | Not |
|---|---|---|
| Bugün | İstanbul'da 00:00 → şimdi | Yalnız o takvim günü |
| Hafta | Pazartesi 00:00 → şimdi | Kullanıcı kararıyla korunur; "Son 7 Gün" değildir |
| Son 7 Gün | Bugün dahil, geriye 7 takvim günü | Trend/gelecek dönemsel yüzeyler için ayrı yardımcı; haftanın yerine geçmez |
| Ay | Ayın 1'i 00:00 → şimdi | Takvim ayı |

20 Temmuz 2026 Pazartesi fikstüründe: bugün ve takvim haftası 34 dakika;
son 7 gün önceki Pazarın 10 saatini de içerdiği için 10 saat 34 dakika; ay
toplamı 43 saattir. Otomatik kanıt:
`app/test/core/stats/wp231_stats_contract_test.dart`.

## Yenilenme ve çevrimdışı davranış

- Kişisel oturum akışı, yerel ekleme/düzenleme/silme sonrasında önbellekten
  aktif dinleyicilere anında yayın yapar; uzak Realtime cevabı beklenmez.
- Grup günlük toplamları önce güvenli önbelleği gösterebilir. Uzak RPC/Realtime
  anlık hata verirse önbellek korunur; akış 2 saniye sonra yeniden bağlanır.
  Yeniden bağlanan snapshot ikinci cihazın yeni toplamını normal şekilde yazar.
- Önbellek yoksa hata saklanmaz; kullanıcı arayüzü mevcut hata/tekrar dene
  davranışını görür. Eski veya uydurulmuş toplam üretilmez.
- Bu WP yalnız okuma, önbellek ve stream dayanıklılığı değiştirir: migration,
  RLS, XP/başarım hesabı ve production dağıtımı kapsam dışıdır.

Otomatik kanıt: `app/test/data/offline_first_repository_test.dart` içindeki
"group stats reconnect" senaryosu. Gerçek cihazda iki cihaz ve ağ kesilip
gelme davranışı ayrıca doğrulanmalıdır.
