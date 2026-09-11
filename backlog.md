# backlog.md — Açık Adaylar

> Güncelleme: **2026-09-11**. Aktif iş ve kabul kuyruğu [progress.md](progress.md).
> Önceki metin bütünüyle [tarihçede](backlog-history-2026-09-11.md) korunur.
> Buradaki adayların varlığı uygulama/deploy izni değildir; seçilen iş WP'ye dönüşür.

## Kodda doğrulanmış açık

- **Yerel kapı, belgelenen kurulumla kırmızı açılıyor (2026-09-11 ölçüldü):**
  [`env.local.example.json`](app/env.local.example.json) `DISTRIBUTION_CHANNEL: "play"`
  veriyor; CI'ın ürettiği sahte `env.json` bu anahtarı hiç yazmıyor
  ([ci.yml](.github/workflows/ci.yml)). Sonuç: `cp env.local.example.json env.json`
  diyen herkeste `distribution_channel_test` (1) ve
  `windows_zip_update_flow_wp578_test` (3) düşüyor — kanal `play` olunca sideload
  güncelleme kolu kapandığı için Windows ZIP akışı hiç çizilmiyor. Anahtar kaldırılıp
  koşulunca dördü de yeşile döndü. Ürün hatası değil; ortam sözleşmesi hatası.
  Karar gerekiyor: yerel örneğin varsayılan kanalı ne olmalı, yoksa bu testler
  kanaldan bağımsız mı kurulmalı. **Düzeltme bu turda yapılmadı.**
- **`group_cards_wp690_test` 390 px kolu kırmızı (2026-09-11 ölçüldü):** üç test
  yalnız 390 px'te düşüyor, 1920 px yeşil; `LeaderboardCard` içinde "1sa" metni ve
  seri rozeti bulunamıyor. `DISTRIBUTION_CHANNEL` ile ilgisi yok. Bu, bir hunter
  turudur: önce 390 px'te neyin çizilmediğini ölçen kırmızı test, sonra düzeltme.
  Sebep bu turda ölçülmedi; ürün regresyonu mu, fikstür/viewport sorunu mu bilinmiyor.
- **Günlük hedefin geçmişe uygulanması:** `weekend_goal_days` ve `perfect_months`
  hesabı bugünkü `daily_goal_minutes` ile geçmişi değerlendiriyor.
  Kaynak: [0025](supabase/migrations/0025_achievements_social_metrics.sql),
  [0058](supabase/migrations/0058_perfect_month_28.sql), 0135 wrapper'ı.
  İlk adım gerçek PostgreSQL'de hedef değişimini ölçen kırmızı test; ardından
  günün hedef kaydına dayalı ileri düzeltme. Backfill ve kazanılmış ödüllerin
  korunması birlikte değerlendirilir. **Bu tur SQL testi veya düzeltmesi yapılmadı.**

## Ölçüm / kabul açığı — hata olduğu henüz kanıtlanmış değil

- **Beklenmeyen asenkron işlemler:** son tur `discarded_futures` için 149 aday
  kaydetti; sayı bu tur yeniden ölçülmedi ve 149 hata demek değil. Öncelik
  kullanıcı verisi yazan işlemler. Toplu `unawaited` eklemek çözüm sayılmaz.
- **WP-760 `_refreshPromotionVerdict`:** native yazımdan sonra `prefs.reload()`
  davranışını gerçekten bozulunca düşen testle ölçme borcu. Önceki teşhis ve
  deneyler [backlog tarihçesinin son bölümünde](backlog-history-2026-09-11.md).
- **`name_reset` tekrarı:** son tur tek aktif ad sıfırlama kuralının sunucuda
  bulunmadığını not etmiş; etkisi ve gerekliliği ölçülmeden yeni iş açılmaz.
- **WP-276 / WP-277 kabul uzlaşması:** hesap silmenin staging uçtan uca
  provası ile başarım/görev/grup matrisi eski kabul borçlarıdır. Yeni deploy ve
  sağlık kanıtlarıyla eşleştirilmeden kapanmış sayılmaz; aynı operasyon da
  eski kart açık diye otomatik tekrarlanmaz.
- **Eski QA maddeleri:** [canlı kabul kuyruğu](progress.md#test-için-bekleyenler).
  Arşive taşınmaları kabul edildikleri anlamına gelmez.

## Ürün / dağıtım kararı bekleyenler

- **Windows Store WP-259–262:** temiz VM/ikinci PC, Private Audience ve public
  kabul kayıtları yeniden uzlaştırılmalı. v83 Windows derlemesi başarılıdır;
  bu, Microsoft Store kabulü değildir.
- **Play production:** son kayıt alpha 83 kapalı testtir; production başvurusu
  ve güncel Console gereklilikleri ayrı doğrulanır. “AAB yolu yok” eski iddiası
  geçersizdir: release workflow'u `play` appbundle üretir.
- **WP-69 aylık rapor / WP-279:** DNS + Resend ile canlıya alma için eski karar
  borcu korunur; bu tur karara bağlanmadı.
- **WP-67 yeni grafik türleri:** eski brief yeni özellik izni sayılmaz; mevcut
  grafiklerle çakışma ve ihtiyaç önce karşılaştırılmalı.
- **Tablet yatay düzeni WP-361:** sahibin “tableti boşver” kararıyla parkta;
  kendiliğinden yeniden açılmaz.

## Yeniden yapılacak iş olmayanlar

Sınav geri sayımı (üç kayıt ve hesap senkronu), v49/v51/v54/v57 uygulama
başlıkları ve WP-766 test düzeltmesi eski açık listeden çıkarıldı. Tarihçeleri
korunuyor; bu sınıflama eksik cihaz kabulünü kapatmaz. Çoklu grup desteği için
eski “tek gruba mı odaklanmalı?” sorusu güncel ürün kararı değildir.

Ürün kapsamı ve reddedilen fikirler [Ürün Politikaları](docs/URUN-POLITIKALARI.md)
içindedir; tarihsel rakip önerileri bu kararların önüne geçmez.
