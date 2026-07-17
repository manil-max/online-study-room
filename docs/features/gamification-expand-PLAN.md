# WP-154 PLAN — Gamification genişletme

**Durum:** ⏳ **ONAY BEKLİYOR**  
**Tarih:** 2026-07-18

## 1. Kapsam

- Level: XP → level eğrisi (ör. `level = floor(sqrt(xp/50))+1` — **ürün kararı**)  
- Yeni rozet kademeleri (dict migration)  
- Günlük/haftalık görevler (login streak görev ≠ study streak)  
- Kozmetik: avatar frame / tema kilidi (`profiles.cosmetics jsonb`)

## 2. Server-authoritative

- Tüm XP `xp_ledger` + `process_achievement_event` DEFINER.  
- Level **türetilmiş** (client display only) veya ledger event `level_up`.  
- Mevcut XP bozulmadan: salt okunur level map.

## 3. Migration taslak

- `achievements_dict` yeni satırlar  
- `user_quests` (optional)  
- cosmetics columns  

## 4. RLS

- Self read cosmetics; write DEFINER only.

## 5. UI

- Profile level bar; quest list; lock icons.

## 6. Test

- Level curve unit; award idempotent.

## 7. Onay

1. Level formülü?  
2. Kozmetik ücretli mi (Play) — **varsayılan ücretsiz unlock**?
