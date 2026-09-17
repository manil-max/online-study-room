# progress.md — Canlı Durum

> Son güncelleme: **2026-09-16** · Saat dilimi: **Europe/Istanbul**
> Güncel durum, aktif iş ve kabul kuyruğunun tek kaynağı bu dosyadır.
> Kurallar: [.agents/AGENTS.md](.agents/AGENTS.md) + [Kalite Programı](docs/KALITE-PROGRAMI.md).
> Önceki WP kartları, kanıtlar ve yayın kayıtları kayıpsız [tarihçede](progress-history-2026-09-11.md).
> Yeni işler buraya yazılır; tarihçedeki “aktif”, “son numara” ve “sıradaki migration” ifadeleri güncel talimat değildir.

## Proje Gerçekleri

| Konu | Doğrulanmış durum | Kanıt / sınır |
|---|---|---|
| Son kayıtlı yayın | **v85 · 1.0.85+85**, etiket commit'i `c4196127` | 2026-09-16 sahip GO "ikisini de yap"; aşağıdaki v85 yayın kaydı. Önceki v84 `c2ad8a6e` |
| v84 release koşumu | **34861451047: completed / success** | preflight, android, windows / build, finalize_android, release_status, finalize_complete başarılı; GitHub Release draft değil (AAB 75,8 MB, APK 81,1 MB, Windows zip 19,8 MB) |
| Play | **production 85, draft** (koşum `35103828308`); alpha 84 completed | Taslak sahip tarafından Console'da ülke seçimi + incelemeye gönderimle açılır; mağaza kabulü değildir |
| Veritabanı | Repo, staging ve production head **0142** (WP-832) | [Sözleşme](tooling/release/deploy-contract.json); 2026-09-16 staging dry-run `35090284985` (72 pgTAP / 1052 PASS), apply `35090616502`; production dry-run `35090984847`, apply `35091309659`; post-check `0142\|0142\|0142`; kapılar yeniden kilitli |
| Kapılar | staging deploy/release **false/false**; production deploy/release **false/true** | Kodda doğrulandı. Production release için ayrı somut GO gerekir; açık bayrak tek başına izin değildir |
| Son yayımlanan Edge düzeltmesi | Yönetimde ad sıfırlamayı geri alma | Staging `34158924034`, production `34158977501`; önceki yayın kaydı, bu tur yeniden deploy yok |
| Çalışma modeli | Tek lider + atanan ayrık dosyalarda alt ajan | Tek dal `main`; 2026-09-14 sahip emriyle push, DB deploy ve v84 yayını yapıldı |
| Son ayrılan WP | **WP-832** | WP-831/832 kartları aşağıda (Google ile devam et) |

**Kanıt sınırı:** Kod/test/yayın başarısı cihaz kabulü değildir. Bu tur başlarken
üç Windows generated plugin dosyası zaten değişikti; bu işlerin kapsamına alınmadı.

## ⚡ Aktif Çalışma Kaydı

### Faz — Google ile devam et (2026-09-16)

Sahip talebi: e-posta doğrulaması/SMTP yükü yerine Android'de "Google ile devam et";
"her şeyi seri yapalım bugün bitsin", ardından "ikisini de yap" (DB apply + yayın).
Sahip kararı: beta ve GitHub dağıtımı kalmayacak → yalnız Play imza anahtarı için
Android OAuth istemcisi; staging Supabase'de Google sağlayıcısı açılmadı.

**Sahip/konsol yapılandırması (lider adım adım yürüttü):**
- Google Cloud projesi `focus-camp-505116`: Branding (logo yok → doğrulama yok),
  Audience External + **In production**; Web istemcisi `1094303444274-0ge35…`
  (redirect: iki Supabase callback), Android istemcisi `com.manilmax.online_study_room`
  + Play uygulama imzalama SHA-1 `71:43:AA:…:F4:7E`.
- Supabase production: Google sağlayıcısı açık, Skip nonce açık.
- GitHub repo variable `GOOGLE_WEB_CLIENT_ID` lider tarafından `gh` ile yazıldı.
- 🔴 Web client secret sahip ekran görüntüsüyle sohbete düştü; sahip döndürmeyi
  istemedi ("iş çıkarma"). Açık risk olarak kayıtlı.

#### WP-831 — Google ile devam et (Android, fail-closed)

**Durum: Otomatik test geçti.** Cihaz kabulü yok.

- **Commit:** `2bae1c6d` (alt ajan). `git show --stat` denetlendi: yalnız SAHİP yollar.
- `google_sign_in` 7.2.0 → `signInWithIdToken` (nonce yok). Düğme yalnız Android +
  `GOOGLE_WEB_CLIENT_ID` dolu + Supabase deposu iken çizilir. İptal sessiz;
  çıkışta Google oturumu da kapanır. Yeni testler: depo 10/10, düğme 9/9.
- **Sınır:** yalnız Play imzalı derlemede çalışır (debug/yükleme anahtarı istemcisi yok).
- **Cihazda doğrulanmalı:** hesap seçici, iptal, ilk girişte adın gelmesi, çıkış → seçici tekrar.

#### WP-832 (0142) — Google adı profile, kayıt tetikleyicisi çökmez

**Durum: Otomatik test geçti + iki ortama uygulandı.** Cihaz kabulü yok.

- **Commit:** `69494227` (alt ajan) + lider `5d1cd787` (local head).
- `handle_new_user`: `display_name → full_name → name`, boşluk sıkıştırma, 24 sınırı;
  yalnız `public_name_not_allowed` boş ada çevrilir (0094 filtresi ve 0122 uzunluk
  kısıtı artık `auth.users` insert'ini düşüremez). DML yok.
- pgTAP 068 yerelde koşmadı (Docker yok); ilk replay CI: 72 dosya / 1052 PASS.
- staging `35090616502`, production `35091309659`, post-check `0142|0142|0142`.

### v85 yayını — 2026-09-16 (sahip GO: "ikisini de yap")

| adım | kanıt |
|---|---|
| Sürüm commit'i | `b837d2d1` notlar; etiket son hâli `c4196127` |
| Deneme 1 | `35091694752` KIRMIZI — CI define'larıyla 10 giriş ekranı testi `Supabase.instance`'a düştü; düzeltme `fe91c089` (karar `SupabaseConfig.isConfigured`) |
| Deneme 2 | `35094590403` KIRMIZI — play-manifest kapısı: `google_sign_in` `USE_FINGERPRINT` sızdırdı; play manifestinde düşürüldü |
| Deneme 3 | `35098855508` 6/6 yeşil; etiket v85 iki kez zorla taşındı (önceki koşumlar Release üretmemişti) |
| Play | `35103828308` — iz `production`, durum `draft` |

🔴 Ders: yerel kapı `GOOGLE_WEB_CLIENT_ID`/`SUPABASE_*` boşken koşuyor; define'a bağlı
UI dalları yalnız release koşumunda çalıştı. Yerelde CI define'larıyla yeniden ölçüldü.

**Birleşik kapı (lider, WP-831+832 sonrası):** 22 kapı · 0 kırmızı · 1 atlandı
(Android native JVM: Gradle wrapper yok) · 294s.

### Faz — Küçük kart erişimi ve güncel notlar (2026-09-11)

Sahip talebi: genel incelemenin **4 ve 5. maddelerini dikkatli uygulamak**; ardından
sahip "sana kalmış, karar ver ve durma" diyerek turu ajana bıraktı (onay alınamaz).
Ajan kararı: kapıyı yeşile döndüren iki kırmızıyı da kapatmak, yayın hattına dokunmamak.

Beş ayrık iş: ürün kodu **WP-822**, belgeler **WP-823**, ortam sözleşmesi **WP-824**,
test fikstürü **WP-825**. **WP-826** denendi ve geri alındı (aşağıda, teşhis yanlıştı).
Kapı liderde tek merkezden.

#### WP-822 — Küçük kart başlık eylemine erişim

**Durum: Otomatik test geçti.** (Cihaz kabulü yok; bir ajanın kapatabileceği en üst aşama.)

- **SAHİP:** `app/lib/features/home/widgets/card_scaffold.dart`, `dday_card.dart`;
  `app/test/features/home/dday_header_edit_wp642_test.dart`, `card_header_access_wp822_test.dart`;
  bu işe ait golden referansları.
- **DOKUNMA:** diğer özellikler, backend/native, tema ve gezinme, Windows generated dosyaları.
- **Kabul:** mevcut simge ve gövde aynı düzenleyiciyi açar; gerçek başlık hedefi en az
  48×48 dp olur; küçük/orta/büyük kartlarda 1/2/3 kayıt taşmaz; klavye ve semantik
  eylem çalışır; mevcut içerik yerleşimi korunur, kaydırma jesti bozulmaz.
- **Yaklaşım:** düğmenin büyümesini mevcut üst dolgu ve başlık boşluğundan karşıla;
  yeni yerleşim veya ayar ekleme. Diğer kartların ölçüleri değişmez.
- **Veri/güvenlik:** repository, migration, RLS, izin ve kullanıcı verisi değişikliği yok.
- **Doğrulama (kodda/testte ölçüldü, 2026-09-11):** `flutter analyze` 0 uyarı.
  `card_header_access_wp822_test.dart` + `dday_header_edit_wp642_test.dart` **18 test yeşil**;
  48×48 hedefin dört köşesi de düzenleyiciyi açıyor, küçük/orta/büyük kartta gövdenin
  üst kenarı ±1 px korunuyor, gövde yüksekliği azalmıyor ve iç kaydırma `maxScrollExtent = 0`.
  İki golden (açık/koyu) gerçek Inter + MaterialIcons yüklenerek yeşil.
- **Golden yolu düzeltildi:** referanslar önce yeni bir kök `app/test/goldens/` altına
  konmuştu; repo kuralı testin yanındaki `goldens/` klasörü (9 dosyada aynı desen).
  `app/test/features/home/goldens/` altına taşındı, o yolda yeniden yeşil.
- **Kaldırılan eski kapı:** WP-642'nin 40×24'ü sabitleyen iddiası düştü; ölçü artık
  48×48. `cardHeaderAction`ın tek çağıranı `dday_card.dart` (kodda doğrulandı), yani
  bu kapının başka tüketicisi yok ve yerine geçen iddia daha güçlü (gerçek kartı ölçer).
- **Cihazda doğrulanmalı:** Samsung'da küçük kartın kalemi; Windows'ta Tab/Enter;
  büyük yazı ölçeğinde üç kayıt. Cihaz kabulü bu kayıtta henüz yok.
- **Geri alma:** yalnız bu WP'nin ayrık commit'i geri alınır; veri taşıması yok.

#### WP-823 — Güncel durum ile tarihsel kaydı ayır

**Durum: Otomatik test geçti.** (Belge işi; doğrulaması arşiv bütünlüğü ve bağlantı denetimi.)

- **SAHİP (lider):** `progress.md`, `backlog.md`, bunların kökteki
  `*-history-2026-09-11.md` arşivleri, `docs/KALITE-PROGRAMI.md`,
  `docs/URUN-POLITIKALARI.md`, `project.md`, `docs/play-store/PLAY-RELEASE-GATE.md`.
- **DOKUNMA:** tüm uygulama ve sunucu kodu, yayın sözleşmesi, gizli dosyalar.
- **Kabul:** eski ilerleme/backlog metni kayıpsız korunur; canlı dosyada v83/0140
  kanıtı ve gerçek kapı değerleri bulunur; eski QA borcu kapanmış sayılmaz;
  yapılmış sınav kartı tekrar yapılacak diye sunulmaz; yeni göreli bağlantılar çözümlenir.
- **Kapsam dışı:** eski bütün WP'lere yeniden kabul vermek, yeni ürün kararı,
  Play production/Windows Store yayını ve deploy.
- **Doğrulama (ölçüldü, 2026-09-11):** arşivler **kayıpsız** — `progress-history` ve
  `backlog-history` dosyalarının 6 satırlık başlıktan sonrası, eski `progress.md` /
  `backlog.md` ile `diff` sonucu birebir aynı (yalnız satır sonu farkı). İki dosyadaki
  tüm göreli bağlantı hedefleri mevcut; `#test-için-bekleyenler` çıpası her iki tarafta var.
  `URUN-POLITIKALARI` §8.1'in "uygulandı" iddiası kodda teyit edildi
  (`kMaxExamEntries = 3`, `exam_countdown_repository.dart`).
  Yayın iddiaları `gh run view` ile teyit edildi: `34166386717` success (headSha
  `1cfcf2f6` = v83 etiketi), `34168099776` success.
- **Geri alma:** belge commit'i geri alınabilir; arşivler eski metni korur.

### İlk birleşik kapı — 2026-09-11, WP-822/823 sonrası

**Kapı KIRMIZI açtı ve kırmızılık bu turun işinden gelmiyordu.** 20 kapıdan 18 geçti,
1 atlandı (Android JVM — Gradle wrapper yok), 1 kırmızı: Flutter test paketi, **7 düşen test**.

**Kanıt:** Aynı 7 test, iki lib dosyası geçici olarak `HEAD` haline döndürülüp
koşulduğunda da **aynı şekilde düştü**; dosyalar yedekten birebir geri kondu.
Yedisi de teşhis edildi ve WP-824 + WP-825 ile kapatıldı (aşağıda).

#### WP-824 — Yerel kapıyı herkeste kırmızı açan env sözleşmesi

**Durum: Otomatik test geçti.**

- **SAHİP:** `app/env.local.example.json`, `scripts/test_all.py`.
- **DOKUNMA:** yayın iş akışları, ürün kodu, diğer env şablonları.
- **Bulgu:** `env.local.example.json` `DISTRIBUTION_CHANNEL: "play"` taşıyordu ve
  belgelenen kurulum (`cp env.local.example.json env.json`) o değeri test paketine
  geçiriyordu. Dört test, **ürün kodu tamamen sağlamken** kırmızıydı:
  `distribution_channel_test` (varsayılanı ölçüyor ama define varken varsayılan hiç
  ölçülmüyor) ve `windows_zip_update_flow_wp578_test` (x3 — kanal `play` olunca
  `UpdaterDialog._downloadAndInstall` fail-closed dönüyor; bu **doğru** davranış,
  indirme akışı hiç çizilmiyor).
- **Kaldırmanın güvenli olduğu kodda doğrulandı:** `distribution_channel.dart`
  `resolve()` içinde flavor kontrolü define'dan **önce** koşar
  (`flavor 'local'|'play' → play`), yani `--flavor local` derlemesinde define'ın
  hiçbir etkisi yok. Gradle `validateEnvironmentIdentity` de bu anahtarı zorunlu
  tutmaz (CHANNEL / APP_ENVIRONMENT / GIT_COMMIT_SHA / MIGRATION_HEAD ister).
  Anahtarın tek gerçek etkisi `flutter test`i bozmaktı.
- **Yeni kapı:** `test-env` (T0, `--internal-test-env-contract`).
  **CI bu sınıfı asla göremez:** `ci.yml` test işinde
  iki anahtarlık sahte `env.json` yazar ve bu anahtarı hiç koymaz; yani CI yeşil
  kalırken yerel kapı herkeste kırmızı açılıyordu. Tek koruma bu kapıdır.
- **Sabotaj kanıtı:** kapı önce bu makinedeki bozuk `env.json`'u yakalayıp FAIL
  döndü, anahtar kaldırılınca OK'e geçti. Ardından üç dosyadaki **23 test yeşil**.
- **Geri alma:** tek commit; veri/şema etkisi yok.

#### WP-825 — 390 px kolundaki üç kırmızı

**Durum: Otomatik test geçti.**

- **SAHİP:** `app/test/features/group_cards_wp690_test.dart`.
- **DOKUNMA:** ürün kodu (`main.dart`, `app_locale.dart`), diğer test dosyaları.
- **Bulgu:** üç test yalnız **390/android** kolunda düşüyordu, 1920 yeşildi.
  Sebep üründe değil fikstürdeydi: `activeAppLocale` globalini **iki ayrı kaynak**
  yazıyor ve ikisi ayrı yerden okuyor — `main.dart` `localeResolutionCallback`
  `.locales` listesinden, `app_locale.dart` `platformLocale()` `.locale` tekilinden.
  Fikstür yalnız `localesTestValue`'yu ezdiği için tekil, host makinenin dilinde
  (`en`) kalıyordu; globali hangisinin **son** yazdığı derleme sırasına, o da
  platforma bağlıydı. Ölçüldü:

  ```
  TANI-LOCALE | active=en ... target=android  →  "3h 22m / 6h", "2h 22m", "1h"
  TANI-LOCALE | active=tr ... target=windows  →  "3sa 22dk / 6sa", "2sa 22dk"
  ```

  Yani test, ürünü değil **host makinenin dilini** ölçüyordu.
- **Düzeltme:** `localeTestValue` da sabitlendi. Gerçek cihazda `.locale` ile
  `.locales.first` **aynıdır**; fikstür cihaza benzetildi, ürün davranışı gizlenmedi.
  Dosyadaki 9 test yeşil. (WP-826 bunu "yüzeysel" sayıp geri almayı denedi ve
  **yanıldı** — aşağıdaki karta bak; yama doğru çözümmüş.)
- **Geri alma:** tek commit; yalnız test fikstürü.

**Kapsam dışı bırakılan, bildirilen bulgular** (`.agents/AGENTS.md §2`):
`release.yml` geçersiz kanal define'ı (**sahip emriyle WP-827'de düzeltildi**) ·
aynı yarım dil fikstürü 12 test dosyasında daha var · `activeAppLocale`in iki
yazarı olması. Üçü de [backlog](backlog.md) içinde, ölçümleriyle.

#### WP-826 — DENENDİ ve GERİ ALINDI (teşhis yanlıştı)

**Durum: Geri alındı.** Commit `b7a2df26`, revert `ef65f915`.

- **Hipotez:** WP-825'in fikstür yaması yüzeyseldi; asıl kusur `activeAppLocale`
  globalini iki yazarın iki ayrı kaynaktan (`.locales` / `.locale`) beslemesiydi.
  `platformLocale()` `.locales.first` okusun, tuzak tümden kalksın.
- **İlk kanıt ikna ediciydi:** `group_cards_wp690_test`, WP-825 yaması
  **kaldırılmış** hâlde bile 9/9 yeşil koştu; sabotaj testi de düzeltmeyi geri
  alınca kırmızı düştü. Buraya kadar her şey hipotezi destekliyordu.
- **🔴 Kapı yanlışı gösterdi:** birleşik kapıda `faq_content_locale_wp526_test`
  kırmızı düştü — *"sistem dili seçili + cihaz Türkçe → içerik TR istenir"*.
  O test **tam tersini** sabitliyor: yalnız `.locale` tekilini. Yani iki test
  dosyası madalyonun iki ayrı yüzünü tutturuyor ve değişiklik kırılmayı
  **çözmedi, yer değiştirdi**.
- **Doğru sonuç:** ayrışma yalnız **test binding'inde** var; üründe `.locale` ile
  `.locales.first` aynı değerdir ve ikisini okumak da meşrudur. `.locale` ayrıca
  "cihazın dili" için Flutter'ın belgelenmiş, niyeti daha açık API'sidir.
  Yani bu bir ürün kusuru **değil**, fikstür kuralıdır: *cihaz dilini sabitleyen
  test her iki yarıyı da sabitlemeli.* `build_config_error_wp594_test` zaten öyle.
  WP-825'in yaması bu kurala uyuyordu — yani baştan doğruymuş.
- **Ders:** "yamayı kaldırınca da yeşil" tek başına kök nedenin kapandığını
  kanıtlamaz; yalnız o dosyadaki belirtinin sustuğunu gösterir. Kanıt birleşik
  kapıdır. Bu tur kapının değerini iki kez gösterdi: ilk koşumda başkasının
  kırmızısını, son koşumda **kendi** kırmızımı yakaladı.
- **Kalıcı etki:** yok; ürün kodu ve test ağacı WP-825 sonrası hâline döndü.

#### WP-827 — Yayın hattındaki geçersiz kanal define'ı (sahip emri)

**Durum: Otomatik test geçti.** Gerçek yayın koşumunda doğrulanmalı.

- **SAHİP:** `.github/workflows/release.yml`, `.github/workflows/stable-candidate.yml`,
  `app/env.ci.example.json`, `docs/denetim/DENETIM-masaustu-surum.md`.
- **DOKUNMA:** ürün kodu, `windows-release.yml`, deploy sözleşmesi, gizli dosyalar.
- **Bulgu:** yayın `env.json`'ına `DISTRIBUTION_CHANNEL: 'github'` yazılıyordu.
  Bu değer `_parseDefine` tarafından tanınmıyor; define sessizce eski `CHANNEL` +
  platform çıkarımına düşüyordu. Sonuç kazara doğruydu, garanti değil.
  **Bu bulgu yeni değil:** `DENETIM-masaustu-surum.md` §T5'te zaten yazılıydı ve
  düzeltilmemişti — rapor edilmiş ama kapıya bağlanmamış bir bulgunun ne kadar
  yaşadığının örneği.
- **Düzeltme:** define artık kanaldan türetiliyor — `beta → githubBeta`,
  `stable → githubStable` (kabuk zaten `FLAVOR`ı aynı dalda seçiyordu, yanına
  `DIST` eklendi). Play adımının `assert`i `githubStable` bekliyor; Play kopyası
  hâlâ `play` alıyor. `stable-candidate.yml` ve aday şablonu `githubStable` oldu.
- **Asıl kalıcı önlem:** `distribution_define_wp614_test.dart` artık `release.yml`
  ve `stable-candidate.yml` enforce adımlarına da bağlı. O test repoda **vardı**
  ama yalnız `windows-release.yml`e bağlıydı; Android yayın yolu tam da onun
  uyardığı hataya bu yüzden düşmüştü.
- **Doğrulama (ölçüldü):**
  - `githubStable` ve `githubBeta` ile WP-614 kapısı **yeşil** (5 test).
  - Eski `github` ile **kırmızı**: *"Verilen define (`github`) kod tarafından
    tanınmadı; derleme sessizce `githubStable` kanalına düştü."* — sabotaj kanıtı.
  - Dört iş akışının YAML'ı ayrıştırıldı, `env.ci.example.json` geçerli JSON (18 anahtar).
  - Kabuk dalı koşturuldu: `beta → DIST=githubBeta`, `stable → DIST=githubStable`.
  - `env.json` yazımı + Play adımı **uçtan uca simüle edildi**; assert geçti,
    `env.play.json` kanalı `play` kaldı, APK `env.json`'ı değişmedi.
- **Cihazda/koşumda doğrulanmalı:** yerelde GitHub Actions koşturulamaz. İlk
  `beta-v*`/`v*` etiketinde kanal adımı ve WP-614 kapısı izlenmeli.
- **Geri alma:** tek commit; artefakt veya veri etkisi yok.

#### WP-828 — Günlük hedef geçmişi yeniden yargılamasın (sahip emri, 2026-09-14)

**Durum: Production'a uygulandı (2026-09-14, sahip emri "yükle").** Cihaz kabulü yok.

- **Sahip emri:** "Kusursuz Ay'da hata varsa düzelt; bug'ları kapat ama **kimsenin
  verisini, rozetini silme**."
- **SAHİP:** `supabase/migrations/0141_goal_frozen_on_completion.sql`,
  `supabase/tests/067_goal_frozen_on_completion_wp828.test.sql`, migration head
  sabitleri (`001_schema_contract.test.sql`, `deploy-contract.json` yalnız
  `local_migration_head`).
- **DOKUNMA:** kullanıcı verisi (DML yok), ödül tabloları, staging/production head
  ve deploy/release bayrakları, Dart kodu.
- **Hata (gerçek PostgreSQL'de ölçüldü):** hafta sonu hedef günleri, Kusursuz Ay,
  "son saniye" ve "sınır yok" geçmişi **bugünkü** `daily_goal_minutes` ile
  yeniden hesaplıyordu. Hedefi düşürmek geçmişi şişiriyor (test: hafta sonu 2 → 12,
  hiç tutulmamış Şubat → Kusursuz Ay 1), yükseltmek ise düzenlenen geçmiş günün
  hedef kaydını **siliyordu** (retract bugünkü hedefle karar veriyordu).
- **Düzeltme:** `goal_progress_events` tamamlanma anındaki hedefi `goal_seconds`
  olarak dondurur. Dört sayım bu kayıtlardan yapılır (0136 ateş serisiyle aynı tek
  kaynak). Geri alma dondurulmuş hedefe bakar; eski (null) satırlarda 60 sn taban.
- **Rozet/veri korunması:** migration hiçbir satır silmez/güncellemez. İlerleme
  projeksiyonu `cumulative` → `greatest` olduğundan kazanılmış kademe düşmez;
  ödül anahtarları tekildir (`URUN-POLITIKALARI §3`). Eski null satırlar yeni
  "sınır yok" açamaz — bilinçli, yanlış pozitif yerine eksik.
- **Doğrulama (ölçüldü):**
  - **Önce kırmızı:** 0141 geçici çıkarılıp yerel baseline koşuldu → 067'de
    A3/A4/A5/B3/B4/C1 tam eski değerlerle düştü; diğer 69 dosya yeşil.
  - **Sonra yeşil:** 0141 ile `tooling/supabase/local.ps1 -Action baseline` →
    **71 dosya · 1031 kontrol · PASS** (067'nin 17 kontrolü dahil).
- **Kapsam dışı:** manuel eklenen geçmiş kayıtlar (hedef olayı üretme kuralı
  değişmedi); Dart çevrimdışı ayna (`achievement_ledger_engine.dart`) tek hedefle
  hesaplıyor — sunucu otoriter, fark [backlog](backlog.md)'da.
- **Yayın (sahip emri "yükle", 2026-09-14), her adım `database-gates`:**
  - staging dry-run `34854178057` — CI'da tam pgTAP replay yeşil, yalnız 0141 listelendi.
  - staging apply `34854599457` — post-check `0141|0141|0141`; kapı kilitlendi.
  - production dry-run `34855061227` — yalnız 0141 listelendi.
  - production apply `34855466018` — post-check `0141|0141|0141` (jiphfrpzvkpzubbkhrwb);
    kapı yeniden kilitlendi. Yedeksiz (Free plan; sahibin 2026-07-27 kalıcı kabulü).
  - Uygulanan SQL veri silmez; mevcut rozet/ödül satırlarına dokunmaz.
- **Canlıda doğrulanmalı:** hedefi değiştiren bir hesapta hafta sonu / Kusursuz Ay
  sayılarının geçmişe göre oynamadığı. Bu kayıtta canlı kullanıcı verisi sorgulanmadı.
- **Geri alma:** 0132/0058/0135 gövdeleri yeniden uygulanır, iki yardımcı
  fonksiyon düşürülür; `goal_seconds` kolonu zararsız kalabilir.

#### WP-829 — Cihaz dilini sabitleyen testler iki yarıyı birlikte ezsin (2026-09-14)

**Durum: Otomatik test geçti.** Ürün kodu değişmedi.

- **SAHİP:** `scripts/test_all.py` (yeni kapı), yarım sabitleme yapan 12 test dosyası.
- **DOKUNMA:** `app/lib`, `l10n_bootstrap_test.dart` (bilerek istisna), diğer testler.
- **Bulgu:** WP-825/826'nın sınıfı — `localeTestValue` ile `localesTestValue`
  test binding'inde ayrı, cihazda aynı. Yalnız birini ezen test diğerini host
  makinenin dilinde bırakır. 11 dosya yalnız listeyi, `faq_content_locale_wp526`
  yalnız tekili eziyordu; hepsi kazara yeşildi.
- **Düzeltme:** her dosyaya eksik yarı, aynı değerle eklendi (cihaz davranışı).
- **Kalıcı önlem:** T0 kapısı `test-locale-pin` — yarım sabitleme varsa FAIL.
- **Doğrulama (ölçüldü):** kapı düzeltmeden önce **tam bu 12 dosyayı** yakalayıp
  kırmızı düştü; sonra OK (14 dosya). Değişen 12 dosya birlikte **148 test yeşil**.
- **Geri alma:** tek commit; yalnız test fikstürü ve kapı.

#### WP-830 — Vitrin rozeti yazması ağ hatasında sessizce kayboluyordu (2026-09-14)

**Durum: Otomatik test geçti.** Cihaz kabulü yok.

- **SAHİP:** `app/lib/features/profile/social_profile_screen.dart`, `app_en.arb` /
  `app_tr.arb` (tek anahtar `profileVitrinKaydedilemedi`),
  `app/test/features/profile/showcase_toggle_feedback_wp830_test.dart`.
- **DOKUNMA:** depo katmanı, sunucu, diğer ekranlar.
- **Ölçüm (backlog'daki 149 aday):** `discarded_futures` + `unawaited_futures`
  geçici açıldı, `lib`'de **152 çağrı** (ayar dosyası geri kondu). Çoğu yerel
  tercih yazımı, animasyon, titreşim, gezinme. Kullanıcı verisini **sunucuya**
  yazıp hatayı kendi içinde **yakalamayan** tek yol vitrin rozetiydi. Alarm
  kaydı (`finally` + `invalidateSelf`, WP-611) ve sayaç durdurma (iç `try`)
  zaten korunuyor; toplu `unawaited` eklenmedi.
- **Düzeltme:** yazma beklenir; hata olursa "Vitrin kaydedilemedi" SnackBar'ı
  (WP-610 kalıbı). Başarıda ek mesaj yok — değişiklik vitrinde görünür.
- **Doğrulama (ölçüldü):** yeni test **önce kırmızı** (yazma yapıldı, hata
  atıldı, mesaj yok) → düzeltme sonrası 2/2 yeşil. Iskalanan dokunuş testi yanlış
  sebeple geçirmesin diye hit-test uyarısı ölümcül yapıldı. Bu ekrana dokunan
  14 test dosyası 122 test yeşil; l10n kapıları yeşil.
- **Cihazda doğrulanmalı:** uçak modunda vitrin rozetine uzun bas → uyarı çıkar.
- **Geri alma:** tek commit; veri etkisi yok.

### v84 yayını — 2026-09-14 (sahip GO: "çıkartsana")

| adım | kanıt |
|---|---|
| Sürüm commit'i | `c2ad8a6e` — `1.0.84+84`, CHANGELOG + uygulama notu + teknik not |
| Yerel kapı | 22 kapı · 0 kırmızı · 1 atlandı (Android JVM, ortam) · 349s |
| GitHub CI | run `34859357035` 7/7 yeşil (analiz+tüm testler, 2 Android emülatör, Windows golden + entegrasyon, SQL sözleşmesi, Edge) |
| Etiket | `v84` → `c2ad8a6e` |
| Release orkestratörü | run `34861451047` 6/6 yeşil; WP-827 kanal yolundan çıkan **ilk** etiket |
| Play alpha | run `34866744677` — iz `alpha`, durum `completed` |
| Mağaza notu | TR 360 / EN 348 karakter (sınır 500) |
| Veritabanı | 0141, yayından **önce** iki ortama uygulanmıştı (WP-828) |

İçerik: WP-822 (küçük kart kalemi), WP-828 (rozet hedef düzeltmesi, sunucuda zaten
canlı), WP-830 (vitrin hata uyarısı), WP-827 (yayın kanalı define'ı).

**Cihazda doğrulanacak (v84):** küçük kart kalemi rahat dokunuluyor; uçak modunda
vitrin rozetine uzun basınca uyarı çıkıyor; hedefi değiştirince hafta sonu /
Kusursuz Ay sayıları geçmişe göre oynamıyor; Windows güncelleyici v84'ü görüyor.

### Kapanış kapıları — 2026-09-11

**1. koşum (WP-822…825 sonrası):** `python scripts/test_all.py` ·
**21 kapı · 0 kırmızı · 1 atlandı** · 294s. Flutter test paketi (+ kapsam) 275s
**GEÇTİ**; yeni `test-env` kapısı listede ve geçiyor. Turun başındaki 7 düşen
testin tamamı kapandı.

**2. koşum (WP-826 denemesi sonrası): KIRMIZI.** `faq_content_locale_wp526_test`
düştü — kırmızıyı bu kez **ajanın kendi değişikliği** çıkardı. WP-826 geri alındı.

**3. koşum (revert sonrası): YEŞİL.** 21 kapı · 0 kırmızı · 1 atlandı · 396s.

**4. koşum (WP-827 sonrası): YEŞİL.** **21 kapı · 0 kırmızı · 1 atlandı** · 330s.
Flutter test paketi (+ kapsam) 314s GEÇTİ. Turun kapandığı durum budur.
Not: bu kapı iş akışı dosyalarını **koşturmaz**; WP-827'nin yayın kanıtı ilk
gerçek etiket koşumundadır.

**5. koşum (WP-828 sonrası, 2026-09-14): YEŞİL.** **21 kapı · 0 kırmızı · 1 atlandı** · 352s.
"Migration head BEŞ yerde pinli" 0141 ile geçti; Flutter test paketi 339s GEÇTİ.
Bu kapı pgTAP koşturmaz; WP-828'in SQL kanıtı yukarıdaki yerel baseline'dır.

**6. koşum (WP-829 sonrası, 2026-09-14): YEŞİL.** **22 kapı · 0 kırmızı · 1 atlandı** · 318s.
Yeni `test-locale-pin` kapısı listede ve geçiyor; Flutter test paketi 304s GEÇTİ.

**7. koşum (WP-830 sonrası, 2026-09-14): YEŞİL.** **22 kapı · 0 kırmızı · 1 atlandı** · 288s.
GitHub CI da WP-828/829 yayın commit'inde (`23b6fb87`, run `34855985526`) tamamen yeşil.

**Atlanan kapı yeşil değildir:** *Android native JVM testleri* — bu makinede
Android Gradle wrapper kurulu değil. Bu bir kod iddiası değil, ortam sınırıdır;
o kapının asıl evi CI'daki Android işidir. Bu turda hiçbir native/Kotlin dosyası
değişmedi, yani atlanan kapının kapsamına giren bir değişiklik de yok.

**Bu yeşil ne demek değildir:** cihaz kabulü verilmedi, Play/Store kabulü
sorgulanmadı, uzak DB ve deploy bu turun kapsamında değil, push/tag yapılmadı.

### v86 turu — sahip geri bildirimi (2026-09-17)

Plan: [docs/V86-PLAN.md](docs/V86-PLAN.md). Yedi WP: WP-833 (Google düğmesi cihazda yok),
WP-834 (şifre ekranı opak hata), WP-837 (tanıtım kartları), WP-836 (ana ekran varsayılanları),
WP-835 (varsayılan tema — sahip onayı gerekir), WP-838 (tema tercihi hesapta, 0143),
WP-839 (Play TR mağaza metinleri).

## 🗺️ Yol Haritası

1. WP-827 kanal yolu `v*` için v84'te yeşil geçti (run `34861451047`); `beta-v*`
   etiketi henüz bu yoldan çıkmadı, ilk beta etiketinde `githubBeta` izlenmeli.
2. WP-828 (0141) canlıda: hedefi değiştiren hesapta geçmiş sayıların sabit kaldığını gözle.
3. Aşağıdaki v83 ve kart cihaz kabulü; bulgu varsa ayrı düzeltme kartı.
4. [Backlog](backlog.md) içindeki açık adaylar; bu tur kendiliğinden uygulanmaz.
5. Play production / Windows Store: güncel mağaza kanıtı ve ayrı sahip kararı.

## Test için bekleyenler

**Cihazda doğrulanmalı — v83 kaydından devreden, bu tur kapatılmayanlar:**

| Senaryo | Beklenen |
|---|---|
| Hedefi tutmuş hesapla soğuk açılış | Kutlama oynamaz; o gün hedef gerçekten aşılınca oynar |
| Uçak modunda pano | Bugün değeri bilinmiyorsa `—`/hata görünür, **BAŞLAT çalışır** |
| Geniş kart / masaüstü yükleme | Sahte `%0` veya dolu çubuk göstermez |
| İki cihazda aynı hesap, bir dürtme | Yalnız bir cihazda bildirim |
| Yönetimde ad sıfırla → Geri al | Önceki ad geri gelir |
| WP-822 küçük kart | Kalem rahatça dokunulur, üç kayıt okunur; klavye erişimi çalışır |

**Önceki kabul borcu korunur:** [tarihçenin “Test için bekleyenler” bölümü](progress-history-2026-09-11.md#test-için-bekleyenler)
ve son turların “Cihazda ölçülmeyen” kayıtları yeniden kabul verilene kadar referanstır.
Oradaki eski migration/deploy bekleme ifadeleri güncel head yerine kullanılamaz.
Arşivleme, bu işlere toplu tamamlandı kararı vermez.

## Tarihçe ve bakım

- [2026-09-11 öncesi tüm WP kartları / yayın kanıtları](progress-history-2026-09-11.md).
- [Önceki backlog ve teşhis notları](backlog-history-2026-09-11.md).
- Yeni yayın sonrası **Proje Gerçekleri** tablosunu yerinde güncelle; eski sürümü
  aynı tabloda ikinci bir “güncel gerçek” olarak bırakma.
- Yeni test sonucu hangi commit/koşuma aitse onu yaz; ölçülmeyeni yeşil sayma.
- Kapanan turun ayrıntısını tarihçeye alırken açık kabul maddelerini burada tut.
