# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> **Öncelik `docs/KALITE-PROGRAMI.md` faz sırasına tabidir.** Kaynak: KALITE-PROGRAMI + `progress.md` açık sorular.
> **Yalnız açık (`[~]`/`[ ]`) maddeler burada.** Tamamlanmış (`[x]`) işlerin ayrıntısı Git geçmişindedir.

---

## 🔴 Yüksek Öncelik

- [~] **v49 stable — sahip cihaz geri bildirimi (2026-07-27) — tamamı planlandı**
  - Sekiz bulgunun **hepsi** `progress.md` **Faz F3 · WP-353…WP-362**'ye bağlandı;
    burada plansız kalan v49 maddesi yoktur. Eşleme: V49-1→WP-357 · V49-2→WP-358+359 ·
    V49-3→WP-360 · V49-4→WP-361 · V49-5→WP-362 · V49-6→WP-354+355 · V49-7→WP-356 ·
    V49-8→WP-353. Ham notlar aşağıda kaynak olarak durur.
  - **V49-1 · Çoklu cihaz sayaç senkronu çalışmıyor.** Tablette sayaç başlatıldı, telefonda başlamadı. **Ayrım yapıldı (kodda doğrulandı, 2026-07-27): bu bir hata değil, açılmamış bir özellik.** `presenceProjectionModeProvider` sabit `legacy` ([`presence_providers.dart:20`](app/lib/data/providers/presence_providers.dart:20)), `globalTimerModeProvider` sabit `disabled` ([`global_timer_providers.dart:22`](app/lib/data/providers/global_timer_providers.dart:22)); `--dart-define`, ortam dosyası veya sunucu tarafı hiçbir anahtara bağlı değil — yalnız testler `overrideWith` ile açabiliyor. Yani v49'da çoklu cihaz senkronu hiçbir koşulda çalışmaz ve bugün denemek için kod değiştirip yeni build çıkarmak gerekiyor. → **WP-357** önce anahtarı ortam bazlı yapar, sonra beta'da iki cihazla kabul alır.
  - **V49-2 · `My Achievement Journey` üstündeki "Primary group" bloğu görüntü kirliliği.** (bkz. ekran görüntüsü 2) Kocaman kart olarak durmayacak; sağ üst köşeye ayar/ikon olarak taşınacak.
    - Grup seçili değilken kullanıcının fark etmesi için **kırmızı rozet** üç yerde birden görünecek: Profil sekmesi (bugün zaten var), Achievement Journey ve ayarların kendisi + ayar ikonunun üstünde.
    - 🔴 **Açık tasarım sorusu:** "kırmızı" kırmızı ağırlıklı temayı seçen kullanıcıda kaybolur. Rozet rengi tema paletinden bağımsız bir uyarı token'ına bağlanmalı; çözüm tema motoruyla birlikte kararlaştırılacak.
  - **V49-3 · Kamp ateşi sahnesi ikinci revizyon.** (bkz. ekran görüntüsü 1) Daha iyi ama bitmedi:
    - Telefonda figürler ateşten **birazcık daha** uzaklaşabilir (küçük artış, abartılmayacak).
    - Gökyüzü çok uzun ve boş — üstten kırpılacak; kart da böylece kısalıp daha az yer kaplar.
    - Yeşil zemin yüksekliği azıcık artacak. 4 kişide sorun yok ama **8 kişide** en üstteki sıranın ucu gökyüzünde kalıyor; kalabalık düzeni bu yükseklikle birlikte kontrol edilecek.
  - **V49-4 · Tablet yatay düzeni.** Tablet kullanıcıları çoğunlukla yatay tutuyor; yatayda kartlar aşırı genişleyip bozuluyor. Tablet/geniş ekran algısı var mı önce tespit edilecek, sonra tablete özel yerleşim konuşulacak. **Sahiple konuşulmadan koda geçilmez.**
  - **V49-5 · Tanıtım turları (onboarding/coach marks) revizyonu.** Mantık doğru, uygulama kötü — hedef/konum/sıra ayarları tutmuyor. Baştan gözden geçirilecek.
  - **V49-6 · Sayaç çalışırken kullanıcı grupta "aktif çalışma"dan düşüyor.** Sayaç başlatılıyor, bir süre sonra grup ekranındaki aktif/çalışıyor listesinden kayboluyor; kronometre kendi tarafında dönmeye devam ediyor. Kodda doğrulanan zemin: presence satırını yalnız Flutter tarafındaki `PresenceLifecycle` 20 sn'de bir tazeliyor ve okuma tarafı 70 sn'den eski satırı çevrimdışı sayıyor ([`presence_lifecycle.dart:39`](app/lib/data/providers/presence_lifecycle.dart:39), [`presence_providers.dart:35-40`](app/lib/data/providers/presence_providers.dart:35)). Native foreground service sayacı yaşamaya devam etse de Flutter izolatı durursa/öldürülürse heartbeat biter. **V3 flag'lerini açmak bu maddeyi tek başına çözmez:** projection yolu da aynı 70 sn'lik istemci lease'ini yeniliyor ([`0081_multi_group_presence_projection.sql:220`](supabase/migrations/0081_multi_group_presence_projection.sql:220)). Önce ölçüm, sonra tasarım kararı.
  - **V49-7 · Kamp ateşinin altındaki gri/kahve leke kalkacak.** PNG katman yığınının en altındaki `ground.png` tam opaklıkla çiziliyor ([`layered_campfire_fire.dart:154`](app/lib/features/classroom/widgets/campfire/layered_campfire_fire.dart:154)); asset büyük, bulanık, koyu kahve-gri bir elips ve yeşil zeminin üstünde kir lekesi gibi duruyor. WP-350 yalnız sıcak glow yarıçapını küçültmüştü, bu katmana dokunmamıştı.
  - **V49-8 · Şifre sıfırlama e-postası hâlâ `localhost:3000`'e atıyor.** Kod tarafı doğru: Android'de `resetPasswordForEmail` flavor'a uygun `redirectTo` geçiyor ([`supabase_auth_repository.dart:197-202`](app/lib/data/repositories/supabase/supabase_auth_repository.dart:197)). Eksik olan **production Supabase projesinin auth yapılandırması**: `Supabase Auth Config` workflow'u bugüne kadar yalnız bir kez başarıyla koştu (run `30164160511`, hedef **staging**). Production'ın `uri_allow_list`i redirect scheme'ini tanımadığı için Supabase linki projenin Site URL'ine (`localhost:3000`) düşürüyor. v49 stable = production backend olduğu için sahip bunu stable'da görüyor. Free tier e-posta şablonu kilitli olduğundan masaüstündeki 6 haneli kod yolu ayrı ve açık bir sorundur.

- [x] **Post-v43 kurtarma: release sadeleştirme + bildirim güveni + sayaç kontratı — WP-269–285 (KAPANDI 2026-07-24)**
  - Sahip 2026-07-24'te (o günkü stable v45 üzerinde) bildirim/sayaç davranışını cihazda kabul etti; bekleyen cihaz kabulleri kapandı. **Güncel ortam durumu bu maddede değil, `progress.md` Proje Gerçekleri'ndedir.**
  - WP-266–285'in kod/staging/yayın işi tamamlandı ve cihazda doğrulandı. `0066–0070` production'a terfi etti; production `deploy_enabled` yeniden `false` kilitlendi.
  - Açık kalan ops kabulü ayrı maddelerde: hesap silme staging (WP-276), başarım/görev/grup matrisi (WP-277).
  - Tarihsel adli rapor git geçmişindedir; güncel ortam durum modeli: `progress.md` Proje Gerçekleri.

- [~] **Global timer + çoklu grup presence + çoklu cihaz senkronu V3 — WP-336–346**
  - Kanonik teknik plan: [`docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md`](docs/GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md). İlk güvenli paralel dalga WP-328 + salt-okunur WP-337'dir.
  - Hedef: çalışma bütün aktif gruplarda görünür; görev/hedef/grup progression yalnız başlangıçtaki primary gruba yazılır; aynı hesap telefon/tablette tek global çalışma durumunu görür ve başka cihazdan durdurabilir.
  - Mevcut native kronometre, bildirim, widget ve `ACTION_STOP_SILENT` sıcak yolu korunur. Global katman additive envelope, ayrı V2 DTO, shadow ölçüm, hesap-bağlı idempotency, `run_revision` + kullanıcı-geneli `state_version` ve feature flag'lerle açılır.
  - Migration hattı **WP-329 → WP-336 → WP-338 → WP-341 → WP-344** seridir. Server finalizer, gün sınırı yeniden yazımı, history retro-attribution ve Pomodoro phase ledger bu programın kapsamı değildir.
  - **Durum 2026-07-27:** migration zinciri üç ortamda da `0085`te; kod yazıldı, **rollout flag'leri kapalı**, cihaz kabulü hiç yapılmadı. Sahip v49'da tam da bu yüzeyde bulgu bildirdi (V49-1). Sonraki adım yeni feature kodu değil, **flag'i önce çalışma zamanında açılabilir hâle getirmek** (bugün sabit kodlanmış) ve beta'da iki cihazla kabul almaktır → **WP-357**.

- [~] **Başarım, görev ve grup ilerlemesi — kod/migration tarihsel, güncel kabul borcu WP-277**
  - Append-only ledger, pending reward/claim, görev, grup avatarı ve süre kaynağı eşitliği için tarihsel implementasyonlar vardır; bunlar yeniden geliştirme kuyruğu değildir.
  - Açık gerçek iş: beş süre kaynağı, iki cihaz, pending claim, görev toggle/undo, private grup/RLS ve İstanbul gün sınırını tek staging+cihaz matrisinde kanıtlamak. Bu WP-277'dir; bug bulunursa ayrı debug WP açılır.
  - Şema tarafı kapandı: production `0085`te. Kalan borç **kod değil kabul** — yeni production migration yine ayrı sahip GO'su ister (`deploy_enabled` varsayılan kapalı).

- [ ] **Google Play production hazırlığı — NO-GO / bilinçli park**
  - Play flavor/updater izolasyonu ve bazı hesap/UGC kodları repoda bulunur; bunları “yapılmadı” diye yeniden claim etmek yanlıştır. Eksikler canlı HTTPS legal kimliği, Console/Data Safety, production Edge/cron kanıtı, izin matrisi, AAB/cihaz/closed-test ve açık GO'dur.
  - Program yalnız kullanıcı Play girişimini açıkça başlattığında canlanır. Kanonik sıra: `docs/KALITE-PROGRAMI.md §8.8`; mağaza kapısı: `docs/play-store/PLAY-RELEASE-GATE.md`.
  - Ek engel: production'da **yedek/PITR yok** (sahip kararıyla muaf). Mağaza kullanıcısı gelmeden önce bu risk ayrıca konuşulmalı — GitHub dağıtımındaki 5 kişilik ekiple mağaza kitlesi aynı risk sınıfı değildir.

- [~] **Hesap silme ve veri saklama — staging ops kabulü WP-276**
  - `0037` RPC'leri, Flutter istek/iptal UI'ı, `purge-accounts` Edge ve retry terminal mantığı kodda var. Eksik olan staging Edge/cron/secret zinciri ile sentetik hesap üzerinden gerçek request→cancel→purge kanıtıdır.
  - Retention kararı: `docs/HESAP-SILME-RETENTION-KARARI.md`. Production purge geri alınamaz ve **yedek yoktur** — staging provası + somut sahip GO'su olmadan production'da çalıştırılmaz.

## 🟡 Orta / Kalan uçlar

- [~] **l10n hijyeni ve audit kapısı — WP-335**
  - WP-295 parametrik önizlemesindeki kullanıcı metinleri EN/TR ARB'ye taşınacak; dört katalog eşliği korunacak.
  - Kullanıcıya çıkmayan `ArgumentError` invariantları yalnız dosya-bazlı, gerekçeli audit muafiyetine alınacak; denetim genel olarak gevşetilmeyecek.

- [~] **Windows Store hazırlığı ve kontrollü yayın — WP-259–262**
  - Stable kanal Microsoft Store MSIX; GitHub Releases yalnız beta/QA ve kaynak dağıtımıdır. Store MSIX'i Microsoft imzalar, ücretli kod imzalama sertifikası alınmaz.
  - Önce Windows Sandbox/VM'de staging test hesabıyla temiz kurulum → iki sürüm arası update → uninstall; mevcut test-imzalı yerel paket korunur, test ortamı izoledir.
  - Sonra Store'da Private Audience ile yalnız seçilen Microsoft hesaplarına görünür pilot; public listing/rollout yalnız WP-262 kanıtları ve somut kullanıcı GO sonrası.
  - WP-259 yerel smoke kanıtı aldı ama temiz VM/ikinci PC kabulü açık; WP-260–262 Partner Center/Private Audience ve kullanıcı GO bekler.
  - Kabul kapıları: `docs/WINDOWS-RELEASE-GATE.md`, `docs/QA-WINDOWS.md` ve `docs/WINDOWS-VM-QA.md`; Windows release flake'i önce WP-273 ile kapanır.

- [ ] **AR/DE dil desteği ve RTL** — WP-278 ürün kararı gerekir
  - EN/TR l10n WP-87/89 ile cihaz/ürün kabulü aldı; AR/DE tabanı vardır ancak insan çevirisi/RTL cihaz kapsamı onaylanmış ürün işi değildir.
- [ ] **Yeni grafik türleri** — WP-67 brief hazır; kullanıcı türleri/onayı vermeden kod WP'si açılmaz.
- [ ] **Taç XP çubuğu — mutlak hedef gösterimi** — WP-275
  - 25k XP / sonraki taç 75k ise etiket ve doluluk mutlak `25k / 75k` olacaktır; ekonomi/server hesabı değişmez.

## ❓ Açık Sorular / Ürün Kararları

- Çoklu sınıf özelliği aktif kullanılıyor mu, yoksa tek sınıfa mı odaklanılmalı? Karar gelince ayrı WP açılır.
- WP-69 aylık rapor: DNS + Resend API key ile canlıya alınacak mı? Karar/ops preflight: WP-279.
- Windows release boşta RAM (300–400 MB iddiası): WP-70 tabanı p95 85.9 MB ölçtü, iddia temiz release'te üretilmedi; bulgu çıkarsa ayrı düzeltme WP'si.
