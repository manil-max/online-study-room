# Dokümantasyon — tek giriş noktası

Bu dizinde geçmiş plan/draft/ajan notu tutulmaz. Eski bir karar gerekiyorsa Git geçmişine
bakılır; `archive/` yalnız `progress.md` tarafından bağlı tarihsel kanıttır ve **asla güncel
karar kaynağı değildir**.

## Okuma sırası ve yetki

1. Aktif iş, sahiplik ve gerçek durum: [`../progress.md`](../progress.md)
2. Ürün, kalite, güvenlik ve yayın kuralları: [`KALITE-PROGRAMI.md`](KALITE-PROGRAMI.md)
3. Aktif başarımlar/görev/grup işi: [`features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md`](features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md)
4. Çalışma kuralları: [`../.agents/AGENTS.md`](../.agents/AGENTS.md)

Bu dört kaynak dışında bir Markdown dosyası, burada açıkça istisna olarak sayılmadıkça,
ajan için karar veya uyarı üretmez. Kod, migration ve canlı sistem hakkındaki gerçek kaynak
ilgili kaynak koddur; eski doküman değil.

## Kalan gerekli belgeler

| Alan | Belge | Neden ayrı duruyor? |
|---|---|---|
| Play production | [`PLAY-STORE-HAZIRLIK-TARAMASI.md`](PLAY-STORE-HAZIRLIK-TARAMASI.md), [`play/OWNER-ACTION-CHECKLIST.md`](play/OWNER-ACTION-CHECKLIST.md), [`play-store/DATA-SAFETY.md`](play-store/DATA-SAFETY.md), [`play-store/PLAY-RELEASE-GATE.md`](play-store/PLAY-RELEASE-GATE.md) | Sahip aksiyonu ve Play beyanı, koddan üretilemez. Şu an durum **NO-GO**. |
| Hesap silme | [`HESAP-SILME-RETENTION-KARARI.md`](HESAP-SILME-RETENTION-KARARI.md) | Ürün sahibinin açık kararı gereken veri/retention politikası. |
| Hukuk | [`legal/`](legal/) | Yayınlanabilir Privacy Policy, Terms ve Community Guidelines metinleri. |
| Kaynak-koda bağlı mimari | [`BASARIM-MIMARISI.md`](BASARIM-MIMARISI.md), [`SAAT-MIMARISI.md`](SAAT-MIMARISI.md), [`TEMA-MIMARISI.md`](TEMA-MIMARISI.md), [`CAMPFIRE-R2-TASARIM.md`](CAMPFIRE-R2-TASARIM.md) | Kod yorumları bu dosyalara doğrudan bağlanır; taşıma/silme link kırar. |
| Windows | [`WINDOWS-URUN-PLANI.md`](WINDOWS-URUN-PLANI.md), [`WINDOWS-RELEASE-GATE.md`](WINDOWS-RELEASE-GATE.md), [`QA-WINDOWS.md`](QA-WINDOWS.md) | Windows paketleme ve cihaz kabulü için canlı çalışma listesi. |
| Ortak cihaz kabulü | [`qa/DEVICE-QA-MATRIX.md`](qa/DEVICE-QA-MATRIX.md) | Samsung/Pixel/Android sürümü ve temel yolculuk kanıtı. |
| Aktif RLS doğrulaması | [`features/ANALYTICS-RLS-TEST-PLAN.md`](features/ANALYTICS-RLS-TEST-PLAN.md) | Play sahip kontrol listesi bunu doğrudan kullanır. |

## Temel değişmezler

- “Tamamlandı” demek için otomatik test, gerçek cihaz QA ve ürün kabulü gerekir.
- Flutter + Riverpod + Supabase; repository hem Supabase hem InMemory uygulanır.
- RLS gerçek yetkilendirme katmanıdır. XP ve kritik ilerleme sunucu tarafından,
  idempotent event + append-only ledger ile yönetilir.
- Kullanıcı metni Türkçe; gün sınırı `Europe/Istanbul`.
- Stable yayın için migration/staging, tüm testler, Android release build, Samsung cihaz,
  temel yolculuklar, widget/bildirim cold-start, recovery/RLS ve rollback kanıtı zorunludur.
- Play artefaktı GitHub APK kurmaz; hesap silme hem uygulama içinden hem webden sağlanır;
  UGC yüzeyleri raporlama/engelleme/moderasyon olmadan production'a çıkmaz.

## Arşiv

[`archive/`](archive/) yalnız `progress.md`deki tarihsel iş kartları ve V8 kanıtları için
korunur. Yeni bir iş bu dosyalardan claim edilmez; güncel kararla çelişen her ifade geçersizdir.
