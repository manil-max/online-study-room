# Windows performans taraması (2026-07-14)

## Ölçüm özeti

| Ortam | Working Set (tipik) | Not |
|---|---|---|
| **Debug** `flutter run` | 450–600+ MB | VM, asserts, DevTools — ürün ölçümü değil |
| **Release** idle (oturum açık) | ~300–410 MB | Bu oturumda örnek |
| WP-70 eski taban | ~86 MB p95 | Farklı oturum/soğuk koşu; karşılaştırırken dikkat |

**Sonuç:** “550 MB” büyük ölçüde **debug**. Release de hâlâ yüksek; asıl kasma kaynakları aşağıda.

## Yapıldı (bu tur + önceki)

| Fix | Etki |
|---|---|
| Android `home_widget` Windows no-op | Exception fırtınası / async jank kesildi |
| Device integration Windows skip | Aynı |
| Sayaç idle ticker kapalı | Boşta saniyelik rebuild yok |
| Alarm FLN init Windows skip | Start-up hata + gereksiz iş yok |
| **N1 debounce** group daily stats (~900 ms) | Realtime RPC thrash azalır |
| **N3** `dailyTotalsProvider` paylaşımı | Çoklu O(n) tarama → 1 |
| **Desktop lazy tabs** | İlk açılışta 5 sekme değil 1; TickerMode offstage |

## Hâlâ açık (öncelik)

### P0 — Sınırsız `watchUserSessions` (OPT N2)
- **Kanıt:** `supabase_study_repository.dart` limit yok; tüm geçmiş RAM’de.
- **Etki:** Bellek + her realtime güncellemede decode + provider zinciri.
- **Öneri:** Son 90–365 gün stream; geçmiş sayfalı. Ürün onayı gerekir.

### P1 — IndexedStack mobilde hâlâ 5 ekran
- Desktop tembel; **mobil** IndexedStack aynı.
- Stats fl_chart + campfire + clock tickers yüklü kalabilir.

### P1 — `DesktopProportionalScale` (FittedBox fill)
- Tüm kabuk ölçekleniyor; resize’da maliyetli olabilir.
- Kabul: esnek UI. İyileştirme: yalnız density/token scale.

### P2 — OPT N4 grup stream O(n·m)
- Üyelik değişiminde ekstra round-trip + firstWhere.

### P2 — Presence heartbeat + group presence periodic
- Çalışırken heartbeat OK; idle’da ucuz ama stream dinleyicileri ayakta.

### P3 — fl_chart tooltip RangeError
- Stats’ta hover jank/exception (ayrı bug).

## Ne yapılmalı (önerilen sıra)

1. ~~Windows Android plugin / idle tick / alarm~~ ✅  
2. ~~N1 debounce + N3 totals + desktop lazy tabs~~ ✅  
3. **N2 session limit** (ürün: kaç gün?)  
4. Mobil lazy stack (istersen desktop ile aynı)  
5. İkinci makinede `scripts/windows_performance_baseline.ps1` release

## Kullanıcı komutu

Hazır ölçüm script’in varsa at; yoksa:

```bat
cd app
flutter build windows --release --dart-define-from-file=env.json
powershell -File ..\scripts\windows_performance_baseline.ps1 -Runs 3 -IdleSeconds 30
```
