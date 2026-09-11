# backlog.md — Açık Adaylar

> Güncelleme: **2026-09-11**. Aktif iş ve kabul kuyruğu [progress.md](progress.md).
> Önceki metin bütünüyle [tarihçede](backlog-history-2026-09-11.md) korunur.
> Buradaki adayların varlığı uygulama/deploy izni değildir; seçilen iş WP'ye dönüşür.

## Kodda doğrulanmış açık

- **`release.yml` Android yoluna GEÇERSİZ kanal define'ı yazıyor (2026-09-11 ölçüldü):**
  [release.yml](.github/workflows/release.yml) yayın `env.json`'ına
  `DISTRIBUTION_CHANNEL: 'github'` yazıyor. Bu değer `distribution_channel.dart`
  `_parseDefine` tarafından **tanınmıyor** (geçerli olanlar: `play`, `githubStable`,
  `githubBeta`, `windows`, `microsoftStore`); tanınmayan define sessizce eski
  `CHANNEL` + platform çıkarımına düşüyor. Bugün kullanıcıya yansıyan hata **yok**:
  fallback `CHANNEL=beta → githubBeta`, `stable → githubStable` ile aynı yere varıyor
  ve Play AAB zaten hem `play` define'ı hem `--flavor play` ile iki kat korunuyor.
  Ama garanti **kazara**: `CHANNEL` define'ı kalkarsa beta APK sessizce stable
  akışını dinler. Tam olarak WP-614'ün sınıfı, bu kez Android tarafında.
  **Kapı var ama bağlı değil:** `distribution_define_wp614_test.dart` yalnız
  `windows-release.yml`de koşuyor; `release.yml` ve `stable-candidate.yml` sadece
  `current_build_manifest_gate_test.dart` koşuyor. Düzeltme iki parçalı: define'ı
  kanala göre (`githubBeta`/`githubStable`) yaz ve WP-614 testini bu iki iş akışına
  da bağla. **Yayın hattı olduğu için bu turda değiştirilmedi — sahip kararı.**
- **Cihaz dilini sabitleyen testler YARIM sabitliyor (2026-09-11 ölçüldü):**
  Test binding'inde `.locale` (tekil) ve `.locales` (liste) ayrı ayrı ezilebilir;
  gerçek cihazda ikisi aynı değerdir. Yalnız birini ezen test, diğerini **host
  makinenin dilinde** bırakır ve sonuç derleme sırasına/platforma bağlı hâle gelir.
  İki yönü de sahada görüldü: `group_cards_wp690_test` yalnız listeyi eziyordu
  (WP-825'te düzeltildi), `faq_content_locale_wp526_test` yalnız tekili eziyor.
  Doğru kural: **ikisini birlikte ez** — `build_config_error_wp594_test` örnektir.
  Yalnız listeyi ezen 11 dosya daha var (`desktop_*`, `clock_desktop_layout`,
  `v8_critical_flows`, `reward_banner_overlap_wp682`); hepsi şu an yeşil, yani
  kazara doğru sırayı yakalamışlar. `l10n_bootstrap_test` bilerek dışarıda:
  o test sistem dilini değiştirerek çözümleme sözleşmesini ölçüyor.
  **Ürün kodunu değiştirerek çözmeyi denemek WP-826'da başarısız oldu** — kırılmayı
  çözmedi, bir dosyadan diğerine taşıdı. Doğru çözüm fikstür tarafındadır; asıl
  kalıcı önlem, eşleşmeyi zorunlu kılan bir kapıdır.
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
