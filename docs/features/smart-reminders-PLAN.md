# WP-153 PLAN — Hatırlatma / akıllı bildirim motoru

**Durum:** ⏳ **ONAY BEKLİYOR**  
**Tarih:** 2026-07-18

## 1. Kapsam

| Tür | Tetik | Not |
|---|---|---|
| Günlük hatırlatma | Kullanıcı saati | local notification |
| Seri koruma | İstanbul günü seconds==0 ve saat > H | opt-in |
| Haftalık özet | Pazar/İstanbul 18:00 | özet metin |

## 2. Teknik (FGS/alarm core’a dokunmadan)

- `flutter_local_notifications` zaten alarm/timer kanallarında — **ayrı channel** `study_reminders`.  
- Zamanlama: zonedSchedule + exact alarm **yalnız kullanıcı açarsa** (mevcut ExactAlarmHelper okunur, değiştirilmez).  
- Alternatif: inexact + WorkManager benzeri (daha az garanti).  
- ⛔ `StudyTimerService` / FGS / widget **dokunulmaz**.

## 3. Veri

- Mevcut `study_reminders` tablosu (migration 0023 civarı) + prefs opt-in.  
- RLS owner-only.

## 4. UI

- Ayarlar → Hatırlatmalar; sessiz saat (notification_preferences).

## 5. Test

- Schedule cancel; opt-out no fire (unit clock mock).

## 6. Onay

1. Exact alarm zorunlu mu?  
2. Seri hatırlatma varsayılan kapalı mı?
