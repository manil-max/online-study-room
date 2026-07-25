# Dokümantasyon — tek giriş noktası

Bu dizinde geçmiş plan/draft/ajan notu tutulmaz. Eski bir karar gerekiyorsa Git geçmişine
bakılır; `archive/` yalnız tarihsel kanıttır ve **asla güncel karar kaynağı değildir**.

## Okuma sırası ve yetki

1. **Yol haritası ve açık kararlar:** [`PLAN.md`](PLAN.md) — nereye gidiyoruz, hangi fazdayız
2. **Aktif iş, sahiplik ve gerçek durum:** [`../progress.md`](../progress.md)
3. **Ürün, kalite, güvenlik ve yayın kuralları:** [`KALITE-PROGRAMI.md`](KALITE-PROGRAMI.md)
4. **Çalışma kuralları:** [`../.agents/AGENTS.md`](../.agents/AGENTS.md)

Bu dört kaynak dışında bir Markdown dosyası, aşağıda açıkça sayılmadıkça, ajan için karar
veya uyarı üretmez. Kod, migration ve canlı sistem hakkındaki gerçek kaynak ilgili kaynak
koddur; eski doküman değil.

## Kalan gerekli belgeler

| Alan | Belge | Neden ayrı duruyor? |
|---|---|---|
| Sahip geri bildirimi | [`V46-SAHIP-GERI-BILDIRIMI.md`](V46-SAHIP-GERI-BILDIRIMI.md) | v46–v49 turunun kök neden kaydı; cihaz QA'sı bitince arşivlenir |
| Mağaza beyanı | [`play-store/DATA-SAFETY.md`](play-store/DATA-SAFETY.md), [`play-store/PLAY-RELEASE-GATE.md`](play-store/PLAY-RELEASE-GATE.md) | Sahip aksiyonu ve mağaza beyanı, koddan üretilemez |
| Hesap silme | [`HESAP-SILME-RETENTION-KARARI.md`](HESAP-SILME-RETENTION-KARARI.md) | Ürün sahibinin açık kararı gereken veri/retention politikası |
| Hukuk | [`legal/`](legal/) | Yayınlanabilir Privacy Policy, Terms ve Community Guidelines metinleri |
| Kaynak-koda bağlı mimari | [`BASARIM-MIMARISI.md`](BASARIM-MIMARISI.md), [`SAAT-MIMARISI.md`](SAAT-MIMARISI.md), [`TEMA-MIMARISI.md`](TEMA-MIMARISI.md), [`TEMA-HIS-KATALOGU.md`](TEMA-HIS-KATALOGU.md), [`CAMPFIRE-R2-TASARIM.md`](CAMPFIRE-R2-TASARIM.md) | Kod yorumları bu dosyalara doğrudan bağlanır; taşıma/silme link kırar |
| Ortam ve migration | [`ORTAM-MIGRATION-YONETISIMI.md`](ORTAM-MIGRATION-YONETISIMI.md), [`recovery/`](recovery/) | Canlı ortamların kanonik durumu ve geri alma yolları |
| Windows | [`WINDOWS-RELEASE-GATE.md`](WINDOWS-RELEASE-GATE.md), [`QA-WINDOWS.md`](QA-WINDOWS.md), [`WINDOWS-VM-QA.md`](WINDOWS-VM-QA.md) | Windows paketleme ve cihaz kabulü için canlı çalışma listesi |
| Cihaz kabulü | [`qa/DEVICE-QA-MATRIX.md`](qa/DEVICE-QA-MATRIX.md) | Samsung/Pixel/Android sürümü ve temel yolculuk kanıtı |
| Aktif RLS doğrulaması | [`features/ANALYTICS-RLS-TEST-PLAN.md`](features/ANALYTICS-RLS-TEST-PLAN.md) | Mağaza kontrol listesi bunu doğrudan kullanır |
| Runbook | [`SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md`](SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md) | Supabase panel adımları, koddan üretilemez |

## Temel değişmezler

- "Tamamlandı" demek için otomatik test, gerçek cihaz QA ve ürün kabulü gerekir.
- Flutter + Riverpod + Supabase; repository hem Supabase hem InMemory uygulanır.
- RLS gerçek yetkilendirme katmanıdır. XP ve kritik ilerleme sunucu tarafında,
  idempotent event + append-only ledger ile yönetilir.
- Kullanıcı metni TR + EN (2026-07-26 kararı; DE/AR dosyaları arşiv olarak repoda kalır).
- ⚠️ Gün sınırı **hedefi** `Europe/Istanbul`; kod bugün hâlâ UTC'ye göre çalışıyor.
  Geçiş [`PLAN.md`](PLAN.md) Faz E'nin işidir.
- 🔴 Sürüm çıkarma sahip onayına bağlıdır (2026-07-26).
- Mağaza artefaktı GitHub APK kurmaz; hesap silme hem uygulama içinden hem webden
  sağlanır; kullanıcı içeriği yüzeyleri raporlama/engelleme/moderasyon olmadan
  production'a çıkmaz.

## Arşiv

[`archive/`](archive/) tarihsel kanıt içindir. Yeni bir iş buradan claim edilmez;
güncel kararla çelişen her ifade geçersizdir.
