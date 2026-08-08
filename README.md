# Odak Kampı · Focus Camp

Küçük gruplar için **ortak online çalışma uygulaması**. Kullanıcılar aynı kampa
katılır, birbirlerinin **canlı çalışma durumunu** görür, çalışma sürelerini
takip eder ve **detaylı istatistiklerle** kıyaslar.

Ürün adı cihaz diline göre değişir: İngilizce cihazda **Focus Camp**, Türkçe
cihazda **Odak Kampı** (sahip kararı, 2026-07-28).

## Özellikler

- **Grup/kamp sistemi** — davet koduyla ortak çalışma odası
- **Profil** — e-posta ile hesap, profil fotoğrafı
- **Kamp ateşi** — kim aktif çalışıyor, gerçek zamanlı sahne
- **Süre takibi** — kronometre, geri sayım, Pomodoro ve manuel süre girişi
- **Detaylı istatistikler** — günlük/haftalık kırılım, tarih aralıkları, kıyaslama
- **Başarım ve XP** — sunucu-otoriter, append-only ledger
- **Çoklu cihaz senkronizasyonu** — Android telefon/tablet + Windows
- **Widget'lar** — Android ana ekran + Windows masaüstü Compact Focus

## Teknoloji

- **Flutter** (Android + Windows, tek kod tabanı)
- **Supabase** (Auth · Postgres · Realtime · Storage · Edge Functions)
- **Riverpod** (durum yönetimi) · **fl_chart** (grafikler)

## Durum

Geliştirme sürüyor; uygulama sahada kullanılıyor. Android dağıtımı bugün GitHub
Releases üzerinden yapılıyor, Play Store kapalı test hazırlığı devam ediyor.

Bu dosya bilerek sürüm numarası veya migration head yazmaz — bayatlar. Güncel
değerlerin tek kaynakları:

| Gerçek | Tek kaynak |
|---|---|
| Uygulama sürümü | [`app/pubspec.yaml`](app/pubspec.yaml) → `version` |
| Yayınlanan sürüm notları | [`CHANGELOG.md`](CHANGELOG.md) |
| Ortam / migration head / apply-release kapıları | [`tooling/release/deploy-contract.json`](tooling/release/deploy-contract.json) |
| Play yayın durumu | [`docs/play-store/YAYIN-PLANI.md`](docs/play-store/YAYIN-PLANI.md) |

## Nereden başlanır

| Ne arıyorsun? | Dosya |
|---|---|
| Güncel durum, yol haritası, aktif iş | [`progress.md`](progress.md) — **tek güncel kaynak** |
| Ajan çalışma kuralları | [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) → [`.agents/AGENTS.md`](.agents/AGENTS.md) |
| Kalite, güvenlik ve yayın programı | [`docs/KALITE-PROGRAMI.md`](docs/KALITE-PROGRAMI.md) |
| Belge indeksi | [`docs/README.md`](docs/README.md) |
| Teknik tasarım dokümanı (vizyon, veri modeli, kararlar) | [`project.md`](project.md) |
| Şema ve migration zinciri | [`supabase/README.md`](supabase/README.md) |
| Deploy / release otomasyonu | [`tooling/README.md`](tooling/README.md) |
