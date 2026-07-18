# Odak Kampı Changelog

Sürüm notlarının kullanıcıya görünen ana kaynağı burasıdır. Uygulama içindeki
`app/assets/release_notes.json`, GitHub Release body ve Ayarlar > Güncelleme
notları ekranı bu metinle aynı kararları yansıtmalıdır.

## [beta-v30 / 1.0.30+30] - 2026-07-18

> **Beta test sürümü.** Canlıda **0039–0043** migration’ları uygulanmış olmalı.
> Onay tick list: `docs/qa/BETA-v30-ONAY-LISTESI.md` · ayrıntılı adımlar: `docs/qa/BETA-TEST-KILAVUZU.md`.

### Highlights
- **Yeni istatistik ekranı (Beta):** Ayarlar’dan aç/kapa; ızgara, kart ekle/çıkar/boyut, dönem yıl/özel + kıyas.
- **Grup analitiği RPC:** üye katkı payı + liderlik serisi (`get_user_day_totals` / contribution / leaderboard).
- **Gamification:** seviye eğrisi, görev vitrini, kozmetik + istemci yazım koruması (0042/0043).
- **Dil:** Arapça / Almanca + RTL altyapı (baseline çeviri).
- **Onboarding / dışa aktarma / akıllı hatırlatma** paketleri bu hatta.

### Fixes
- Analitik migration `start_time` (0039/0040 doğru kolon; 0041 yedek).
- Feedback: oturum/RLS hataları debug log + net oturum mesajı (WP-168).
- Timer test FakeTimer dispose sızıntısı (WP-167).
- Onboarding per-user; export PII strip; RTL directional (WP-166).

### Notes
- Flag **kapalı** varsayılan: eski İstatistik ListView birebir. Test için Ayarlar’dan Beta’yı aç.
- Widget/bildirim SSOT (WP-134–137) hâlâ **cihaz onayı** bekliyor.
- Stable v30 Play kapısı ayrı; bu tag yalnız **githubBeta** sideload APK.

## [v29 / 1.0.29+29] - 2026-07-16

> **Stable — Android ≤13 sayaç FGS çökmesi (WP-103).**

### Highlights
- Android 10–13’te kronometre başlat/durdur uygulama kapanması giderildi.
- Servis API 29–33 `dataSync`, 34+ `specialUse`; manifest `dataSync|specialUse`.

### Fixes
- specialUse-only beyan + DATA_SYNC runtime uyumsuzluğu (IllegalArgumentException).

### Notes
- API 33: başlat → arka plan → durdur; 0 çökme.

## [v28 / 1.0.28+28] - 2026-07-16

> **Stable — gece yarısı saat kartı + hızlı pull-to-refresh.**

### Highlights
- Gece yarısından sonra Ana Sayfa dünün süresini dondurmaz (Europe/Istanbul gün).
- Aşağı çekerek yenileme kritik veriyi ~2 sn içinde bitirir.

### Fixes
- StudyTimerCard freeze yalnız aynı Istanbul gününde (WP-102).
- Pull-to-refresh dar kritik liste + kısa timeout.

### Notes
- Gece yarısı sonrası saat toplamı + bir ekranda pull-to-refresh.

## [v27 / 1.0.27+27] - 2026-07-15

> **Stable — saat başına 50 XP + senkron güvenilirliği (WP-100/101).**  
> Ayrıntı: `release_notes.json` v27 girdisi.

### Highlights
- Her tamamlanan çalışma saati 50 XP (önceden 10).
- Manuel süre ekleme ana sayfa toplamını hemen günceller.
- Pull-to-refresh timeout; widget start presence yeniden yazımı.

## [beta-v26 / 1.0.26+26] - 2026-07-15

> **Beta — tercihler, açılış bildirimleri ve uygulama dili düzeltmeleri.**

### Fixes
- **Aylık e-posta tercihi kalıcı:** Anahtarı kapattığında ekran eski profil
  verisi gelene kadar geri açılmaz; kaydetme başarısız olursa önceki değer geri
  yüklenir.
- **Açılıştaki eski dürtmeler sessiz:** Dinleyici açılmadan önce oluşturulmuş
  dürtmeler artık uygulamayı açınca yerel bildirim üretmez. Uygulama açıkken
  gelen yeni dürtme ise yalnızca bir kez gösterilir.
- **Ayarlar > Uygulama dili:** Sistem varsayılanı, Türkçe ve İngilizce seçenekleri
  eklendi. Seçim hemen uygulanır, yeniden açılıştan sonra korunur ve `sa/dk/sn`
  ile `h/m/s` süre kısaltmalarını da aynı dile göre belirler.

### Test odağı
- Aylık e-posta anahtarını kapatıp Ayarlar'dan çıkıp geri gir; kapalı kalmalı.
- Uygulamayı tamamen kapatıp eski dürtmeler varken aç; eski kayıtlar bildirim
  olarak gelmemeli. Ardından uygulama açıkken yeni bir dürtme gönder.
- Ayarlar'dan uygulama dilini Türkçe ve İngilizce yap; metinler ve istatistik
  süreleri anında değişmeli, uygulamayı kapatıp açınca seçim korunmalı.

## [beta-v25 / 1.0.25+25] - 2026-07-15

> **Beta — Türkçe süre kısaltması düzeltmesi.**

### Fixes
- **Türkçe süreler artık Türkçe:** grafik, istatistik, hedef, kayıt ve sayaç
  kartlarında `4h 5m` yerine `4sa 5dk`; saniye değerinde `40sn` görünür.
- **İngilizce kompakt kaldı:** İngilizce arayüz bilinçli olarak `4h 5m` ve
  `40s` kullanır; uzun `hours/minutes` etiketleri grafiğe geri dönmez.

### Test focus
- Telefonun uygulama dilini Türkçe yap; Ana Sayfa ve İstatistikler'de `sa/dk/sn`,
  ardından İngilizce'de `h/m/s` kaldığını kontrol et.

## [beta-v24 / 1.0.24+24] - 2026-07-15

> **Beta — Kanıtlı One UI bildirim düzenine dönüş ve evrensel yenileme.**

### Fixes
- **Geçmişteki satır geri geldi:** Dil paketi öncesinde kullanılan `timer_notification.xml`
  geri yüklendi: solda canlı sayaç, sağda tek **Başlat/Durdur** düğmesi.
- **Asıl neden giderildi:** `WP-80`'de dinamik panel uygunluğu için silinen özel
  görünüm geri getirildi. Bu, çeviri paketiyle ilişkili değildi.
- **Aşağı çekerek yenile:** Tüm uygulama route'larında dikey listeyi aşağı çekmek,
  güncel oturum/istatistik, grup, ders, bildirim, presence ve başarım verisini
  yeniden ister; uygulamayı kapatıp açmak gerekmez.
- **Belirgin beta paketi:** Launcher adı artık **Odak Kampı BETA TEST**. Mevcut
  beta ikonundaki BETA şeridi adaptive-icon kırpılsa bile paket stable'la karışmaz.

### Test odağı
- Samsung One UI'da bildirimde eski yatay görünümü; uygulamayı açmadan **Durdur**
  ve **Başlat** eylemlerini dene.

## [v22 / 1.0.22+22] - 2026-07-15

> **Stable — Bildirim ve İngilizce bağlam düzeltmeleri.**

### Fixes
- **Sade odak bildirimi:** Çalışırken sistem başlığı altında yalnız canlı sayaç
  ve **Durdur**; boşta yalnız `00:00:00` ve **Başlat** görünür. Eski açıklama
  satırları ile Mola eylemi kaldırıldı.
- **İngilizce süre metinleri:** Başarımlarda `6 Clock` yerine `6 hours`, kademe
  satırlarında `Level 1`; grafiklerde uzun süre adları yerine `4h 5m` biçimi.
- **Başarım ayrıntıları:** Tıklanan başarımlar, aktif dilde tam cümleli koşulları
  gösterir. Açılmış gizli başarımlar koşulunu açıklar; kilitli olanlar sır kalır.

### Test odağı
- Samsung One UI'da odak sayacını başlat/durdur; bildirimde sistem başlığı
  dışında yalnız sayaç ve tek eylem olduğunu doğrula.
- İngilizce ve Türkçe'de Başarımlar ekranını aç; kademe koşullarının anlamlı
  cümleler olduğunu ve grafik sürelerinin `4h 5m` biçiminde kaldığını doğrula.

## [v21 / 1.0.21+21] - 2026-07-15

> **Stable — Global grup erişimi.** Açık gruplar keşfedilebilir; gizli gruplar
> davet koduyla sınırlı kalır.

### Highlights
- **Açık grup keşfi:** Grupları keşfet ekranında açık gruplar aranabilir,
  üyelik kapasitesi ve günlük hedefi görülebilir; tek eylemle katılınabilir.
- **Grup gizliliği:** Yeni grup oluştururken veya yönetici ayarından **Gizli**
  (davet kodu gerekir) ya da **Herkese açık** seçilebilir.
- **Global dil zemini:** Bu yüzey İngilizce ve Türkçe çalışır; desteklenmeyen
  sistem dilleri İngilizceye düşer.

### Security
- Keşif kartları davet kodu, üye listesi, kullanıcı profili ve grup çalışma
  verisi göstermez. Katılım ve kapasite denetimi sunucu tarafında yapılır.

### Notes
- Açık/özel grup migration'ı yayın öncesinde Supabase'e uygulanmıştır.
- Sorun görürsen grup adı, cihaz modeli ve uygulama sürümüyle bildir.

## [beta-v20 / 1.0.20+20] - 2026-07-15

> ⚠️ **Beta test sürümü.** Bu paket stable değildir; bildirim teslimi ve dinamik
> sayaç paneli düzeltmeleri gerçek Android cihazda doğrulansın diye yayımlanır.

### Fixes
- **Açılışta güncelleme bildirimi:** Uygulama açılırken Android sistem bildirimi
  oluşturulmaz; güncelleme anahtarı yalnız uygulama içi güncelleme penceresini
  yönetir.
- **Dürtme patlaması:** Uygulama kapalıyken gelen eski dürtmeler açılışta topluca
  bildirim üretmez. Uygulama açıkken canlı gelen yeni dürtme yalnız bir kez görünür.
- **Dinamik panel uygunluğu:** Sayaç bildirimi özel şablon yerine standart Android
  canlı kronometre, **Mola** ve **Durdur** eylemlerini kullanır; OEM canlı paneli
  için uygun yüzey budur.

### Test odağı
- Uygulamayı açarken Android sisteminde güncelleme bildirimi görünmediğini doğrula.
- Uygulama kapalıyken gönderilmiş dürtmelerin açılışta patlamadığını; uygulama
  açıkken yeni dürtmenin bir kez geldiğini doğrula.
- Sayacı başlatıp uygulamayı görev listesinden kapat; bildirimde süre, Mola ve
  Durdur'u dene. Destekleyen cihazda canlı panel/Now Bar/HyperOS terfisini kaydet.

### Notes
- OEM canlı paneli Android sürümü ve üretici politikasına bağlıdır; standart canlı
  bildirim ve kontroller tüm desteklenen Android sürümlerinde çalışmalıdır.

## [beta-v19 / 1.0.19+19] - 2026-07-14

> ⚠️ **Beta test sürümü.** Bu paket stable değildir; dinamik sayaç paneli ve
> Android izin yönetimi gerçek cihazda doğrulansın diye yayımlanır.

### Highlights
- **Dinamik sayaç paneli:** Bildirim genişletildiğinde canlı süre, **Mola** ve
  **Durdur** kontrolleri gösterilir. Mola sonunda **Çalışmaya dön** kullanılabilir.
- **App kapalı kontrol:** Bildirim eylemleri Flutter ekranının açılmasını
  beklemeden native foreground service tarafından işlenir.
- **İzinleri geri alma:** Widget ve izinler ekranında dört izin için **Kapat**
  düğmesi ilgili Android ayarına gider; ekrandaki rehber, ayarı nasıl geri
  alacağını açıklar.

### Test odağı
- Samsung One UI ve Pixel’de uygulamayı görev listesinden kapatıp panelden
  Başlat/Durdur/Mola dene.
- Bildirim, kesin alarm, pil istisnası ve tam ekran alarm için **Kapat** →
  sistem ayarı → anahtarı kapat → uygulamaya dön akışını dene.

### Notes
- OEM'e göre dinamik panel görünümü ve ayar başlıkları değişebilir.
- Sorun varsa stable yerine bu beta sürümünün numarası ve cihaz modeliyle bildir.

## [v8 / 1.0.18+8] - 2026-07-13

> **Stable — Güven Sürümü.** beta-v8…v18 hattının ürün paketi. Windows masaüstü bu sürüme dahil değil.

### Highlights
- **Native sayaç:** App kapalıyken bildirim/widget Başlat–Durdur; akan süre; oturum kaydı.
- **Saat Merkezi:** Alarm (app kapalı çalar), timer, kronometre, dünya saati, StandBy; timer/krono çalışma oturumuna yazılır.
- **Başarım 3.0:** Server-authoritative XP; taç sıralama/aktif/sohbet/istatistik/profil fotoğrafında; profilde Başarılar üstte.
- **Tema Stüdyosu:** 15 atmosfer (Buzul, Kamp Ateşi, Gelecek Neon, Yumuşak…); anında uygula.
- **IA:** Widget/izinler Ayarlar’da; Ana Sayfa’ya tekrar basınca en üste kayar; avatar zoom.

### Notes
- **XP sıfırlama:** Genel yayın için `0028_xp_reset_general_launch.sql` Supabase SQL Editor’da **bir kez** çalıştırılmalı (tag öncesi/hemen sonrası). Çalıştırılmazsa mevcut XP kalır.
- Sorun olursa bir sonraki stable (v9+) hotfix olarak çıkar.
- Windows (MSIX/IA) ayrı program; bu APK Android stable.

## [beta-v18 / 1.0.18+18] - 2026-07-13

### Highlights
- Taç rütbesi artık profil dışında da görünür: sıralama, aktif üyeler, sohbet, istatistik, grup üyeleri, profil fotoğrafı.
- Profil sırası: **Başarılar** üstte, altında Çalışma kayıtları → Ayarlar.
- Saat: Widget/izinler Ayarlar’a taşındı (ayrı sekme yok); Ana Sayfa sekmesine tekrar basınca en üste kayar.
- Atmosfer temaları: Buzul, Yumuşak Krem, Gelecek Kenarı + Türkçe aile adları (15 tema).

### Notes
- v8 stable’a gömüldü; ayrı beta paketi gerekmez.

## [beta-v17 / 1.0.17+17] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v16 alarm app-kapalı çalmama + hub/widget düzeltmeleri.

### Alarm güvenilirlik

- **`setAlarmClock`:** Doze ertelemesini azaltan saat-uygulaması API’si.
- **Her tetikte fullScreen bildirim + Activity** (app kapalıyken Activity tek başına yetmiyordu).
- **İzin sihirbazı:** Bildirim, kesin alarm, pil, tam ekran — Widget sekmesi + alarm eklerken.
- Exact izni yoksa artık sessizce yutulmuyor; inexact yedek kuruluyor.

### Saat hub

- **6 sekme tek satır:** Widget · Saat · Alarm · Timer · Krono · Dünya (kaydırma yok).
- **En sol: Widget** — ana ekran widget listesi + izin durumu.
- **Saat = çalışma birleşik:** Büyük saat + çalışma oturumu Başlat/Durdur + Mod/ders.

### Widget

- Yeni: **Dijital saat** (TextClock), **Sıradaki alarm**.
- Mevcut: çalışma sayacı, istatistik, sıralama.

## [beta-v16 / 1.0.16+16] - 2026-07-13

> ⚠️ **Beta test sürümü.** Saat Merkezi + native alarm güvenilirlik (P0). Cihaz QA odaklı.

### Saat Merkezi (yeni)

- **6 sekmeli Saat Merkezi:** Saat · Dünya · Alarm · Timer · Kronometre · Odak.
- **Epoch zaman motoru:** Süre duvar saati farkından; Doze/frame atlamaya dayanıklı.
- **Alarm 2.0:** Tekrar günleri, sonrakini atla, anti-snooze (matematik), kademeli ses,
  erteleme, exact alarm izin uyarısı.
- **Native alarm (P0):** `AlarmManager` + kilit ekranı `AlarmRingActivity`;
  varsayılan alarm sesi ile 30 sn crescendo; Kapat / Ertele native.
- **Boot / timezone:** Yeniden başlatma ve saat dilimi değişiminde alarm/timer
  mirror'dan yeniden planlanır.
- **Çoklu timer:** Preset'ler, +1/+5 dk, app kill sonrası bitiş için native schedule.
- **Dünya saati:** Gündüz/gece kartları + ofset etiketi.
- **Kronometre:** Tur, en hızlı/yavaş highlight, kopyala.
- **StandBy:** Yatay masa saati, gece kırmızı ton, burn-in kayması.

### Not

- Çalışma sayacı (Odak / native StudyTimer) ayrı kaldı; bu beta kişisel saat ürününü dener.
- SQL 0025–0027 canlıda olmalı; 0028 yalnız genel yayın. Bu beta XP sıfırlamaz.

## [beta-v15 / 1.0.14+15] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v14 görünüm rötuşunun küçük düzeltmesi.

### Görünüm

- **Bildirimdeki süre tam görünüyor:** Rakamlar çok büyük olduğu için son saniyeler
  (`00:00:` gibi) kırpılıyordu; boyut biraz küçültülüp düğmeye yer açıldı, artık tüm
  `HH:MM:SS` sığıyor.

## [beta-v14 / 1.0.13+14] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v13 cihazda sorunsuz çalıştı; bu sürüm yalnız görünüm rötuşu.

### Görünüm

- **Ana ekran widget'ı sadeleşti:** Artık yalnız akan saat + tek Başlat/Durdur düğmesi
  (başlık ve durum yazısı kaldırıldı).
- **Bildirim/widget düğmesi yumuşadı:** Başlat/Durdur düğmesinin köşeleri yuvarlatıldı
  (pill görünümü).

## [beta-v13 / 1.0.12+13] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v12'de cihazda görülen **açılış çökme döngüsü** giderildi + sayaç bildirimi durak-saati görünümüne yaklaştırıldı.

### Kritik düzeltme

- **Açılış çökme döngüsü giderildi:** beta-v12'de uygulama kapalıyken bildirim/widget
  Durdur'a basınca native servis çöküyor, ardından uygulama her açılışta ~1 sn sonra
  kapanıyordu ("this app has a bug"). Sebep: foreground servis `START_STICKY` ile
  boş komutla yeniden başlatılıp `startForeground` çağrılmadan Android 12+ zaman
  aşımına düşüyordu. Servis artık `START_NOT_STICKY` + her komut yolunda güvenli
  `startForeground`; bildirim aksiyonları arka planda `getForegroundService` kullanır
  (arka plan servis başlatma yasağına takılmaz). Her komut ayrıca sessiz toparlanma
  (try/catch) ile sarıldı — hiçbir durumda uygulamayı çökertmez.

### Görünüm

- **Sayaç bildirimi durak-saatine yaklaştırıldı:** "Boş kutu" yerine büyük, akan
  `HH:MM:SS` rakamları + tek Durdur/Başlat düğmesi. *Not: Android 12+ standart bildirim
  başlığındaki uygulama adını sistem çizer; özel görünümle bile kaldırılamaz. Uygulama
  adı olmayan yüzen kapsül (referans görsel) OEM "canlı bildirim" / Android 16 Live
  Update yoludur — sıradaki adım.*

### Bilinen / sıradaki

- Bildirimin uygulama-adı olmayan **dinamik panel/kapsül** görünümü (HyperOS "Live
  notifications" / Samsung "Now Bar" / Android 16 Live Updates) OEM'e bağlı ayrı iş
  paketidir; bu sürümde standart (uygulama-adı başlıklı) canlı bildirim kullanılır.

## [beta-v12 / 1.0.11+12] - 2026-07-13

> ⚠️ **Beta test sürümü.** Sayaç bildirimi ve ana ekran widget'ı **native** altyapıya taşındı; beta-v11'in R1/R2 düzeltmelerini de içerir.

### Yenilikler / Düzeltmeler

- **Ana ekran widget'ı ve bildirim artık uygulama tamamen kapalıyken de çalışıyor:**
  Sayaç bildirimi ve widget artık native bir Android servisiyle yönetiliyor. Widget'taki
  **Başlat/Durdur** ve bildirimdeki buton, uygulamayı hiç açmadan çalışır. Süre bildirimde
  ve widget'ta native olarak akar (saniyede bir uygulama güncellemesi yok → pil dostu).
- **Oturum kaydı güvende:** Uygulama kapalıyken yaptığın Başlat/Durdur'lar bir kuyruğa
  yazılır; uygulamayı açtığında her çalışma aralığı sunucuya doğru biçimde kaydedilir
  (arka arkaya durdur/başlat oturum sayımını bozmaz).
- **beta-v11 dahil:** Bildirimde gövde yazısı yok + Durdur↔Başlat kalıcı toggle.

### Bilinen / sıradaki

- Native bildirimin cihazın **dinamik paneline** (HyperOS "Live notifications" / Samsung
  "Now Bar") terfisi OEM'e bağlıdır; desteklenmeyen cihazda düz ama temiz canlı bildirime düşer.

## [beta-v11 / 1.0.10+11] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v10 cihaz geri bildirimine göre sayaç bildirimi iki noktada elden geçirildi.

### Düzeltmeler

- **Bildirimde gövde yazısı kalktı (saat uygulaması gibi):** Sayaç bildiriminde artık
  "Odak Kampı çalışıyor" alt satırı yok; yalnız akan `HH:MM:SS` süre ve buton görünür.
- **Durdur↔Başlat kalıcı toggle:** Bildirimdeki **Durdur**'a basınca bildirim artık
  kaybolmaz; süre kaydedilir ve buton **Başlat**'a döner (`00:00:00`). Uygulamayı hiç
  açmadan **Başlat** ile yeni bir oturuma devam edebilirsin; her Durdur ayrı bir oturum
  olarak doğru kaydedilir (arka arkaya durdur/başlat oturum sayımını bozmaz).

### Bilinen / sıradaki

- Bildirimin cihazın **dinamik paneline** (HyperOS "Live notifications" / Samsung "Now Bar")
  native kronometre gibi terfi etmesi ayrı bir adımda ele alınacak (WP-51).
- **Ana ekran widget'ı** ve widget üzerindeki Başlat/Durdur bir sonraki beta'da aynı
  mantıkla elden geçirilecek (WP-42).

## [beta-v10 / 1.0.9+10] - 2026-07-13

> ⚠️ **Beta test sürümü.** Sayaç bildirimi tamamen yeniden yapıldı.

### Düzeltmeler

- **Artık TEK bildirim, canlı akan saat ve Durdur butonu:** Sayaç çalışırken tek bir
  bildirim çıkar; başlığında saniye saniye akan `HH:MM:SS` süre ve altında **Durdur**
  butonu bulunur. Önceki çift bildirim (biri düz "arka planda korunuyor", biri ayrı
  kronometre) kaldırıldı — tek, temiz, saat uygulaması gibi.
- **Durdur uygulama tamamen kapalıyken de çalışır:** Bildirimdeki Durdur'a basınca
  sayaç, uygulamayı açmadan durur; oturum gerçek durdurma anıyla kaydedilir (uygulamayı
  sonra açsan bile aradaki süre yanlış eklenmez).

### Bilinen / sıradaki

- **Ana ekran widget'ı** ve widget üzerindeki Başlat/Durdur bir sonraki beta'da
  aynı mantıkla elden geçirilecek (WP-42).

## [beta-v9 / 1.0.8+9] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v8 cihaz geri bildirimine göre düzeltmeler.

### Düzeltmeler

- **Sayaç bildirimi artık tek ve canlı:** Sayaç çalışırken bildirimde saniye saniye
  akan `HH:MM:SS` kronometre baskın olarak görünür. Önceden servisin düz "arka planda
  korunuyor" bildirimi öne çıkıp canlı bildirimi gizliyordu; artık düz servis
  bildirimi en dibe alındı, üstte tek canlı kronometreli bildirim kalıyor (sessiz).
- **Kamp ateşi sahnesi kısaldı:** Gruplar sekmesindeki kamp ateşi çok uzundu ve
  üstte/altta gereksiz boşluk kaplıyordu; sahne kısaltıldı.

### Bilinen / sıradaki

- Bildirim ve widget'taki **Başlat/Durdur butonlarının uygulama tamamen kapalıyken**
  işlenmesi bir sonraki beta'da (arka plan komut işleme). Şu an bu butonlar uygulama
  açık/açılırken çalışır.

## [beta-v8 / 1.0.7+8] - 2026-07-12

> ⚠️ **Beta test sürümü.** "Odak Kampı Beta" olarak ayrı kurulur. Bu sürümdeki
> native arka plan sayaç, bildirim ve widget davranışı gerçek cihazlarda test
> ediliyor; cihaz/OEM'e göre değişebilir. Geri bildirim bekleniyor.

### Öne çıkanlar

- **Güvenilir arka plan sayacı (V8-A):** Uygulama kapalıyken de çalışan native
  zamanlayıcı ve foreground service; cihaz yeniden başlasa bile aktif sayaç
  geri yüklenir.
- **Canlı bildirim:** Kalıcı bildirimde akan `HH:MM:SS` kronometre ve uygulamayı
  açmadan **Başlat/Durdur**.
- **Widget paritesi:** Ana ekran widget'ında canlı kronometre, olay bazlı
  istatistik/sıralama beslemesi, açık/koyu tema ve Android 12+ dynamic color.
- **Senkronizasyon denetimi (V8-B):** Aynı toplam artık her ekranda tutarlı;
  çevrimdışı açılan oturum tekrar bağlanınca **bir kez** yazılır; gün sınırı
  (Europe/Istanbul) tek kaynaktan.
- **İstatistik sırası:** Sıralama (leaderboard) artık grup günlük trendinin
  **üstünde**, özet kartlarının hemen altında.
- **Gruplar sekmesi:** Kamp ateşi en üstte; davet kodu alttaki açılır "Grup
  bilgileri" paneline taşındı; kamp ateşi yerleşme animasyonu hızlandı ve
  sistemdeki **"animasyonları azalt"** ayarına uyar (batarya dostu).

### Notlar

- Native arka plan sayacı, bildirim aksiyonları ve widget davranışı cihaz pil
  optimizasyonuna ve OEM kısıtlarına bağlıdır; force-stop sonrası garanti değildir.
- Yeni sunucu migration'ı yoktur; v7 ile aynı şema (0020–0023) yeterlidir.

## [v7 / 1.0.6+7] - 2026-07-12

### Öne çıkanlar

- **Bildirim Merkezi:** Dürtme, çalışma hatırlatıcıları, alarm/zamanlayıcı, duyuru,
  güncelleme ve sessiz saatler artık tek ekrandan yönetiliyor.
- **Çalışma hatırlatıcıları:** Seçtiğin saat ve günlerde yerel bildirimle hatırlatma
  kurabilirsin.
- **Sessiz saatler:** Belirlediğin aralıkta dürtme ve hatırlatıcı bildirimleri susturulur.
- **Sosyal Profil 2.0 ve Başarı Yolculuğu:** Kademeli başarılar, XP ve taç vitrini.
- Beş sekmeli yapı netleşti (Ana Sayfa / Saat / Gruplar / İstatistik / Profil);
  Ayarlar'daki tekrar eden "Ana Sayfa" grubu kaldırıldı.

### Düzeltmeler

- Duyurular Bildirim Merkezi'nde okundu takibiyle listelenir.
- Bildirim türleri ve cihaz izin durumu tek yerde açıkça görünür.

### Notlar

- Hatırlatıcı ve alarmlar Android'de yerel bildirimdir; cihaz izni gerekir ve uygulama
  tamamen kapalıyken tam-zamanlı teslim garanti edilmez.
- Bildirim Merkezi'nin sunucu tarafı özellikleri (hatırlatıcı ve duyuru okundu kaydı)
  için `0023_notification_center.sql` ve önceki `0020–0022` migration'ları canlı
  Supabase şemasına uygulanmalıdır.

## [v6 / 1.0.5+6] - 2026-07-11

### Düzeltmeler

- Sayaç bildirimindeki başlıkta artık takılı kalan “0 sn” yerine canlı ilerleyen
  saat (HH:MM:SS) gösterilir.
- Grup adı, hedefi veya davet kodu değiştirildiğinde liste anında tazelenir;
  değişikliği görmek için uygulamayı kapatıp açmak gerekmez.
- Kimse dürtmese bile tekrar tekrar gelen sahte “... seni dürttü” bildirimi
  giderildi; her dürtme yalnızca bir kez bildirilir.
- Bildirim ya da ana ekran widget'ındaki Durdur/Başlat komutu, uygulama kapalıyken
  basıldıysa artık uygulama açılışında da işlenir (önceden yalnız arka plandan öne
  gelişte çalışıyordu).

### Notlar

- Uygulama tamamen kapalıyken Durdur/Başlat'ın ve widget canlı saatinin anında
  çalışması için bir foreground service gerekir; bu ayrı bir iş paketi olarak
  cihaz üzerinde test edilerek eklenecektir.

## [v5 / 1.0.4+5] - 2026-07-11

### Öne çıkanlar

- Android saat, bildirim ve widget deneyimi sadeleştiriliyor.
- Sürüm geçmişi, tek seferlik “Yenilikler” penceresi ve Ayarlar içinden geçmiş
  güncelleme notları eklendi.
- Yeni ikon/branding, tema paleti ve V5 release hazırlıkları ayrı iş paketleriyle
  takip ediliyor.

### Düzeltmeler

- GitHub Release, repo dokümanı ve uygulama içi notlar için tek kaynak prensibi
  kuruldu.

### Notlar

- Push/FCM yoktur. Güncelleme bildirimi uygulama açıldığında yapılan yerel
  GitHub release kontrolüyle best-effort çalışır.

## [v4 / 1.0.3+4] - 2026-07-11

### Öne çıkanlar

- Görünen uygulama adı Odak Kampı olarak netleştirildi.
- Canlı sayaç yüzeyleri, sade bildirim akışı ve grup ekranı hiyerarşisi V4
  hazırlığına alındı.
- Grup sohbeti ve grup ayarlarına erişim daha anlaşılır hale getirildi.

### Düzeltmeler

- Gamification profili yokken başarılar kartı güvenli varsayılan veriyle
  görünür kalır.
- Ana ekrandan yönetilen sayaç ayarlarının ayarlarda tekrarlanması sadeleştirildi.

## [v3 / 1.0.2+3] - 2026-07-10

### Öne çıkanlar

- Kalıcı Android sayaç bildirimi ve bildirim izni altyapısı eklendi.
- Dürtme bildirimleri ve bildirim tercihleri ayarlara bağlandı.
- Grup/presence ve canlı çalışma yüzeyleri daha güvenilir hale getirildi.

### Düzeltmeler

- Uygulama yeniden açıldığında aktif sayaç durumunun wall-clock süreyle toparlanması
  iyileştirildi.
- Demo/offline akışlar için repository davranışları güçlendirildi.

## [v2 / 1.0.1+2] - 2026-06-27

### Öne çıkanlar

- Ana sayfa kart düzeni ve çalışma odası deneyimi geliştirildi.
- Odak/pomodoro sayaç davranışları daha okunur hale getirildi.
- İstatistik ve grup hedefi yüzeyleri sonraki sürümlere zemin olacak şekilde
  toparlandı.

### Düzeltmeler

- Kart taşmaları ve temel responsive düzen sorunları azaltıldı.
- Provider/repository sınırları test edilebilirlik için netleştirildi.

## [v1 / 1.0.0+1] - 2026-06-21

### Öne çıkanlar

- İlk Odak Kampı yayını.
- Odak oturumu başlatma, durdurma ve temel çalışma takibi yayınlandı.
- Profil, grup ve temel istatistik ekranları eklendi.
- Supabase bağlı ve Supabase'siz demo kullanım için temel mimari kuruldu.

## [beta-v1 / 1.0.0-beta+1] - 2026-07-11

### Öne çıkanlar

- Stable ve beta release kanalları ayrıldı.
- Beta APK adı ve GitHub prerelease akışı ayrı takip edilmeye başladı.
