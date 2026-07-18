# beta-v33 — Cihaz test listesi (güncel özellikler)

| Alan | Değer |
|---|---|
| Tag / build | `beta-v33` · **1.0.33+33** |
| Kanal | GitHub **beta** (prerelease APK) |
| Tarih | 2026-07-18 |
| Eski listeler | `BETA-v32-TEST.md` → **bu dosyaya yönlendirir** |
| Kaynak WP | WP-190–193 (cihaz turu-2) + WP-194 (yayın hazırlığı) |

> Her madde: **Önkoşul → Adım → Beklenen → ☐**.  
> Yalnız **MEVCUT** özellikler.

---

## 0. ÖN KOŞUL

### 0.1 Canlı SQL (proje `jiphfrpzvkpzubbkhrwb`)

**Önkoşul:** Supabase Dashboard → proje ref **`jiphfrpzvkpzubbkhrwb`**  
(`env.json` `SUPABASE_URL` = `https://jiphfrpzvkpzubbkhrwb.supabase.co` — **aynı proje**).

**Adım:** Aşağıdakiler uygulanmış mı doğrula (yoksa SQL Editor’da çalıştır):
- `0039` / `0040` / `0041` — grup/kişisel analitik RPC (`start_time`)
- `0044_feedback_ensure.sql` — feedback tablo/policy/bucket
- **`0045_feedback_reload.sql`** — ensure + `NOTIFY pgrst, 'reload schema'`

**Beklenen:** Hata yok; feedback insert mümkün; PostgREST önbellek güncel.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 0.2 beta-v33 kur + giriş kalıcı

**Önkoşul:** 0.1.

**Adım:** beta-v33 APK (`1.0.33+33`) kur → bilinen hesapla giriş → kill/reopen.

**Beklenen:** Launcher **Odak Kampı BETA**; oturum kalıcı; sürüm/build **1.0.33 / 33**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 1. FEEDBACK

**Önkoşul:** 0.1 (0045) + 0.2 authenticated.  
Referans: `docs/qa/WP-193-FEEDBACK-DERIN.md`

### 1.1 Düz öneri

**Adım:** Ayarlar → Geri bildirim → öneri + mesaj → Gönder.

**Beklenen:** Başarı snackbar; `feedback_tickets` satırı DB’de; “sunucu hazır değil” **YOK**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.2 Patlarsa Detay kodu

**Adım:** Hata olursa snackbar’ı oku.

**Beklenen:** Net mesaj + **`Detay: <code> <message>`** satırı görünür (ör. `PGRST205`, `42P01`, `42501`).  
**Sahip:** Detay satırını buraya yaz: ________

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 2. İSTATİSTİK BAŞLIĞI (WP-190)

**Önkoşul:** 0.2.

### 2.1 Tek yatay satır (Kişisel)

**Adım:** İstatistikler → Kişisel; üst çubuğa bak; dar ekranda kaydır.

**Beklenen:**
- Dönem chip’leri **TEK yatay satır** (Bugün/Hafta/Ay/Yıl/Tümü/Özel)
- **Kötü satır kırılması / Wrap yok** — sığmazsa **yatay kaydırılabilir**
- Kıyas: satır **sonunda** kompakt `compare_arrows` toggle (ayrı tam satır yok)
- Seçili chip primary stil; Özel → date range picker

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 2.2 Grup aynı

**Adım:** İstatistikler → Grup; aynı üst çubuk.

**Beklenen:** Personal ile aynı tek satır + kompakt kıyas.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 3. GRUP İSTATİSTİĞİ (WP-191 + 0039–0041)

**Önkoşul:** Üye olduğun grup + 0.1 RPC.

### 3.1 Sıralama en üstte + gauge

**Adım:** İstatistikler → Grup; yukarıdan aşağı kaydır.

**Beklenen:**
- **Sıralama (leaderboard) en üstte** (gauge/donut’tan önce)
- Hedef **gauge** kartında **ölü boş alan yok** (altında % / süre özeti)
- Katkı **donut** + liderlik **zaman serisi**
- Crash yok

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 3.2 Non-üye (opsiyonel)

**Adım:** Üye olunmayan grup bağlamı.

**Beklenen:** Empty/yetkisiz; crash yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 4. PROFİL (WP-192)

**Önkoşul:** 0.2.

**Adım:** Profil → başarımlar kartı.

**Beklenen:**
- **Gerçek taç:** pp etrafında **renkli halka** + **üstte taç** (madalya ikonu değil)
- **Taç XP çubuğu** (“Sonraki taç” / progress; level bar değil)
- **YOK:** Level N, Quest, day streak, streak freezes, total saat yığını
- **VAR:** başarım rozetleri

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 5. ANA EKRAN IZGARA

**Önkoşul:** 0.2.

**Adım:** Ayarlar’da density ara; Home’da yeni kart ekle.

**Beklenen:** Density seçici **yok**; herkes **32**; eklenen widget **kullanışlı boyutta** (minnacık değil); sürükle-bırak çalışır.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 6. GÖREVLER KARTI

**Önkoşul:** 0.2.

**Adım:** Home → kart ekle → **Görevler** → madde ekle → tikle; Günlük/Haftalık sekmeler.

**Beklenen:** Tik + üstü çizme; kalıcı (kill/reopen); günlük/haftalık ayrı; dönem sıfırlama Europe/Istanbul mantığı; XP yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 7. DİL (ar / de / tr)

**Önkoşul:** 0.2.

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 7.1 | Dil → Arapça; Ana/Stats/Profil | **Gerçek Arapça** + RTL | ☐ |
| 7.2 | Dil → Almanca | **Gerçek Almanca** | ☐ |
| 7.3 | Dil → Türkçe | TR geri gelir | ☐ |

---

## 8. WIDGET / BİLDİRİM / SSOT (WP-134–137 — yalnız cihaz)

> Kod değiştirme; gözlem.

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 8.1 | Sayaç başlat → widget | Canlı süre | ☐ |
| 8.2 | Bildirim mola/durdur | Engine uyumu | ☐ |
| 8.3 | Kill sonrası | SSOT; çift kayıt yok | ☐ |

---

## 9. DUMAN

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 9.1 | Açık / koyu tema | Sabit gri sızıntı yok | ☐ |
| 9.2 | textScale ~1.3 | Kritik taşma yok | ☐ |
| 9.3 | Airplane mode kısa | Crash yok; anlaşılır hata | ☐ |

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
| `docs/qa/WP-193-FEEDBACK-DERIN.md` | Feedback Detay + SQL teşhis |
| `docs/qa/WP-184-FEEDBACK-CACHE.md` | 0045 NOTIFY |
| `docs/qa/BETA-v32-TEST.md` | Eski — **v33’e yönlendirir** |
