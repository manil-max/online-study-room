# WP-188 — Home Görevler kartı (v2 plan + uygulama)

| Alan | Değer |
|---|---|
| Tarih | 2026-07-18 |
| Kaynak | Cihaz turu feedback (günlük/haftalık görev, tik/üstü çizme) |
| Eski plan | `GOREV-LISTESI-KART-PLAN.md` (WP-169) — analytics ızgaraya göreydi |
| **v2 hedef** | Kart **Home dashboard**'a eklenir (`DashboardCardType.tasks`) |
| XP | **v1 yok** (server-authoritative kuralı bozulmasın) |

## Model

```
UserTask { id, title, scope(daily|weekly), completed, createdAt, completedAt?, sortOrder }
periodKey: daily `d:YYYY-MM-DD` | weekly `w:YYYY-MM-DD` (startOfWeek, Istanbul)
```

## Kalıcılık

- Prefs: `user_tasks_v1.<userId|local>.<scope>.<periodKey>` JSON list
- Repo çift: `InMemoryUserTaskRepository` + `SupabaseUserTaskRepository` (v1 = prefs mirror)

## UI

- Home kart: sekmeler Günlük/Haftalık, ekle/sil, tik (üstü çizili), boş durum
- a11y 48dp + Semantics; l10n tr/en/ar/de

## Donuk

Timer / widget / FGS · XP ledger yazımı
