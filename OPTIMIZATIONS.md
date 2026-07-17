# OPTIMIZATIONS.md

**Tarih:** 2026-07-17  
**Kapsam:** Düşük/orta risk optimizasyonlar + muhtemel bug taraması + güvenlik notları  
**Kural:** Kod **değiştirilmedi**. Yalnız rapor.

> **Bu sürümden çıkarılanlar (bilerek):** materialize group stats, Drift/SQLite migrasyonu, chat stream mimarisi rewrite, mobil lazy-tab refaktörü, presence redesign, süre hard-cap ürün kararı gerektiren agresif S1 “hemen uygula” yamaları, cron/secret “force” olmadan production kırma riski taşıyan derin işler.  
> Bunlar bozma ihtimali yüksek / büyük refactor; buraya yazılmıyor.

---

## 1) Optimization Summary

**Sağlık:** Küçük grup için yeterli. N1 debounce, N2 90g hot window, N3 `dailyTotalsProvider`, N5 create/join RPC **zaten kodda**.

**Top 3 (düşük bozma riski, makul ROI):**
1. **R3** — `watchMembers` içinde `firstWhere` → `Map` (davranış aynı, crash yüzeyi azalır)
2. **R9** — `userStudySummaryProvider` her session stream tick’inde RPC atmasın (debounce / mutation-only)
3. **R12** — aktif `group_members(group_id) WHERE left_at IS NULL` index (yalnız ekleme)

**Yapılmazsa en büyük pratik risk:** Büyük mimari değil; **muhtemel buglar (B1–B5)** ve **e-posta kuyruk retry (B2)** kullanıcı/işlev tarafında daha çok acıtır.

---

## 2) Findings — güvenli / düşük risk optimizasyonlar

### R3 — `watchMembers` O(n·m) eşleştirme
- **Category:** Algorithm  
- **Severity:** Low–Medium  
- **Impact:** Üyelik değişiminde CPU; `firstWhere` eşleşmezse crash riski (bkz. B3)  
- **Evidence:** `app/lib/data/repositories/supabase/supabase_group_repository.dart` `watchMembers` — profil başına `rows.firstWhere(...)`  
- **Recommended fix:** Bir kez `Map<userId, row>`; `orElse` ile güvenli fallback  
- **Tradeoffs:** Yok (aynı semantik)  
- **Expected impact:** Küçük; doğru eşleştirme + StateError koruması  
- **Removal Safety:** Likely Safe  
- **Reuse Scope:** module  

### R9 — `userStudySummaryProvider` gereksiz yeniden fetch
- **Category:** Network  
- **Severity:** Low  
- **Impact:** `user_study_summary` RPC spam  
- **Evidence:** `study_providers.dart` — `ref.watch(userSessionsProvider)` her stream emit’te FutureProvider’ı düşürür  
- **Recommended fix:** Debounce 1–2s **veya** yalnız add/update/delete sonrası invalidate  
- **Tradeoffs:** Özet 1–2 sn bayat kalabilir  
- **Expected impact:** Düşük–orta RPC azalması  
- **Removal Safety:** Likely Safe (kısa bayatlık kabulüyle)  
- **Reuse Scope:** module  

### R11 — Ölü `watchGroupSessions`
- **Category:** Dead Code  
- **Severity:** Low  
- **Evidence:** Interface + 3 impl; supabase boş stream; UI çağıran yok  
- **Recommended fix:** Grep + test sonrası sil veya `UnsupportedError`  
- **Removal Safety:** Needs Verification (grep)  
- **Classification:** Dead Code  

### R12 — Aktif üye partial index
- **Category:** DB  
- **Severity:** Low  
- **Evidence:** `group_daily_totals` / RLS helper’lar `left_at is null` filtreler; partial index yok  
- **Recommended fix:**  
  `create index concurrently if not exists idx_group_members_active on public.group_members (group_id) where left_at is null;`  
- **Tradeoffs:** Disk; semantik yok  
- **Removal Safety:** Safe  
- **Reuse Scope:** service-wide  

### R8 (dar) — Görünmeyen ekranda yüksek frekanslı ticker
- **Category:** Frontend  
- **Severity:** Low  
- **Evidence:** Stopwatch 50ms, alarm 200ms; Windows audit: mobil IndexedStack sekmeleri canlı  
- **Recommended fix (dar):** Yalnız `isRunning && mounted/visible` iken yüksek frekans; idle’da iptal (büyük lazy-tab yok)  
- **Tradeoffs:** Yanlış visibility gate → sayaç donmuş görünür  
- **Removal Safety:** Needs Verification  
- **Reuse Scope:** local widgets  

### R13 — Admin Edge Function ortak auth
- **Category:** Maintainability  
- **Severity:** Low  
- **Evidence:** `admin-operations` / `admin-user-actions` kopya auth bloğu  
- **Recommended fix:** `_shared/auth.ts`  
- **Classification:** Reuse Opportunity  
- **Removal Safety:** Likely Safe (davranış aynı tutulursa)  

### Bilgi notu (yüksek risk fix yok)
- `watchGroupDailyStats` hâlâ tablo-geneli realtime + debounce’lu full RPC (`supabase_study_repository.dart`). Küçük grupta genelde OK. **Materialize/trigger önerisi bu raporda yok** (büyük risk).  
- Offline cache SharedPreferences JSON: pro hedef Drift; **migrasyon önerisi yok** (büyük risk).

---

## 3) Quick Wins

1. R3 Map + `orElse` (B3 ile birleşik)  
2. R12 partial index  
3. R11 ölü API temizliği (testli)  
4. R9 summary debounce  
5. R8: stopwatch ticker yalnız running iken  

---

## 4) Deeper Optimizations

Bu sürümde **bilerek boş / erteledi**. Büyük refactor listesi ayrı ürün kararı ister.

---

## 5) Validation Plan (düşük risk maddeler)

| Madde | Doğrulama |
|---|---|
| R3 | Üye listesi aynı; soft-left üye `isActive=false`; eksik profile crash yok |
| R9 | Session ekle → summary en geç ~2s güncellenir; RPC sayısı düşer |
| R11 | `flutter analyze` + test; referans kalmadı |
| R12 | `EXPLAIN` group_daily_totals / membership sorguları |
| R8 | Kronometre çalışırken akıcı; durunca timer iptal |

Genel: `flutter analyze`, `flutter test`, ilgili widget testleri.

---

## 6) Optimized snippets (uygulanmadı)

### R3 + B3

```dart
final byUser = {
  for (final r in rows) r['user_id'] as String: r,
};
return profs.map<Profile>((pMap) {
  final p = Profile.fromMap(pMap);
  final row = byUser[p.id];
  return p.copyWith(isActive: row == null ? false : row['left_at'] == null);
}).toList();
```

### R9 (özet)

```dart
// userSessionsProvider watch'ını kaldır;
// addSession/update/delete sonrası:
// ref.invalidate(userStudySummaryProvider);
```

### R12

```sql
create index concurrently if not exists idx_group_members_active
  on public.group_members (group_id)
  where left_at is null;
```

---

# 7) Muhtemel bug taraması

Kod okuma ile; runtime reproduce yok. Etiket: **Likely** = yol net, **Possible** = senaryo varsayımlı.

### B1 — XP / başarım oturum bitince gecikebilir veya hiç tetiklenmeyebilir (Likely)
- **Severity:** Medium (ürün)  
- **Evidence:** `gamificationProgressSyncProvider` (`gamification_providers.dart`) `session_completed` fırlatır ama **yalnız** şu yerler `watch` eder:  
  - `features/profile/widgets/gamification_card.dart`  
  - `features/profile/social_profile_screen.dart`  
- **Why:** Provider `autoDispose`. Kullanıcı çalışmayı bitirip profil/vitrin açmazsa RPC `process_achievement_event` çalışmaz; XP/taç sunucuda oturuma bağlı metrik olsa da **ledger’a yazılmaz** ta ki biri bu provider’ı izleyene kadar.  
- **Impact:** Saat XP (50/saat), streak başarıları, confetti gecikir veya “neden XP yok?”  
- **Suggested fix (ileride):** Home shell veya timer `stop` / `_recordSession` sonrası tek sefer `process(eventType: 'session_completed')`; autoDispose’a bağlı kalma.  
- **Confidence:** High (call-site grep net)

### B2 — Aylık e-posta job `failed` olduktan sonra asla yeniden denenmez (Likely)
- **Severity:** Medium (ops / özellik)  
- **Evidence:** `send-report/index.ts`: hata → `status = failed` (retry_count &lt; 3) veya `abandoned`. Seçim: `.eq('status', 'pending')` only.  
- **Why:** İlk hata sonrası job `failed`; bir sonraki cron/send yalnızca `pending` alır → **retry_count anlamsız**.  
- **Impact:** Geçici Resend/API hatasında o ayın raporu kalıcı kaçabilir.  
- **Suggested fix:** `status in ('pending','failed') and retry_count < 3` veya failed’i tekrar `pending` yap.  
- **Confidence:** High  

### B3 — `watchMembers` `firstWhere` StateError (Possible → Likely under race)
- **Severity:** Medium (crash)  
- **Evidence:** `supabase_group_repository.dart` — profile listesi ile `group_members` satırları eşleşmezse `firstWhere` fırlatır (`orElse` yok).  
- **Why:** Realtime ara durum, silinmiş profil, veya `inFilter` / stream sıralama tutarsızlığı.  
- **Impact:** Sınıf üyeleri stream’i hata; kamp ateşi / sınıf ekranı error state.  
- **Suggested fix:** R3 Map + null-safe `isActive`.  
- **Confidence:** Medium–High  

### B4 — Manuel oturum gün sınırı cihaz saati; ürün kuralı Europe/Istanbul (Likely TZ bug)
- **Severity:** Medium (istatistik gün kayması)  
- **Evidence:**  
  - `manual_session_dialog.dart` `manualSessionRange` → `DateTime(date.year, month, day, now.hour, now.minute)` (**local**)  
  - `StudySession.toMap` → `start.toIso8601String()` / `end` (**UTC Z yoksa local string**)  
  - Ürün kuralı: `istanbulDay` / `Europe/Istanbul` (`istanbul_calendar.dart`, DB `group_daily_totals`)  
- **Why:** Cihaz TZ ≠ Istanbul veya local ISO parse farkı → oturum **yanlış takvim gününe** düşebilir (özellikle gece 00:00 civarı).  
- **Impact:** “Bugün” toplamı, streak, heatmap kayması.  
- **Suggested fix:** Manuel aralığı `istanbul` wall-clock ile kur; DB’ye **UTC** (`toUtc().toIso8601String()`) yaz.  
- **Confidence:** High (kod yolu net; şiddet kullanıcı TZ’sine bağlı)

### B5 — `user_study_summary` RPC yoksa lifetime/year **hot window ile şişirilir / eksik kalır** (Likely fallback bug)
- **Severity:** Low–Medium  
- **Evidence:** `supabase_study_repository.dart` `fetchUserStudySummary` — RPC catch sonrası:  
  `lifetimeSeconds: hotSec`, `yearSeconds` hot içinden — yani 0031 deploy edilmemişse UI “tüm zamanlar” aslında ~90g.  
- **Impact:** Yanıltıcı ömür boyu / yıl sayıları.  
- **Suggested fix:** Fallback’te lifetime’ı göstermeyin veya “özet yüklenemedi”; migration 0031 prod’da zorunlu.  
- **Confidence:** High  

### B6 — Offline `addSession`: remote fail olunca queue; remote success ama UI hata yutulması (Possible)
- **Severity:** Low  
- **Evidence:** `OfflineFirstStudyRepository.addSession` — cache önce yazılır; remote fail → outbox. `catch (_)` boş — kullanıcıya hata yok (bilinçli offline-first).  
- **Why:** Ağ “başarısız görünüp sonra yazılmış” veya tersi edge; outbox coalesce var (iyi).  
- **Impact:** Nadir double-feeling; upsert `onConflict: id` çift insert’i yumuşatır.  
- **Confidence:** Low–Medium (tasarım tercihi; asıl bug değil)

### B7 — `regenerateInviteCode` / bazı update’ler 0 satırda sessiz başarı (Possible)
- **Severity:** Low–Medium  
- **Evidence:** `groups.update({'invite_code': code}).eq('id', groupId)` — PostgREST çoğu kurulumda 0 row’da exception atmaz. RLS admin değilse kod “yenilendi” sanılır, DB aynı kalır.  
- **Suggested fix:** `.select().single()` veya count kontrolü.  
- **Confidence:** Medium  

### B8 — Cron migration localhost URL (Likely misconfig, app bug değil)
- **Severity:** Medium (feature dead)  
- **Evidence:** `0030_monthly_report_infrastructure.sql` → `http://localhost:54321/functions/v1/collect-reports`  
- **Impact:** Prod’da aylık collector hiç tetiklenmez (pg_cron + net.http_post).  
- **Confidence:** High  

### B9 — `send-report` / `collect-reports` zayıf auth (güvenlik; bug değil exploit)
- Bkz. §8 S2. Fonksiyon public ise spam; değilse düşük.

### B10 — Achievement sync her session stream emit’te RPC (perf + olası rate)
- **Severity:** Low  
- **Evidence:** `gamificationProgressSyncProvider` `await ref.watch(userSessionsProvider.future)` sonra her değişimde `process_achievement_event`.  
- **Why:** Idempotent (event_key) ama gereksiz DB CPU; profil kartı açıkken chatty.  
- **Suggested fix:** Debounce; yalnız net session count/sum değişince.  
- **Confidence:** Medium  

### B11 — `todayRecordedSecondsProvider` `DateTime.now()` local day vs Istanbul (Possible edge)
- **Severity:** Low  
- **Evidence:** `dayOf(DateTime.now())` aslında `istanbulDay` — **OK**.  
- **Not:** B4 manuel yazım ile tutarsızlık asıl risk; provider tarafı Istanbul’a hizalı.  
- **Confidence:** N/A (false positive check)

### B12 — Presence heartbeat hata yutma (by design)
- **Severity:** Info  
- **Evidence:** `catchError((_) {})` — presence düşer, timer sürer.  
- **Impact:** “Çalışıyor görünmüyor” şikayeti; timer kaybı yok.  

---

## 8) Güvenlik notları (uygulama yok — farkındalık)

Büyük “hemen kes” yamaları bu raporda **fixinmiyor**; sadece kayıt:

| ID | Konu | Severity | Not |
|---|---|---|---|
| S1 | Client `study_sessions` insert + zayıf süre bound | High (abuse) | UI 23h; API daha uzun yazabilir → XP/sıralama. Düzeltme **ürün max süre** ister |
| S2 | Report Edge Functions: Authorization varlığı yeterli + service_role env | Critical if public | Cron secret ile düzelt; **önce cron job’u güncelle** yoksa mail ölür |
| S3 | `get_user_monthly_stats` DEFINER + authenticated | High IDOR | Self/admin guard SQL |
| S4 | `profiles_select using (true)` hâlâ | Medium | Enumerasyon; UI bağımlılığı taransın |

Secrets (`env.json`, keystore): gitignore’da; `git ls-files` ile izlenmiyor (doğrulandı).

---

## 9) Öncelik matrisi (bu raporun kapsamı)

| Öncelik | ID | Tip | Bozma riski |
|---|---|---|---|
| 1 | B1 | Bug | Düşük (ek tetik; mevcut UI bozmaz) |
| 2 | B2 | Bug | Düşük (sorgu genişletme) |
| 3 | B3 + R3 | Bug+opt | Çok düşük |
| 4 | B4 | Bug | Orta (TZ; test şart) |
| 5 | B5 / 0031 deploy | Bug/ops | Düşük |
| 6 | B8 | Ops | Ops-only |
| 7 | R9, R12, R11 | Opt | Düşük |
| 8 | S2/S3 | Security | S2: ops sırası kritik |

---

## 10) Assumptions

- Prod’da migration 0012–0033’ün hepsi uygulanmış olmayabilir → B5/B8 şiddeti ortama bağlı.  
- Edge Function public invoke varsayımı S2 için; dashboard kilidi doğrulanmadı.  
- Hiçbir runtime test bu turda koşturulmadı.

---

*Sonuç: Büyük riskli optimizasyonlar listeden çıkarıldı. Asıl “ bozmadan düzeltmeye değer” paket: **B1, B2, B3/R3, B4, R9, R12**. Kod değişikliği yapılmadı.*
