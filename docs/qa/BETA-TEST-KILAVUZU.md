# Beta test kılavuzu (sahip — adım adım)

> **Kanonik güncel liste: [`BETA-v32-TEST.md`](./BETA-v32-TEST.md)** (1.0.32+32).  
> Bu dosya ek bağlam içindir; ızgara/toggle maddeleri **silindi** — v32 listesini kullan.  
> Tarih: 2026-07-18 · Kaynak: `progress.md` + WP-134–137 / 184–188 / 189.

| Meta | |
|---|---|
| Cihaz | ________ (ör. Samsung A… / Android __) |
| Build | beta-v__ / versionCode __ |
| Testçi | ________ |
| Tarih | ________ |

---

## 0. ÖN KOŞUL (migration + build)

### 0.1 SQL Editor — 0039–0043

**Önkoşul:** Canlıda 0038+; sahip 0039–0043 uyguladıysa ✓.

**Adımlar:** Eksikse sırayla `0039`…`0043` SQL Editor. Not: 0039/40 `start_time` kullanır.

**Beklenen:** RPC’ler hata vermeden create; `get_user_day_totals` vb. hazır (WP-175’te klasik ekrana bağlanacak).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 0.2 Beta APK yükle ve giriş

**Adımlar:** beta build yükle → giriş → cold start.

**Beklenen:** Ana sayfa; InMemory düşmez.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 0.3 Analytics beta toggle YOK (WP-170)

**Adımlar:** Ayarlar’da “Yeni istatistik ekranı (Beta)” aranmaz / yoktur.

**Beklenen:** Toggle yok; İstatistikler her zaman klasik.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 1. Klasik + zengin istatistikler (WP-170 / 178–180)

### 1.1 Kişisel ListView

**Adımlar:** İstatistikler → Kişisel; kaydır (uzun ekran).

**Beklenen:**
- Dönem: Bugün/Hafta/Ay/**Yıl**/Tümü/**Özel** + kıyas switch
- Gauge hedef, area trend, radar, katlı scatter, detaylı geçmiş
- **Izgara/sürükle yok**

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.2 Grup ClassStatsView

**Adımlar:** İstatistikler → Grup (üyeyken / non-üye).

**Beklenen:** Gauge + üye katkı donut + liderlik serisi + sıralama; non-üye empty/crash yok; ham session yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 2. Gruplar sekmesi kaydırma (WP-172) + Home

### 2.1 Gruplar scroll

**Adımlar:** Gruplar; hedef/sıralama/trend kartı **üzerinden** parmakla kaydır.

**Beklenen:** Nested scroll yutmaz; akıcı dikey kaydırma.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 2.2 Home dashboard

**Adımlar:** Ana Sayfa düzenle → kart sürükle.

**Beklenen:** Sürükle-bırak **hâlâ çalışır** (WP-170–175 dokunmadı).

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

### 4.1 Seviye eğrisi + görevler + kozmetik + başlık (WP-171)

**Önkoşul:** 0042 (+ tercihen 0043); XP’li hesap.

**Adımlar:**
1. Profil’de seviye / görevler / çerçeve.
2. **Başarımlar** başlığı: uzun taç / textScale — **dikey harf dizilimi olmamalı** (WP-171).

**Beklenen:** Seviye türetilmiş; başlık yatay; istemci XP yazmaz.

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
