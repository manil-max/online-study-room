# WP-151 PLAN — Onboarding / ilk açılış

**Durum:** ⏳ **ONAY BEKLİYOR**  
**Tarih:** 2026-07-18

## 1. Akış (3–4 adım, atlanabilir)

1. Hoş geldin + kısa değer önerisi  
2. Bildirim izni (Android 13+ POST_NOTIFICATIONS) — red OK  
3. İlk grup: oluştur / koda katıl / atla  
4. Tema veya “ilk sayacı dene” (deep link home timer UI — **native FGS’e yeni API yok**)

Kalıcı: `prefs` `onboarding.completed_v1 = true`.

## 2. İzin sırası

- Bildirim → (alarm exact sonra, Ayarlar’da mevcut clock_widgets) — onboarding’de exact alarm **zorlama**.

## 3. l10n / a11y

- Tüm adımlar ARB; semantics; ≥48dp.

## 4. Test

- Widget: complete / skip sets flag.  
- Reopen: onboarding gösterilmez.

## 5. Onay

1. 3 mü 4 mü adım?  
2. Zorunlu grup mu?
