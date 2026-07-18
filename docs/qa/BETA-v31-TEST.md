# beta-v31 — Cihaz test listesi (güncel özellikler)

| Alan | Değer |
|---|---|
| Tag / build | `beta-v31` · **1.0.31+31** |
| Kanal | GitHub **beta** (prerelease APK) |
| Tarih | 2026-07-18 |
| Eski listeler | `BETA-v30-ONAY-LISTESI.md` / grid maddeleri **geçersiz** (ızgara silindi) |

> Her madde: **Önkoşul → Adım → Beklenen → ☐**.  
> Silinen özellik yok: sürükle-ızgara, Ayarlar “Yeni istatistik (Beta)” toggle, 22-kart edit.

---

## 0. Kurulum

### 0.1 SQL önkoşul (canlı)

**Önkoşul:** Supabase SQL Editor erişimi.

**Adım:** Şunlar uygulanmış mı doğrula (yoksa çalıştır):
- `0039` / `0040` / `0041` — grup/kişisel analitik RPC (`start_time`)
- `0044_feedback_ensure.sql` — feedback tablo/policy/bucket

**Beklenen:** Hata yok; `get_user_day_totals` / contribution / leaderboard çağrılabilir; feedback insert policy var.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 0.2 APK kur + giriş

**Önkoşul:** 0.1.

**Adım:** beta-v31 APK kur → bilinen hesapla giriş → uygulamayı kill/reopen.

**Beklenen:** Launcher **Odak Kampı BETA**; oturum kalıcı (InMemory’ye düşmez).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 1. İstatistik — klasik + sabit bölümler (toggle YOK)

**Önkoşul:** 0.2; Ayarlar’da analytics beta anahtarı **yok**.

### 1.1 Kişisel bölümler

**Adım:** İstatistikler → Kişisel; uzun listeyi kaydır.

**Beklenen (sırayla görünür / empty state OK):**
- Özet şerit (toplam, ortalama, hafta içi/sonu, dönem kartları)
- Area trend + bar (günlük dağılım)
- Ders donut
- Saatlik aktivite
- Hedef **gauge**
- Streak / heatmap
- Haftalık ritim
- Rekorlar
- Scatter (**varsayılan katlı** — açılınca grafik)
- Detaylı geçmiş (uzun aralık / RPC)
- **Radar** (basit skorlar)

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.2 Dönem çubuğu

**Adım:** Bugün / Hafta / Ay / **Yıl** / Tümü / **Özel** dene; “önceki dönemle kıyas” aç/kapa.

**Beklenen:** Seçim grafikleri günceller; özel aralık date picker; kıyas şeridi (veri varsa); **ızgara/edit yok**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 1.3 Kaydırma

**Adım:** Bölümlerin **üzerinden** parmakla kaydır.

**Beklenen:** Jest yakalanmaz; akıcı dikey scroll.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 2. Grup istatistiği

**Önkoşul:** Üye olduğun grup + (mümkünse) non-üye ikinci hesap; 0.1 RPC.

### 2.1 Üye

**Adım:** İstatistikler → Grup.

**Beklenen:** Grup toplam + **gauge**; üye katkı **donut (açık)**; liderlik listesi; liderlik **zaman serisi**; trend; heat table. Crash yok; ham session sızmaz.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 2.2 Non-üye

**Adım:** Üye olunmayan grup bağlamında (veya gruptan çıkınca) grup kartlarını dene.

**Beklenen:** Yetkisiz / empty; **crash yok**.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 3. Feedback (0044 sonrası)

**Önkoşul:** 0.1 (0044); authenticated oturum.

### 3.1 Düz öneri

**Adım:** Ayarlar → Geri bildirim → öneri + mesaj → Gönder.

**Beklenen:** Başarı snackbar; `feedback_tickets` satırı DB’de.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 3.2 Ekli görsel

**Adım:** Ekran görüntüsü ekle → gönder.

**Beklenen:** Ticket + `attachment_path` / storage (bucket var).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 3.3 Oturum geçersiz

**Adım:** Oturumu düşür / expire sonrası gönder (mümkünse).

**Beklenen:** **Net** oturum mesajı (jenerik “gönderilemedi” değil).

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 4. Başarımlar kartı (profil)

**Önkoşul:** 0.2.

**Adım:** Profil → başarımlar kartı; textScale ~1.3 (erişilebilirlik).

**Beklenen:** Başlık **yatay tek satır** (dikey harf yok); Level/Crown chip’ler taşmadan; 48dp makul.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 5. Gruplar sekmesi kaydırma

**Önkoşul:** Aktif grup.

**Adım:** Gruplar; hedef / sıralama / trend **üzerinden** kaydır.

**Beklenen:** Nested scroll yutmaz; her yerden akıcı dikey kaydırma.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 6. Dil (ar / de / tr)

**Önkoşul:** 0.2.

### 6.1 Arapça + RTL

**Adım:** Dil → Arapça; Ana / Stats / Ayarlar gez.

**Beklenen:** RTL hizalama; metin **gerçek Arapça** (en az çekirdek UI); tamamen İngilizce kalmamalı. (AR residual uzun metinler olabilir — not et.)

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 6.2 Almanca

**Adım:** Dil → Almanca; geri bildirim / stats etiketleri.

**Beklenen:** Almanca metinler; crash yok.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

### 6.3 Türkçe dönüş

**Adım:** Dil → Türkçe.

**Beklenen:** TR metinler geri gelir.

**Sonuç:** ☐ Geçti / ☐ Kaldı · not: ________

---

## 7. Widget / bildirim / SSOT (WP-134–137 — yalnız cihaz)

> Kod değiştirme; gözlem.

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 7.1 | Sayaç başlat → ana ekran widget | Canlı süre (Chronometer) | ☐ |
| 7.2 | Bildirim başlat / mola / durdur | Aksiyonlar engine ile uyumlu | ☐ |
| 7.3 | Kill sonrası bildirim/widget/app | SSOT uyumu; çift kayıt yok | ☐ |

---

## 8. Duman

| # | Adım | Beklenen | Sonuç |
|---|---|---|---|
| 8.1 | Açık / koyu tema | Sabit gri sızıntı yok | ☐ |
| 8.2 | textScale ~1.3 | Kritik taşma yok | ☐ |
| 8.3 | Airplane mode kısa | Crash yok; anlaşılır hata | ☐ |

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
| `docs/qa/WP-177-FEEDBACK-KAPANIS.md` | 0044 SQL |
| `docs/features/ISTATISTIK-ZENGINLESTIRME-PLAN.md` | Stats plan |
| `docs/qa/BETA-v30-ONAY-LISTESI.md` | **Eski** — grid maddeleri geçersiz; v31 kullan |
