# Odak Kampı — Kalite Programı ve Ürün Yol Haritası (Master Plan)

> **Tarih:** 2026-07-12 · **Durum:** Plan — kod değişikliği yok, onay bekliyor
> **Kapsam:** Bu belge tek kanonik kaynaktır. Şunları birleştirir:
> - Ürün vizyonu / yeni konsept (kullanıcı brief'i)
> - Ürün yol haritası sunumu — https://claude.ai/code/artifact/bac7ff5d-1ba9-4306-868e-64b6fbae292d
> - Teknik & mimari plan sunumu — https://claude.ai/code/artifact/d6047722-025b-43a4-bbda-45f3f0faa321
> - Codex yönetici değerlendirmesi ve revize plan (kalite programı)
>
> `docs/YOL-HARITASI.md` ve `docs/TEKNIK-PLAN.md` bu belgeye taşınmıştır; bundan sonra **bu dosya** güncellenir.

## Kanıt etiketleri (her iddiada kullanılır)

| Etiket | Anlamı |
|---|---|
| `Kodda doğrulandı` | İlgili dosya/satır okunarak teyit edildi. |
| `Cihazda doğrulanmalı` | Gerçek Android cihazda kanıt gerektirir. |
| `Ürün kararı gerekiyor` | Kullanıcının/ürün sahibinin kararı olmadan ilerlenmez. |

---

## 0. Yönetici Özeti

Kullanıcının talebi **daha fazla özellik değil, ürün geliştirme kültürünün değişmesidir.** Sorun ekip hızı değil; "kodlandı" durumunun "bitti" sayılmasıdır. Bu yüzden bundan sonraki iş, klasik bir özellik yol haritası değil, bir **kalite programıdır.**

Doğru cevap:
- Daha çok WP açmak değil, "tamamlandı" kelimesini zorlaştırmak.
- Native davranışı gerçek cihazda kanıtlamak.
- Görünüm sistemini semantic token'lara taşımak.
- Saat'i bağımsız bir ürün gibi tasarlamak.
- Başarı ilerlemesini server-authoritative yapmak.
- Stable release'i kalite kapısına bağlamak.

**Sürüm çerçevesi (olgu düzeltmesiyle):** v7 bu oturumda zaten yayınlandı (tag `v7`, 1.0.6+7 — `Kodda doğrulandı`, git log + GitHub Release). Dolayısıyla v7, bir *özellik* sürümüdür; kalite kapısından geçmiş değildir. **İlk kalite-kapılı stable, bir sonraki sürüm olacaktır (öneri: v8 "Güven Sürümü").** Sürüm numarası kalite kapısından geçmeden kesinleştirilmez. `Ürün kararı gerekiyor` (numara/isim).

---

## 1. Ürün Vizyonu ve Konsept (kullanıcının istediği son hâl)

Bu bölüm, her alanın hedeflenen deneyimini kullanıcının kendi ifadeleriyle sabitler. Ölçüt: "çalışsın" değil, **profesyonel kalite** — süre/maliyet önemsiz.

**Benchmark, kopya değil.** Amaç Apple/Google/Samsung arayüzlerini birebir kopyalamak değil; özellik kapsamlarını ve güvenilirlik standartlarını referans alıp, etkileşim kalitesini yakalayıp, **Odak Kampı kimliğiyle özgün** bir ürün tasarlamaktır. (Tasarım/IP açısından da doğrusu budur.)

Beş sekmeli hedef mimari: **Ana Sayfa · Saat · Gruplar · İstatistikler · Profil.** Ana Sayfa günlük kullanım alanıdır; diğer alanların verisi kendi sekmelerinde eksiksiz bulunur.

- **Saat (5):** Dümdüz saat + eski sayaç ayarı değil; bağımsız bir saat uygulaması gibi — Dünya Saati, Alarm, Kronometre, Zamanlayıcı, Odak, StandBy. Ana ekran widget'ı ve bildirim paneli de aynı kalite ve uyumda.
- **Bildirim/sayaç (1):** Bildirimde yalnız `HH:MM:SS` ve altında Başlat/Durdur. Uygulamayı açmadan buradan yönetilebilsin; widget da uygulama açılmadan eklenip çalışsın.
- **Senkron (2):** Uygulama içi çalışma saatleri ile widget istatistikleri arasındaki gecikme/tutarsızlık giderilsin; geniş çaplı denetim.
- **Tema (6):** Sadece yazı rengi değil; uygulamanın **havası** değişsin. Samsung Themes / Android tema uygulamaları ruhunda; 10 palet %99 aynı olmasın. Gerekirse birkaç paket.
- **Başarım & Profil (7, 8):** Başarımlar ayarların içinden çıksın → **Çalışma kayıtlarım / Başarımlar / Ayarlar.** Clash tarzı kademeli başarım listesi (her başarımın kademeleri), XP topla, taç kademe kademe değişsin ve **her yerde** (gruplar dahil) görünsün. Herkese açık profil: gruptan kullanıcıya tıkla → istatistikleri ve seçtiği rozetler; seri arttıkça profil etrafında alev efekti.
- **Gruplar & İstatistik (8):** Boş kalmasın; ana sayfadaki içeriğin karşılığı bu sekmelerde de bulunsun.
- **Bildirimler (8):** Yalnız dürtme değil; yeni bildirim türleri ve ayarları.
- **Küçük düzenler (3, 4):** İstatistik grubunda sıralamayı "grup günlük trendi"nin üstüne al. Gruplar'da kamp ateşini en üste taşı, toparlanma animasyonunu kısalt.

---

## 2. Temel İlke: İki "Tamamlandı" Tanımı

Projede bugün iki farklı "tamamlandı" tanımı var:

1. **Kod/ekran oluşturuldu.**
2. **Özellik kullanıcı beklentisini karşılıyor ve cihazda güvenilir çalışıyor.**

`progress.md` çoğunlukla (1)'i kullanıyor; kullanıcının memnuniyetsizliği (2)'nin gerçekleşmemesinden geliyor. Kalite programının özü: **artık yalnızca (2) "tamamlandı" sayılır.**

---

## 3. Kod Kanıtlı Durum Denetimi

Aşağıdaki teşhisler kaynak kodda doğrulandı ve program bunları çözmek üzerine kuruludur.

| # | Alan | Bulgu | Etiket |
|---|---|---|---|
| B1 | Tema | 10 palet `app_theme.dart`'ta ortak `_bg`/`_card`/yüzey kullanıyor; yalnız `primary`/`accent` değişiyor → hepsi aynı görünüyor. | `Kodda doğrulandı` |
| B2 | Saat | `clock_screen.dart`: Saat sekmesi = büyük saat metni + mevcut `StudyTimerCard`. Bağımsız saat deneyimi yok. | `Kodda doğrulandı` |
| B3 | Başarım | İki motor paralel: `gamification.dart` (4 başarı) + `achievement_engine.dart` (10×6). Yeni motorda `currentStreak=0`, `perfectWeeks=0`, grup günleri boş. XP istemcide hesaplanıyor. | `Kodda doğrulandı` |
| B4 | Widget/senkron | `study_providers.dart` yalnız `AndroidWidgetSnapshot.timer` besliyor; `StudyStatsWidgetProvider` ve `GroupLeaderboardWidgetProvider` gerçek veri almıyor; foreground service yok. | `Kodda doğrulandı` |
| B5 | Sayaç lifecycle | Bildirim/widget Durdur-Başlat komutu uygulama yaşam döngüsüne aşırı bağımlı; canlı akan saat yok (foreground service yok). | `Kodda doğrulandı` |
| B6 | Bilgi mimarisi | `settings_screen.dart`: "Başarı Yolculuğum" Ayarlar > Hesap içinde gömülü. Grup/istatistik ekran sıraları kullanıcı beklentisiyle uyuşmuyor. | `Kodda doğrulandı` |
| B7 | Güvenlik/RLS | `0022` yaklaşımında `gamification_profiles` ve `user_achievements` tüm authenticated kullanıcılara açık; hedef ise sosyal profilin yalnız ortak aktif grup üyelerine görünmesi. | `Cihazda doğrulanmalı` / canlı şema teyidi |
| B8 | Migration | Canlı Supabase'de yalnız `0001–0019` etkileri doğrulandı; `0020–0023` hâlâ uygulanmalı. | `Cihazda doğrulanmalı` |
| B9 | Test kapsamı | Son çalıştırmada ~245–254 test geçti, derleme hatası yok; buna rağmen temel kullanıcı sorunları sürüyor → testler native/arka plan/OEM/gerçek Supabase/uçtan uca davranışı kapsamıyor. | `Kodda doğrulandı` |
| B10 | Doküman gerçeği | `progress.md` / `backlog.md` / `project.md` birbirini tam yansıtmıyor; bazı "tamamlandı" işler backlog'da hâlâ planlı; bazı tablo isimleri gerçek migration'lardan farklı. | `Cihazda/depoda doğrulanmalı` |

**"Tamamlandı" görünen ama (2) tanımını karşılamayan örnekler:** WP-23 Clock Center, WP-26 tema paketi, WP-35 başarı sistemi, Android widget sistemi, WP-36 IA. Her biri Faz 0'da yeniden sınıflandırılacak.

---

## 4. Yeni Çalışma Sistemi

### 4.1 WP durum merdiveni (8 aşama)

1. `Planlandı`
2. `Geliştiriliyor`
3. `Kod tamamlandı`
4. `Otomatik test geçti`
5. `Gerçek cihaz QA geçti`
6. `Ürün kabulü geçti`
7. `Yayınlandı`
8. `Yayın sonrası doğrulandı`

Bir ajan yalnız ilk 3–4 aşamayı kapatabilir. **"Tamamlanan İş Paketleri"ne geçiş için gerçek cihaz (5) ve ürün kabulü (6) zorunludur.**

### 4.2 Her WP için zorunlu teslim paketi

Problem tanımı · kullanıcı senaryoları · kapsam dışı maddeler · tasarım/prototip · teknik tasarım · veri ve migration etkisi · RLS/güvenlik değerlendirmesi · edge-case listesi · otomatik testler · gerçek cihaz test matrisi · performans/batarya değerlendirmesi · erişilebilirlik kontrolü · geri alma planı · kanıtlar (ekran görüntüsü/video/test çıktısı) · ürün sahibi kabulü.

### 4.3 Release kalite kapısı

Aşağıdakilerden biri sağlanmıyorsa **stable release çıkmaz:**
- Kritik/ağır bug: 0
- Migration dry-run: başarılı
- Supabase staging testi: başarılı
- Tüm otomatik testler: başarılı
- Android release build: başarılı
- Gerçek Samsung cihaz testi: başarılı
- Temel kullanıcı yolculukları: başarılı
- Widget ve bildirim cold-start testi: başarılı
- Recovery, admin ve RLS testleri: başarılı
- Beta soak süresi: ≥ 3 gün
- Rollback planı: hazır

### 4.4 Ölçülebilir kabul kriterleri (örnekler)

"Apple seviyesinde / profesyonel" tek başına kriter değildir; ölçülebilir karşılığı:
- Sayaç uygulama kapalıyken 8 saatte ≤ ±1 sn sapar.
- Widget aksiyonu ≤ 500 ms içinde görsel geri bildirim verir.
- Oturum kaydı sonrası uygulama içi istatistik ≤ 1 sn'de değişir.
- Ana ekran stats widget'ı, oturum bitiminden ≤ 5 sn sonra yenilenir.
- Hiçbir başarı aynı kademe için iki kez XP vermez.
- Tema değişince ana UI yüzeylerinin ≥ %95'i yeni token setinden beslenir.
- Kritik metinlerde WCAG AA kontrastı sağlanır.
- Samsung ve Pixel test matrisinde bildirim/widget davranışı kanıtlanır.

---

## 5. Altyapı ve Mimari

### 5.1 Yığın denetimi (tut / ekle / değiştir)

Mevcut sağlam çekirdek (Flutter + Riverpod 3 + Supabase + çift repository + RLS + offline-first) korunur. Felsefe: **yıkma, güçlendir.**

| Katman | Bugün | Pro hedef | Karar |
|---|---|---|---|
| Durum yönetimi | Riverpod 3.3 (elle) | + `riverpod_generator` (ops.) | tut |
| Arka plan yürütme | **Yok** | `flutter_foreground_task` + Kotlin foreground service + WorkManager | **ekle** |
| Bildirim | flutter_local_notifications | + chronometer + full-screen intent | ekle |
| Home widget | home_widget + 3 native provider | + arka plan besleme pipeline (isolate/WorkManager) | ekle |
| Yerel veri | shared_preferences + özel cache | **drift (SQLite)** | değiştir |
| Hata/çökme izleme | **Yok** | `sentry_flutter` | **ekle** |
| Ürün analitiği | **Yok** | PostHog / Firebase Analytics (gizlilik odaklı) | ekle |
| Feature flag / config | **Yok** | Supabase config tablosu / Remote Config | ekle |
| Sunucu mantığı | RPC agregasyon | + Edge Functions + `pg_cron` + trigger | ekle |
| Test | unit + widget | + `integration_test` + golden (tema) + CI kapısı | ekle |
| CI/CD | Release workflow | + PR'da analyze/test/golden kapısı + Play Internal | ekle |
| Animasyon/asset | Vektör fallback | rive / Lottie | ekle |
| Tema | Elle `AppTheme` | **Token tabanlı `ThemeExtension` motoru** | değiştir |
| i18n | Sabit TR string | flutter_localizations + arb (ops.) | ekle |

### 5.2 Android native gerçeği (manifest) ve platform sınırları

`AndroidManifest.xml` `Kodda doğrulandı`:
- **Var:** `INTERNET`, `POST_NOTIFICATIONS`, `REQUEST_INSTALL_PACKAGES`; 3 widget provider + `TimerActionReceiver`.
- **Eklenecek (v8/Saat):** `FOREGROUND_SERVICE` (+ tipi), `WAKE_LOCK`, `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `RECEIVE_BOOT_COMPLETED`, foreground `<service>` tanımı.

**Dürüst platform sınırları (`Cihazda doğrulanmalı`):**
- Bildirimin son **görünümünü sistem/OEM belirler**; Samsung, Pixel ve farklı Android sürümlerinde piksel piksel aynı görünüm garanti edilemez. Hedef `HH:MM:SS` + butonlar ulaşılabilir, ama layout OEM'e bağlıdır.
- Bildirim aksiyonları uygulamayı açmadan native receiver/service ile çalışabilir; foreground service uzun süren görünür işler için kalıcı bildirim kullanır — ancak **servis başlangıç kısıtları ve sürüm farkları** dikkate alınmalı.
- Widget'ı **saniyede bir Flutter'dan yeniden çizmek yanlıştır.** Android periyodik widget güncellemesini < 30 dk garanti etmez; WorkManager normalde < 15 dk'ya uygun değildir. Canlı süre için **native `Chronometer`/zaman tabanlı sistem görünümü**, state değişimleri için **receiver/service** kullanılır. Stats widget'ları **olay bazlı** güncellenir.

### 5.3 Güvenlik ve veri bütünlüğü (kalite kadar kritik)

- **Sosyal profil görünürlüğü:** yalnız ortak aktif grup üyesi görebilmeli; e-posta görünmemeli; adminlik erişimi otomatik genişletmemeli. `0022`'nin geniş açık RLS'i düzeltilmeden sosyal profil "tamamlandı" sayılamaz. `Ürün kararı gerekiyor` + migration.
- **Server-authoritative ilerleme:** XP ve achievement progress istemcide hesaplanmamalı (kullanıcı API ile yazabilir). Akış: server-side RPC/Edge Function + **idempotent achievement event** + **benzersiz ödül kaydı (append-only XP ledger)** + denetim/test.

---

## 6. AI Katmanı (sonraki aşama, sunucu tarafı, graceful)

AI çekirdeği **Supabase Edge Function → Claude API** ile çalışır. İlkeler: anahtar asla istemcide değil; yalnız **agregat** veri gider (isim/e-posta/ham içerik yok); AI kapalıyken çekirdek aynen çalışır; yanıtlar önbeklenir + hız sınırı; maliyet/gecikme ölçülür.

- **AI Çalışma Koçu:** istatistik özetinden kişisel içgörü/öneri ("akşam 20–22 arası %30 daha verimlisin").
- **Adaptif hedef & bildirim metni:** hedefi geçmişe göre ayarla; dürtme/hatırlatıcı metnini bağlama göre yaz.
- **Grup haftalık AI özeti.**
- **Akıllı tema/rozet önerisi.**
- (Ops.) **Anomali/anti-hile tespiti.**

AI, kalite programının önüne geçmez; güven sürümü ve server-authoritative altyapı oturduktan sonra devreye alınır.

---

## 7. Program Sırası ve Fazlar

**Eşzamanlılık kuralı:** Aynı anda **en fazla iki çalışma hattı**. Saat, Tema ve Başarım aynı anda açılamaz — üçü de ortak theme/navigation/profile/provider yüzeylerine dokunur ve büyük çakışma yaratır.

### Faz 0 — Gerçeklik ve kalite altyapısı (yeni özellik üretmez)

**0A · Tek Kaynak ve Tamamlanma Denetimi**
`progress`/`backlog`/`project`/migration'lar/gerçek kodu uzlaştır; her "tamamlandı" WP'yi 8-aşamalı merdivende yeniden sınıflandır; canlı Supabase migration ve Edge Function deploy durumunu kesinleştir.
Teslim: özellik envanteri · bilinen bug listesi (P0/P1/P2) · canlı/yerel migration matrisi · deploy edilmiş Edge Function listesi · risk kaydı · v8 blocker listesi.

**0B · Test ve Gözlemlenebilirlik Temeli**
Kritik akışlar için integration test; widget/bildirim için native Android test planı; senkron olaylarını ölçülebilir kıl; hata/log/telemetry yaklaşımı (Sentry).
Zorunlu senaryolar: cold start · force stop · telefon kilidi · yeniden başlatma · internet kaybı · aynı hesabın iki cihazda açık olması · saat dilimi/gün değişimi · uygulama güncellemesi · batarya optimizasyonu · Samsung One UI ve Pixel davranışı.

### V8 — Güven Sürümü (reliability release; "V7-A/B/C" içerikleri)

Yeni devasa Saat/Tema motoru buraya sıkıştırılmaz. Önce mevcut ürün güvenilir olur.
- **V8-A** Sayaç–bildirim–widget tek doğruluk kaynağı (bkz. §9.1)
- **V8-B** Genel senkronizasyon denetimi (bkz. §9.2)
- **V8-C** Küçük ama görünür IA düzenlemeleri (bkz. §9.3)
Sonra: V8 beta → gerçek cihaz soak → V8 stable (kalite kapısıyla).

### Sonraki büyük sürümler (ayrı adaylar, sırayla)

- **Saat ürünü** (bir uygulama büyüklüğünde program — §9.4)
- **Tema Stüdyosu** (§9.5)
- **Başarım & Sosyal Profil 3.0** — server-authoritative (§9.6)
- **Windows masaüstü kalitesi** (mevcut WP-27)

### Önerilen 12 adımlık sıra

1. Proje gerçeği ve kalite kapıları
2. Migration/RLS/Edge Function canlı durum doğrulaması
3. Sayaç–bildirim–widget tek doğruluk kaynağı
4. Genel session/stat senkronizasyonu
5. Stats ve Groups küçük IA değişiklikleri
6. V8 beta
7. Gerçek cihaz soak testi
8. V8 stable
9. Saat motoru ve Saat uygulaması
10. Tema Stüdyosu
11. Başarım/Sosyal Profil server-authoritative dönüşüm
12. Windows masaüstü kalitesi

---

## 8. Detaylı Program Kapsamları

### 8.1 Sayaç–Bildirim–Widget Tek Doğruluk Kaynağı (V8-A)

Hedef mimari — bütün yüzeyler aynı timer state'ini okur:

```
Native Timer State Store
        │
        ├── Flutter sayaç ekranı
        ├── Kalıcı bildirim
        ├── Ana ekran timer widget'ı
        └── Oturum tamamlama / senkronizasyon
```

State yalnız "geçen saniye" saklamaz; şunları taşır: `mode · status · startedAt · accumulatedSeconds · targetSeconds · currentPhase · cycle · subjectId · commandSequence/version · lastUpdatedAt`.

**Bildirim deneyimi**
- Dar görünüm: `HH:MM:SS` + tek durum metni + Başlat/Durdur.
- Geniş görünüm: `HH:MM:SS` + Başlat/Durdur + (gerekliyse) Sıfırla / +1 dk.
- Butonlar Flutter'ı açmadan native receiver/service üzerinden çalışır.

**Timer widget**
- Sistem `Chronometer` tabanlı canlı süre; Başlat/Durdur; uygulamayı açmadan state değişimi; uygulama açıldığında çift taraflı reconciliation; 2×1, 4×1 ve geniş varyant; light/dark ve Android dynamic color.

**Stats ve leaderboard widget'ları** — saniyelik değil, **olay bazlı**: session eklendi/düzenlendi/silindi · sync tamamlandı · grup değişti · gün sınırı geçti · manuel refresh. Widget kalite kriterleri: intentional empty state, manuel refresh, 48 dp touch target, light/dark, cihaz temasına uyum.

**Kabul kriterleri**
- Uygulama kapalıyken bildirimden 20 ardışık Başlat/Durdur testi geçer.
- Force-stop dışı normal lifecycle'da kontrol kaybı yok.
- Uygulama yeniden açıldığında çift session oluşmaz.
- Bildirim/widget/uygulama arasında durum farkı yok.
- Sayaç 8 saatte ≤ ±1 sn sapar.
- Stats/leaderboard placeholder göstermez.
- Samsung ve Pixel cihaz videosu teslim edilir.

### 8.2 Genel Senkronizasyon Denetimi (V8-B)

```
DB study_sessions
       ↓
Repository stream
       ↓
Canonical stats projection
       ↓
App UI + profile + group + widgets
```

Aynı metrik farklı ekranlarda tekrar tekrar farklı hesaplanmamalı.
Yapılacaklar: tüm istatistik tüketicilerinin envanteri · `Europe/Istanbul` gün sınırının tek yardımcıdan gelmesi · session insert/update/delete sonrası provider invalidation standardı · offline outbox ve Supabase realtime reconciliation · idempotency (aynı session iki kez yazılmaz) · çoklu cihaz conflict politikası · widget snapshot'ın canonical projection kullanması · cache freshness/version alanı · kullanıcıya "son güncelleme" + manuel yenileme.

**Kabul:** aynı veri kümesi tüm ekranlarda aynı toplamı üretir · session sonrası uygulama içi yüzeyler ≤ 1 sn'de güncellenir · widget ≤ 5 sn'de yenilenir · offline session bağlantı gelince bir kez yazılır · gün değişiminde bugünün toplamı sıfırlanır · 23:59–00:01 sınır testleri geçer.

### 8.3 Küçük ama Görünür IA Düzenlemeleri (V8-C)

**İstatistikler — önerilen kesin sıra** (`Ürün kararı gerekiyor` — kullanıcının orijinal isteği "sıralamayı grup günlük trendinin üstüne al" bu sırayla karşılanır ve genişletilir):
1. Grup hedefi
2. Özet kartları
3. Sıralama
4. Grup günlük trendi
5. Uzun dönem eğilim
6. Tüm zamanlar
7. Karşılaştırma

Değişiklik screenshot/golden test ile sabitlenir.

**Gruplar — önerilen sıra:**
1. Kamp ateşi
2. Grup hedefi
3. Grup sıralaması
4. Grup trendi
5. Grup bilgileri/yönetim

Davet kodu / grup değiştirme gibi operasyonel bilgiler kamp ateşinin üstünde büyük alan kaplamamalı; kompakt başlık veya açılır yönetim alanına taşınır.

**Kamp ateşi animasyonu:** toparlanma süresi azaltılır · kullanıcı ilk anlamlı içeriği beklemez · `reduce motion` desteği · hedef: ilk sahne ≤ 300 ms, tam yerleşim ≤ 700 ms · dekoratif/sonsuz animasyon batarya tüketmez.

### 8.4 Saat Ürünü (ayrı bir uygulama büyüklüğünde program)

Saat tek WP olarak yürütülmez.

**Saat 1 — Alan modeli ve zaman motoru (önce motor, UI değil):** tek zaman kaynağı · alarm modeli · çoklu timer modeli · kronometre/lap modeli · pomodoro modeli · timezone/world clock modeli · local persistence · native scheduling · reboot recovery · clock/timezone-change recovery · alarm izinleri ve exact alarm davranışı.

**Saat 2 — Bilgi mimarisi:** Dünya Saatleri · Alarm · Kronometre · Timer · Odak · StandBy. Her alan bağımsız state ve yolculuk. Mevcut `StudyTimerCard` dört sekmede tekrar kullanılmaz.

**Saat 3 — Alarm kalitesi (minimum):** tekrar günleri · tek tarih · etiket · ses · titreşim · kademeli ses · snooze süresi · tek günlük tekrar atlama · ses tuşu davranışı · yaklaşan alarm bilgisi · izin/batarya uyarısı · yeniden başlatmada schedule recovery.

**Saat 4 — Kronometre ve çoklu timer:**
- Kronometre: lap · lap farkı · en hızlı/yavaş lap · kopyala/paylaş · analog/dijital yüz · arka planda devam · bildirim kontrolü.
- Çoklu timer: aynı anda çalışan timer'lar · etiket/renk/ikon · preset · tekrar · başlangıç gecikmesi · +1 dk · sıralama · geçmiş · tamamlanınca güvenilir alarm.

**Saat 5 — StandBy ve widget ailesi:** yatay masa saati · gece modu · AMOLED · burn-in koruması · düşük parlaklık · büyük tipografi · tarih/hava opsiyonu · aktif timer/odak görünümü · saat/alarm/timer/odak ana ekran widget'ları.

**Saat kalite kapısı:** Android sürüm matrisi · Samsung batarya optimizasyonu · reboot testi · DST/timezone testi · alarm aynı dakikada iki kez çalmaz · timer process death sonrası toparlanır · ses/titreşim izinleri açık raporlanır · 24 saat soak testi.

### 8.5 Tema Stüdyosu (renk seçici değil, görünüm motoru)

Mevcut `AppPalette` yalnız `primary/onPrimary/accent/onAccent` taşıyor. Tam sistem katmanlara ayrılır:

- **Renk:** app background · elevated background · surface 1–5 · primary/secondary/tertiary · container rolleri · outline/divider · text primary/secondary/disabled · success/warning/error/info · chart serileri · heatmap tonları · campfire renkleri · widget renkleri · notification accent.
- **Tipografi:** font ailesi · display saati · başlık · gövde · sayısal/monospace · ağırlık ve harf aralığı.
- **Şekil:** kart/buton/input/chip/widget radius · border kalınlığı.
- **Derinlik:** gölge · elevation · outline · blur · glass davranışı.
- **Atmosfer:** gradient · doku · arka plan illüstrasyonu · kamp ateşi çevresi · ambient parçacıklar · glow yoğunluğu.
- **Hareket:** motion profili · geçiş süresi · spring/curve · reduce-motion varyantı.

**Hazır tema aileleri (her biri tam bir sanat yönü, sadece renk değil):** Campfire Night · Deep AMOLED · Nordic Snow · Forest Study · Ocean Glass · Coffee Library · Retro Terminal · Neon Focus · Paper & Ink · Pastel Day · Royal Academy · Dynamic Material You.

**Tema editörü (katmanlı deneyim, 30 renk alanı dayatmadan):** 1) tema seç → 2) mood/varyant seç → 3) ana renk değiştir → 4) gelişmiş token düzenleme → 5) canlı önizleme → 6) kontrast denetimi → 7) kaydet/paylaş/sıfırla.

**Tema kalite kapısı:** ≥ 12 gerçekten farklı hazır tema · light/dark · ana UI'nin ≥ %95'i semantic token'dan · sabit renkler yalnız belgelenmiş istisnada · widget'lar tema/dynamic color ile uyumlu · screenshot/golden matrisi · WCAG AA kontrast · tema değişiminde restart yok · bozuk tema güvenli varsayılana döner.

### 8.6 Başarım ve Sosyal Profil 3.0 (önce birleştir, sonra server-authoritative)

Bugün iki motor paralel yaşıyor; seri/kusursuz hafta/grup günleri sıfır; XP istemcide. **Tek kanonik sistem** kalır.

Server-authoritative akış:

```
Session / Nudge / Group Event
          ↓
Server-side progression evaluator
          ↓
Achievement progress
          ↓
XP ledger (append-only)
          ↓
Crown / rank projection
          ↓
Profile + groups + leaderboard
```

**Append-only XP ledger** alanları: `event id · user id · achievement id · tier · XP amount · reason · created_at · unique event key` — çift ödülü ve hileyi engeller.

**Başarım kategorileri (yalnız saatle sınırlı değil):**
- **Çalışma:** toplam süre · oturum sayısı · tek gün rekoru · tek oturum rekoru · sabah/öğle/gece · hafta sonu · ders çeşitliliği · manuel kayıt kullanmadan çalışma · hedef üstü çalışma.
- **Seri ve düzen:** günlük seri · haftalık hedef · kusursuz hafta · aylık istikrar · zamanında başlama · mola disiplini.
- **Grup:** günlük grup birinciliği · arka arkaya grup birinciliği · grup hedefi katkısı · grup çalışma günü · aynı anda çalışma · grup rekoru.
- **Sosyal:** dürtme gönderme · dürtme ile çalışmaya başlama · arka arkaya dürtme · en çok farklı üyeyi motive etme · grup arkadaşının hedefine katkı. *(Spam'e dayalı başarılar cooldown ve benzersiz günlük kullanıcı koşulu olmadan verilmez.)*
- **Eğlenceli/gizli:** Gece Kuşu · Gün Doğumu · Son Dakikacı · Kamp Ateşinin Bekçisi · Sessiz Maraton · Pazartesi Kahramanı · 404 Dakika · Tam Saat · Baykuş Modu.

**Profil IA — ana eylemler tam olarak:** 1) Çalışma kayıtlarım · 2) Başarımlar · 3) Ayarlar. Başarımlar ayrı tam ekran; ayarların altında olmaz.

**Sosyal profil:** avatar+isim · taç/rütbe · XP · seri · hareket-azaltmalı alev efekti · seçilmiş üç rozet · temel istatistikler · ortak grup bilgisi · gizlilik kontrolleri.

**Güvenlik:** yalnız ortak aktif grup üyesi görebilir · e-posta görünmez · adminlik erişimi otomatik genişletmez · seçilen rozet gerçekten açılmış olmalı · kullanıcı yalnız kendi vitrinini değiştirir · XP/tier istemciden keyfi yazılamaz.

### 8.7 Windows Masaüstü Ürünü (mobil EXE değil)

Windows hattı Flutter/Riverpod/Supabase çekirdeğini korur; ayrı bir desktop
presentation shell kurar. Kanonik ayrıntılı tasarım: `docs/WINDOWS-URUN-PLANI.md`.

- `<640` minimal, `640–1007` kompakt sol rail, `≥1008` etiketli geniş rail;
  mobil alt navigasyon değiştirilmez.
- Geniş içerik max 1440 px içinde masaüstü panellerine adapte olur; mevcut 6
  sütunlu dashboard kayıt modeli ikinci bir desktop veri modeline çatallanmaz.
- Mini pencere bütün uygulamayı küçültmez; timer/aktif ders/temel kontrollerden
  oluşan ayrı Compact Focus yüzeyidir.
- Klavye, mouse/hover, görünür focus, Narrator, high contrast, %100–%200 ölçek,
  çoklu monitör ve sleep/resume birinci sınıf gereksinimdir.
- İlk sürüm standart Windows title bar'ını korur; özel Mica/title bar ancak Snap,
  yüksek kontrast, DPI ve caption davranışları kanıtlanırsa değerlendirilir.
- Stable dağıtım hedefi MSIX'tir; önerilen kanal Microsoft Store'dur. ZIP yalnız
  geliştirme/portable yedektir. İmza/kimlik secret store dışında tutulmaz.

**Windows kalite kapısı:** gerçek Windows release build · 1366×768/1080p/1440p
ve %100/%125/%150/%200 ölçek · yalnız klavye temel yolculuk · Narrator/high
contrast · compact/normal pencere restore · multi-monitor + sleep/resume ·
offline→online ve Android+Windows aynı hesap · temiz install/update/uninstall ·
Windows App Certification/paket doğrulama · çökme/P0=0.

---

## 9. Cihaz QA Matrisi ve Test Senaryoları

Zorunlu senaryolar (Faz 0B'de kurulur, her kalite kapısında koşulur): cold start · force stop · telefon kilidi · yeniden başlatma · internet kaybı · aynı hesap iki cihazda · saat dilimi/gün değişimi · uygulama güncellemesi · batarya optimizasyonu · Samsung One UI ve Pixel davranışı · 23:59–00:01 gün sınırı · reboot sonrası alarm/timer recovery · widget/bildirim cold-start.

---

## 10. Claude'dan Beklenen Sonraki Somut Çıktılar

Yeni bir görsel sunumdan önce üretilecek belgeler (Faz 0 teslimleri):
1. Mevcut özellik kalite envanteri
2. P0/P1/P2 bug listesi
3. V8 blocker listesi
4. Migration ve Edge Function canlı durum matrisi
5. Sayaç/native state mimari şeması
6. Widget veri akışı şeması
7. Tema token sözlüğü
8. Saat özellik matrisi
9. Başarım event ve XP ledger tasarımı
10. Cihaz QA matrisi
11. Her faz için Definition of Done
12. Rollback ve release planı

Her iddia `Kodda doğrulandı` / `Cihazda doğrulanmalı` / `Ürün kararı gerekiyor` etiketiyle verilir.

---

## 11. Açık Kararlar (`Ürün kararı gerekiyor`)

1. **Sürüm çerçevesi:** İlk kalite-kapılı stable adı/numarası (öneri: v8 "Güven Sürümü").
2. **Başlangıç hattı:** Faz 0 → V8 güven sürümü önerilir. Onaylıyor musun, yoksa farklı sıra mı?
3. **Native onayı:** foreground service + exact alarm + boot receiver (item 1/2/5 için şart) — evet mi?
4. **İstatistik kesin sırası:** §8.3'teki 7 maddelik sıra onaylanıyor mu?
5. **Tema derinliği/aileleri:** §8.5'teki 12 aile ve katmanlı editör kapsamı.
6. **Saat kapsamı:** §8.4'teki alanların hangileri ilk sürümde (Uyku/StandBy dahil mi?).
7. **Sosyal profil gizlilik politikası:** yalnız ortak aktif grup üyesi görünürlüğü (RLS `0022` düzeltmesi) — onay.
8. **Windows dağıtımı:** Microsoft Store MSIX (önerilen) mı, doğrudan imzalı
   MSIX + App Installer mı? Windows 10 yalnız best-effort olsun mu? Kapatınca
   normal çıkış mı, isteğe bağlı system tray mi?

---

## 12. Uzlaştırma Notları

- **v7 zaten yayında** (`Kodda doğrulandı`: git log `d7729f4 release: v7 (1.0.6+7)` + GitHub Release). Codex "henüz V6" varsaymış; bu yüzden "kalite sürümü" bir *sonraki* stable (öneri v8) olarak konumlandırıldı. v7 retroaktif olarak bir özellik sürümüdür.
- **Yol haritası vs kalite programı:** İlk sunumdaki v8–v12 özellik yol haritası, Codex'in kalite programıyla birleştirilerek **Faz 0 + Güven Sürümü + sıralı büyük programlar** yapısına dönüştürüldü. Büyük projeler (Saat/Tema/Başarım) korundu ama güven sürümünden ve Faz 0'dan sonra gelir.
- **"Copy Apple/Samsung/Google" ifadesi** benchmark + güvenilirlik + etkileşim kalitesi + özgün Odak Kampı kimliği olarak düzeltildi (IP-güvenli).
- **Platform sınırları** (bildirim OEM'e bağlı, widget < 15 dk garanti yok, native Chronometer, olay bazlı stats) açıkça belgelendi.
- **Codex'in `Hiçbir proje dosyasını değiştirmedim` notu** ile hizalı: bu belge de yalnız plandır; hiçbir uygulama kodu değişmedi.

---

## 13. Kaynaklar

- Android bildirimleri — https://developer.android.com/develop/ui/compose/notifications
- Android foreground services — https://developer.android.com/develop/background-work/services/fgs
- Widget güncelleme kuralları — https://developer.android.com/develop/ui/views/appwidgets/advanced
- Glance app widget güncellemeleri — https://developer.android.com/develop/ui/compose/glance/glance-app-widget
- Android notification actions (home screen guides) — https://developer.android.com/design/ui/mobile/guides/home-screen/notifications
- Android widget quality — https://developer.android.com/docs/quality-guidelines/widget-quality
- Android Dynamic Color — https://developer.android.com/develop/ui/views/theming/dynamic-colors
- Google Clock özellikleri — https://support.google.com/clock/faq/6273949
- flutter_foreground_task — https://pub.dev/packages/flutter_foreground_task
- flutter_local_notifications (chronometer) — https://pub.dev/packages/flutter_local_notifications
- Windows NavigationView — https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/navigationview
- Windows keyboard interactions — https://learn.microsoft.com/en-us/windows/apps/develop/input/keyboard-interactions
- Windows accessibility — https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessibility-overview
- Flutter Windows deployment — https://docs.flutter.dev/deployment/windows
- MSIX signing — https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide
- MSIX container/update model — https://learn.microsoft.com/en-us/windows/msix/msix-containerization-overview
