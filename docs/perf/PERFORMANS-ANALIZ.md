# WP-142 — Performans & başlangıç profili analizi

**Tarih:** 2026-07-18 · **Tür:** araştırma (ürün kodu yok) · **Kanıt:** dosya okuma

## 1. Özet

Soğuk açılış Android’de **seri `await` zinciri** + birçok **StreamProvider** aboneliği + büyük `home_screen` ile yük taşır. İlk kare Windows’ta bilinçli geciktirilir; Android’de init bitmeden UI yok.

## 2. `main()` init zinciri (`app/lib/main.dart`)

| Adım | Satır (yaklaşık) | Risk |
|---|---|---|
| `WidgetsFlutterBinding.ensureInitialized` | 32 | zorun |
| Windows `ErrorWidget` / `FlutterError` | 40–59 | yalnızca Windows |
| Android: `TimerNotificationService.initialize` + HomeWidget callback | 66–68 | I/O; plugin |
| `initDesktopWindow` | 72 | Windows |
| **Supabase.initialize** (await) | 76–81 | ağ/DNS; soğuk açılışın en pahalı parçası olabilir |
| **SharedPreferences.getInstance** | 85 | disk |
| **ObservabilityService.initialize** | 86 | Sentry init (DSN varsa) |
| DeviceTimezone + AlarmNotificationService | 89–96 | plugin |
| Android NativeAlarmBridge reschedule | 97–102 | prefs + AlarmManager |
| `runApp(ProviderScope…)` | 105–110 | |
| Windows: first frame → `showDesktopWindowWhenReady` | 113–116 | beyaz HWND önlemi |

**Ölçüm önerisi:** her `await` öncesi/sonrası `Timeline`/`Stopwatch` (yalnız profile build). Hedef: `main` toplam p50/p95; Supabase init ayrı satır.

## 3. Provider / realtime ağı

Aktif `StreamProvider` örnekleri (`app/lib/data/providers/**`):

- `authStateProvider`, `userSessionsProvider`, `groupDailyStatsProvider`
- `userGroupsProvider`, `groupMembersProvider`, `groupPresenceProvider`
- `classMessagesProvider`, `userSubjectsProvider`
- `gamificationProfile` / `userAchievements` (family)
- `receivedNudgesProvider`

**Supabase Realtime:** `supabase_study_repository.dart` channel `.subscribe()` (oturum + grup stats).  
**Risk:** home shell açılınca birden fazla stream + channel → CPU/jank ve bellek; grup değişince yeniden abone.

## 4. UI ağır yüzeyler

| Yüzey | Gözlem | Dosya |
|---|---|---|
| `home_screen.dart` | ~1100 satır; dashboard + kartlar | rebuild maliyeti yüksek |
| `grid_reflow` | matris yeniden akış | `core/…/grid_reflow` + home |
| fl_chart stats | paint maliyeti | `features/stats/**` |
| Campfire sahne | animasyon + üye listesi | `classroom/widgets/campfire*` |
| Avatar/network image | cache yoksa jank | çeşitli |

**const kaçakları / watch:** home ve classroom’da çoklu `ref.watch` aynı frame’de — ayrıntılı sayım profile run ile yapılmalı; statik tahmin: gereksiz üst-widget watch.

## 5. Ölçüm planı (cihaz)

```bash
cd app
flutter run --profile --dart-define-from-file=env.json -d <device>
# DevTools: CPU / Memory / Performance
# Timeline: main→first frame; scroll home; open stats; start/stop UI (FGS native ayrı)
```

| Metrik | Nasıl | Hedef (öneri) |
|---|---|---|
| Cold start → first useful frame | Timeline | p95 &lt; 2.5s mid-range |
| Home scroll jank | Performance overlay | &lt; few dropped frames / 5s |
| Peak RSS after 2 min | Memory | trend; leak = rising realtime channels |

## 6. Öncelikli iyileştirme WP önerileri (WP-156+)

| Öneri | Risk | Kazanç | Not |
|---|---|---|---|
| **WP-156** Supabase init defer / splash paralel | Orta | Soğuk açılış | Offline-first uyumu |
| **WP-157** Stream abonelik birleştir / lazy tab subscribe | Orta | Bellek + jank | Presence/session |
| **WP-158** home_screen parçala + select/watch daralt | Düşük | Rebuild | const/kart izolasyonu |
| **WP-159** chart lazy load (sekme görünürken) | Düşük | İlk paint | |
| **WP-160** image cache / avatar decode | Düşük | jank | |

⛔ Timer FGS/widget bu analizin ölçümünde **ayrı** tutulmalı (WP-134–137 donmuş).

## 7. Kanıt etiketleri

- Init zinciri, provider listesi: **Kodda doğrulandı**
- Süre/ms hedefleri: **Cihazda doğrulanmalı** (`--profile`)
