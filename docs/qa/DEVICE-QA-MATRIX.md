# Cihaz QA matrisi (tek sayfa)

> Fiziksel cihaz kanıtı olmadan **kapatma**. Her satır için: tarih · cihaz · sonuç · not.

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
| A3 | Yıl / özel aralık | true | Hot window dışı veri (0042 RPC) | ⬜ |
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
