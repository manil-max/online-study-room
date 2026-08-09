# Rakip Analizi — Değerlendirme ve Karar Önerileri

> `docs/RAKIPANALIZI.md` üzerine ikinci okuma. Buradaki her "bizde şu var/yok" cümlesi
> **koda bakılarak** yazıldı; dosya:satır referansı verilmeyen iddia yok.
> Tarih: 2026-07-28 · Bu bir plan değildir; karar ve politika önerisidir.

---

## 0. Dokümanın kendisi hakkında

**Değerli olan:** 439 gerçek yorumun tema sayımı bizim tahminlerimizi değil, rakibin
5 yıldır kapatamadığı yaraları gösteriyor. Özellikle §2.1.2(1) (ağ giderse sayaç
durdurulamıyor) ve §2.1.2(6) (Ağustos 2025 regresyon isyanı) bizim mevcut mimari ve
süreç kararlarımızı doğrudan doğruluyor — bunlar **kanıt**, artık varsayım değil.

**Metodolojik sınırlar (karar verirken hatırla):**
1. Yıldız yok, dil İngilizce, Play "en yararlı"yı öne çıkarır → gösterilen örneklem
   şikayete eğimli. 4.5 puanlı bir uygulamanın 439 yorumunun %66'sının şikayet işaretli
   olması, kullanıcıların %66'sının memnuniyetsiz olduğu anlamına **gelmez**.
2. §2.2–2.9 tamamen ikinci el (🟡/⚪). Bunlar hipotez; tek başına hiçbir kararı
   taşıyamaz. Kararı yalnız §2.1 (birinci el) ve kod gerçeği taşımalı.
3. Sayılar mutlak değil oransal okunmalı: 75K oylu bir üründe 15 kişinin istediği şey,
   0 kullanıcılı bir üründe öncelik değildir.

**Dokümanın kendi içindeki çelişki:** §4.1 "offline-first akış bizde var" diyor,
§4.3 aynı şeyi **P0 backlog** olarak listeliyor. İkisi aynı anda doğru olamaz.
Doğrusu §1.2'de.

---

## 1. §4.1 tablosunda düzeltilmesi gereken üç iddia

### 1.1 "Drift (SQLite) yerel depo" — **YANLIŞ, böyle bir şey yok**
`app/pubspec.yaml` bağımlılıklarında drift/sqflite/sqlite yok. `app/lib/data/local/`
dizini yok. Gerçek yerel katman:
- `app/lib/data/repositories/offline/offline_cache_store.dart` (280 satır) —
  **SharedPreferences üzerine JSON**. Anahtar başına tüm liste yeniden yazılır.
- `offline_first_study_repository.dart` (336 satır) — cache + **outbox**
  (`queueStudyMutation` / `flushPending`).

Bu iş görüyor ama veritabanı değil: sorgu yok, kısmi yazma yok, liste büyüdükçe her
yazma tüm JSON'u yeniden serialize eder. Doküman "SQLite" yazdığı için ileride biri
buna güvenip yanlış tasarım yapabilir. Satır düzeltilmeli.

### 1.2 "offline-first akış" — **YARISI DOĞRU, ve doğru olan yarısı gerçekten değerli**
Kodda doğrulandı (`app/lib/data/providers/study_providers.dart:1468-1512`):
`startLiveRun` başarısız olursa **sayaç yerel olarak çalışmaya devam ediyor**,
sadece `verification: statisticsOnly` işaretleniyor. Durdurma yerel;
`addSession` ağ yoksa kuyruğa alınıyor (`offline_first_study_repository.dart:117-125`).

> Yani YPT'nin **en ölümcül hatası (36/41 yorum, 5 yıldır açık) bizde yapısal olarak
> yok.** Bu bir pazarlama cümlesi hak ediyor: *"İnternet gitse bile sayacın durur ve
> süren kaydedilir."*

Doğru olmayan yarı: **canlı/sosyal katman** (presence, gruptaki "şu an çalışıyor",
çoklu cihaz global run) ağ ister ve istemeye devam edecek. Bu bir kusur değil, tanım
gereği. Tablo bunu ayırmalı.

### 1.3 "Davet kodlu kapalı grup — yapısal bağışıklık" — **KISMEN**
`supabase/migrations/0032_public_group_discovery.sql:16` ile gruplarda
`visibility in ('private','public')` var ve **public grup keşfi açık**. Yani açık
pazarın moderasyon vergisini kısmen biz de ödüyoruz. "Yapısal bağışıklık" cümlesi
yalnız private gruplar için doğru. (Sahibin daha önce dediği *"public de olsa"*
cümlesi de bunu doğruluyor.)

### 1.4 Doğrulanan ve doğru olan iddialar
| İddia | Durum |
|---|---|
| `study_sessions.group_id` kaldırıldı | ✅ `0010_drop_session_group_id.sql:31` |
| immutable `study_session_group_attribution` | ✅ `0080_session_group_attribution.sql` |
| foreground service ile arka planda ölmeyen sayaç | ✅ `StudyTimerService.kt` + manifest |
| Windows birinci sınıf hedef | ✅ `window_manager` + `docs/WINDOWS-RELEASE-GATE.md` |
| home_widget ile Android widget | ✅ `pubspec.yaml` + `StudyWidgetProviders.kt` |
| `admin_audit_log`, `feedback_tickets` | ✅ `0021`, `0018`/`0044`/`0074` |
| server-authoritative kazanım zinciri | ✅ `0063_equal_study_sources.sql` |

---

## 2. §4.3 backlog'unun triyajı

### 2.1 Zaten yapılmış — backlog'dan çıkar
| Madde | Gerçek |
|---|---|
| **P0** Çevrimdışıyken sayaç başlat/durdur/kaydet | Var (§1.2). Kalan tek eksik §3'te. |
| **P0** Gün kırılımı muhasebesi | Karar verilmiş ve tutarlı: `0073_session_day_stamp.sql:24` → gün = `start_time at time zone 'Europe/Istanbul'`. İstemci tarafı da aynı: `app/lib/core/stats/istanbul_calendar.dart`. Oturum **başladığı güne** yazılır. Eksik olan kod değil, **açıklama**. |
| **P1** Manuel süre gruba yansısın | Yansıyor: attribution trigger `source` ayırmıyor, her insert'te çalışıyor (`0080`). Ayrıca `0063` ile manuel/live **eşit XP** alıyor. Yani YPT'nin 5 yorumluk öfkesi bizde yok. Eksik olan **rozet** (§3). |
| **P1** Streak + günlük hedef | Var (`profile.dart` daily_goal, `smart_reminder_scheduler.dart` streak). |
| **P1** Bildirimden duraklat/başlat | Var (`timer_notification_service.dart:197`, `StudyTimerService.kt:382`). |
| **P1** Alarm sesi | Var, üstelik native `AlarmManager` birincil (`alarm_notification_service.dart:23`). |

### 2.2 Reddedilmesi gerekenler (ve gerekçesi)
- **Gün başlangıç saatini kullanıcıya seçtirmek (P1).** YPT'nin şikayeti 05:00
  dayatması; istenen 00:00. **Bizde zaten 00:00.** Ayarlanabilir yapmak `day`
  sütununun materialize edilmiş olması yüzünden migration + backfill + tüm istatistik
  zinciri demek. Bedeli faydasından büyük. **Hayır.**
- **Boşta kalma (idle) tespiti (P2).** İnvazif, pil yakar, yanlış pozitifte kullanıcının
  gerçek saatini siler — yani rakibin en sert şikayetini (süre kaybı) biz üretiriz.
  Bizde kazanım zaten sunucu-yetkili ve lease sweeper'lı (`0089`). **Hayır.**
- **Uygulama engelleme (P2, "isteğe bağlı olsun" olarak listelenmiş).** Doküman 33/40
  şikayet sayıyor. Doğru sonuç "opsiyonel yap" değil, **hiç yapma**. Yazılı politika
  olsun ki sonradan sızmasın.
- **Sesli/görüntülü ortak seans (§2.1.3 #9).** StudyStream'in hem maliyet hem taciz
  cephesi. Ücretsiz kalma hedefiyle uyumsuz. **Hayır.**
- **Araç yığını yarışı** (sözlük, hesap makinesi, flashcard, beyaz gürültü). YPT'nin
  gücü bu ama bizim kaybedeceğimiz oyun. **Girme.** Tek istisna önerisi §4.6'da.

### 2.3 Kabul — ama yayından sonra
Sırayla: manuel rozeti (§3) · sıralamayı gizleme/kişisel hedef modu · sohbette görsel +
alıntı · hesap e-postası değiştirme · ders klasörü · AMOLED tema · çalışma dışı kategori.

---

## 3. Dokümanın kaçırdığı, kodda bulunan gerçek açık

> 🔴 **REDDEDİLDİ — proje sahibi kararı, 2026-08-09.** Aşağıdaki "elle eklendi"
> etiketi önerisi uygulanmayacak. Sahip açıkça istemedi. Manuel ve sayaçla
> girilen süre hiçbir yerde ayırt edilmez. Bölüm analiz kaydı olarak duruyor,
> **backlog maddesi değildir**. Bağlayıcı karar: `docs/URUN-POLITIKALARI.md` §7.

**Manuel oturum tam XP alıyor ve hiçbir yerde işaretlenmiyor.**

- `0063_equal_study_sources.sql:5` — *"source veya eski live_run bağı, XP/başarım/grup
  metriği bakımından fark yaratmaz"*.
- `0001_initial_schema.sql:57` — *"'live' | 'manual' — sadece kayıt amaçlı;
  istatistikte/UI'da ayrım yapılmaz."*

Kazanımın eşit olması **doğru karar** — YPT'nin "unuttum, saatim sayılmadı" öfkesi
bizde yok. Ama public grup + liderlik tablosu varken, elle 8 saat girip listenin
başına geçmek mümkün ve **kimse göremiyor**. Dokümanın kendi §4.2.6 önerisi tam da bu:
*"girsin ama işaretli girsin"*. Şu an ilk yarısı var, ikinci yarısı yok.

**Öneri:** kazanım eşit kalsın, `source='manual'` oturumlar **grup katkı listesinde ve
oturum geçmişinde küçük bir "elle eklendi" etiketi** taşısın. Ceza değil şeffaflık.
Küçük grupta sosyal denetim bunu kendiliğinden çözer.

---

## 4. Yazılı politika önerileri

Bunlar kod değil, **karar metni**. Yazılı olmazsa altı ay sonra sessizce ihlal edilir.

### 4.1 Regresyon politikası (en kanıtlı ders)
Kullanıcıya görünen bir düzen değişirse **eski düzen seçenek olarak kalır**; bir özellik
kaldırılacaksa önce sürüm notunda duyurulur ve bir sürüm boyunca geri alınabilir olur.
Kanıt: YPT Ağustos 2025 (32/41 yorum) + My Study Life + Forest. Rakip geri adım atıp
"Klasik/Yeni ana ekran" seçeneği koyunca öfke söndü. `docs/KALITE-PROGRAMI.md`'ye
sürüm kapısı maddesi olarak girmeli.

### 4.2 Ücret politikası — yazılı ve mağaza açıklamasında
> "Sayaç, gruplar, istatistikler ve bildirimler kalıcı olarak ücretsiz ve reklamsızdır.
> İleride ücretli bir şey gelirse yalnız kozmetik olur ve çalışarak da kazanılabilir."

Rakibin **en taze** öfke kaynağı 2026'da eklenen açılış reklamları ve satın alınan
"flame"ler. Bu cümle sıfır maliyetli en güçlü farklılaştırıcı. Yalnız ileride bağlayıcı
olduğunu bilerek yaz.

### 4.3 Zorlama yok politikası
Uygulama engelleme yok · mola cezası yok (Study Bunny) · kolektif ceza yok (Flora'da
host çıkınca herkesin ağacı ölüyor). Kamp ateşi/grup hedefi mekanikleri tasarlanırken
"birinin hatası herkesi cezalandırır" kalıbı **yasak**.

### 4.4 Yıkıcı eylem politikası — "stop ≠ sil"
Rakipte kullanıcılar yanlış butonla saatlerini sildi (§2.1.2/2). Bizde durdurma ile
oturum silme görsel ve metinsel olarak ayrık olmalı, silme onay ister ve geri
alınabilir olmalı. Yayın öncesi cihazda tek turluk kontrol maddesi.

### 4.5 Dağıtım politikası — açılışta yalnız Türkiye
Ürünün **tek takvim sınırı Europe/Istanbul** (`istanbul_calendar.dart:13`,
`0073:24`) ve bu bilinçli bir karar. Play varsayılanı tüm dünyadır: Berlin'de 23:30'da
çalışan biri süresini ertesi güne yazılmış görür — YPT'nin 21/24 şikayetinin aynadaki
hâli. **Açılışta ülke listesi Türkiye (+ istersen birkaç ülke) olsun.** Uluslararası
açılım, kullanıcı saat dilimi kararı verildikten sonra. Bu bir Play ayarı, kod değil.

### 4.6 Kapsam politikası — araç yığınına girmiyoruz, tek istisna
YPT'nin övgüsü "tek uygulamada her şey". Bu yarışa girmek bizi bitirir. Tek ucuz ve TR
pazarına birebir oturan istisna önerisi: **sınav geri sayımı (D-Day)** — "YKS'ye 214
gün". Neredeyse bedava, profil/ana ekranda tek satır, TR öğrenci bağlamının tam
merkezinde. Bunun dışında hiçbir araç eklenmiyor.

---

## 5. Yayın öncesine ne ekleniyor?

**Neredeyse hiçbir şey — ve bu iyi haber.** Bu doküman esas olarak *yapmadığımız
şeyleri doğruluyor*, yeni iş açmıyor. Yayın kapısına eklenmesi önerilen yalnız iki
madde, ikisi de kod değil:

1. **Politika metinleri** (§4.1–4.6) yazılıp `docs/`'a girsin; §4.2 mağaza açıklamasına
   ve SSS'e cümle olarak geçsin.
2. **Play ülke listesi Türkiye** (§4.5) — konsolda tek ayar.

Ayrıca SSS'e üç madde ekleniyor (zaten yazılacak olan SSS'in içine):
- "Gün ne zaman biter?" → gece 00:00, Türkiye saati; oturum **başladığı güne** yazılır.
- "İnternetim yokken çalışırsam?" → sayaç çalışır, durur, kaydedilir; bağlanınca
  senkronlanır. Sadece "şu an çalışıyor" görünürlüğü ve çoklu cihaz senkronu ağ ister.
- "Elle süre eklersem sayılır mı?" → evet, tam sayılır (XP dahil).

Geri kalan her şey (manuel rozeti dahil) **yayın sonrası**.

---

## 6. Sıradaki araştırma — sadece biri değer

Dokümanın §5'i dört adım öneriyor. Üçü şu an israf: rakibin changelog'u, ikinci el
dökümler, StudyStream/FLIP ham verisi — hiçbiri bizim önümüzdeki iki haftalık işi
değiştirmez.

Değeri olan tek adım: **Türkçe yorumlar.** Mevcut dökümde 1 tane var. YKS/KPSS
bağlamındaki TR öğrenci beklentisi (konu takibi, deneme, net hesabı, sınav geri sayımı)
İngilizce yorumlarda **hiç görünmüyor** ve bizim gerçek pazarımız orası. Yayından sonra,
kendi kullanıcı geri bildirimimiz gelmeye başlayınca yapılırsa daha da değerli olur —
o zaman rakibin değil kendi kullanıcımızın sesini okuruz.
