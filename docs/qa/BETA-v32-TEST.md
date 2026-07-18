# beta-v32 — Cihaz test listesi (güncel özellikler)

| Alan | Değer |
|---|---|
| Tag / build | `beta-v32` · **1.0.32+32** |
| Kanal | GitHub **beta** (prerelease APK) |
| Tarih | 2026-07-18 |
| Eski listeler | `BETA-v31-TEST.md` → **bu dosyaya yönlendirir**; v30 grid maddeleri **geçersiz** |
| Kaynak WP | WP-184–188 (cihaz turu) + WP-189 (yayın hazırlığı) |

> Her madde: **Önkoşul → Adım → Beklenen → ☐**.  
> Yalnız **MEVCUT** özellikler. Silinen: analytics ızgara toggle, density seçici (6/8/12/16), profil level/quest/streak/freeze/total UI.

---

## 0. ÖN KOŞUL

### 0.1 Canlı SQL (proje `jiphfrpzvkpzubbkhrwb`)

**Önkoşul:** Supabase Dashboard → proje ref **`jiphfrpzvkpzubbkhrwb`**  
(`env.json` `SUPABASE_URL` = `https://jiphfrpzvkpzubbkhrwb.supabase.co` — **aynı proje**).

**Adım:** Aşağıdakiler uygulanmış mı doğrula (yoksa SQL Editor’da çalıştır):
- `0039` / `0040` / `0041` — grup/kişisel analitik RPC (`start_time`)
- `0044_feedback_ensure.sql` — feedback tablo/policy/bucket
- **`0045_feedback_reload.sql`** — ensure tekrarı + **`NOTIFY pgrst, 'reload schema'`**

**Beklenen:** Hata yok; `get_user_day_totals` / contribution / leaderboard çağrılabilir; feedback insert policy var; PostgREST şema önbelleği yenilenmiş.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 0.2 beta-v32 kur + giriş kalıcı

**Önkoşul:** 0.1.

**Adım:** beta-v32 APK (`1.0.32+32`) kur → bilinen hesapla giriş → uygulamayı kill/reopen.

**Beklenen:** Launcher **Odak Kampı BETA**; oturum kalıcı (InMemory’ye düşmez); sürüm/build 1.0.32 / 32.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 1. FEEDBACK (0045 sonrası)

**Önkoşul:** 0.1 (özellikle **0045**) + 0.2 authenticated.

### 1.1 Düz öneri

**Adım:** Ayarlar → Geri bildirim → öneri + mesaj → Gönder.

**Beklenen:** Başarı snackbar; `feedback_tickets` satırı DB’de; **“Geri bildirim sunucusu henüz hazır değil” / schema_missing YOK**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.2 Ekli görsel (opsiyonel)

**Adım:** Ekran görüntüsü ekle → gönder.

**Beklenen:** Ticket + `attachment_path` / storage (bucket var).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.3 Oturum geçersiz

**Adım:** Oturumu düşür / expire sonrası gönder (mümkünse).

**Beklenen:** **Net** oturum mesajı (jenerik “gönderilemedi” değil).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

**Referans:** `docs/qa/WP-184-FEEDBACK-CACHE.md`, `docs/qa/WP-177-FEEDBACK-KAPANIS.md`

---

## 2. İSTATİSTİK başlığı (declutter)

**Önkoşul:** 0.2.

### 2.1 Tek satır dönem + kompakt kıyas (Kişisel)

**Adım:** İstatistikler → Kişisel; üst çubuğa bak.

**Beklenen:**
- **Today / Week / Month / Year / All / Custom** aynı Wrap’te (6 chip)
- Kıyas: tam satır SwitchListTile **değil** — **kompakt icon-toggle** (`compare_arrows` / benzeri)
- Üst blok belirgin **küçük** (eski tam-genişlik switch satırı yok)
- Dönem değiştirince grafikler güncellenir; özel aralık date picker

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 2.2 Grup sekmesi aynı başlık

**Adım:** İstatistikler → Grup; aynı üst çubuk.

**Beklenen:** Personal ile aynı dönem + kompakt kıyas davranışı.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 2.3 textScale 1.3

**Adım:** Sistem metin ölçeği ~1.3; stats başlığı.

**Beklenen:** Taşma / dikey harf dizilimi yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 3. ANA EKRAN IZGARA (sabit 32)

**Önkoşul:** 0.2.

### 3.1 Density seçici yok

**Adım:** Ayarlar’ı aç; ızgara yoğunluğu / 6 / 8 / 12 / 16 arat.

**Beklenen:** **Density seçici YOK**; “Izgara yoğunluğu” dropdown yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 3.2 Herkes 32 + yeni widget boyutu

**Adım:** Ana Sayfa → düzenle → **yeni bir kart ekle** (ör. Bugün özeti veya Görevler).

**Beklenen:** Izgara 32 sütun mantığı; eklenen kart **minnacık değil** — kullanışlı w×h; sürükle-bırak bozulmaz.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 4. PROFİL (sade)

**Önkoşul:** 0.2.

**Adım:** Profil → başarımlar / oyunlaştırma kartı; textScale ~1.3.

**Beklenen:**
- **YOK:** seviye çubuğu, “Level N”, XP metni, Quest bölümü, “N day streak”, “streak freezes”, total saat + alt yazı
- **VAR:** başarım **rozetleri** (vitrin / showcase); karta dokununca sosyal profil / katalog erişimi makul
- Başlık yatay tek satır

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 5. GÖREVLER KARTI (Home)

**Önkoşul:** 0.2.

### 5.1 Ekle + tik + üstü çizme

**Adım:** Ana Sayfa → kart ekle → **Görevler** → madde ekle → tikle → geri al.

**Beklenen:** Kart eklenebilir; tamamlanınca **üstü çizili + tik**; geri alınabilir; boş durum metni; 48dp dokunma.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 5.2 Günlük / haftalık + sıfırlama

**Adım:** Günlük ve Haftalık sekmelerde ayrı maddeler ekle.  
(İsteğe bağlı) Cihaz tarihini ileri al veya ertesi gün / Pazartesi sabahı tekrar aç.

**Beklenen:**
- Günlük ve haftalık listeler **ayrı**
- **Günlük** yeni günde boş/sıfır (periodKey `d:YYYY-MM-DD`, **Europe/Istanbul**)
- **Haftalık** hafta başında (Pazartesi) sıfır (periodKey `w:…`)
- Kalıcılık: kill/reopen aynı dönemde maddeler durur
- XP ödülü **yok** (v1)

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 6. GRUP İSTATİSTİĞİ (0039–0041)

**Önkoşul:** Üye olduğun grup + 0.1 RPC; mümkünse non-üye ikinci hesap.

### 6.1 Üye

**Adım:** İstatistikler → Grup.

**Beklenen:** Grup toplam + **gauge**; üye katkı **donut**; liderlik listesi; liderlik **zaman serisi**; trend / heat. Crash yok; ham session sızmaz.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 6.2 Non-üye

**Adım:** Üye olunmayan grup bağlamında grup kartlarını dene.

**Beklenen:** Yetkisiz / empty; **crash yok**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 7. DİL (ar / de / tr)

**Önkoşul:** 0.2.

### 7.1 Arapça + RTL

**Adım:** Dil → Arapça; Ana / Stats / Ayarlar / Görevler kartı gez.

**Beklenen:** RTL hizalama; metin **gerçek Arapça** (çekirdek UI); tamamen İngilizce kalmamalı.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 7.2 Almanca

**Adım:** Dil → Almanca; stats etiketleri + Görevler + feedback.

**Beklenen:** **Gerçek Almanca**; crash yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 7.3 Türkçe dönüş

**Adım:** Dil → Türkçe.

**Beklenen:** TR metinler geri gelir.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 8. WIDGET / BİLDİRİM / SSOT (WP-134–137 — yalnız cihaz)

> Kod değiştirme; gözlem. 🔴 Bu turda timer/widget/FGS koduna dokunulmadı.

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 8.1 | Sayaç başlat → ana ekran widget | Canlı süre (Chronometer) | ☐ |
| 8.2 | Bildirim başlat / mola / durdur | Aksiyonlar engine ile uyumlu | ☐ |
| 8.3 | Kill sonrası bildirim/widget/app | SSOT uyumu; çift kayıt yok | ☐ |

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
| `docs/qa/WP-184-FEEDBACK-CACHE.md` | 0045 + sahip SQL (aynı proje) |
| `docs/qa/WP-177-FEEDBACK-KAPANIS.md` | 0044 ensure |
| `docs/features/GOREV-KART-PLAN-v2.md` | Görevler kartı planı |
| `docs/qa/BETA-v31-TEST.md` | Eski — **v32’ye yönlendirir** |
| `docs/qa/BETA-v30-ONAY-LISTESI.md` | Grid maddeleri geçersiz |
