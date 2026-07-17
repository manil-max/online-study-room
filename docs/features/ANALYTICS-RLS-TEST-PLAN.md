# WP-164 — Analitik RPC RLS test planı

## Kapsam
Migration `0042_fix_study_sessions_start_time.sql` + `0040`/`0041` fonksiyonları:
- `get_user_day_totals(p_from, p_to)`
- `group_contribution_breakdown(p_group_id, p_from, p_to)`
- `group_leaderboard_series(p_group_id, p_from, p_to)`

## Şema doğrulaması
- `study_sessions` zaman kolonu: **`start_time`** (0001_initial_schema).
- 0042: `CREATE OR REPLACE` ile `s.start` → `s.start_time`.

## İki hesap senaryosu

### Hesap A (üye)
1. Grup G’ye katıl.
2. A ve B için G aralığında oturum üret.
3. `get_user_day_totals`: yalnız **A’nın** gün toplamları; B’nin saniyeleri yok.
4. `group_contribution_breakdown(G, …)`: A+B aggregate; **ham session id yok**.
5. `group_leaderboard_series(G, …)`: day×user_id×seconds; ham satır yok.

### Hesap B (üye)
1. Aynı G için 4–5 ile simetrik sonuç (kendi self totals farklı).

### Hesap C (non-üye)
1. G’ye üye değil.
2. `group_contribution_breakdown(G, …)` → `42501 not authorized`.
3. `group_leaderboard_series(G, …)` → `42501`.
4. `get_user_day_totals` → yalnız C’nin kendi oturumları (boş olabilir).

## Otomasyon (InMemory)
`app/test/features/stats/analytics_delivery_test.dart`:
- contribution + series seed → doğru aggregate sıralama
- day totals long range (hot window dışı)

## Canlı SQL Editor dumanı (manuel)
```sql
-- auth.uid() = A iken
select * from get_user_day_totals(current_date - 30, current_date);
select * from group_contribution_breakdown('<group_uuid>', current_date - 14, current_date);
select * from group_leaderboard_series('<group_uuid>', current_date - 14, current_date);
-- non-member JWT ile aynı group çağrısı → hata
```

## Cihazda doğrulanmalı
- Flag `analytics_grid_v1=true`: ızgara, sürükle-bırak, boyut, dönem/kıyas, üye donut, liderlik geçmişi.
- Flag `false`: eski Personal/Class stats + StatsPeriodBar birebir.
