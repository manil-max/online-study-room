# Dokümantasyon — tek giriş noktası

Bu dizinde geçmiş plan/draft/ajan notu tutulmaz. Eski bir karar gerekiyorsa **yalnız Git
geçmişine** bakılır — repoda arşiv dizini yoktur (2026-07-27'de kaldırıldı).

## Okuma sırası ve yetki

1. **Yol haritası, açık kararlar, aktif iş ve gerçek durum:** [`../progress.md`](../progress.md)
   — yol haritası için oradaki *🗺️ Yol Haritası* bölümü (2026-07-26 sahip kararı: tek güncel kaynak)
2. **Ürün, kalite, güvenlik ve yayın kuralları:** [`KALITE-PROGRAMI.md`](KALITE-PROGRAMI.md)
3. **Çalışma kuralları:** [`../.agents/AGENTS.md`](../.agents/AGENTS.md)

Bu üç kaynak dışında bir Markdown dosyası, aşağıda açıkça sayılmadıkça, ajan için karar
veya uyarı üretmez. Kod, migration ve canlı sistem hakkındaki gerçek kaynak ilgili kaynak
koddur; eski doküman değil.

## Kalan gerekli belgeler

| Alan | Belge | Neden ayrı duruyor? |
|---|---|---|
| Mağaza beyanı | [`play-store/DATA-SAFETY.md`](play-store/DATA-SAFETY.md), [`play-store/PLAY-RELEASE-GATE.md`](play-store/PLAY-RELEASE-GATE.md) | Sahip aksiyonu ve mağaza beyanı, koddan üretilemez |
| Hesap silme | [`HESAP-SILME-RETENTION-KARARI.md`](HESAP-SILME-RETENTION-KARARI.md) | Ürün sahibinin açık kararı gereken veri/retention politikası |
| Hukuk | [`legal/`](legal/) | Yayınlanabilir Privacy Policy, Terms ve Community Guidelines metinleri |
| Evrensel saat (V3) | [`GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md`](GLOBAL-TIMER-PRESENCE-MULTI-DEVICE-ARCHITECTURE-PLAN.md), [`GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md`](GLOBAL-TIMER-V3-COMPATIBILITY-EVIDENCE.md) | Nihai uygulama planı ve C0 uyumluluk kanıtı; senior review turları git geçmişinde |
| Kaynak-koda bağlı mimari | [`BASARIM-MIMARISI.md`](BASARIM-MIMARISI.md), [`SAAT-MIMARISI.md`](SAAT-MIMARISI.md), [`TEMA-MIMARISI.md`](TEMA-MIMARISI.md), [`TEMA-HIS-KATALOGU.md`](TEMA-HIS-KATALOGU.md), [`CAMPFIRE-R2-TASARIM.md`](CAMPFIRE-R2-TASARIM.md) | Kod yorumları bu dosyalara doğrudan bağlanır; taşıma/silme link kırar |
| Ortam ve migration | [`ORTAM-MIGRATION-YONETISIMI.md`](ORTAM-MIGRATION-YONETISIMI.md), [`recovery/`](recovery/) | Canlı ortamların kanonik durumu ve geri alma yolları |
| Windows | [`WINDOWS-RELEASE-GATE.md`](WINDOWS-RELEASE-GATE.md), [`QA-WINDOWS.md`](QA-WINDOWS.md), [`WINDOWS-VM-QA.md`](WINDOWS-VM-QA.md) | Windows paketleme ve cihaz kabulü için canlı çalışma listesi |
| Cihaz kabulü | [`qa/DEVICE-QA-MATRIX.md`](qa/DEVICE-QA-MATRIX.md) | Samsung/Pixel/Android sürümü ve temel yolculuk kanıtı |
| Aktif RLS doğrulaması | [`features/ANALYTICS-RLS-TEST-PLAN.md`](features/ANALYTICS-RLS-TEST-PLAN.md) | Mağaza kontrol listesi bunu doğrudan kullanır |
| Runbook | [`SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md`](SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md) | Supabase panel adımları, koddan üretilemez |
| Windows dağıtımı | [`../app/windows/DAGITIM.md`](../app/windows/DAGITIM.md) | Windows derleme/paketleme adımları; kod ve CI'dan üretilemez |
| Kamp ateşi asset'leri | [`../references/campfire/TASARIMCI_BRIEF.md`](../references/campfire/TASARIMCI_BRIEF.md), [`../references/campfire/AI_PROMPT_SETI.md`](../references/campfire/AI_PROMPT_SETI.md) | Tasarımcıya/görsel AI'ya verilen teslim sözleşmesi; hayvanlar hâlâ vektör fallback |
| Play yayını | [`play-store/YAYIN-PLANI.md`](play-store/YAYIN-PLANI.md), [`play-store/AAB-YOLU.md`](play-store/AAB-YOLU.md) | Kapalı test için sahip adımları ve AAB üretim/imzalama yolu |
| Saha geri bildirimi | [`qa/V59-FIELD-FEEDBACK.md`](qa/V59-FIELD-FEEDBACK.md) | Sahip cihaz notlarının dosya:satır doğrulamasıyla karşılanmış hâli |

## Temel değişmezler

- "Tamamlandı" demek için otomatik test, gerçek cihaz QA ve ürün kabulü gerekir.
- Flutter + Riverpod + Supabase; repository hem Supabase hem InMemory uygulanır.
- RLS gerçek yetkilendirme katmanıdır. XP ve kritik ilerleme sunucu tarafında,
  idempotent event + append-only ledger ile yönetilir.
- Kullanıcı metni TR + EN (2026-07-26 kararı; DE/AR dosyaları arşiv olarak repoda kalır).
- ✅ Gün sınırı `Europe/Istanbul`'dur ve **kodda uygulanmıştır**:
  `app/lib/core/stats/istanbul_calendar.dart` `tz.getLocation('Europe/Istanbul')`
  kullanır, `session_window.dart` bunu tüketir; sözleşme
  [`recovery/STATS-CONTRACT.md`](recovery/STATS-CONTRACT.md).
  Grup bazlı gün sınırı IANA bölge adıyla çalışır (WP-326).
- 🔴 Sürüm çıkarma sahip onayına bağlıdır (2026-07-26).
- Mağaza artefaktı GitHub APK kurmaz; hesap silme hem uygulama içinden hem webden
  sağlanır; kullanıcı içeriği yüzeyleri raporlama/engelleme/moderasyon olmadan
  production'a çıkmaz.

## Silinmiş belge referansları

Aşağıdaki iki dosya repoda **yoktur**; onlara atıf veren satırlar tarihsel bağlam
olarak duruyor, tıklanabilir bir hedefleri yok. İçerikleri `git log`/`git show` ile
okunur. Atıf veren dosyalar kasten değiştirilmedi (biri uygulanmış migration'dır).

| Atıf veren | Var olmayan hedef |
|---|---|
| `.github/workflows/ci.yml:3` | `docs/BETA-YAYIN-ARIZA-NIHAI-RAPORU-2026-07-23.md` |
| `supabase/migrations/0056_six_tier_economy.sql:9` | `docs/features/BETA-v41-KADEME-XP-KARARLARI.md` |

## Arşiv

Repoda arşiv dizini tutulmaz. Tarihsel plan, adli rapor ve kapanmış WP kartları
`git log`/`git show` ile okunur; hiçbiri güncel karar kaynağı değildir.
