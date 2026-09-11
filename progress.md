# progress.md — Canlı Durum

> Son güncelleme: **2026-09-11** · Saat dilimi: **Europe/Istanbul**
> Güncel durum, aktif iş ve kabul kuyruğunun tek kaynağı bu dosyadır.
> Kurallar: [.agents/AGENTS.md](.agents/AGENTS.md) + [Kalite Programı](docs/KALITE-PROGRAMI.md).
> Önceki WP kartları, kanıtlar ve yayın kayıtları kayıpsız [tarihçede](progress-history-2026-09-11.md).
> Yeni işler buraya yazılır; tarihçedeki “aktif”, “son numara” ve “sıradaki migration” ifadeleri güncel talimat değildir.

## Proje Gerçekleri

| Konu | Doğrulanmış durum | Kanıt / sınır |
|---|---|---|
| Son kayıtlı yayın | **v83 · 1.0.83+83**, etiket commit'i `1cfcf2f6` | 2026-09-08 yayın kaydı; [tarihçe](progress-history-2026-09-11.md) son bölümü |
| v83 release koşumu | **34166386717: completed / success** | 2026-09-11 `gh run view` ile salt okunur doğrulandı: preflight, android, windows / build, finalize_android, release_status, finalize_complete başarılı |
| Play | Son kayıtlı kapalı test **alpha 83, completed** | Koşum `34168099776`; bu tur Play Console yeniden sorgulanmadı. Production mağaza kabulü demek değildir |
| Veritabanı | Repo ve deploy sözleşmesi **0140**; son kayıtlı staging/production head **0140** | [Sözleşme](tooling/release/deploy-contract.json); bu tur uzak DB sorgulanmadı |
| Kapılar | staging deploy/release **false/false**; production deploy/release **false/true** | Kodda doğrulandı. Production release için ayrı somut GO gerekir; açık bayrak tek başına izin değildir |
| Son yayımlanan Edge düzeltmesi | Yönetimde ad sıfırlamayı geri alma | Staging `34158924034`, production `34158977501`; önceki yayın kaydı, bu tur yeniden deploy yok |
| Çalışma modeli | Tek lider + atanan ayrık dosyalarda alt ajan | Tek dal `main`; push/tag/deploy bu turun kapsamında değil |
| Son ayrılan WP | **WP-825** | Bu turun WP-822…WP-825 kartları aşağıda |

**Kanıt sınırı:** Kod/test/yayın başarısı cihaz kabulü değildir. Bu tur başlarken
üç Windows generated plugin dosyası zaten değişikti; bu işlerin kapsamına alınmadı.

## ⚡ Aktif Çalışma Kaydı

### Faz — Küçük kart erişimi ve güncel notlar (2026-09-11)

Sahip talebi: genel incelemenin **4 ve 5. maddelerini dikkatli uygulamak**; ardından
sahip "sana kalmış, karar ver ve durma" diyerek turu ajana bıraktı (onay alınamaz).
Ajan kararı: kapıyı yeşile döndüren iki kırmızıyı da kapatmak, yayın hattına dokunmamak.

Dört ayrık iş: ürün kodu **WP-822**, belgeler **WP-823**, ortam sözleşmesi **WP-824**,
test fikstürü **WP-825**. Tam test kapısı liderde tek merkezden.

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
  Dosyadaki 9 test yeşil.
- **Geri alma:** tek commit; yalnız test fikstürü.

**Kapsam dışı bırakılan, bildirilen bulgular** (`.agents/AGENTS.md §2`):
`release.yml` Android yoluna geçersiz `DISTRIBUTION_CHANNEL='github'` yazıyor ·
aynı yarım dil fikstürü 12 test dosyasında daha var · `activeAppLocale`in iki
yazarı olması. Üçü de [backlog](backlog.md) içinde, ölçümleriyle.

### Kapanış kapısı — 2026-09-11, WP-822…825 sonrası

`python scripts/test_all.py` · **21 kapı · 0 kırmızı · 1 atlandı** · 294s.
Flutter test paketi (+ kapsam) 275s **GEÇTİ**; yeni `test-env` kapısı listede
ve geçiyor. Turun başındaki 7 düşen testin tamamı kapandı.

**Atlanan kapı yeşil değildir:** *Android native JVM testleri* — bu makinede
Android Gradle wrapper kurulu değil. Bu bir kod iddiası değil, ortam sınırıdır;
o kapının asıl evi CI'daki Android işidir. Bu turda hiçbir native/Kotlin dosyası
değişmedi, yani atlanan kapının kapsamına giren bir değişiklik de yok.

**Bu yeşil ne demek değildir:** cihaz kabulü verilmedi, Play/Store kabulü
sorgulanmadı, uzak DB ve deploy bu turun kapsamında değil, push/tag yapılmadı.

## 🗺️ Yol Haritası

1. `release.yml` geçersiz kanal define'ı (`'github'`) + WP-614 kapısının bu iş
   akışına bağlanması. **Yayın hattı — sahip kararı bekliyor.**
2. Aşağıdaki v83 ve kart cihaz kabulü; bulgu varsa ayrı düzeltme kartı.
3. [Backlog](backlog.md) içindeki açık adaylar; bu tur kendiliğinden uygulanmaz.
4. Play production / Windows Store: güncel mağaza kanıtı ve ayrı sahip kararı.

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
