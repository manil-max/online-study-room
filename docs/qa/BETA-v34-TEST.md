# beta-v34 — Cihaz test listesi (güncel özellikler)

| Alan | Değer |
|---|---|
| Tag / build | `beta-v34` · **1.0.34+34** |
| Kanal | GitHub **beta** (prerelease APK) |
| Tarih | 2026-07-18 |
| Eski listeler | `BETA-v33-TEST.md` → **bu dosyaya yönlendirir** |
| Kaynak WP | WP-196–200 (Görevler deadline) + WP-195 (trigger/taç) + WP-201 |

> Her madde: **Önkoşul → Adım → Beklenen → ☐**.  
> Yalnız **MEVCUT** özellikler.

---

## 0. ÖN KOŞUL

### 0.1 beta-v34 kur + giriş kalıcı

**Önkoşul:** APK `1.0.34+34`.

**Adım:** Kur → bilinen hesapla giriş → kill/reopen.

**Beklenen:** Launcher **Odak Kampı BETA**; oturum kalıcı; sürüm/build **1.0.34 / 34**.  
(Tüm SQL — 0039–0041, 0044–0046 — zaten uygulanmış kabul; feedback çalışıyor.)

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 1. GÖREVLER (YENİ) — WP-196–200

**Önkoşul:** 0.1.

### 1.1 Araçlar sekmesi + Görevler alt-sekme

**Adım:** Alt-nav’da eski “Saat” yerine **Araçlar** (el aleti ikonu) aç; üst şeritte **Görevler**’e bas.

**Beklenen:** Araçlar açılır; alt-sekmeler: Saat · Alarm · Timer · Krono · Dünya · **Görevler**; varsayılan hâlâ Saat.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.2 Ekle — tarih ve kalan süre

**Adım:** Görevler → + → serbest metin.  
(a) Bir görev **tarih seç** (bugün/yarın).  
(b) Ayrı bir görev **kalan süre** (saat) ile ekle.  
(c) İsteğe bağlı: süresiz görev.

**Beklenen:** İkisi de eklenir; tarih → o gün sonu (Istanbul); süre → şimdi+süre.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.3 Sıra + renk + gecikti

**Adım:** Yakın ve uzak bitişli görevler ekle; birini geçmişe düşür (veya kısa süre bekle).

**Beklenen:**
- En **yakın bitiş üstte**; **süresiz en altta**
- Renk: uzak sakin → yaklaşınca sarı/turuncu/kırmızı
- Geçmiş: **"Gecikti"** + koyu kırmızı (silinmez)

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.4 Düzenle / sil / işaretle / tamamlananlar

**Adım:** Düzenle → kaydet; sil; tikle; “Tamamlananlar” sekmesine bak.

**Beklenen:** CRUD çalışır; tamamlanan aktif listeden düşer; Tamamlananlar’da üstü çizili.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.5 Home “Görevler” kartı

**Adım:** Ana Sayfa → kart ekle → Görevler.

**Beklenen:** Renkli aktif liste + tik; **ekleme YOK** (+ yok); sığmazsa **“+N daha”**; taşma yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 2. FEEDBACK

**Önkoşul:** 0.1; 0046 canlıda.

**Adım:** Ayarlar → Geri bildirim → öneri → Gönder.

**Beklenen:** Başarı snackbar; `feedback_tickets` satırı; 42704/role yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 3. PROFİL

**Önkoşul:** 0.1.

**Adım:** Profil → başarımlar kartı.

**Beklenen:** Gerçek taç (renkli halka + taç, **biraz büyük**) + taç XP çubuğu; level/quest/streak yığını yok; **rozetler var**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 4. İSTATİSTİK

**Önkoşul:** 0.1.

### 4.1 Dönem tek satır

**Adım:** İstatistikler → kişisel/grup üst çubuk.

**Beklenen:** Dönem chip’leri **tek yatay satır** (kaydırılabilir); kıyas satır sonu kompakt.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 4.2 Grup sıralama + gauge

**Adım:** İstatistikler → Grup.

**Beklenen:** **Sıralama en üstte**; gauge kartında ölü boş alan yok; donut/seri çalışır.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 5. ANA EKRAN IZGARA

**Önkoşul:** 0.1.

**Adım:** Ayarlar density; Home’a widget ekle.

**Beklenen:** Density seçici **yok**; herkes **32**; eklenen widget makul boyutta.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 6. DİL

**Önkoşul:** 0.1.

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 6.1 | Arapça | Gerçek Arapça + RTL | ☐ |
| 6.2 | Almanca | Gerçek Almanca | ☐ |
| 6.3 | Türkçe | TR geri | ☐ |

---

## 7. WIDGET / BİLDİRİM / SSOT (WP-134–137 — yalnız cihaz)

> Kod değiştirme.

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 7.1 | Sayaç → widget | Canlı süre | ☐ |
| 7.2 | Bildirim mola/durdur | Engine uyumu | ☐ |
| 7.3 | Kill sonrası | SSOT; çift kayıt yok | ☐ |

---

## 8. DUMAN

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 8.1 | Açık / koyu tema | Sabit gri sızıntı yok | ☐ |
| 8.2 | textScale ~1.3 | Kritik taşma yok | ☐ |
| 8.3 | Airplane mode | Crash yok | ☐ |

---

## İmza

| | |
|---|---|
| Genel | ☐ **GO** · ☐ **GO with notes** · ☐ **NO-GO** |
| Cihaz / Android | |
| Blokerler | |
| İmza / tarih | |

---

## Referans

| Dosya | Not |
|---|---|
| `docs/features/GOREVLER-DEADLINE-PLAN.md` | Görevler tasarımı |
| `docs/qa/WP-193-FEEDBACK-DERIN.md` | Feedback 42704 / 0046 |
| `docs/qa/BETA-v33-TEST.md` | Eski — **v34’e yönlendirir** |
