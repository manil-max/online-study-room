# beta-v41 — kullanıcı geri bildirimi, kademe ve XP kararları

> Kaynak: beta-v40 saha testi (kullanıcı 10 bulgu). Bu dosya **karar defteri** —
> WP'lere bölünmeden önce isteklerin ve sayısal kararların tek kaydı. Plan onayı
> ("tamm") sonrası WP'lere bölünecek. XP ödülleri ve taç 6. eşiği **kullanıcıdan
> bekleniyor** (dengesizlik düzeltmesi gelecek).

## 1. Bulgu / istek listesi (beta-v40)

| # | İstek | Tip | Kök neden |
|---|---|---|---|
| 1 | Başarımlar sayfası ~4 sn'de bir yenileniyor, ekran zıplıyor | BUG | `reward_toast.dart:50` `Timer.periodic(4 sn)` → `onRefresh` → tüm provider `invalidate` → rebuild + scroll reset |
| 2 | Kademe renkleri (platin≈elmas). 4→Elmas(mavi), 5→Zümrüt(yeşil), **6→Immortal(kırmızı)** ekle | TASARIM | `progression_visuals.dart:14` yalnız 5 kademe; platin `#67E8F9` ≈ elmas `#38BDF8` |
| 3 | Alpha Wolf kademeleri baştan | TASARIM | `achievement_ledger_engine.dart:131` |
| 4 | Ödül claim çalışmadı, eski gibi otomatik terfi etti | BUG P1 | Claim akışı derin inceleme (inbox yerine oto-terfi kaçağı) |
| 5 | Task işlemi ~1.5 sn gecikmeli; ertesi gün yenilenme (00:00 sonrası gözlem) | PERF | Optimistic UI yok |
| 6 | Grup fotoğrafı yüklenmedi: "direct deletions from storage tables is not allowed" | BUG P1 | `0049_group_avatar.sql:110` trigger `DELETE FROM storage.objects` — yeni Supabase yasaklıyor |
| 7 | Daily task'lar üstte, süreli görevler altta | TASARIM | Görev sıralama |
| 8 | "Add time manually" saat alanı EN'de "Clock" | BUG | `manual_session_dialog.dart:197` `profileSaat` = `'Clock'` |
| 9 | Alpha Wolf gelmedi + nasıl hesaplanıyor | İZAH+BUG | Aşağıda |
| 10 | Yanlışlıkla pull-to-refresh tetikleniyor → **tamamen kaldır** | TASARIM | `social_profile_screen.dart:335` RefreshIndicator |

### Alınan kararlar (kullanıcı onayı)
- **Kademe kapsamı:** 6. kademe (Immortal) **her şeyi kapsar** — tüm kademeli başarımlar + taç/XP rütbe sistemi. Gizli (secret) başarımlar tek kademe kalır.
- **Renkler:** Valorant paletinden — Zümrüt = Valorant Ascendant yeşili, Immortal = Valorant Immortal kırmızısı; Elmas(4) = mevcut elmas mavisi `#38BDF8`. (Kesin hex plan aşamasında; "bulamazsan hallederiz".)
- **Pull-to-refresh:** tamamen kaldırılacak; 4 sn otomatik poll da düzeltilecek.

## 2. Alpha Wolf gerçek hesap mantığı (madde 9)

`0053_group_achievement_metrics.sql`: bir grup içinde, bir İstanbul gününde, o günkü
**verified** toplam süresi en yüksek olan **tek** üye o gün 1 "alpha win" alır
(beraberlikte kimse almaz). Başarım = **finalized** günlerdeki win toplamı.

Gelmeme sebepleri (üçü birden):
1. Yalnız verified/live oturumlar sayılıyor (shadow/native/normal sayılmıyor).
2. Yalnız `finalized_at` işaretli günler; sunucu projector RPC'si gerekiyor — QA'da staging-only, üretimde çalışmıyor → pratikte hep 0.
3. Yerel motor `achievement_ledger_engine.dart:513` alpha_wolf/campfire/locomotive için `break_enemy` secret bayrağını okuyor gibi — stub/hata şüphesi, planda netleşecek.

## 3. Yeni kademe eşikleri (6 kademe)

Tuple: `(kademe, eşik, birim, XP)`. **XP sütunu bekliyor** — kullanıcı yeniden dengeleyecek; aşağıda mevcut XP referans olarak duruyor, `?` = yeni tier6 XP.

| Başarım | 1 | 2 | 3 | 4 | 5 | 6 (yeni) | Not |
|---|---|---|---|---|---|---|---|
| marathon_total (saat) | 50 | 200 | 500 | 1000 | 2500 | **5000** | |
| steel_will (dk) | 60 | 90 | 120 | 180 | 300 | **480** | |
| day_hero (gün-saat) | 2 | 4 | 6 | 8 | 10 | **12** | |
| fire_streak / blazing fire (gün) | 7 | 30 | 150 | 365 | 730 | **1000** | |
| weekend_goal_days (gün) | 4 | 8 | 20 | 50 | 100 | **250** | |
| perfect_month (ay) | 1 | 3 | 6 | 12 | 24 | **36** | |
| **alpha_wolf (gün 1.'liği)** | **7** | **30** | **90** | **180** | **360** | **720** | tamamen yeni |
| team_player (grup katkı) | 10 | 30 | 100 | 300 | **600** | **1000** | eski 5=1000; 5→600'e indi |
| campfire_hours (saat) | 10 | 50 | 150 | **300** | **600** | **1000** | eski 4=500,5=1000 değişti |
| inspiration / secret of inspirations (dürtme) | 5 | 20 | 50 | 150 | 500 | **1000** | |
| locomotive (olay) | 5 | 15 | 30 | 100 | 300 | **600** | |

### Değişmeyen (tek kademe secret başarımlar)
secret_night_owl, secret_dawn, secret_404, secret_pi, secret_break_enemy,
secret_last_second, secret_1337, secret_no_limits, secret_matrix, secret_nye —
tümü 1 kademe, dokunulmuyor.

### Ek kural değişikliği
- **perfect_month:** artık "bir takvim ayında 30 gün" değil, **28/30 gün tamamlanınca**
  (blazing_fire ile ayrışsın diye — blazing = kesintisiz seri, perfect_month = ay
  içinde en fazla 2 kaçırma). QA 1.2 metni de güncellenmeli.
- **around_the_campfire (campfire) koşulu dinamik:** eşzamanlı aktif üye eşiği artık
  sabit 3 değil, grup büyüklüğü N'e göre: **çift N → N/2; tek N → floor(N/2)+1;
  global minimum 2.** Tablo: N=2→2, 3→2, 4→2, 5→3, 6→3, 7→4, 8→4. Bu hem yerel
  başarım motorunu hem sunucu `campfire_seconds` hesabını (0053) etkiler.

### Gizli (secret) başarım XP kararları
Tek kademe; yalnız XP değişir. **`secret_1337` (1337 Elite) tamamen silinecek** —
kullanıcı isteği. Silme; tanım listesi + `achievement_showcase.dart` (169, 203) +
metric map (318) + secrets tespit haritası (`'leet'`, 489/532) referanslarına dokunur.

| Gizli başarım | Koşul | Eski XP | Yeni XP |
|---|---|---|---|
| Gece Kuşu (`secret_night_owl`) | Gece yarısı–04:00 başla, ≥2 saat | 500 | **2000** |
| Gün Doğumu (`secret_dawn`) | Şafak oturumu | 500 | **2500** |
| 404 (`secret_404`) | Espri | 4044 | **5000** |
| Pi Sırrı (`secret_pi`) | Pi temalı | 314 | **3147** (kullanıcı; pi=3.1415 ise 3141/31415 alternatif) |
| Mola Düşmanı (`secret_break_enemy`) | Molasız uzun odak | 1000 | **2500** |
| Son Saniye Kurtarıcısı (`secret_last_second`) | Son saniyede | 1500 | **1500** (aynı) |
| ~~1337 Elite (`secret_1337`)~~ | — | 1337 | **SİLİNECEK** |
| Sınır Tanımaz (`secret_no_limits`) | Bir günde günlük hedefin 3 katı | 3000 | **5000** |
| Matrix Hatası (`secret_matrix`) | Espri | 1111 | **1111** (aynı) |
| Yılbaşı Nöbeti (`secret_nye`) | Yılbaşı gecesi yarısını aşan oturum | 5000 | **3000** |

## 4. XP ödülleri (kademe başına), onaylı

Tuple: `(kademe → XP)`. ✅=kullanıcı onayı, 🔶=öneri (onay bekliyor).

| Başarım | L1 | L2 | L3 | L4 | L5 | L6 |
|---|---|---|---|---|---|---|
| marathoner | 100 | 500 | 1500 | 5000 | 15000 | ✅45000 |
| steel will | 50 | 100 | 250 | 1000 | 5000 | ✅15000 |
| hero of day | 50 | 150 | 500 | 1500 | 5000 | ✅15000 |
| blazing fire | 100 | ✅2000 | ✅5000 | ✅20000 | ✅50000 | ✅100000 |
| weekend warrior | ✅150 | ✅450 | ✅1000 | ✅3000 | ✅10000 | ✅25000 |
| perfect month | ✅2000 | ✅4000 | ✅8000 | ✅16000 | ✅32000 | ✅64000 |
| alpha wolf | ✅1000 | ✅2500 | ✅7500 | ✅15000 | ✅30000 | ✅60000 |
| team player | 50 | 200 | 800 | 2500 | 8000 | ✅20000 |
| around the campfire | 100 | 400 | 1500 | 5000 | 12000 | ✅25000 |
| source of inspirations | 100 | 400 | 1200 | 4000 | 15000 | ✅30000 |
| locomotive | 150 | 500 | 1500 | 4500 | 15000 | ✅30000 |

> L1–L5 (işaretsiz olanlar) mevcut değerler; kullanıcı "aynı kalsın, sadece L6 ekle" dedi.
> blazing fire L1 = mevcut 100 korundu (kullanıcı L2–L6 verdi).

## 5. Taç/rütbe sistemi — ONAYLI

6 rütbe, rozet paletiyle aynı isim/renk. Eski `[0,2500,10000,25000,75000]` yeni XP
ekonomisinde önemsiz kaldığı için yeniden ölçeklendi.

| # | Rütbe | Eşik (toplam XP) |
|---|---|---|
| 1 | Bronz | 0 |
| 2 | Gümüş | 20.000 |
| 3 | Altın | 75.000 |
| 4 | Elmas | 200.000 |
| 5 | Zümrüt | 500.000 |
| 6 | Immortal | 1.000.000 |

Yani `kCrownXpThresholds = [0, 20000, 75000, 200000, 500000, 1000000]`. Sunucu
`_recalc_crown_rank` / ilgili migration ile birebir aynı olmalı. Rütbe id'leri de
6'ya çıkar (platin → elmas'a kayar, zümrüt + immortal eklenir).

## 7. Yeni başarım: Lider Kurt (`alpha_wolf_weekly`)
ISO hafta (Istanbul) boyunca grubun en yüksek verified toplamına sahip **tek** üye o hafta 1
kazanım alır (beraberlikte kimse almaz). Başarım = kaç hafta 1. bitirdiğin.

| Kademe | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| Hafta 1.'liği | 1 | 4 | 12 | 26 | 52 | 104 |
| XP | 2500 | 6000 | 15000 | 30000 | 60000 | 120000 |

Ayrıca: grup sıralamasında her üyenin **toplam günlük-alpha** sayısı 🐺 + sayı olarak
gösterilir (streak alevi korunur). Detay: plan WP-K/WP-L.

## 6. Bekleyen kararlar
- [ ] Kesin renk hex'leri (Valorant Ascendant yeşili / Immortal kırmızısı) — plan aşamasında bağlanacak ("bulamazsan hallederiz").
