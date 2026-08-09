# DENETİM — Kimlik doğrulama + hesap yaşam döngüsü

**Tarih:** 2026-08-09 · **Kapsam:** kayıt, giriş, çıkış, oturum kalıcılığı, e-posta
doğrulama, şifre sıfırlama, hesap silme, profil okuma/yazma, çevrimdışı kimlik.
**Yöntem:** yalnız kod ve komut çıktısı. `progress.md`, `docs/**`, `.agents/**` ve
kod yorumları **iddia** sayıldı; çeliştikleri yerde kod esas alındı (bir çelişki
Bulgu 3'te, biri Bulgu 5'te raporlandı).

**Sayım:** 2 KANAMA · 4 RİSK · 3 TEMİZLİK.

---

## KANAMA

### 1. Windows'ta şifre sıfırlamanın hiçbir çalışan yolu yok — ekran "gönderildi" diyor

- **Belirti:** Windows kullanıcısı şifresini unutuyor, giriş ekranında "Şifremi
  unuttum"a basıyor, "Şifre sıfırlama bağlantısı e-postana gönderildi" yazısını
  görüyor. E-postadaki bağlantıya bilgisayarında tıklayınca tarayıcı "bu bağlantıyı
  açacak uygulama yok" diyor. Kod girecek bir ekran da yok. Hesabına bir daha
  giremiyor.
- **Kanıt:**
  - `app/lib/data/providers/auth_providers.dart:21-30` — `resolveRecoveryRedirect()`
    Android değilse `null` döner, yani Windows'ta `redirectTo` gönderilmez.
  - `.github/workflows/supabase-auth-config.yml` (Patch adımı) —
    `site_url='com.manilmax.onlinestudyroom://login-callback'`. `redirectTo`
    verilmeyince bağlantı **Android özel şemasına** düşer; Windows'ta bu şemayı
    açacak kayıt yok.
  - `app/windows/runner/main.cpp:9,22-25` + `app/lib/main.dart:39`
    (`Future<void> main()` — argüman bile almıyor) — Windows tarafında URL protokol
    kaydı ve derin bağlantı işleme yok; `app/pubspec.yaml` içinde masaüstü protokol
    paketi yok.
  - Yedek yol kapalı: `app/lib/features/auth/auth_screen.dart:28-30,354` — kod ile
    sıfırlama ekranı `kResetWithCodeEnabled` derleme bayrağına bağlı ve düğme bayrak
    açık değilken **hiç çizilmiyor**. `RESET_WITH_CODE_ENABLED` repoda hiçbir yerde
    tanımlı değil: `env.production.example.json` / `env.staging.example.json` /
    `env.ci.example.json` anahtar listelerinde yok,
    `.github/workflows/windows-release.yml:73` yalnız `--dart-define-from-file=env.json`
    veriyor.
  - Çapraz cihaz kaçışı da kapalı: `app/lib/main.dart:109-120` `Supabase.initialize`
    çağrısı `authOptions` vermiyor → varsayılan **PKCE** akışı. Kod doğrulayıcı isteği
    başlatan cihazda kaldığı için kullanıcı e-postayı telefonunda açsa bile
    Windows'tan başlatılan sıfırlama tamamlanamaz.
  - Aynı ölü yol hesap ayarlarında da var:
    `app/lib/features/profile/account_settings_screen.dart:131-168`.
- **Etki:** Windows sürümündeki **her** kullanıcı, şifresini her unuttuğunda. Sonuç
  kalıcı hesap kaybı. Windows Store yolu açılırken bu, mağaza sayfasındaki ilk
  kullanıcı şikâyeti olur.
- **Öncelik:** KANAMA

### 2. Profil değişiklikleri ağ hatasında sessizce kayboluyor (hata da yok, onay da)

- **Belirti:** Kullanıcı günlük hedefini 6 saatten 4 saate çekiyor / kamp hayvanını
  değiştiriyor / adını düzenliyor. Diyalog kapanıyor, hiçbir uyarı çıkmıyor, ama
  değer eski kalıyor. Kullanıcı kaydetmeyi beceremediğini sanıp tekrar tekrar
  deniyor.
- **Kanıt:**
  - `app/lib/data/repositories/supabase/supabase_auth_repository.dart:540-551`
    (`updateDailyGoal`) — hiç `try/catch` yok. Ağ/sunucu hatası buradan
    `PostgrestException` veya `ClientException` olarak çıkar; **`AuthException`
    değildir**.
  - `app/lib/features/classroom/widgets/study_timer_card.dart:94-111` ve
    `app/lib/features/profile/settings_screen.dart:69-85` — ikisi de yalnız
    `on AuthException` yakalıyor. Yani yakalama dalı, o çağrının **hiç atmadığı** bir
    tür için yazılmış: gerçek hata dalın yanından geçip gidiyor.
  - `app/lib/features/profile/settings_screen.dart:60` (`_pickAnimal`) — `try/catch`
    **hiç yok**; üstelik hata atınca bir sonraki satırdaki
    `setState(() => _animalOverride = picked)` de çalışmıyor, yani seçim ekranda bile
    görünmüyor.
  - `app/lib/features/profile/profile_screen.dart:274-282` (`_editName`) ve
    `:301-313` (`_pickAvatar`) — yine yalnız `on AuthException`.
  - Hatanın gittiği yer: `app/lib/core/observability/observability_service.dart:370-373`
    — `PlatformDispatcher.instance.onError` yakalanmamış her asenkron hatayı yutup
    `true` dönüyor. Ekranda hiçbir iz kalmıyor.
  - Doğrusu aynı depoda zaten var (karşı örnek):
    `app/lib/features/profile/social_profile_screen.dart:263-283` (`catch (_)` +
    kullanıcıya mesaj) ve
    `app/lib/features/notifications/notification_permissions_screen.dart:23-36`
    (`catch (_)` + değeri geri alma).
- **Etki:** Bütün kullanıcılar, ağ her titrediğinde — mobil bir çalışma
  uygulamasında bu istisna değil rutin. Günlük hedef ayrıca seri (streak), ilerleme
  halkası ve "hedefi tuttun mu" hesabının girdisi olduğu için yanlış hedefle devam
  etmek istatistikleri de bozuyor.
- **Öncelik:** KANAMA

---

## RİSK

### 3. Silme durumu okunamayınca ekran "hesabın silinecek" diyor; iptal düğmesi de hata veriyor

- **Belirti:** Hesap silmeyi hiç istememiş kullanıcı, ağ kötüyken Hesabım'a girince
  kırmızı kartta "Silme planlandı — İptal et" başlığını görüyor. Panikleyip
  dokununca "Beklenmeyen bir hata oluştu." alıyor. Aynı anda, hesabını **gerçekten**
  silmek isteyen kişi silme düğmesine hiç ulaşamıyor.
- **Kanıt:** `app/lib/features/profile/account_settings_screen.dart:435-472` —
  `final active = failed || snap.data?.active == true;` ve
  `onTap: active ? _cancelAccountDeletion : _requestAccountDeletion`. Aynı yerdeki
  gerekçe yorumu (satır 429-434) "cancel RPC'si bekleyen istek yoksa zararsızdır"
  diyor; **SQL bunu çürütüyor**:
  `supabase/migrations/0037_account_deletion_core.sql:146-149` —
  `if row.id is null then raise exception 'no_active_request'`.
  (Belge/yorum ile kod çelişkisi: kod haklı.)
- **Etki:** Her kullanıcı, durum sorgusu düştüğü anda. Yanlış alarm + çalışmayan
  düğme + silme yolunun kaybolması. Kartta "yenile" düğmesi olması iyi, ama başlık
  ile altyazı ("Silme durumu okunamadı") birbirini yalanlıyor.
- **Öncelik:** RİSK

### 4. Çevrimdışı "Güvenli çıkış": kullanıcı gerçekten çıkmış, ekran "çıkılamadı" diyor

- **Belirti:** İnternet yokken çıkış yapılıyor. Kırmızı "Çıkış yapılırken bir hata
  oluştu" uyarısı çıkıyor ve ekran kapanmıyor — ama oturum **zaten kapandı**.
  Kullanıcı çevrimdışı olduğu için geri de giremiyor ve neye inanacağını bilmiyor.
- **Kanıt:**
  - `app/lib/data/repositories/supabase/supabase_auth_repository.dart:689` —
    `await _client.auth.signOut();` sarmalanmamış; hata `_current = null;` satırına
    varmadan yukarı çıkıyor.
  - gotrue 2.22 davranışı (kurulu paket kaynağı,
    `gotrue-2.22.0/lib/src/gotrue_client.dart:963-989`): `signOut` önce yerel oturumu
    siler ve `signedOut` yayar, **sonra** sunucuya gider; 401/403/404 dışındaki hata
    (ağ hatası dahil) yeniden fırlatılır.
  - `app/lib/features/profile/account_settings_screen.dart:201-218` bu istisnayı
    "çıkış yapılamadı" diye gösteriyor ve `popUntil` çalışmıyor.
- **Etki:** Çevrimdışı çıkış yapan herkes. Yanlış mesaj + tutarsız ekran durumu.
  Aynı çağrının profil ekranındaki ikizi (`profile_screen.dart:221`) hiç
  `await`lenmiyor ve hiç yakalanmıyor — orada da geri bildirim yok.
- **Öncelik:** RİSK

### 5. Ağ turu düşünce üretilen "varsayılan" profil, çevrimdışı önbelleğe gerçek profil gibi yazılıyor

- **Belirti:** Profil satırı **ilk kez** çekilemeyen kullanıcıda günlük hedef
  sessizce varsayılana (6 saat) düşüyor ve bu değer diske yazılıyor; sonraki
  çevrimdışı açılışlarda da yanlış hedef görünüyor.
- **Kanıt:**
  - `app/lib/data/repositories/supabase/supabase_auth_repository.dart:196-227` —
    `_profileFor` hata dalında `offlineProfileFallback(...)` döner. Önbellek **boşsa**
    dönen şey yalnız `display_name` taşıyan varsayılan profildir
    (`app/lib/data/models/profile.dart:14` — `dailyGoalMinutes = kDefaultDailyGoalMinutes`).
  - `app/lib/data/providers/auth_providers.dart:221-232` — `onRemoteProfile` her
    non-null profilde çalışıyor ve `cache.saveProfile(profile)` çağırıyor. Yorum
    "Sunucudan gelen her profil…" diyor; oysa buraya sunucudan **gelmemiş** yedek
    profil de düşüyor (`authStateWithOfflineFallback` içinde `source` dalı,
    aynı dosya 126-128).
- **Etki:** WP-609 önbellek **varken**ki kaybı kapattı; önbellek **yokken** aynı
  sessiz kayıp duruyor ve üstelik diske kalıcılaşıyor. Koşul dar (ilk profil çekimi
  başarısız), ama sonucu kullanıcının hedefe bağlı bütün ekranları.
- **Öncelik:** RİSK

### 6. Çevrimdışı açılışın ilk saniyelerinde profil değişiklikleri hiçbir şey yapmıyor

- **Belirti:** İnternetsiz açılan uygulamada kullanıcı adını / hedefini / hayvanını
  değiştiriyor. Hata yok, onay yok, değer değişmiyor.
- **Kanıt:** `app/lib/data/providers/auth_providers.dart:69` — ekran
  `kAuthColdStartBudget = 2 saniye` sonra önbellekteki profille açılıyor. Ama depo
  `_current`'ı ancak `_sessionProfiles`'ın ilk `await _profileFor(...)`'ı bitince
  dolduruyor (`supabase_auth_repository.dart:128`) ve bu turun çevrimdışında ~20
  saniye sürdüğü aynı dosyada ölçülmüş olarak yazılı
  (`auth_providers.dart:48-67`). O aralıkta bütün profil yazmaları
  `if (cur == null) return;` ile **sessizce** çıkıyor:
  `supabase_auth_repository.dart:519-520` (ad), `542-543` (hedef), `555-556`
  (hayvan), `566-567` (ünvan), `591-592` (aylık rapor), `606-607` (avatar).
- **Etki:** Çevrimdışı açan kullanıcı, açılıştan sonraki ilk ~18 saniye. Bulgu 2 ile
  aynı sonucu verir ama ağ hatası olmadan da olur.
- **Öncelik:** RİSK

---

## TEMİZLİK

### 7. Çıkışta profil önbelleği diskte kalıyor

- **Belirti:** Ortak kullanılan bir bilgisayarda/telefonda çıkış yapıldıktan sonra
  önceki kullanıcının adı, avatar adresi ve günlük hedefi cihazda duruyor.
- **Kanıt:** `app/lib/data/repositories/supabase/supabase_auth_repository.dart:675-691`
  — `signOut` push kaydını temizliyor, `OfflineCacheStore`a hiç dokunmuyor.
  `app/lib/data/repositories/offline/offline_cache_store.dart:33-49` yalnız
  `readProfile`/`saveProfile` sunuyor; dosyada temizleme metodu yok (arama yalnız
  `removeCachedSession`'ı buluyor).
- **Etki:** Başka hesaba **sızmıyor** — hem `offlineProfileFallback` hem
  `localSessionProfile` `cached.id == userId` kontrolü yapıyor. Yani veri karışması
  değil, artık veri / gizlilik hijyeni sorunu.
- **Öncelik:** TEMİZLİK

### 8. Kayıt "doğrulama bekliyor" dalı hâlâ Türkçe alt dizeye bağlı

- **Belirti:** (Şu an çalışıyor.) Mesaj metnindeki tek kelime değişirse kullanıcı
  "Hesabın oluşturuldu" onayını göremez, yerine "Beklenmeyen bir hata oluştu."
  görür ve hesabının açılıp açılmadığını bilemez.
- **Kanıt:** `app/lib/features/auth/auth_screen.dart:101` —
  `final verifiedEmailNotice = e.message.contains('e-postana gönderilen');`
  Karşılığındaki istisna **kodsuz** atılıyor:
  `app/lib/data/repositories/supabase/supabase_auth_repository.dart:245-251`.
  WP-539 tam bu deseni (mesaja `contains`) kaldırmıştı; kayıt yolunda kalmış.
- **Etki:** Bugün kullanıcı zararı yok; kırılganlık.
- **Öncelik:** TEMİZLİK

### 9. `Profile.isActive` ölü alan — sunucuda karşılığı yok

- **Belirti:** Yok (kullanıcıya erişmiyor).
- **Kanıt:** `app/lib/data/models/profile.dart:25,77` alanı okuyor;
  `grep -rn "isActive" app/lib` içinde profil tarafında **hiçbir okuyucu yok**.
  Sunucuda da sütun yok: `supabase/migrations/0001_initial_schema.sql:15-20` ile
  `alter table public.profiles` satırlarının tamamı (0005, 0014, 0030, 0115, 0122)
  `is_active` eklemiyor; yani `map['is_active']` her zaman null.
- **Öncelik:** TEMİZLİK

---

## Kontrol ettim, SAĞLAM çıktı

Aşağıdakilere baktım ve sorun bulmadım — bir sonraki denetim buraları yeniden
taramasın.

- **Şifre değiştirme zinciri (WP-319 / 319-G).** `changePassword` gerçekten önce
  `signInWithPassword` ile yeniden doğruluyor, sonra `updateUser`, sonra
  `signOut(scope: others)` çağırıyor; sıra doğru ve iptal başarısızlığı istisna
  değil **sonuç** olarak taşınıyor. Ekran iki durumu ayrı cümleyle söylüyor
  (`account_settings_screen.dart:102-122`). Ekran doğrulamayı atlayamıyor: kontrol
  depo sözleşmesinde.
- **E-posta değiştirme (WP-458).** Mevcut şifreyle yeniden doğrulama zorunlu;
  `verificationPending` / `confirmed` ayrımı korunuyor ve ekranda farklı mesaj +
  farklı süreyle gösteriliyor. Uygulama kendi doğrulama kodunu uydurmuyor.
- **Ağ hatası ile "şifre yanlış" ayrımı (WP-536).** `_reauthFailure`
  `AuthRetryableFetchException`i ayrı kodluyor; şifre değiştirme, e-posta
  değiştirme, hesap silme ve giriş ekranlarının dördü de `AuthErrorCode.network`i
  "sunucuya ulaşılamadı" diye çeviriyor. Şifre hakkında haksız hüküm verilmiyor.
- **Doğrulama postasını yeniden gönderme (WP-587).** Düğme gerçekten bağlı
  (`auth_screen.dart:321-326` → `_resendVerificationEmail` → depo →
  `_client.auth.resend`), yalnız `_emailNotConfirmed` durumunda çiziliyor ve hız
  sınırına takılınca **kaybolmuyor**. Ölü anahtar değil.
- **AuthGate'in üç dalı.** Veri, hata ve yükleme dallarının hepsinde çıkış var:
  hata dalında "tekrar dene" + "çıkış yap", yükleme dalında 12 saniye sonra aynı
  çıkış (`auth_gate.dart:113-156,164-229`). Çıkmaz sokak yok.
- **Bayat refresh token.** `_recoverFromStaleRefreshToken` yerel oturumu temizleyip
  `null` yayınlıyor; kullanıcı sonsuz hata döngüsüne değil giriş ekranına düşüyor
  (`supabase_auth_repository.dart:125-193`).
- **Hesap silme diyaloğu.** Şifre alanı kendi `State`'inde yaşıyor (dispose edilmiş
  denetleyici hatası yok) ve boş şifre form doğrulamasıyla engelleniyor — WP-539'un
  "sessiz düğme"si gerçekten kapanmış (`account_settings_screen.dart:493-561`).
- **Silme durumu sorgusu.** `initState`'te bir kez kuruluyor; her çizimde yeni RPC
  açılmıyor ve `unawaited` dinleyicisi hatayı zone patlamasına çevirmiyor.
- **Çevrimdışı önbellek hesap karışması.** Hem `offlineProfileFallback`
  (`supabase_auth_repository.dart:31-45`) hem `localSessionProfile`
  (`auth_providers.dart:159-169`) `id` eşitliği arıyor; cihaz el değiştirdiğinde
  başkasının hedefi/adı gösterilmiyor.
- **Onboarding bayrağı.** Kullanıcı başına anahtarlanmış
  (`onboarding.completed_v1.<userId>`, `onboarding_prefs.dart:12-16,44-48`); hesap
  değişiminde yanlış hesaba taşınmıyor.
- **Ünvan yazma (WP-475).** Sunucu reddi (`title_not_earned`) depoda `AuthException`a
  çevriliyor, ekran kullanıcıya söylüyor ve yerel durum geri alınıyor
  (`social_profile_screen.dart:263-283`). Kablo testi de gerçek PostgREST sorgu
  üreticisiyle ölçüyor (`test/data/supabase_wire_auth_test.dart`).
- **Auth derin bağlantı şeması.** Flavor'a göre üretiliyor (sabit yazılmamış) ve
  workflow allow-list'i aynı üç şemayı içeriyor, joker (`*`) yok — açık yönlendirme
  riski kapalı (`auth_redirect_config.dart` + `supabase-auth-config.yml`).
- **Oturum iptali sözleşme testi.** `test/data/auth_session_revocation_contract_test.dart`
  kaynak okuyor ama bunu **açıkça söylüyor** ve neyi ölçemediğini yazıyor; sahte bir
  yeşil değil.

## Bilerek raporlamadım

- `0124` migration'ının production'a uygulanmamış olması (zaten bilinen ve açık
  madde). Başka bir hesap silme kusuru bulundu ve Bulgu 3'te yazıldı.
- `ResetWithCodeScreen` + `resetPasswordWithCode` "yazılmış ama çağıran yok" sınıfına
  giriyor, fakat bu bilinçli bir karar (WP-539) ve gerekçesi kodda yazılı. Ayrı bulgu
  yerine Bulgu 1'in kanıtı olarak kullandım.

## Emin olmadıklarım

- Bulgu 1'de Windows kullanıcısının e-postadaki bağlantıya tıkladığında tarayıcıda
  **tam olarak** hangi hatayı gördüğünü cihazda doğrulamadım; kod ve yapılandırma
  bağlantının bir Android özel şemasına çıktığını ve Windows'ta karşılayıcı
  olmadığını gösteriyor.
- Bulgu 6'daki ~18 saniyelik pencerenin gerçek cihazdaki uzunluğunu ölçmedim; süre
  kodun kendi yorumundaki ölçüme dayanıyor, sabitler (`2 sn` bütçe, `10 sn` HTTP
  tavanı) doğrulandı.
