# progress.md — Canlı Durum

> Son güncelleme: **2026-07-24** · Saat dilimi: **Europe/Istanbul**
>
> Bu dosya yalnız aktif iş, açık kabul ve ürün kararlarını taşır. Tamamlanmış WP'lerin ayrıntısı git geçmişi, [`docs/archive/progress-tarihsel-2026-07.md`](docs/archive/progress-tarihsel-2026-07.md) ve kanonik raporlardadır; burada tekrar edilmez.

## Proje Gerçekleri

- **Stable/production:** v45 yayında. Production migration head `0065`; staging `0070`. Yeni production migration, Edge deploy veya stable tag/release yalnız ayrı, somut kullanıcı GO ile yapılır.
- **Beta/staging:** beta-v4308 staging `0070` üzerinde yayında. Proje sahibi 2026-07-24'te stable+beta yayınını ve bildirim/sayaç davranışını cihazda test etti; genel sorun yok, bekleyen cihaz kabulleri kapatıldı.
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
| 0 | Production backend değişikliği | 🔴 Kapalı | Yeni migration/Edge deploy/secret yalnız backup+dry-run ve somut GO ile; v45 mevcut head `0065` ile çalışır |
| 1 | WP-276/277 ops kabulü | [ ] Bekliyor | Sentetik staging ops kanıtı |
| Karar | WP-278/279 | [?] Ürün/ops kararı | Açık sahip ve kapsam kararı olmadan başlanmaz |

## Yeni Özellik Turu (Aşama 1 — konuşma)

Proje sahibi yeni özellik turu açtı. Sıra: **konuşma → plan → WP paketleme → uygulama.**
Konuşma notları: [`docs/YENI-OZELLIK-NOTLARI.md`](docs/YENI-OZELLIK-NOTLARI.md). Plan aşamasına geçilene kadar WP açılmaz, kod yazılmaz.

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
| WP-269–275, 280–285 | **Kapandı (2026-07-24).** Kod/test kanıtı + proje sahibinin v45 stable ve beta-v4308 üzerindeki cihaz testi; bekleyen cihaz kabulü kalmadı |
| WP-271 | Staging gerçek push/retry ve timer action davranışı sahip testinde sorunsuz; ölçümlü matris kaydı istenirse yeni WP açılır |
| WP-225, 226, 258 | Tarihsel tamamlanmış işler; ayrıntı arşiv+git'te |
| WP-266/267/268 | Eski ayrıntılar arşivde; açık push/timer kabulü WP-271 ve QA matrisinde |

## Worker'a Verilecek Kısa Komutlar

- `worker'ı oku ve WP-276'yı yap`
- `worker'ı oku ve WP-277'yi yap`
- WP-278/279 için önce ürün/ops kararı alınır.

> Her worker önce Aktif Çalışma Kaydı'nı okur, kendi lane'ini claim eder ve SAHİP yolları çakışıyorsa başlamaz. Production/stable hiçbir WP'nin örtük parçası değildir.
