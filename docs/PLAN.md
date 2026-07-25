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
| Cihaz QA | 🔴 **Büyük borç:** v46–v49 arası işlerin çoğu hiç cihazda doğrulanmadı |
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
| **K4** Gün sınırı backfill | ✅ **Geçmişe dokunma** — sadece bundan sonrası düzelsin. Gerekçe: kullanıcı sayısı çok az, risk almaya değmez |
| **K5** Çoklu grup | ✅ **Birincil grup** — kullanıcı seçer; görev/hedef/başarım onu sayar |
| **K6** İsim + logo | ⏸️ Faz B sırasında konuşulacak |
| **K7** Gizlilik URL'i | ⏸️ Sahip deneyimi yok → öneri bekliyor (bkz. §Ek C) |

---

# PLAN 1 — ÜRÜN & KOD

## Faz A — Doğrulama borcunu kapat 🔴 *önce bu*

Hiçbir yeni iş, elimizde ne olduğunu bilmeden başlamamalı. v46–v49 arasında
çok sayıda değişiklik cihaza hiç değmedi.

**A1. v49 kabulü.** Tema sihirbazı: his adımı artık görünür efekt veriyor mu ·
özel temada okunmayan yazı kalmadı mı (koyu **ve** açık modda) · spektrum renk
seçici · font düğmeleri sabit mi · grafikte her sütunun altında tarih var mı.

**A2. Birikmiş QA kuyruğu.** `progress.md` → *Cihaz QA Kuyruğu*: ayarlar IA,
şifre sıfırlama, tema göçü, gömülü fontlar, taç/aura görselleri, l10n borcu,
boş ikinci bildirim, ana ekran düzenleme paneli. Windows tarafı da var.

**A3. Bulunan her hata** buraya "Faz A bulguları" olarak yazılır; kritik
olanlar Faz B'den önce düzeltilir, kozmetik olanlar Faz F'ye ertelenir.

**Çıktı:** hangi ekranın gerçekten çalıştığını bilen bir liste. Play'in
"P0 hata = 0" kapısı da bunu istiyor.

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
🔴 *Karar gerekiyor — K1 (aşağıda).*

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
🔴 *Karar gerekiyor — K2.*

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
🔴 *Karar gerekiyor — K3.*

---

## Faz E — Veri doğruluğu ve grup semantiği

Bu fazın iki işi de **geri alınamaz veri** ile ilgili: yedek, staging provası ve
rollback planı olmadan production'a dokunulmaz.

**E1. Gün sınırı `Europe/Istanbul`.** ✅ *Karar verildi, yapılacak.*
Şu an günlük toplam/seri hesabı UTC'ye göre; gece 02:00'de çalışan kullanıcının
süresi ertesi güne yazılıyor, serisi haksız yere kırılıyor.
Sıra: (1) sunucu fonksiyonlarını İstanbul gününe çevir → (2) staging'de
sentetik veriyle prova → (3) production yedeği → (4) geçmiş veriyi yeniden
hesapla (backfill) → (5) rollback betiği hazır beklet.
🔴 *Karar gerekiyor — K4 (geçmişin ne kadarı düzeltilecek?).*

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
🔴 *Karar gerekiyor — K5.*

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

| # | Konu | Soru |
| --- | --- | --- |
| **K1** | Yanıt kanalı | Admin yanıtı **tek yönlü duyuru** mu olsun, yoksa kullanıcı **geri yazabilsin** mi (gerçek yazışma)? Tek yön basit ve hızlı; çift yön daha iyi ama moderasyon/bildirim yükü getirir |
| **K2** | Şifre değiştirme | "Mevcut şifre" alanı **gerçekten doğrulansın** mı (kullanıcı şifresiyle yeniden giriş yapılır, güvenli ama bir adım fazla), yoksa Supabase'in varsayılanı gibi **sadece yeni şifre** mi sorulsun? Ayrıca: hiç şifresi olmayan (Google/passkey ile giren) kullanıcıya bu ekran ne göstersin? |
| **K3** | Tanıtım turu | Tur **zorunlu mu** (ilk girişte otomatik açılır) yoksa **isteğe bağlı mı** ("?" düğmesi ile açılır)? Kaç balon fazla — ekran başına 3–4 mü, her öğe için mi? |
| **K4** | Gün sınırı backfill | Geçmiş veri **ne kadar geriye** düzeltilsin — hepsi mi, son 90 gün mü, yoksa sadece bugünden sonrası mı? (Hepsi = en doğru ama en riskli) |
| **K5** | Çoklu grup | Kullanıcı birden fazla gruptaysa: **(a)** hepsi aynı anda aktif · **(b)** bir tanesi "birincil grup" seçilir, görev/hedef/başarım onu sayar · **(c)** kullanıcı aynı anda **tek** gruba üye olabilir (en basit, ama mevcut çoklu üyelikler göç ister) |
| **K6** | İsim + logo | Değişecek mi? Değişecekse **ne zaman** — Faz A–C sürerken karar verip mağaza işlerine hazır girelim mi? TR ve EN'de aynı isim mi kullanılacak? |
| **K7** | Gizlilik URL'i | Politika metinleri nerede yayınlanacak? (GitHub Pages ücretsiz ve hızlı · kendi domainin varsa oraya · her ikisi de olur) |

---

# RİSK VE TUZAK NOTLARI

- **Sürüm disiplini.** Artık sürüm sahibin onayıyla çıkar. Düzeltmeler birikir,
  tek sürümde çıkar. (2026-07-26 kararı)
- **Cihaz QA borcu birikiyor.** Her yeni faz bu borcu büyütür; Faz A'nın önce
  gelmesinin sebebi bu.
- **Geri alınamaz işler.** Gün sınırı backfill'i ve hesap silme purge'ü bu
  sınıfta. Yedek + staging provası + rollback betiği olmadan production'a
  dokunulmaz (`.agents/AGENTS.md` ve `docs/recovery/` kuralı).
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

## Ek C — K7 önerisi: gizlilik metinleri nerede yayınlansın?

Motto: *"basit durmayan ama bizi uğraştırmayan."* Önerim **GitHub Pages**:
bedava, HTTPS hazır, repoda zaten duran `docs/legal/*.md` dosyalarından
otomatik yayınlanır, ayrı sunucu/domain/ödeme yok. Adres
`https://<kullanıcı>.github.io/<repo>/privacy` gibi olur — mağaza formları
bunu kabul eder. İleride alan adı alınırsa aynı sayfaya yönlendirilir,
mağazadaki bağlantı değişmez. Kurulum yarım saatlik iş; sahip tarafında
yapılacak tek şey repo ayarlarından Pages'i açmak.

## Ek D — Faz A bulguları (cihaz QA öncesi, koddan çıkanlar)

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
