# progress.md — Canlı Durum

> Son güncelleme: **2026-07-23** · Saat dilimi: **Europe/Istanbul**
>
> Bu dosya yalnız aktif iş, açık kabul ve ürün kararlarını taşır. Tamamlanmış WP'lerin ayrıntısı git geçmişi, [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) ve kanonik raporlardadır; burada tekrar edilmez.

## Proje Gerçekleri

- **Stable/production:** HOLD. Production migration head `0065`; staging `0070`. Production'a migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO ile yapılır.
- **Beta/staging:** beta-v4307 staging `0070` üzerinde yayımlandı. beta-v4308, cooldown tanısı ve timer biçimi için sıradaki adaydır.
- **Release ilkesi:** Android beta/stable artefaktı Android işi başarılı olunca yayımlanır. Windows bağımsız sürer ve başarılı olursa aynı release'e eklenir; Windows hatası Android güncellemesini geri çekmez.
- **Yönetim varsayılanı:** Production `deploy_enabled/release_enabled` kapalıdır. Stable yalnız protected `production` Environment, exact SHA/head/project-ref GO ve reviewer kanıtıyla ilerler.
- **Kurallar:** Kök `AGENTS.md`, `.agents/AGENTS.md` ve `docs/KALITE-PROGRAMI.md` geçerlidir. Tek çalışma dalı `main`; her WP ayrı commit; production varsayılmaz.
- **Son WP:** **285** · Sıradaki boş numara: **286**.

## ⚡ Aktif Çalışma Kaydı

### Gemini Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Claude Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Codex Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —
- **Son not:** WP-285 kod/test tamam; beta-v4308 P7 cihaz kabulü bekler. Timer state motoru, migration, backend ve production değişmedi.

### Codex-2 Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

### Grok Lane
- **Durum:** [x] Boşta
- **Faz/WP:** —
- **SAHİP yollar:** —

## Öncelik ve Yürütme Sırası

| Öncelik | İş | Durum | Kalan gerçek iş |
|---|---|---|---|
| 0 | Stable/production freeze | 🔴 HOLD | beta kabulü/soak, production backup+dry-run ve somut GO olmadan kalkmaz |
| 1 | WP-285 timer formatı | [x] Kod+test tamam | beta-v4308'de P7 Samsung görünüm kabulü |
| 2 | WP-284 cooldown tanısı | [x] Kod+otomatik test tamam | beta-v4308 C1–C3 cihaz kabulü |
| 3 | WP-271 staging gerçek push | [~] Staging/worker hazır | P1–P6 ölçümlü FCM, retry ve timer action kabulü |
| 4 | WP-273 Windows release | [x] Kod/test tamam | Temiz VM: MSIX kurulum, N→N+1, kaldırma |
| 5 | WP-274 Tools kararı | [x] Kod/test tamam | Dikey/yatay cihaz smoke |
| 6 | WP-275 mutlak XP barı | [x] Kod/test tamam | Android/Windows cihaz smoke |
| Sonra | WP-276/277 ops kabulü | [ ] Bekliyor | Kurtarma cihaz/release kapılarından sonra |
| Karar | WP-278/279 | [?] Ürün/ops kararı | Açık sahip ve kapsam kararı olmadan başlanmaz |

## Cihaz Kabulü / Park

Uzun, otomatik testi tamamlanmış WP kartları kaldırıldı. Bu tablodaki satırlar tamamlanmış işi tekrar açmaz; yalnız fiziksel cihaz, dış ortam veya karar gerektiren kalanı gösterir.

| WP | Kanıtlı durum | Açık kabul / karar |
|---|---|---|
| 269, 282, 283 | Release kapıları ile Android-önce yayın politikası kod/test ile tamam | beta-v4308 Android APK'sının Windows sonucundan bağımsız yayımlandığını gözlemle; stable production GO/reviewer ister |
| 270, 280 | Worker/health ve `pg_net` staging post-check tamam | WP-271'de ölçümlü gerçek FCM/retry kabulü |
| 281 | beta-v4307 APK/prerelease ve artefakt paketleme kanıtı mevcut | Yeni aday APK'sını cihazda doğrula |
| 272, 285 | v43 panel sözleşmesi ve native format fix'i otomatik test/Kotlin derleme ile doğrulandı | P5/P7 Samsung görünümü ve app-kapalı action kabulü |
| 273 | Windows test/build/paketleme kanıtı mevcut | Temiz VM kurulum, N→N+1 güncelleme, kaldırma |
| 274 | Kalıcı kaldırma kararı ve regresyon testleri tamam | Dikey/yatay cihaz smoke |
| 275 | Mutlak XP barı otomatik test tamam | Android/Windows cihaz smoke |
| 284 | Cooldown tanı mesajları otomatik test tamam | beta-v4308 C1–C3 cihaz kabulü |

### WP-271 — Staging gerçek push ve tek-cihaz beta kabulü

- **Mevcut gözlem:** Kullanıcı foreground/background/normal kapatma ve ağ kes→aç self-test smoke'unda işlev gördü; sık isteklerde cooldown mesajı göründü. Bu ölçümlü kabul değildir ve satırlar bu nedenle işaretlenmedi.
- **Yapılacak:** [`docs/qa/DEVICE-QA-MATRIX.md`](docs/qa/DEVICE-QA-MATRIX.md) içindeki P1–P7 ve C1–C3'ü beta-v4308 ile kaydet: 20 self-testte duplicate=0, yanlış hedef=0, p95≤10 sn; normal process-terminated teslim, zorlanmış retry, app-kapalı timer action ve `59:55 → 1:00:05` geçişi.
- **Sınır:** Android “Force stop” normal process termination değildir. Testte bug çıkarsa ayrı debug WP açılır; production'a dokunulmaz.

## Bekleyen Uygulanabilir WP'ler

### WP-276 — Hesap silme staging ops ve kabul kanıtı
- **Durum:** [ ] Bekliyor · **Bağımlılık:** Kurtarma release güveni; production için ayrıca somut GO.
- **Amaç:** Sentetik staging hesapta request/cancel/purge, 14 günlük grace simülasyonu, yetkisiz çağrı, retry/terminal hata ve rollback runbook'unu kanıtlamak.
- **Sınır:** Gerçek kullanıcı hesabı, production purge, yeni feature/migration kapsam dışıdır.
- **Sahip yollar:** `docs/qa/ACCOUNT-DELETION-STAGING.md`, `docs/play-store/PLAY-RELEASE-GATE.md`, redacted staging kanıtı ve yalnız gerekli testler.

### WP-277 — Başarım, görev ve grup ilerlemesi kabul matrisi
- **Durum:** [ ] Bekliyor · **Bağımlılık:** WP-271 cihaz/release güveni; WP-276 ile paralel backend ops yok.
- **Amaç:** Beş süre kaynağında istatistik/XP/başarım/grup sonucunu, pending reward/claim'i, iki cihazı ve İstanbul gün sınırını sentetik staging kanıtıyla sınıflandırmak.
- **Sınır:** Yeni ekonomi kuralı, migration/backfill ve production claim kapsam dışıdır; bulunmuş hata ayrı WP olur.

### WP-278 — AR/DE dil desteği ve RTL ürün kararı
- **Durum:** [?] Kullanıcı üründe AR/DE olup olmayacağını ve çeviri sahibini belirlemeli.
- **Karar sonrası:** Evetse insan çevirisi/RTL cihaz QA için ayrı WP'ler; hayırsa EN/TR sınırı ve kullanıcıya görünen dil seçenekleri dürüstçe güncellenir.

### WP-279 — Aylık rapor canlı ops kararı
- **Durum:** [?] DNS domaini, sender, sağlayıcı, maliyet limiti ve opt-in sahibi kararı yok.
- **Sınır:** Karar olmadan secret, cron, staging/production e-posta gönderimi yapılmaz.

## Kapanan / Tekilleştirilen Kayıtlar

| Kayıt | Canlı durum |
|---|---|
| WP-269, 270, 280–284 | Kod/test veya staging kanıtı tamam; ayrıntılı kartlar kaldırıldı, yalnız yukarıdaki dış kabul kaldı |
| WP-272–275 | Otomatik test tamam; cihaz kabulü tabloya indirildi |
| WP-285 | Native `"00:%s"` öneki kaldırıldı; Kotlin derleme, sözleşme testi, tam Flutter test ve analiz tamam |
| WP-225, 226, 258 | Tarihsel tamamlanmış işler; ayrıntı arşiv+git'te |
| WP-266/267/268 | Eski ayrıntılar arşivde; açık push/timer kabulü WP-271 ve QA matrisinde |

## Worker'a Verilecek Kısa Komutlar

- `worker'ı oku ve WP-276'yı yap`
- `worker'ı oku ve WP-277'yi yap`
- WP-278/279 için önce ürün/ops kararı alınır.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
