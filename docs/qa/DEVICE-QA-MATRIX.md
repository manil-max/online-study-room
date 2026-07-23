# Cihaz QA matrisi (tek sayfa)

> Fiziksel cihaz kanıtı olmadan **kapatma**. Her satır için: tarih · cihaz · sonuç · not.

## Cihaz kabul adayı (kalıcı politika)

Android cihaz QA'sı GitHub prerelease beta APK'sıyla yapılır. Önce mevcut adayın tag/SHA/migration head/APK SHA-256 değeri doğrulanır; aday güncel değilse yeni benzersiz beta tag'i ve prerelease normal preflight sonrasında çıkarılır. Bu akış için yeniden ürün onayı sorulmaz. Stable/production/Store yayını bu politikaya dahil değildir ve ayrı GO gerektirir.

## A. Timer / widget / FGS (WP-134–137) — DONUK

| # | Senaryo | Beklenen | Sonuç | Kanıt |
|---|---|---|---|---|
| T1 | Sayaç başlat → FGS bildirim | Chronometer canlı; Flutter saniyede rebuild yok | ⬜ | |
| T2 | Uygulama kill + bildirimden dön | Süre sapması ≤ ±1 sn / 8 sa | ⬜ | |
| T3 | Widget bugün süresi | Olay bazlı güncelleme; 15 dk poll garanti değil | ⬜ | |
| T4 | Stop → session yazımı | UI ≤ 1 sn; XP server event | ⬜ | |
| T5 | Exact alarm / izin red | Graceful; crash yok | ⬜ | |

⛔ Refactor yok; bug çıkarsa **ayrı debug WP**.

## B. Analitik (WP-157–164)

| # | Senaryo | Flag | Sonuç | Kanıt |
|---|---|---|---|---|
| A1 | Stats eski ekran | false | PeriodBar 4 segment; ListView | ⬜ |
| A2 | Izgara düzenle sürükle | true | Reflow; overlap yok; id sabit | ⬜ |
| A3 | Yıl / özel aralık | true | Hot window dışı veri (0041 RPC) | ⬜ |
| A4 | Kıyas toggle | true | Toplam/delta değişir | ⬜ |
| A5 | Üye donut / liderlik history | true | RPC; grup üyesi olmayan hata | ⬜ |
| A6 | TalkBack 48dp | true | Düzenle/ekle etiketleri | ⬜ |

## C. Onboarding / export / hatırlatma / gamification / dil

| # | WP | Senaryo | Sonuç | Kanıt |
|---|---|---|---|---|
| C1 | 151 | Skip → bir daha gösterilmez | ⬜ | |
| C2 | 151 | Bildirim red → devam | ⬜ | |
| C3 | 152 | Export JSON paylaş | ⬜ | |
| C4 | 153 | Seri hatırlatma opt-in | ⬜ | |
| C5 | 154 | Seviye/quest görünür | ⬜ | |
| C6 | 155 | AR RTL layout | ⬜ | |
| C7 | 155 | DE dil seçimi | ⬜ | |

## D. Play pre-launch (WP-123)

Ayrıntı: `docs/play-store/` ve `docs/play/OWNER-ACTION-CHECKLIST.md`.

## E. beta-v4307 push/timer kabulü (WP-271)

> Aday kimliği: `beta-v4307` · `1.0.43-beta.7+4307` · staging head `0070`.
> Backend ön kabulü tamamdır; aşağıdaki satırlar fiziksel Android cihazda doldurulur.

| # | Senaryo | Beklenen | Sonuç | Kanıt |
|---|---|---|---|---|
| P1 | Bildirim Sağlığı → remote self-test, foreground | Tek bildirim; UI `sent`; duplicate 0 | ⬜ | |
| P2 | Remote self-test, background | Tek bildirim ≤10 sn; doğru hesap/cihaz | ⬜ | |
| P3 | Remote self-test, process terminated | Bildirim görünür; dokununca doğru ekran açılır | ⬜ | |
| P4 | Ağ kes → self-test → ağı aç | Otomatik retry ile teslim; ikinci kullanıcı eylemi gerekmez | ⬜ | |
| P5 | Sayaç Başlat/Duraklat/Durdur | v43 paneli; aksiyonlar uygulama kapalıyken çalışır | ⬜ | |
| P6 | 20 ölçümlü remote self-test | duplicate=0; yanlış hedef=0; p95≤10 sn | ⬜ | |
| P7 | Timer `59:55` → `1:00:05`, dar ve geniş One UI görünümü | Alt-saatte `MM:SS`; bir saatten itibaren `H:MM:SS`; kesilmiş/çift saat öneki yok | ⬜ | |

> **Gözlem, 2026-07-23:** Kullanıcı foreground/background/normal kapatma ve ağ kes→aç smoke'unda teslimin işlevsel olduğunu; sık self-testte cooldown bilgisinin göründüğünü bildirdi. Ölçüm sayısı, duplicate ve p95 kanıtı kaydedilmediği için P1–P7 ve C1–C3 satırları bilinçli olarak açık bırakılmıştır.

### beta-v4308 cooldown tanı tekrarı (WP-284)

> Bu adayın backend/migration değişikliği yoktur; yalnız kullanıcıya görünen hata sınıflandırmasını düzeltir.

| # | Senaryo | Beklenen | Sonuç | Kanıt |
|---|---|---|---|---|
| C1 | Remote self-test'i ikinci kez 20 sn dolmadan başlat | Teslim timeout'u değil, 20 sn bekleme bilgisi; yeni outbox isteği yok | ⬜ | |
| C2 | Aynı kişiye ikinci dürtmeyi 10 dk dolmadan gönder | Genel hata değil, 10 dakikalık kural görünür; ikinci dürtme oluşmaz | ⬜ | |
| C3 | Cooldown bittikten sonra remote self-test/dürtme | Normal başarılı yol değişmeden çalışır | ⬜ | |
