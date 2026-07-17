# WP-152 PLAN — Kendi verini dışa aktar

**Durum:** ⏳ **ONAY BEKLİYOR**  
**Tarih:** 2026-07-18

## 1. Kapsam (GDPR / Play portability)

JSON (birincil) + opsiyonel CSV sessions:

- profile (display_name, goals, animal)  
- study_sessions (hot window + “tümü” sayfalı)  
- subjects, achievements, xp summary  
- **Hariç:** diğer kullanıcıların mesajları, admin loglar  

## 2. Teknik

- Ayarlar → “Verilerimi dışa aktar”  
- `Share.shareXFiles` / path_provider temp file  
- Supabase: select own only; page 1000 rows  
- In_memory: dump local maps  

## 3. RLS

- Yalnız `auth.uid()`; no service_role client.

## 4. Test

- Export non-empty JSON schema; unauthorized empty.

## 5. Onay

1. JSON only mi CSV de?  
2. Max history (all vs 1 year)?
