# Doküman Rehberi

Bu klasörün kökünde yalnız güncel çalışma belgeleri bulunur. Bir belgenin güncel
ürün kararı sayılması için aşağıdaki **Kanonik** veya **Güncel karar ve yayın**
gruplarında yer alması gerekir. Tarihsel dosyalar `archive/` altındadır ve güncel
durum kaynağı değildir.

## Başlangıç noktaları

| İhtiyaç | Kaynak |
|---|---|
| Aktif iş, sahiplik ve çakışma | [`../progress.md`](../progress.md) |
| Kanonik ürün/kalite programı | [`KALITE-PROGRAMI.md`](KALITE-PROGRAMI.md) |
| Proje çalışma kuralları | [`../.agents/AGENTS.md`](../.agents/AGENTS.md) |
| Ajan kullanım kılavuzu | [`AJAN-KULLANIM.md`](AJAN-KULLANIM.md) |

## Güncel karar ve yayın

| Belge | Kullanım |
|---|---|
| [`PLAY-STORE-HAZIRLIK-TARAMASI.md`](PLAY-STORE-HAZIRLIK-TARAMASI.md) | Play production hazırlığı ve mevcut NO-GO riskleri |
| [`HESAP-SILME-RETENTION-KARARI.md`](HESAP-SILME-RETENTION-KARARI.md) | Hesap silme ve saklama kararı |
| [`AYLIK-RAPOR-KARAR.md`](AYLIK-RAPOR-KARAR.md) | Aylık rapor e-posta sağlayıcısı/teslim kararı |
| [`VERSIONS.md`](VERSIONS.md) | Okunur sürüm indeksi |
| [`DAGITIM.md`](DAGITIM.md) | Dağıtım ve markalama notları |

## Aktif mimari, ürün briefleri ve QA

- Mimari: `BASARIM-MIMARISI.md`, `SAAT-MIMARISI.md`, `TEMA-MIMARISI.md`
- Ürün briefleri: `ANDROID-WIDGET-R2-BRIEF.md`, `CAMPFIRE-R2-TASARIM.md`,
  `ISTATISTIK-R2-BRIEF.md`, `WINDOWS-DESKTOP-UI-R3.md`, `WINDOWS-URUN-PLANI.md`
- QA ve kalite: `QA-ANDROID-WIDGETS.md`, `QA-L10N-EN-TR.md`,
  `QA-MULTI-DEVICE-SYNC.md`, `QA-WINDOWS.md`, `WINDOWS-RELEASE-GATE.md`,
  `WINDOWS-PERF-AUDIT.md`, `WINDOWS-PERFORMANCE-BASELINE.md`
- Yerelleştirme: `L10N-ENVANTER.md`, `L10N-SOZLUK.md`
- Canlı backend referansı: `BACKEND-DURUM.md`

## Arşiv

`archive/` tarihsel kayıtları tutar — **güncel bağımlılık/release kapısı olarak kullanma:**
- [`archive/v8/`](archive/v8/README.md) — V8 dönemi denetim/yayın kanıtları.
- [`archive/progress-tarihsel-2026-07.md`](archive/progress-tarihsel-2026-07.md) — progress.md'den ayrılan tamamlanmış WP kartları (Tarihsel uygulama kartları, Play detay, park/Tamamlanan detayları, Son Teslim Notları).
- [`archive/KALITE-PROGRAMI-tarihsel.md`](archive/KALITE-PROGRAMI-tarihsel.md) — KALITE-PROGRAMI'den ayrılan tamamlanmış program kapsamları (§0/1/3/5.1/6/8.1–8.7/10/12).
