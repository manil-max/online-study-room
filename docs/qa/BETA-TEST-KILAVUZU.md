# Beta test kılavuzu (sahip — adım adım)

> Tek dosya ile bekleyen **cihaz** işlerini dolaş. Her madde: **Önkoşul → Adımlar → Beklenen → ☐ Geçti/Kaldı**.  
> Tarih: 2026-07-18 · Kaynak: `progress.md` `[~] Cihazda doğrulanmalı` + WP-134–137 / 151–166 / 168.

| Meta | |
|---|---|
| Cihaz | ________ (ör. Samsung A… / Android __) |
| Build | beta-v__ / versionCode __ |
| Testçi | ________ |
| Tarih | ________ |

---

## 0. ÖN KOŞUL (migration + beta bayrağı)

### 0.1 SQL Editor — 0039–0043 uygula

**Önkoşul:** Canlı/staging’de en az **0038** uygulanmış olmalı. **0039–0043 bu repoda henüz uygulanmadı varsayımı** (ADIM 0 renumber; eski 0040–44 adları yok).

**Adımlar:**
1. Supabase Dashboard → SQL Editor.
2. Sırayla dosya içeriğini çalıştır (her biri sonrası hata yok):
   - `supabase/migrations/0039_user_day_totals_rpc.sql`
   - `supabase/migrations/0040_group_contribution_breakdown.sql`
   - `supabase/migrations/0041_fix_study_sessions_start_time.sql` (start_time CREATE OR REPLACE)
   - `supabase/migrations/0042_gamification_expand.sql` (cosmetics + dict)
   - `supabase/migrations/0043_guard_cosmetics_write.sql` (cosmetics write guard)
3. Opsiyonel RLS dumanı: `docs/features/ANALYTICS-RLS-TEST-PLAN.md`.

**Beklenen:** Hata yok; `get_user_day_totals` / `group_contribution_breakdown` / `group_leaderboard_series` çağrılabilir (üye hesapla).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 0.2 Beta APK/AAB yükle ve giriş

**Önkoşul:** 0.1 tamam; test hesabı authenticated.

**Adımlar:**
1. Beta build yükle (Play internal veya local release).
2. Bilinen hesapla giriş yap; cold start sonrası oturum kalıcı olsun.

**Beklenen:** Ana sayfa açılır; “giriş yok” / InMemory’ye düşmez (`env.json`/flavor doğru).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 0.3 Ayarlar → Yeni istatistik ekranı (Beta) AÇ

**Önkoşul:** 0.2.

**Adımlar:**
1. Profil → Ayarlar.
2. **“Yeni istatistik ekranı (Beta)”** anahtarını **AÇ**.
3. Alt sekmelerden **İstatistikler**’e git.

**Beklenen:** Eski ListView yerine ızgara; kapatınca eski StatsPeriodBar + ListView birebir.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 1. Analitik ızgara (WP-157–164)

### 1.1 22 kart render

**Önkoşul:** 0.3 açık; kişisel sekme.

**Adımlar:**
1. İstatistikler → Kişisel.
2. Kartları kaydır; boş/placeholder “yakında” metni olmamalı (yasaklı placeholder kartları yok).

**Beklenen:** Varsayılan layout’ta kartlar gerçek veri veya boş durum UI ile çizilir; crash yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.2 Kart ekle / çıkar / boyutlandır

**Önkoşul:** 1.1.

**Adımlar:**
1. Düzenle moduna gir.
2. Bir kart ekle → bir kart sil → bir kartı genişlet/daralt.
3. Düzenlemeyi bitir; uygulamayı kill → yeniden aç → İstatistikler.

**Beklenen:** Layout kalıcı (prefs); overlap yok; kart kimlikleri bozulmaz.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.3 Dönem seçici + kıyas

**Önkoşul:** 0.1 (yıl aralığı RPC), 0.3.

**Adımlar:**
1. Dönem: bugün / hafta / ay / **yıl** / **özel** dene.
2. “Geçen döneme göre” (kıyas) toggle’ı aç/kapa.
3. Yıl veya özel aralıkta toplamların 90g hot window dışı da dolabildiğini gözle (veri varsa).

**Beklenen:** Dönem değişince kartlar güncellenir; kıyas açıkken delta/karşılaştırma görünür; hata snackbar spam yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.4 Flag kapalı regresyon

**Önkoşul:** —

**Adımlar:**
1. Ayarlar → Beta anahtarını **KAPA**.
2. İstatistikler’e dön.

**Beklenen:** Eski PersonalStatsView + ClassStatsView + StatsPeriodBar (4 segment) birebir.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 2. Grup analitiği (WP-161 + 0039/0040/0041)

### 2.1 Grup kartları (üye)

**Önkoşul:** 0.1; 0.3 açık; en az bir gruba **üye** hesap + grupta oturum verisi.

**Adımlar:**
1. İstatistikler → Grup (veya ilgili grup yüzeyi).
2. Üye katkı / liderlik / donut benzeri grup kartlarını aç.

**Beklenen:** Aggregate veriler gelir; **ham session satırı / başka kullanıcının private detayı yok**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 2.2 Non-üye reddi

**Önkoşul:** Grup G’ye üye **olmayan** ikinci hesap (veya gruptan çık).

**Adımlar:**
1. Aynı grup için katkı/liderlik kartını tetikle (mümkünse).

**Beklenen:** Yetkisiz / boş / hata durumu; app crash yok. (SQL: `42501 not authorized` — `ANALYTICS-RLS-TEST-PLAN.md`)

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 3. WP-155 — Dil + RTL

### 3.1 Arapça + RTL

**Önkoşul:** Ayarlar dil seçici.

**Adımlar:**
1. Dil → Arapça.
2. Ana sayfa, İstatistikler, Ayarlar’ı gez.
3. Geri → Türkçe veya sistem.

**Beklenen:** Metinler görünür (baseline EN olabilir); **RTL hizalama** (ok yönü, chevron, padding); layout taşması yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 3.2 Almanca

**Önkoşul:** —

**Adımlar:**
1. Dil → Almanca.
2. Ana menü + Ayarlar + geri bildirim diyaloğu etiketleri.

**Beklenen:** Dil değişir; crash yok; Türkçe’ye dönüş OK.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 4. WP-166 / 151–154 paketi

### 4.1 Seviye eğrisi + görevler + kozmetik

**Önkoşul:** 0042 (+ tercihen 0043) uygulandı; oturumlarla XP birikmiş hesap.

**Adımlar:**
1. Profil’de seviye / görevler / çerçeve alanını aç.
2. Seviye 3 civarı kozmetik “ücretsiz açık” davranışını kontrol et (varsa).

**Beklenen:** Seviye türetilmiş (istemci XP yazmaz); görevler salt okunur; crash yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 4.2 Onboarding (ilk açılış)

**Önkoşul:** Yeni hesap **veya** onboarding prefs sıfırlanmış hesap.

**Adımlar:**
1. İlk giriş → onboarding 4 adım.
2. Bildirim iznini **reddet** → devam.
3. Grup adımını atla veya katıl.
4. Uygulamayı kapat-aç.

**Beklenen:** Onboarding bir daha zorlanmaz; hesap B aynı cihazda onboarding’i tekrar görebilir (per-user bayrak — WP-166).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 4.3 Verilerimi dışa aktar

**Önkoşul:** Girişli; biraz oturum verisi.

**Adımlar:**
1. Ayarlar → Verilerimi dışa aktar.
2. Aralık seç (90g / yıl / tümü) → dışa aktar → paylaşım sheet.

**Beklenen:** JSON üretilir; e-posta/token sızmaz; offline’da anlaşılır hata.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 5. WP-134–137 — Widget / bildirim / SSOT (uzun süredir bekleyen)

> ⛔ Bu bölümde **kod değiştirme**; yalnız gözlem. Bug → ayrı debug WP.

### 5.1 Widget canlı süre (WP-134)

**Önkoşul:** Android ana ekran widget eklenmiş (1×1 ve en az bir büyük boyut).

**Adımlar:**
1. Uygulamada sayacı **başlat**.
2. Ana ekrana dön; widget süresini 30 sn izle.
3. Boyut değiştir (mümkünse).

**Beklenen:** Chronometer canlı akar; Flutter saniyede bir uyanmaz (pil); boyut bozulmaz.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 5.2 Bildirim başlat / durdur (WP-135 + 137)

**Önkoşul:** Bildirim izni açık; FGS görünür.

**Adımlar:**
1. Sayaç başlat → bildirimde süre.
2. Bildirimden **Mola** / **Durdur** (varsa) dene.
3. 10–20 tur start/stop (WP-135).

**Beklenen:** Aksiyonlar engine ile uyumlu; idle’da sıfırlama doğru; crash / çift oturum yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 5.3 SSOT senkron (WP-136)

**Önkoşul:** Widget + bildirim + uygulama açık/kapalı karışık.

**Adımlar:**
1. Uygulamada başlat → kill → bildirimden bak.
2. Widget’tan / bildirimden durdur → uygulamayı aç.

**Beklenen:** Süre ve durum tek kaynak (SSOT); sapma kabaca ±1 sn / makul süre; çift kayıt yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 6. Feedback (WP-168 sonrası)

**Önkoşul:** Authenticated oturum; 0018 (ve ek için 0019) canlıda. Tanı: `docs/qa/WP-168-FEEDBACK-TANI.md`.

### 6.1 Düz öneri (eksiz)

**Adımlar:**
1. Ayarlar → Geri bildirim gönder → Öneri.
2. Konu + mesaj doldur → Gönder.
3. (Admin) ticket listesinde veya SQL `feedback_tickets` son satır.

**Beklenen:** Başarı snackbar; satır DB’de `status=open`, `user_id=auth.uid()`.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 6.2 Ekli görsel

**Önkoşul:** 0019 bucket + storage policy.

**Adımlar:**
1. Aynı diyalog → ekran görüntüsü ekle → gönder.

**Beklenen:** Ticket + `attachment_path`; storage’da `user_id/...` dosya.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 6.3 Oturum düşmüş (negatif)

**Adımlar:**
1. Oturumu düşür / başka cihazdan revoke (mümkünse) veya uzun idle sonrası dene.
2. Gönder.

**Beklenen:** **Net** oturum mesajı (jenerik “gönderilemedi” değil); debug build log’da code.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 7. Hızlı duman (opsiyonel ama önerilir)

| # | Senaryo | Beklenen | Sonuç |
|---|---|---|---|
| 7.1 | Açık/koyu tema | Sabit gri sızıntı yok (WP-141 ruhu) | ☐ |
| 7.2 | textScale ~1.3 | Taşma / kesilme kritik değil | ☐ |
| 7.3 | Airplane mode kısa | Anlaşılır hata; crash yok | ☐ |
| 7.4 | Akıllı hatırlatma opt-in (WP-153) | İzin + sessiz saat makul | ☐ |

---

## 8. Özet imza

| Alan | |
|---|---|
| Genel sonuç | ☐ Beta GO · ☐ GO with notes · ☐ NO-GO |
| Bloker bug’lar | |
| Notlar | |
| İmza / tarih | |

---

## Referanslar

| Dosya | Ne |
|---|---|
| `docs/qa/DEVICE-QA-MATRIX.md` | Kısa matris |
| `docs/qa/WP-168-FEEDBACK-TANI.md` | Feedback SQL / kök neden |
| `docs/features/ANALYTICS-RLS-TEST-PLAN.md` | RPC üye/non-üye |
| `docs/play/OWNER-ACTION-CHECKLIST.md` | Play ops (bu kılavuz dışı) |
| `progress.md` | `[~] Cihazda doğrulanmalı` kartlar |
