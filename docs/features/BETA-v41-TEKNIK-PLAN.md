# beta-v41 — teknik plan ve WP dağılımı

> Girdi: beta-v40 saha testi (10 bulgu) + kilitli sayısal kararlar
> ([BETA-v41-KADEME-XP-KARARLARI.md](BETA-v41-KADEME-XP-KARARLARI.md)).
> Kurallar: tek dal `main`, her WP tek ayrık commit, yalnız kendi SAHİP yolları
> (`.agents/AGENTS.md §1`). Aşağıdaki WP'ler bağımlılık sırasına göre dizildi.

## 0. Mimari arka plan (neden bazı işler büyük)

Başarım sistemi **iki kaynakta ayna** tutuluyor ve **yarı-göçmüş** durumda:

- **Client:** `app/lib/core/stats/achievement_ledger_engine.dart` — kademe/eşik/XP tuple'ları,
  `kCrownXpThresholds`, `kCrownRanks`; `progression_visuals.dart` — renk/isim.
- **Server:** `achievements_dict.tiers` (JSONB) — aynı eşik/XP; `_recalc_crown_rank` — taç eşikleri;
  `process_achievement_event` (0027) — **eski oto-award**; `0053` — grup-verified inbox.

**Kritik:** çalışma/streak/social başarımları `process_achievement_event` içinde eşik geçince
`_award_achievement_tier` ile **anında XP veriyor** (item 4'ün sebebi). Grup-verified olanlar
(alpha/campfire/locomotive; event path'te `progress=0`) zaten candidate→claim inbox'ında.
Hedef: **hepsi inbox'tan geçsin.**

İki kaynak birbirini aynalamak zorunda — WP'lerde client ve migration **birlikte** değişir,
yoksa sözleşme kırılır (0050 metric contract).

---

## WP-A — 6 kademe görsel dili (renk + isim)
**SAHİP:** `app/lib/core/stats/progression_visuals.dart`, l10n arb'leri (`coreZumrut`, `coreImmortal`,
`coreZumrutTac`, `coreImmortalTac` + üretilen `app_localizations*.dart`).
**Bağımlılık:** yok (görsel; veriyle çakışmaz).

1. `tierColorFor` → 6 renk:
   - 1 bronz `#B87333`, 2 gümüş `#9CA3AF`, 3 altın `#EAB308`,
   - **4 Elmas `#38BDF8`** (eski elmas mavisi; platin kalkar),
   - **5 Zümrüt** — Valorant Ascendant yeşili, öneri `#17E4A0` (veya `#1FB98A`),
   - **6 Immortal** — Valorant Immortal kırmızısı, öneri `#B02E42` (parlak alt: `#FF4654`).
   - `clamp(1,6)` yap.
2. `tierLabel` → 6 etiket; `corePlatin` yerine 4=Elmas, 5=`coreZumrut`, 6=`coreImmortal`.
3. `kCrownRanks` 6 eleman: `[bronze_beginner, silver_learner, gold_achiever, diamond_owl,
   emerald_sage, immortal_legend]` (id önerileri). `normalizeCrownRank`:
   `platinum_scholar`/`ruby_master` → `diamond_owl`; eski `diamond_owl` → `diamond_owl` (4).
   **DİKKAT:** eski 5. rütbe (`diamond_owl`) artık **4.** kademe rengine denk gelir; taç eşik
   göçü WP-B ile aynı commit mantığında düşünülmeli (rütbe id anlamı kayıyor).
4. `crownLabel`/`crownColorFor` 6 duruma genişler.
5. Renk hex'leri tek yerde sabit; testler (`theme_settings_test`, `achievement_showcase_test`) güncellenir.

**Risk:** taç rütbe id semantiği değişiyor. WP-A (client sabit) ve WP-B (server eşik) **birlikte**
yayınlanmalı; ara durumda kullanıcı yanlış taç görebilir.

---

## WP-B — Kademe/XP verisi + taç eşikleri (client ⇄ server aynası)
**SAHİP:** `app/lib/core/stats/achievement_ledger_engine.dart`,
`supabase/migrations/0054_six_tier_economy.sql` (yeni), ilgili testler.
**Bağımlılık:** WP-A ile eşli yayın.

1. **Client engine:** her kademeli başarıma 6. tuple + değişen eşik/XP
   (kaynak: karar defteri §3–4). `kCrownXpThresholds = [0,20000,75000,200000,500000,1000000]`.
   `secret_1337` girişini ve tüm referanslarını sil (showcase 169/203, metric map 318,
   secrets `'leet'` 489/532/538). Gizli XP'leri güncelle.
2. **Migration 0054:**
   - `achievements_dict.tiers` JSONB'lerini 11 kademeli başarım için UPDATE (6 tier).
   - `_recalc_crown_rank` → 6 rütbe + yeni eşikler; yeni rank id'leri.
   - Mevcut `gamification_profiles.crown_rank` değerlerini yeni id'lere map + `_recalc` ile hizala
     (XP korunur, reset yok).
   - `secret_1337` sözlük satırını ve varsa ledger referanslarını temizle (FK'ye dikkat).
   - `max_tier` kolonlarını 6'ya çek (kademeli başarımlarda).
   - `notify pgrst, 'reload schema'`.
3. **Sözleşme testi:** client tuple'ları ile `achievements_dict.tiers` birebir eşit mi — bir
   doğrulama testi/örnek script.

**Risk:** client ve migration sayıları birebir aynı olmalı. Tek kaynak yok; kopya hatası
riskini test ile kapat.

---

## WP-C — Claim inbox birleştirme (item 4, en kritik)
**SAHİP:** `supabase/migrations/0055_route_awards_to_inbox.sql` (yeni),
`app/lib/features/profile/widgets/reward_toast.dart`, `achievement_showcase.dart` (claim UI teyidi).
**Bağımlılık:** WP-B (yeni eşikler yürürlükte olmalı).

1. **Server:** `process_achievement_event` içindeki `_award_achievement_tier` doğrudan-award'ı,
   çalışma/streak/social başarımları için **candidate üretimine** çevir
   (`achievement_reward_candidates` insert, `on conflict do nothing`, event_key idempotent) —
   grup-verified ile aynı sözleşme. Doğrudan XP verilmez; XP yalnız `claim_achievement_reward`
   ile verilir.
2. **İdempotentlik:** aynı tier için tekrar candidate üretilmemeli; zaten award edilmişse
   (xp_ledger'da varsa) candidate açılmamalı — çift-claim / çift-XP guard (QA 1.3).
3. **Geçiş:** beta-v40'ta zaten oto-award edilmiş tier'lar için geriye dönük candidate açma;
   yalnız ileriye etki (aksi halde retro çift ödül).
4. **Client:** `reward_toast` banner + Profil "Topla"/"Tümünü topla" akışı tüm başarım tiplerini
   kapsıyor mu doğrula; boş/tek/çoklu ve hata (ödül kaybolmaz) yolları.

**Risk (P0 sınıfı):** yanlış kurgu çift-XP veya XP kaybı üretir. Staging'de QA §1 senaryoları
(1.3–1.7) zorunlu. Rollback planı: 0055'i geri al → 0027 oto-award davranışı döner.

---

## WP-D — perfect_month = 28/30 kuralı
**SAHİP:** server `_achievement_metrics` (perfect_months hesabı) migration'ı,
`app/lib/core/stats/achievement_engine.dart` (varsa client hesap), QA 1.2 metni + l10n açıklama.
**Bağımlılık:** yok.

1. **28/30 kuralı:** ay içinde **≥28 hedef-tamamlanan gün** (30 günlük ayda 28/30; en fazla 2 kaçırma).
   Şubat/29 günlük ay için de eşik sabit 28 gündür.
2. `perfect_month` başarım **açıklama** metni güncelle (l10n, 4 dil) + `BETA-v40-TEST` 1.2 notu.
3. Geçmiş kazanılmış perfect_month kaybolmamalı (idempotent).

---

## WP-E — around_the_campfire dinamik eşik
**SAHİP:** `supabase/migrations` 0053 campfire hesabı güncellemesi,
`achievement_showcase.dart` açıklama metni + l10n.
**Bağımlılık:** yok (ama WP-B eşikleriyle aynı sürümde).

1. Sunucu `campfire_seconds` hesabı: eşzamanlı aktif üye eşiği artık sabit 3 değil,
   grup büyüklüğü N'e göre: **çift → N/2; tek → floor(N/2)+1; global min 2.**
2. Açıklama metni "en az 3 kişi" → dinamik ifade (l10n 4 dil).
3. Test: N=2→2, 4→2, 5→3, 6→3, 7→4 (QA'ya satır eklenir).

---

## WP-F — alpha_wolf yeniden + hesap kaçakları (item 3, 9)
**SAHİP:** `achievement_ledger_engine.dart` (local metric okuması), 0053 projeksiyon,
prod projector zamanlama (ops/edge/cron).
**Bağımlılık:** WP-B (yeni eşikler 7/30/90/180/360/720 orada).

1. **Local stub düzelt:** `achievement_ledger_engine.dart:513` alpha_wolf/campfire/locomotive
   için `secrets['break_enemy']` okuması yanlış → doğru metric kaynağına
   (`achievement_metric_progress`) bağla; UI ilerleme doğru görünsün.
2. **Üretim projeksiyonu:** verified grup günlerinin `finalize_verified_group_day` +
   `project_verified_group_day` akışının **üretimde** (staging-only değil) güvenli çalışması
   — zamanlanmış görev/edge function; idempotent, cursor güvenli (QA 6.2).
3. **İzah dokümante:** alpha = grup gün-birinciliği (unique top, verified, finalized).

**Risk:** üretimde metric üretimi açmak ops kararı; yanlışsa duplicate ödül. Staging kanıtı şart.

---

## WP-G — Başarımlar sayfası: poll + pull-to-refresh (item 1, 10)
**SAHİP:** `app/lib/features/profile/widgets/reward_toast.dart`,
`app/lib/features/profile/social_profile_screen.dart`.
**Bağımlılık:** WP-C (claim akışı stabilize olduktan sonra polling'e gerek azalır).

1. `reward_toast.dart:50` 4 sn `Timer.periodic` → kaldır veya olayla tetiklenen yenilemeye çevir
   (claim sonrası + uygulama resume'da invalidate; sürekli poll yok). Scroll zıplaması biter.
2. `social_profile_screen.dart` `RefreshIndicator` (335–344) **tamamen kaldır** (kullanıcı isteği).
3. Yenileme artık: sayfa açılışı + claim + resume. Test: sayfa 4 sn'de zıplamıyor; liste konumu korunuyor.

---

## WP-H — Grup avatarı storage trigger fix (item 6, P1)
**SAHİP:** `supabase/migrations/0056_group_avatar_cleanup_fix.sql` (yeni).
**Bağımlılık:** yok.

1. `cleanup_group_avatar_object` trigger'ından **`DELETE FROM storage.objects`** kaldır
   (yeni Supabase yasaklıyor: "direct deletions from storage tables is not allowed").
2. Eski nesne temizliği zaten client `_removeUploadedObject` (storage API) ile yapılıyor →
   trigger'ı ya kaldır ya da yalnız kolon güncellemesi yapan no-op'a çevir. Alternatif: temizliği
   `pg_net`/edge function ile storage API'ye devret. **En sade:** trigger'ı düşür, client best-effort
   temizlik + periyodik storage-audit yeter.
3. Test: fotoğraf yükle / değiştir / sil — hata yok; yetkisiz erişim reddi korunur (QA 3.1–3.3).

---

## WP-I — "Clock" → "Hours" etiketi (item 8)
**SAHİP:** `app/lib/features/profile/widgets/manual_session_dialog.dart` + l10n.
**Bağımlılık:** yok.

1. `manual_session_dialog.dart:197` `profileSaat` (EN "Clock") yerine saat-birimi key'i
   (`classroomSaat`="Hours" mevcut) veya `profileSaat` EN karşılığını "Hours" yap — ama
   `profileSaat` başka yerde "Clock" anlamında kullanılıyorsa ayrı `profileSaatBirimi` key aç.
2. TR "Saat" zaten iki anlamlı; sorun yalnız EN/DE/AR. 4 dil kontrol.

---

## WP-J — Görev: daily üstte sıralama + hız (item 7, 5)
**SAHİP:** `app/lib/features/home/widgets/tasks_card.dart`,
`app/lib/data/providers/user_task_providers.dart`.
**Bağımlılık:** yok.

1. **Sıralama:** `isDaily` görevler üstte, sonra süreli/tek-sefer (`dueAt`/once);
   grup içi mevcut `sortOrder` korunur. Ana Sayfa Görevler kartı + Araçlar listesi aynı sıra.
2. **Hız (item 5):** ekle/tamamla/geri al için **optimistic UI** — state'i hemen güncelle,
   yazma arka planda; hata olursa geri al + bildir. ~1.5 sn algılanan gecikme kalkar.
3. **Ertesi gün yenilenme:** `recurrence=daily` + `completionDay` projeksiyonu 00:00 (Europe/Istanbul)
   sonrası tekrar aktif mi — koda bakılıp doğrulanır; kullanıcı 00:00 gözlemi ile teyit.

---

## WP-K — Grup sıralamasında alpha göstergesi
**SAHİP:** `app/lib/features/home/widgets/leaderboard_card.dart`,
`app/lib/features/stats/widgets/class_stats_view.dart`, yeni sunucu sorgusu/RPC (grup üyesi
başına toplam alpha-win), ilgili provider.
**Bağımlılık:** WP-F (verified projeksiyon üretimde olmalı; yoksa herkes 0 görür).

1. Streak alevi **korunur**; yanına **🐺 + alpha-win sayısı** eklenir (0 ise gizli, streak gibi).
2. Sunucu: grup için üye başına toplam alpha-win döndüren sorgu/RPC (`group_achievement_daily`
   sum veya `achievement_metric_progress`). İstemci ranking satırına alan eklenir.
3. Hem Ana Sayfa `leaderboard_card` hem Gruplar `class_stats_view` aynı göstergeyi kullanır.
4. RLS: üye yalnız kendi grubunun üyelerinin alpha toplamını görebilir.

## WP-L — Yeni başarım: Haftalık Alpha (Haftanın Kurdu)
**SAHİP:** `achievement_ledger_engine.dart` (yeni `alpha_wolf_weekly` girişi),
migration (weekly metric + dict satırı), l10n (isim/açıklama 4 dil), badge ikon/renk.
**Bağımlılık:** WP-B (6 kademe altyapısı), WP-F (verified projeksiyon).

1. **Koşul:** ISO hafta (Europe/Istanbul) boyunca grubun **en yüksek verified toplamına sahip
   tek üye** o hafta için 1 "weekly-alpha win" alır (beraberlikte kimse almaz; günlük alpha ile
   aynı deterministik kural). Başarım = kaç hafta 1. bitirdiğinin toplamı.
2. **Server:** haftalık agregasyon + finalize (ISO hafta sınırı, Istanbul tz); yeni metric
   `alpha_wolf_weekly`; idempotent projeksiyon; ödül candidate → inbox.
3. **Client:** yeni kademeli başarım girişi (6 kademe), badge ikonu (kurt), 6-kademe paleti.
4. **Eşik + XP (ONAYLI):** kademe **1/4/12/26/52/104 hafta**,
   XP **2500/6000/15000/30000/60000/120000**.
5. **İsim (ONAYLI):** **"Lider Kurt"** (`alpha_wolf_weekly`).
6. Sıralamada gösterilmez (kullanıcı isteği); yalnız başarım olarak.

## Yayın ve test
- Sürüm: `1.0.41+41`, cihazda `1.0.41-beta`. CHANGELOG + release_notes + VERSIONS güncelle.
- Yeni QA listesi `docs/qa/BETA-v41-TEST.md`: v40 listesi + değişen ekonomi, 6 kademe renk,
  claim inbox (çift-XP guard), campfire dinamik eşik, avatar fix, görev sırası/hız.
- **GO şartı:** WP-C (claim) ve WP-B/A (ekonomi) staging kanıtı olmadan GO yok; çift-XP / XP
  kaybı P0'dır.

## Önerilen sıra (dalga)
1. **Hızlı bug kazanımları:** WP-H (avatar), WP-I (etiket), WP-G (poll/refresh), WP-J (görev).
2. **Ekonomi çekirdeği (eşli):** WP-A + WP-B.
3. **Claim birleştirme:** WP-C (B'den sonra).
4. **Kural/metric:** WP-D (perfect_month), WP-E (campfire), WP-F (alpha).

## Açık ops/karar notları
- [x] Item 4 yaklaşımı: **tüm başarımlar inbox'a** (oto-award kalkar) — **ONAYLI**.
- [x] Taç rütbe id göçü: mevcut kullanıcıların XP'si korunur, rütbe yeniden hesaplanır (reset yok) — **ONAYLI**.
- [x] Alpha/verified projeksiyonun üretimde açılması (ops) — **ONAYLI**.
- [ ] Kesin renk hex'leri (Zümrüt/Immortal) — WP-A'da bağlanacak.
