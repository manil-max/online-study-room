# WP-149 PLAN — Çalışma serisi (streak) + takvim/heatmap

**Durum:** ↪ **WP-156 kart kataloğuna bağlandı** (`streakHeatmap`) — uygulama 156 faz planında  
**Üst plan:** [`ISTATISTIK-GRUPLAR-ANALITIK-PLAN.md`](./ISTATISTIK-GRUPLAR-ANALITIK-PLAN.md)  
**Tarih:** 2026-07-18

## 1. Ürün

- Günlük streak (bugün çalıştı mı), en uzun seri, son 7/30/365 gün heatmap.
- Dashboard kartı + Stats sekmesi.
- Gün sınırı: **Europe/Istanbul** (`istanbulDay`).

## 2. Veri modeli (öneri)

| Seçenek | Artı | Eksi |
|---|---|---|
| A) Mevcut `study_sessions` + client aggregate | Migration yok | Büyük history maliyeti |
| B) `user_study_day` özet tablosu (server) | Hızlı, authoritative | Migration + backfill |
| **Öneri: B** | | |

```sql
-- taslak
user_study_day (
  user_id uuid, day date, -- Istanbul calendar date
  seconds int not null,
  primary key (user_id, day)
)
-- RLS: select/insert/update own; write via DEFINER on session insert
```

## 3. RLS / server

- Trigger veya `process_achievement_event` benzeri: session yazılınca day seconds upsert.
- Streak hesabı: ardışık `day` satırları seconds > 0.

## 4. Repository çift

- `StudyStatsRepository.watchStreak(userId)` / `watchHeatmap(range)`
- in_memory: sessions’tan türet; supabase: table/RPC.

## 5. UI / l10n / tema

- Kart: “Seri: N gün”, heatmap grid (colorScheme.primary alpha scale).
- ARB: streak titles, empty “Bugün henüz yok”.
- Erişilebilir: her hücre Semantics “tarih, süre”.

## 6. Test planı

- Unit: gap in days breaks streak; midnight Istanbul.
- Widget: empty/loading/error.
- ⛔ Timer FGS dokunulmaz.

## 7. Risk

- Backfill historical sessions (batch job).
- Privacy: heatmap only self (default).

## 8. Onay soruları

1. Veri modeli A mı B mi?  
2. Grup streak var mı? (öneri: yok, v2)
