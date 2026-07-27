# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> **Öncelik `docs/KALITE-PROGRAMI.md` faz sırasına tabidir.** Kaynak: KALITE-PROGRAMI + `progress.md` açık sorular.
> **Yalnız açık (`[~]`/`[ ]`) maddeler burada.** Tamamlanmış (`[x]`) işlerin ayrıntısı Git geçmişindedir.

---

## 🔴 Yüksek Öncelik

- [ ] **v51 stable — sahip cihaz geri bildirimi (2026-07-27, ham not; WP'ye bölünmedi)**
  - 🟢 **Önce ne DÜZELDİ (sahip cihazda doğruladı):** Bir cihazda sayaç başlatılınca
    kullanıcı artık **hem kendi cihazında hem diğer cihazında hem de başka
    kullanıcılarda** "aktif çalışanlar" listesinde ve kamp ateşinde görünüyor.
    WP-363 (legacy presence payload şema düzeltmesi) ve WP-365 (V3 rollout,
    presence `shadow`) **cihazda kabul edildi.** Kalan maddeler bu kazanımın
    üstüne biner, onu geçersiz kılmaz.
  - **V51-1 · Yaklaşık 80 saniye sonra aktiflikten düşüyor.** Sayaç çalışmaya
    devam ederken kullanıcı ~80 sn sonra hem **sayacı başlatan cihazda** hem de
    **diğer kullanıcılarda** aktif çalışanlardan ve kamp ateşinden "çalışmıyor"a
    düşüyor. Bu, V49-6'nın hayatta kalan kısmıdır: ilk yazım artık başarılı
    (WP-363), ama satırı diri tutan **heartbeat** tutmuyor. Süre `70 sn`lik
    bayatlama eşiğiyle (`kPresenceStaleThreshold`) örtüşüyor — yani ilk
    yazımdan sonra tazeleme gelmiyor. WP-364 artık bu hatayı **kayda geçiriyor**,
    teşhiste ilk bakılacak yer orası.
    - 🔬 **KÖK NEDEN BULUNDU (kodda doğrulandı, 2026-07-27) → WP-367.** Heartbeat
      *atılıyor* ve *başarılı*; sorun neyi tazelediği. `heartbeat_multi_group_presence()`
      (`0081:219`) lease'i **yalnız** kanonik `user_live_presence_state` satırında
      yeniliyor — fonksiyonun kendi yorumu projeksiyonu bilerek dışarıda
      bıraktığını söylüyor. Ama okuma tarafı `group_live_presence`'ı okuyor ve
      canlılığı **o satırın** `lease_expires_at`'inden türetiyor
      (`presence_providers.dart:85`); o alan apply anında `+70 sn` damgalanıp bir
      daha hiç tazelenmiyor. Shadow birleştirmesinde projeksiyon satırı legacy
      satırı **ezdiği** için (`supabase_presence_repository.dart:142`) taze
      `updated_at` de kurtaramıyor. 70 sn lease + 20 sn okuyucu tik'i = **~80 sn**.
  - **V51-2 · Sayaç değerleri iki cihaz arasında eşitlenmiyor.** İlk ~80 sn
    boyunca iki cihaz da "çalışıyor" gösteriyor **ama sayaçlar senkron değil**:
    birinde başlatınca diğeri hâlâ `00.00.00`. Dahası, biri çalışırken diğerinde
    **yeni bir sayaç başlatılabiliyor** (aynı hesapta ikinci eşzamanlı çalışma
    engellenmiyor). Bildirimler de senkron değil. Yani V49-1'in *görünürlük*
    kısmı çözüldü, *durum/süre aynalama* kısmı çözülmedi — `foregroundMirror`
    kademesi açık olmasına rağmen beklenen aynalamayı üretmiyor.
    - 🔬 **KÖK NEDEN BULUNDU (kodda doğrulandı, 2026-07-27) → WP-368.** Başlatma
      komutu **sunucuya hiç gitmiyor**; cihazda `timer_pending_intervals`
      kuyruğunda bekliyor. Kuyruğu boşaltan `flushShadow()` tek yerden çağrılıyor:
      `_syncBackgroundTimerState` (`study_providers.dart:704`) — yani soğuk açılış
      ve uygulama öne gelme. Başlatmanın hemen ardından çağıran **yok**. A'da
      başlatılan koşu sunucuya yazılmadığı için B açıldığında snapshot boş →
      `00.00.00`. **İkinci sayaç başlatılabilmesi ayrı bir hata değil**, aynı
      hatanın sonucu: sunucu A'nın koşusundan haberdar değil.
      İkincil yarış: `start()` içinde `bindActiveAccount` ile
      `TimerForegroundService.start` ikisi de `unawaited` — bind yetişmezse zarf
      boş `account_id` ile yazılıp kalıcı karantinaya düşüyor.
    - ⚠️ **Kapsam dışı kalan bağımlılık:** `device_id` push kaydından gelir ve
      öyle kalmalıdır — `global_timer_commands.device_id` `push_devices(id)`'ye
      **FK** (`0082:95`). Push kaydı olmayan cihazda senkron çalışmaz; bu ayrı
      bir kart konusudur. Native yalnız kronometre + `work` fazı için komut
      üretir (`StudyTimerService.kt:136`) — V1 sözleşmesi, korunuyor.
  - **V51-3 · Admin ↔ kullanıcı yazışmasında mesaj sırası ters.** Yeni mesajlar
    listenin **altına** eklenip aşağı kaydırmak yerine **üste** ekleniyor;
    beklenen davranış WhatsApp benzeri (yeni mesaj altta, görünüm sona kayar).
    - 🔬 **Kısmen teşhis (kodda doğrulandı, 2026-07-27).** Veri sırası **doğru**
      (`fetchTicketNotes`/`fetchTicketMessages` ikisi de `order('created_at')`
      artan). Eksik olan sunum: **hiçbir ekranda sohbet düzeni yok** — ne
      `reverse: true`, ne sona kaydıran `ScrollController`, ne admin
      (`admin_reports_tab.dart:499`) ne kullanıcı tarafında
      (`feedback_tickets_screen.dart:195`). Liste büyüdükçe görünen pencere en
      eskide takılı kalıyor. Sahibin gördüğü "üste ekleniyor" görüntüsünün bu
      mekanizmayla **birebir** eşleştiği cihazda doğrulanmalı.
  - **V51-4 · Yazışmada karşı tarafın mesajları görünmüyor.** Gelen mesajın
    bildirimi düşse ve duyurularda görünse bile, yazışma ekranına girince
    **yalnız kendi gönderdiğin mesajlar** listeleniyor. Bildirim/duyuru yolu
    mesajı görüyor ama yazışma sorgusu göremiyor → okuma tarafında bir filtre
    veya RLS farkı olması muhtemel (doğrulanmadı).
    - 🔬 **KÖK NEDEN BULUNDU (kodda doğrulandı, 2026-07-27) — RLS değil.**
      **Admin panelinde yazışma ekranı hiç yok.** `fetchTicketMessages` /
      `sendTicketMessage` (yani `feedback_ticket_messages` tablosu) yalnız
      **kullanıcı** tarafındaki `feedback_tickets_screen.dart:107` tarafından
      kullanılıyor. Admin panelindeki diyalog `feedback_ticket_notes`
      tablosunu okuyup yazıyor (`admin_reports_tab.dart:412`) — o tablo admin'in
      **iç notları** içindir, sohbet için değil. Admin kendi notlarını görüyor
      (→ "sadece kendi mesajlarım"), kullanıcının mesajları başka tabloda
      olduğu için hiç görünmüyor. Bildirim/duyuru yolları doğru tabloyu
      okuduğundan onlar çalışıyor. Yani bu bir bozulma değil, **hiç yapılmamış
      bir ekran** — düzeltme değil yapım işi.
  - **Durum (2026-07-27, sahip emri):** V51-1 ve V51-2 → `progress.md` **Faz F5**
    (WP-367 · WP-368 · WP-369/v52). V51-3 ve V51-4 bir süre beklemedeydi
    ("admin tarafı kalsın"); sahip 2026-07-27'de birikmiş işlerin de yapılmasını
    isteyince **WP-374**'e bağlandı ve kapandı.
  - ✅ **V51-3 düzeltildi (WP-374).** Sohbet diyaloğunda hiç `ScrollController`
    yoktu; görünen pencere en eskide takılı kalıyordu. Artık açılışta ve her yeni
    mesajda sona kayar.
  - 🔴 **V51-4'ün yukarıdaki kök nedeni YANLIŞTI — WP-374'te koddan
    çürütüldü.** "Admin panelinde yazışma ekranı hiç yok" iddiası doğru değil:
    `Yanıt yaz` eylemi WP-317/318'den beri `admin_reports_tab.dart`te duruyor ve
    aynı admin-farkında sohbet diyaloğunu açıyor; RPC admin rolünü
    `is_super_admin()`'den türetiyor, RLS süper-admin'e tüm mesajları açıyor.
    Gerçek mekanizma: `İç Notlar` diyaloğu metin kutusu + gönder düğmesiyle bir
    sohbet gibi görünüyor ama yöneticinin özel notlarına yazıyor — yönetici
    oraya yazınca "sadece kendi mesajlarım" tablosu birebir oluşuyor. WP-374
    iki yüzeyi ayırdı.
  - ✅ **V51-1 düzeltmesi production'da (2026-07-27).** `0086` üç ortamda da
    uygulandı (apply run `30288908244`, post-check head `0087`). Sunucu taraflı
    olduğu için **v51 istemcisinde de geçerli** — sahip güncelleme beklemeden
    deneyebilir.
  - ✅ **V51-2 düzeltmesi tamamlandı — ama üç turda (2026-07-27).** Sorunun
    **üç ayrı engeli** vardı ve her tur yalnız bir tanesini kapattı:
    1. İstemci komutu yalnız resume'da yayınlıyordu → WP-368 (v52).
    2. `v2_enabled` hiçbir ortamda açılmamıştı, sunucu her komutu reddediyordu
       → `0087` (v52).
    3. 🔴 **Sunucu→B sinyalini üreten parça hiç devrede değildi:**
       `enqueue_timer_sync_push` yalnız kendi tanımında ve testinde geçiyordu,
       `apply_global_timer_command` onu hiç çağırmıyordu; `timer_sync_push_runtime_config.enabled`
       da kapalıydı → WP-370 / `0088` (v53). **v52 release notu eşitlemeyi vaat
       etti ama tutmadı;** v53 notu bunu açıkça düzeltiyor.
    Aynalama için **iki cihazda da v53** ve push kaydı şart.
    **Ders:** "komut sunucuya gitti" testi, "diğer cihaz haberdar oldu" demek
    değildir. v52'nin testi yalnız birinci ayağı ölçüyordu ve yeşildi.
  - ⚠️ **Bu turda kapatılmayan, bilinen sınır (kart açılmadı, cihaz kabulünden
    sonra değerlendirilecek):** V2 koşusunun kendi lease'ini (`live_study_runs`,
    150 sn) tazeleyen bir `heartbeat` komutu istemci tarafında **üretilmiyor** —
    native yalnız `start`/`stop` zarfı yazıyor (`TimerStateStore.appendV2Command`
    diğer eylemleri reddeder). Süpürücü de bir cron'a bağlı olmadığından koşu
    kendiliğinden `abandoned` olmuyor; pratikte uygulama ölse bile koşu sunucuda
    `running` kalır ve bir sonraki `start` onu devralır. Yani **bu tur için
    zararsız**, ama "cihaz çöktü, koşu kapanmalı" senaryosu hâlâ eksik.
  - ⚠️ **İkinci bilinen sınır (kart açılmadı):** V2 komut üreticisi yalnız
    **Android** ve yalnız `stopwatch` + `work` için çalışıyor
    (`StudyTimerService.kt:136`). Pomodoro, geri sayım ve Windows hiç komut
    üretmiyor, dolayısıyla o modlarda eşitleme **tasarım gereği yok**. v53
    release notunda kullanıcıya açıkça yazıldı.

- [~] **v49 stable — sahip cihaz geri bildirimi (2026-07-27) — tamamı planlandı**
  - ✅ **Kapanan bulgular (2026-07-28, birikmiş düzeltme turu):**
    V49-1 → WP-365 + **WP-373** (senkronun komut sözleşmesi) ·
    V49-2 → WP-358 + **WP-376** (birincil grup bloğu sağ üste) ·
    V49-5 → **WP-375** (tanıtım turu hedef/konum/sıra) ·
    V49-6 → WP-363/364/367 · V49-7 → WP-356 · V49-8 → WP-353.
  - ✅ **V49-3 kapandı → WP-377** (2026-07-28). Parametrik önizleme
    (`campfire_wp377_preview.png`) sahibe sunuldu; sahip halka `1.50` ve gökyüzü
    `85 px` kırpma seçti, marşmelov çubuğunun da uzamasını istedi. Üçü de
    uygulandı ve sabitlere/testlere bağlandı. Aynı turda sahibin "gece gündüz
    saatlerini kontrol et" notu gerçek bir hataya çıktı: sabit çıpalar gerçek
    güneşten ±2,5 saat sapıyordu, mevsimsel model ±13 dakikaya indirdi.
  - 🟡 **Açık kalan tek bulgu:** **V49-4** (tablet yatay yerleşimi, eski
    kart WP-361). Kartın kendi kuralı "sahiple konuşulmadan koda geçilmez" ve
    sahip 2026-07-28'de "tableti boşver" dedi. Bilinçli park.
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
- [x] **Taç XP çubuğu — mutlak hedef gösterimi** — WP-275 (**zaten yapılmış**,
  2026-07-28'de koddan doğrulandı; madde bayattı)
  - `xpBarMetrics` (`app/lib/core/stats/progression_visuals.dart:143`) tam da
    istenen davranışı üretiyor: `currentXp`/`nextThreshold` **mutlak** XP'dir,
    kademe-içi `5.000/55.000` görünümü bilerek üretilmiyor. Hem
    `achievement_showcase.dart` `_XpBar`'ı hem `gamification_card.dart` bu
    ölçüyü kullanıyor ve `achievement_showcase_test.dart` kilitliyor.
    Ekonomi/server hesabı değişmedi.

## ❓ Açık Sorular / Ürün Kararları

- Çoklu sınıf özelliği aktif kullanılıyor mu, yoksa tek sınıfa mı odaklanılmalı? Karar gelince ayrı WP açılır.
- WP-69 aylık rapor: DNS + Resend API key ile canlıya alınacak mı? Karar/ops preflight: WP-279.
- Windows release boşta RAM (300–400 MB iddiası): WP-70 tabanı p95 85.9 MB ölçtü, iddia temiz release'te üretilmedi; bulgu çıkarsa ayrı düzeltme WP'si.
