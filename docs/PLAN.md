# Odak Kampı — Nihai Plan (2026-07-26)

> **Bu dosya artık tek yol haritasıdır.** Sahibin 2026-07-26 sohbetinde söylediği
> her şey + repoda dağınık duran eski planlar burada birleşti. WP numarası
> kullanmıyoruz; iş **faz**larla yürüyor. `progress.md` günlük çalışma kaydı
> olarak kalır, bu dosya "nereye gidiyoruz"u söyler.
>
> **İki plan var, sırayla:**
> **PLAN 1 — Ürün & Kod** (Faz A…F) → **PLAN 2 — Mağaza** (Faz G…J).
> Tek istisna: **kimlik kararı (isim + logo)** Plan 2'ye ait ama Plan 1
> bitmeden verilmeli — mağaza görselleri, MSIX kimliği ve uygulama içi marka
> ona bağlı.

---

## 0. Şu anki gerçek durum

| Konu | Durum |
| --- | --- |
| Sürüm | `v49` stable (2026-07-25/26). Android APK + Windows MSIX/ZIP GitHub Releases'ta |
| Sürüm politikası | 🔴 **Sahip onayı olmadan yeni sürüm çıkmaz** (2026-07-26 kararı) |
| Test | 811 test yeşil, `flutter analyze` temiz, l10n audit temiz |
| Migration head | `0070` (local = staging = production, `docs/recovery/MIGRATION-BASELINE.md`) |
| Cihaz QA | ✅ Sahip v48'de test etti: özel tema okunabilirliği, spektrum seçici, font düğmeleri, grafik tarihleri **çalışıyor**. Kalan tek madde: v49'daki his adımı (acele değil) |
| Play Console | Hesap açıldı, doğrulama sürüyor. Hiçbir form doldurulmadı |
| Microsoft Partner Center | Hesap açıldı. Hiçbir hazırlık yapılmadı |

### Kapanan kararlar (bu sohbette)

| Karar | Sonuç |
| --- | --- |
| Diller | ✅ **Sadece TR + EN.** DE/AR dil seçeneğinden kalkar, `.arb` dosyaları repoda kalır |
| Gün sınırı | ✅ **Kesin yapılacak** (`Europe/Istanbul`), planlı ve provalı şekilde → Faz E |
| Aylık e-posta raporu | ✅ **İptal.** Kod dursun, kurulum yapılmayacak (bkz. §Ek A) |
| Tema sihirbazı sadeleştirmesi | ✅ **Gerek yok.** Tek gerçek sorun his adımıydı, v49'da çözüldü (doğrulanacak) |
| **K1** Yanıt kanalı | ✅ **Çift yönlü** — kullanıcı admin yanıtına geri yazabilecek |
| **K2** Şifre değiştirme | ✅ Klasik üç alan + "Şifremi unuttum". **Google/passkey girişi zaten yok** (`passkeys` paketi kurulu ama kullanılmıyor — ölü bağımlılık). Herkesin şifresi var, dolayısıyla "mevcut şifre" alanı gerçekten doğrulanabilir |
| **K3** Tanıtım turu | ✅ Yalnız **ilk açılışta**, ekrana basınca sonraki balona geçer. Ekran başına az sayıda balon; hızlı geçmek isteyen üst üste basar |
| **K4** Gün sınırı backfill | ✅ **Konusuz kaldı.** Sahip "hangisi kolaysa" dedi; incelemede gün toplamlarının **hiç saklanmadığı**, her sorguda ham oturumlardan hesaplandığı görüldü → backfill diye bir iş yok |
| **K5** Çoklu grup | ✅ **Birincil grup** — kullanıcı seçer; görev/hedef/başarım onu sayar |
| **K6** İsim + logo | ⏸️ **Faz B sırasında** konuşulacak (sahip onayı 2026-07-26) |
| **K7** Gizlilik URL'i | ✅ **GitHub Pages** — ücretsiz ve yeterli olduğu için onaylandı (bkz. §Ek C) |
| **K8** Yurtdışı gün sınırı | ✅ **Birincil grubun bölgesi** gün sınırını belirler; grubu olmayan cihaz saat dilimini kullanır. Ayrıca gruplara bölge alanı, üye sınırı **8**, keşifte saat dilimi yakınlığına göre sıralama ve arama filtresi (bkz. Faz E1/E3) |

---

# PLAN 1 — ÜRÜN & KOD

## Faz A — Doğrulama borcu ✅ *kapandı (2026-07-26)*

Sahip v48 üzerinde cihaz testini kendisi yaptı. **Özel tema okunabilirliği,
spektrum renk seçici, font düğmelerinin sabitliği, grafikteki gün etiketleri —
hepsi çalışıyor.** Diğer birikmiş QA maddeleri de v46–v48 turlarında test
edilmiş durumda.

**Kalan tek madde:** v49'daki his adımı (tema sihirbazı 6/8) cihazda
doğrulanmadı — ama v49 sürümü acele değil, sonraki sürümle birlikte bakılacak.

Bu faz artık **iş kuyruğunda değil**. Buradan çıkan kod bulguları §Ek D'de.

---

## Faz B — Admin & geri bildirim döngüsü

Sahibin doğrudan şikâyet ettiği üç şey. Şu an kullanıcıdan geri bildirim
alıyoruz ama **kapatamıyoruz**: fotoğrafı göremiyoruz, cevap yazamıyoruz,
liste temizlenmiyor.

**B1. Geri bildirim ekran görüntüleri görünmüyor.** 🔴
Kod yolu var: `feedback_attachments` bucket'ına imzalı URL üretiliyor
(`supabase_admin_repository.dart` · `getFeedbackAttachmentUrl`). Admin
ekranında da "Ekran görüntüsü" çipi var. Yani sorun **kodda değil, ortamda**.
Sırayla bakılacak:
1. `0019_feedback_attachments` migration'ı production'da gerçekten uygulandı mı
   (bucket + iki storage policy)?
2. `public.is_super_admin()` production'da senin hesabın için `true` dönüyor mu?
3. Kullanıcı tarafı yüklemeyi gerçekten yapıyor mu, `attachment_path` doluyor mu
   — yoksa yükleme sessizce mi düşüyor?
4. Bucket private; imzalı URL 1 saat geçerli. Süre dolmuş URL cache'lenmiş olabilir.
**Kabul:** ekli bir geri bildirimde çipe basınca görsel açılıyor; ek yoksa çip
görünmüyor; yükleme hatası kullanıcıya sessiz kalmıyor.

**B2. Kullanıcıya cevap yazma.**
İyi haber: altyapı hazır. `announcements` tablosu zaten
`target_type = 'user'` + `target_id` destekliyor ve kullanıcı tarafında
**Duyurular** ekranı (`notification_center_screen.dart`) bunu okuyor.
Yapılacak: geri bildirim kartına "Yanıtla" eylemi → hedefi o kullanıcı olan
duyuru oluştur → push bildirimi gönder → bilet durumunu otomatik ilerlet.
**Kabul:** admin yanıtı kullanıcının Duyurular'ında görünüyor · bildirim
düşüyor · yanıt biletin altında da görünüyor (kim ne demiş, iz kalıyor).
✅ *K1 kapandı: çift yönlü — kullanıcı admin yanıtına geri yazabilir.*

**B3. Bilet arşivi.** Şu an sadece `open / in_progress / closed` var ve hepsi
listede duruyor. Eklenecek: **"Tamamlandı → listeden kaldır"**.
Teknik yaklaşım: yeni bir `archived_at` alanı (satır **silinmez** — kanıt ve
istatistik lazım), varsayılan liste arşivlenmemişleri gösterir, "Arşivi göster"
filtresiyle geri gelinir.
**Kabul:** biriken liste temizleniyor, hiçbir kayıt kaybolmuyor.

---

## Faz C — Hesap, güvenlik ve ayarlar hijyeni

Mağazaya çıkmadan önce "temel şeylerin eksik" görünmemesi gereken kısım.

**C1. Şifre değiştirme.** 🔴 Şu anda **hiç yok** — `account_settings_screen.dart`
sadece hesap silmeyi taşıyor. Klasik yapı gelecek: *mevcut şifre · yeni şifre ·
yeni şifre tekrar*, ve aynı ekranda **"Şifremi unuttum"** yolu.
⚠️ Teknik tuzak: Supabase `updateUser(password:)` **eski şifreyi doğrulamaz**.
"Mevcut şifre" alanının gerçekten işe yaraması için önce o şifreyle yeniden
kimlik doğrulaması yapılmalı; yoksa alan dekoratif olur (= ölü anahtar).
✅ *K2 kapandı: mevcut şifre gerçekten doğrulanacak. Google/passkey girişi
zaten yok (`passkeys` paketi kurulu ama kullanılmıyor), yani herkesin şifresi
var — özel durum ekranı gerekmiyor.*

**C2. "Verilerimi dışa aktar" taşınıyor.** `data_export_screen.dart` şu an
ayarların ortasında duruyor. **Hesabımı yönet** başlığı altına, hesap silmenin
yanına gelecek. (Mağaza veri beyanları da bu ikisini bir arada arıyor.)

**C3. Ayarların sırası.** Şu anki sıra rastgele büyümüş. Platform
konvansiyonuna göre yeniden dizilecek — kabaca: *Hesap → Bildirimler →
Görünüm → Çalışma tercihleri → Gizlilik & güvenlik → Hakkında/Yasal*.
Gizlilik politikası ve yasal metinler **en alta**. Araştırma + öneri önce
sana gelir, sonra kodlanır.

**C4. TR + EN'e in.** Dil listesinden DE/AR kalkar, l10n kapısı iki dil parity'si
kontrol eder, Arapça RTL cihaz QA borcu düşer, gömülü fontların Arapça glif
zinciri gereksinimi ortadan kalkar.
⚠️ Bu bir **davranış değişikliği**: cihaz dili Almanca olan mevcut kullanıcı
İngilizce'ye düşer. Kabul edilebilir, ama bilinerek yapılmalı.

**C5. Teknik borç temizliği.** §Ek D'den çıkan, sahibi olmayan küçük maddeler
burada toplanır — hepsi mağazaya çıkmadan kapanmalı:
- `passkeys` paketini kaldır (kurulu ama hiç kullanılmıyor; APK boyutu + izin yüzeyi)
- `pubspec.yaml` sürümünü (`1.0.43-beta.9+4309`) yayınlanan etiketlerle hizala —
  mağaza paketleri bu numarayı okur
- Windows MSIX kendi kendine güncellemeyi Store yapısında kapat (Faz H'nin ön şartı)
- Kalan test kararsızlığını kapat: `study_timer_card_stop_test.dart` tam suitte
  bir koşumda düştü, ikincide geçti. **Sürüm çıkmadan önce çözülmüş olmalı.**

---

## Faz D — Yeni kullanıcı deneyimi (tanıtım turu)

Şu an sadece açılışta tek bir `onboarding_screen` var; uygulamanın içinde
hiçbir yerde rehberlik yok.

**D1. Bölüm bazlı tanıtım.** Kullanıcı bir sekmeye/ekrana **ilk kez** girdiğinde
oradaki öğeler kısa balonlarla tanıtılır (oyunlardaki gibi): Ana Sayfa kartları,
Sayaç, Kamp Ateşi, Gruplar, İstatistik, Profil. "Atla" her zaman var.

**Tasarım notları (şimdiden karara bağlanması gerekenler):**
- Her ekranın kendi "görüldü" anahtarı olur; hepsi tek bayrağa bağlanmaz.
- Anahtarlar **sürümlenir** (`home.v1`, `home.v2`): ekran ciddi değişince tur
  yeniden gösterilebilsin, ama her güncellemede herkese tekrar açılmasın.
- Ayarlarda **"Tanıtım turlarını sıfırla"** olur.
- Windows'ta da çalışmalı (fare/klavye; balon konumları farklı).
- Tur, izin isteme diyalogları ve güncelleme bildirimiyle çakışmamalı.
✅ *K3 kapandı: yalnız ilk açılışta, ekrana basınca sonraki balona geçer.
Ekran başına az sayıda balon; hızlı geçmek isteyen üst üste basar.*

---

## Faz E — Veri doğruluğu ve grup semantiği

Bu fazın iki işi de **geri alınamaz veri** ile ilgili: yedek, staging provası ve
rollback planı olmadan production'a dokunulmaz.

**E1. Gün sınırı — yurtdışı kullanıcı.** *Kapsam 2026-07-26'da yeniden yazıldı.*

⚠️ **Eski plan yanlıştı.** "Günlük toplam UTC'ye göre" diye yazıyordu; **değil**.
Sunucu tarafı zaten baştan sona `Europe/Istanbul` (`0007`, `0011`, `0024`,
`0039`, `0051`, `0053`, `0062`, `0063` … 60'tan fazla yerde), istemci tarafı da
`istanbulDay`. Yani "İstanbul'a çevirme" işi **çoktan yapılmış**.

⚠️ **Backfill diye bir iş de yok.** Gün toplamları hiçbir tabloda saklanmıyor;
`get_user_day_totals` her çağrıda ham `study_sessions` satırlarından hesaplıyor.
Gün sınırı ifadesi değişirse geçmiş kendiliğinden yeniden hesaplanır. (K4 bu
yüzden konusuz kaldı.)

**Gerçek açık:** herkesin günü İstanbul yarısında sıfırlanıyor. Yurtdışında bu
bozuluyor:

| Kullanıcı | Günü ne zaman sıfırlanıyor | Sonuç |
| --- | --- | --- |
| Türkiye (UTC+3) | 00:00 | doğru |
| Sydney (UTC+11) | 08:00 | sabah çalışması düne yazılır |
| New York (UTC−5) | 16:00 | 🔴 akşam çalışması yarına yazılır — asıl çalışma saati kayboluyor |

**✅ K8 kararı (2026-07-26): gün sınırı = birincil grubun bölgesi.**

Sahip "sadece grup tarafına ekleyelim" dedi ve bu, önce önerilen *kişisel/grup
ikiye bölme*den **daha iyi** çıktı. Gerekçe: iki ayrı saat tutulsaydı kullanıcı
"kişisel bugün 3 saat, grup bugün 1 saat" gibi bir çelişki görecekti. Tek saat
olunca o sorun **hiç doğmuyor**.

Kural zinciri:
1. Kullanıcının **birincil grubu** varsa (K5) → o grubun bölgesi gün sınırıdır.
2. Hiç grubu yoksa → **cihazın** saat dilimi.
3. Cihaz saat dilimi okunamazsa → `Europe/Istanbul` (bugünkü davranış).

Böylece kişisel istatistik ile grup istatistiği **her zaman aynı günde** olur.

**Elimizde hazır olan:** cihazın saat dilimi adı zaten toplanıyor —
`0066_push_notification_delivery.sql` push zamanlaması için `time_zone text`
saklıyor. 3. adımın kaynağı bu.

⚠️ Saat dilimi **IANA adı** olarak saklanır (`America/New_York`), offset (`-5`)
olarak değil — yoksa yaz saati geçişinde kayar. Türkiye'de yaz saati olmadığı
için bu hata bugüne kadar hiç görünmedi.

⚠️ **Kabul edilen bedel:** ABD'deki bir kullanıcı TR grubuna girerse günü yine
TR saatine göre işler. Ama artık bu **görünür** bir tercihtir — grup bilgisinde
bölge ve saat farkı yazıyor, ayrıca keşif listesi yakın saat dilimlerini üste
alıyor (E3). Gizli bir bozukluk değil, bilinçli bir seçim.

⚠️ **Birincil grup değişirse gün sınırı da değişir.** Kullanıcı TR grubundan
ABD grubuna geçtiğinde geçmiş günler yeni sınıra göre yeniden hesaplanır
(toplamlar saklanmadığı için bu kendiliğinden olur). Serisi bir gün kayabilir.
Grup değiştirme ekranında bir kez uyarılmalı.

**E2. Birden fazla gruptaki kullanıcı.** 🔴 Sahibin yakaladığı gerçek boşluk.
Bugün bir kullanıcı birden çok gruba üye olabiliyor ama şu sorular
cevapsız:
- **Grup görevleri:** üç grubun da görevi mi listelenir? Aynı çalışma süresi
  üç görevi birden mi ilerletir?
- **Grup hedefi / liderlik:** ana ekrandaki "grup hedefi" hangi grubunki?
- **Başarımlar:** "grubunda 1. ol" gibi bir başarım hangi grubu sayar?
- **Bildirimler:** üç gruptan üç ayrı dürtme mi gelir?
Cevapsız kalırsa kullanıcı "neden ilerlemiyor / neden üç kere geldi" diye
şikâyet eder ve düzeltmesi veri göçü gerektirir.
✅ *K5 kapandı: **birincil grup** — kullanıcı seçer, görev/hedef/başarım/bildirim
onu sayar. Diğer gruplar üyelikte kalır ama sayaç tutmaz.*

**E3. Grup bölgesi, üye sınırı ve keşif.** *(sahip talebi, 2026-07-26)*

**E3.1 — Grup bölgesi.** Gruplara IANA saat dilimi alanı eklenir
(`groups.time_zone`, varsayılan `Europe/Istanbul`). E1'in gün sınırı buradan
beslenir. Grup oluştururken ve ayarlarında seçilir.
⚠️ **Konum izni istenmez, enlem/boylam sorulmaz** — sadece bölge/saat dilimi
seçtirilir. Gerçek konum istemek Play Data Safety'de yeni bir veri kategorisi
ve Android'de konum izni açar; buna hiç girmeye gerek yok. (Faz F3'ün gökyüzü
hesabı ayrı bir iş; saat dilimi yaklaşık boylam verir, gerekirse orada
konuşulur.)

**E3.2 — Grup bilgilerinde bölge.** Herkese açık grup kartında ve grup bilgi
ekranında bölge adı yazar. **Bölgeye basınca kullanıcıya göre saat farkı**
görünür: *"Türkiye (senden +8 saat)"*.
⚠️ Fark **anlık hesaplanır, saklanmaz** — yaz saati yüzünden aynı grup yazın
−7, kışın −8 olabilir. Sabit sayı yazmak sessiz bir hatadır.

**E3.3 — Üye sınırı 8.** Bugün `member_limit` **varsayılan 50**, kısıt `2..100`
(`0032_public_group_discovery.sql`). Sahip kararı: **8**.
Yapılacak: varsayılan 8, kısıt `2..8`, `create_group_with_access` varsayılanı 8,
istemcideki seçici 2–8 aralığına iner.
⚠️ **Göç ön şartı:** `member_limit` kısıtı daraltılmadan önce production'da
8'den fazla **aktif** üyesi olan grup olmadığı doğrulanmalı; varsa kısıt
uygulanamaz (`guard_group_member_limit` zaten sınırı aktif üye sayısının altına
indirmeyi engelliyor). Mevcut kullanıcı sayısıyla sorun beklenmiyor ama
**kontrol edilmeden migration çalıştırılmaz**.

**E3.4 — Keşifte saat dilimi yakınlığı.** Herkese açık grup önerileri
kullanıcının saat dilimine **en yakından en uzağa** sıralanır. Sıralama
anahtarı: iki bölgenin **o andaki** UTC farkının mutlak değeri. Eşitlikte
mevcut sıra (`created_at desc`) korunur.
⚠️ `idx_groups_public_discovery` şu an `created_at desc` üzerine kurulu;
sıralama değişince bu indeks sorguyu artık karşılamaz — sayfalama ve
performans birlikte gözden geçirilmeli.

**E3.5 — Grup arama/filtre.** İsim araması + bölge filtresi. Sınır 8'e indiği
için **"boş kontenjanı var"** filtresi de eklenir; yoksa kullanıcı sürekli dolu
gruplara tıklar.

---

## Faz F — Kamp ateşi ve görsel işler

Mağazaya çıkışı **bloklamaz**; ürünü güzelleştirir. Faz A–E bittikten sonra.

- **F1.** Kamp ateşi: oturma yayları + 2 poz
- **F2.** Gündüz/gece gökyüzü, gece uyuma animasyonu
- **F3.** Grup konumu (enlem/boylam + saat dilimi) — F2'nin gökyüzü hesabı buna dayanıyor
- **F4.** Faz A'dan çıkan kozmetik bulgular

⚠️ Kural (sahip talebi): görsel işlerde **ilk çıktı kod değil** — parametrik
önizleme gelir, sahip sayıyı/pozu seçer, seçilen değer teste bağlanır.

---

# PLAN 2 — MAĞAZA HAZIRLIĞI

## Faz G — Kimlik: isim ve logo 🔴 *erken karar, geç uygulama*

Sahip: *"logo ve isim tekrar düşünülmeli, hem TR hem English."*
Bu karar **her mağaza görselini, mağaza kaydını ve MSIX kimliğini** etkiler;
sonradan değiştirmek pahalıdır.

⚠️ Neyin değişip neyin değişemeyeceği:
- **Değişebilir:** görünen uygulama adı, logo, mağaza başlığı, uygulama içi marka
- **Değişmesi pahalı:** Android paket adı (`applicationId`) — değişirse
  **yeni uygulama** olur, mevcut kullanıcılar güncelleme alamaz
- **Değişmesi pahalı:** MSIX `Identity Name` — Partner Center'da rezerve edilen
  adla **birebir** eşleşmeli, sonradan değişmez
- Ayrıca: domain/e-posta (gizlilik politikası URL'i buraya bağlı), sosyal hesaplar

🔴 *Karar gerekiyor — K6.*

---

## Faz H — Microsoft Store (önce burası)

Play doğrulaması sürerken buraya çıkmak mantıklı: Windows sürümü zaten
üretiliyor (MSIX + ZIP) ve Microsoft'un incelemesi genelde daha hızlı.

- **H1.** Partner Center'da uygulama adını rezerve et (Faz G kararından sonra)
- **H2.** MSIX kimliğini Store'un verdiği `Identity Name` / `Publisher` ile
  hizala — şu anki paket kendi imzamızla üretiliyor, Store'a öyle gitmez
- **H3.** Yaş derecelendirme anketi, kategori, gizlilik politikası URL'i
- **H4.** Mağaza görselleri: ekran görüntüleri (TR + EN), açıklama metni, tanıtım videosu
- **H5.** Windows cihaz QA'sı (`docs/QA-WINDOWS.md`, `docs/WINDOWS-VM-QA.md`)
- **H6.** İlk gönderim → geri bildirim → düzeltme turu

---

## Faz I — Google Play

- **I1.** 🔴 **AAB.** Play `.apk` kabul etmiyor, `.aab` istiyor. Şu anki
  release hattı sadece APK üretiyor — pipeline'a bundle çıktısı eklenecek
- **I2.** 🔴 **Hesap silme kanıtı.** Play'in zorunlu kapısı: hesap silme akışı
  uygulama içinden **ve** webden erişilebilir olmalı, uçtan uca çalıştığı
  kanıtlanmalı (istek → 14 gün bekleme → kalıcı silme → yetkisiz çağrı reddi →
  rollback). Kodu var, kanıtı yok
- **I3.** **Gizlilik politikası + Kullanım şartları canlı HTTPS adreste.**
  Metinler `docs/legal/` içinde hazır ama hiçbir yerde yayınlanmıyor. Data
  Safety formu bunsuz doldurulamaz
- **I4.** **Data Safety formu** — envanter `docs/play-store/DATA-SAFETY.md`'de
  satır satır hazır, Console'a girilecek
- **I5.** İçerik derecelendirme anketi + mağaza listesi görselleri (TR + EN)
- **I6.** Kullanıcı içeriği beyanı (raporlama/engelleme/moderasyon) cihaz smoke testi
- **I7.** İmzalama anahtarı yedeği + rollback planı yazılı olarak
- **I8.** Kademeli yayın: %10 → %25 → %50 → %100 (her kademe en az 24 saat)

Kapı listesi: `docs/play-store/PLAY-RELEASE-GATE.md`

---

## Faz J — Yayın sonrası

- Çökme/hata takibi (Sentry zaten var), ilk 72 saat gözlem
- Mağaza yorumlarına yanıt akışı — Faz B'deki geri bildirim döngüsüyle birleşir
- İlk güncelleme turu

---

# AÇIK KARARLAR — cevabını bekliyorum

> **K1–K5 ve K7 kapandı** (2026-07-26). Cevapları yukarıdaki *"Kapanan
> kararlar"* tablosunda. Bu bölümde yalnız **hâlâ açık** olanlar durur.

| # | Konu | Soru |
| --- | --- | --- |
| **K6** | İsim + logo | ⏸️ **Faz B'de konuşulacak** (sahip kararı). Sorular o zaman: değişecek mi · TR ve EN'de aynı isim mi · Android `applicationId` ve MSIX `Identity Name` sabit kalabilir mi |

*K8 kapandı: gün sınırı birincil grubun bölgesinden gelir (bkz. Faz E1/E3).*

---

# RİSK VE TUZAK NOTLARI

- **Sürüm disiplini.** Artık sürüm sahibin onayıyla çıkar. Düzeltmeler birikir,
  tek sürümde çıkar. (2026-07-26 kararı)
- **Cihaz QA borcu.** v48 turunda kapatıldı (Faz A). Her yeni faz bu borcu
  yeniden büyütür — faz sonlarında cihaz turu atlanmamalı.
- **Geri alınamaz işler.** Hesap silme purge'ü bu sınıfta. Yedek + staging
  provası + rollback betiği olmadan production'a dokunulmaz
  (`.agents/AGENTS.md` ve `docs/recovery/` kuralı). *Gün sınırı artık bu
  sınıfta değil: toplamlar saklanmıyor, her sorguda hesaplanıyor.*
- **Ölü anahtar riski.** "Mevcut şifre" alanı gibi görünen ama hiçbir şey
  doğrulamayan arayüzler en kötü hata türü — kullanıcı korunduğunu sanır.
  Faz C'de bu özellikle kontrol edilecek.
- **Çoklu grup semantiği** karara bağlanmazsa Faz E sonrası veri göçü gerekir;
  yani K5 ne kadar geç cevaplanırsa o kadar pahalı.
- **MSIX kimliği** Partner Center'da rezerve edilen adla eşleşmezse paket
  reddedilir ve sonradan düzeltmek yeni uygulama demektir.

---

## Ek A — Aylık e-posta raporu (iptal edildi)

Sahip sordu: *"zor mu bunu kurmak?"* — Kısaca: **çok zor değil ama bedava değil.**
Gerekenler: bir domain, DNS kayıtları (SPF/DKIM — gönderdiğin postanın spam'e
düşmemesi için şart), bir e-posta sağlayıcısı (Resend/Postmark gibi), aylık
gönderim limiti ve maliyet takibi, opt-in/opt-out yönetimi. Teknik iş yaklaşık
bir gün; asıl yük domain doğrulaması ve teslimat itibarı.
**Karar: şimdilik iptal.** Kod repoda kalıyor, hiçbir secret/cron kurulmuyor.
Mağazadan sonra istenirse yarım günde açılır.

## Ek C — K7 ✅ onaylandı: gizlilik metinleri GitHub Pages'te

Motto: *"basit durmayan ama bizi uğraştırmayan."* Önerim **GitHub Pages**:
bedava, HTTPS hazır, repoda zaten duran `docs/legal/*.md` dosyalarından
otomatik yayınlanır, ayrı sunucu/domain/ödeme yok. Adres
`https://<kullanıcı>.github.io/<repo>/privacy` gibi olur — mağaza formları
bunu kabul eder. İleride alan adı alınırsa aynı sayfaya yönlendirilir,
mağazadaki bağlantı değişmez. Kurulum yarım saatlik iş; sahip tarafında
yapılacak tek şey repo ayarlarından Pages'i açmak.

## Ek D — Faz A bulguları (koddan çıkanlar)

> Aşağıdaki 🟡 maddelerin tamamı artık **Faz C5**'e bağlıdır; başıboş not
> değildir. 🔴 madde kapandı, kalan riski C5 takip eder.

- 🔴 **Gece yarısı test tuzağı (kapatıldı, 2026-07-26).** `v49` sürümü koddaki
  bir hatadan değil, **koşum saatinden** kırıldı: üç sayaç testi geçmişi
  `now − N dakika` ile kuruyor, ürünün gün sınırı ise `Europe/Istanbul`.
  Koşum 00:00–01:00 arasına denk gelince oturum düne düşüyor ve test hatasız
  kodu suçluyor. `test/support/istanbul_fixture.dart` ile kapatıldı.
  ⚠️ **Kalan risk:** tam suitte aynı test bir koşumda düştü, ikincide geçti —
  kararsızlık tümüyle kapanmadı, sürüm öncesi tekrar bakılacak.
- 🟡 **`passkeys` paketi kurulu ama hiç kullanılmıyor** — ölü bağımlılık;
  APK boyutunu ve izin yüzeyini gereksiz büyütüyor. Kaldırılmalı.
- 🟡 **`pubspec.yaml` sürümü `1.0.43-beta.9+4309`** ama yayınlanan etiketler
  v46–v49. Mağaza paketleri bu numarayı okur; hizalanmalı.
- 🟡 **Windows MSIX kendi kendine güncelleme açık.** Microsoft Store sürümünde
  bu kapatılmalı (Android'de Play kanalı için zaten kapalı).
- 🟡 Depoda yanlışlıkla izlenen 24 MB bozuk `test.zip` takipten çıkarıldı;
  git geçmişinden temizlemek ayrı bir iş (geçmiş yeniden yazılır).

## Ek B — Arşivlenen belgeler

2026-07-26'da `docs/archive/`'e taşınanlar: beta arıza raporları (3),
kurtarma ön incelemesi, sayaç düzeltme planı, sayaç mimari raporu, bildirim
sistemi denetimi, başarım/görev/grup planı, XP kararları, yeni özellik
planı + notları, Play hazırlık taraması, Windows ürün planı, Windows Store
planı, Play sahip checklist'i. İçlerindeki **yaşayan** iş bu dosyaya taşındı.
Silinen: iki boş "denetim yanıtı" bağlantı dosyası.
Ayrıca depoda yanlışlıkla izlenen 24 MB'lık bozuk `test.zip` takipten çıkarıldı.
