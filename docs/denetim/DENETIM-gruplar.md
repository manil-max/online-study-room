# DENETİM — Gruplar · Sosyal · Güvenlik

Tarih: 2026-08-09 · Yöntem: **salt kod okuması**. `progress.md`, `docs/**` ve kod
yorumları kanıt sayılmadı; her bulgunun altında `dosya:satır` var. Uygulama
çalıştırılmadı, test koşulmadı.

Kapsam: `app/lib/features/classroom/**`, `app/lib/features/safety/**`,
`app/lib/features/notifications/**`, `group/presence/nudge/moderation/chat`
provider + repository'leri, `supabase/migrations/**` içindeki ilgili RLS/RPC'ler.

Özet: **3 KANAMA · 5 RİSK · 6 TEMİZLİK.**

---

## KANAMA

### K1 — Grup en fazla 8 kişi; 13 testçi aynı grupta buluşamaz

**Belirti.** Kapalı test 13 kişiyle başlıyor. Bir gruba 8'inci kişiden sonrası
alınmıyor; 9'uncu kişi "Grup dolu" görüyor. Sınırı büyütmenin ne uygulamada ne
veritabanında yolu var. Uygulamanın çekirdeği "birlikte çalışmak" olduğu için
grup ikiye bölünmek zorunda: sıralama, grup hedefi, kamp ateşi ve grup serisi
iki ayrı kümeye dağılır ve testin asıl ölçmek istediği "hep birlikte" hissi hiç
oluşmaz.

**Kanıt.**
- `supabase/migrations/0071_group_member_limit_8.sql:53`
  → `check (member_limit between 2 and 8);` (DB kısıtı, veri değil politika)
- `supabase/migrations/0071_group_member_limit_8.sql:83`
  → `create_group_with_access` içinde `if p_member_limit not between 2 and 8 then`
- `app/lib/data/models/study_group.dart:11-12`
  → `kMaxGroupMemberLimit = 8; kDefaultGroupMemberLimit = kMaxGroupMemberLimit;`
- `supabase/migrations/0093_group_bans.sql:190` ve `:219`
  → `join_group` / `join_public_group`: `raise exception 'Grup dolu.';`
- Sınır **arayüzden değiştirilemiyor**: `app/lib/features/classroom/widgets/class_detail_screen.dart:490`
  gizlilik diyaloğu `memberLimit: group.memberLimit` diye mevcut değeri geri
  yolluyor; `_promptCreateGroup` (`class_switcher.dart:224-231`) `memberLimit`
  parametresini hiç geçmiyor. Yani `GroupRepository.updateGroupAccess`'in üye
  sınırı kolu (`group_repository.dart:133-138`) **yazılmış ama çağıran yok**.

**Etki.** Test planı seviyesinde engel. Hata mesajı doğru ve çevrili
(`core/l10n/group_error_text.dart` → `Grup dolu` → `classroomGrupDolu`), yani
uygulama yalan söylemiyor — ama 13 kişilik senaryo bu sınırla çalışmaz.

**Öncelik:** KANAMA (ürün kararı gerektirir: ya sınır yükseltilir — DB kısıtı +
RPC + `kMaxGroupMemberLimit` üç yerde birden — ya da test iki gruba bölünerek
planlanır ve testçilere önceden söylenir.)

---

### K2 — Sohbette mesaj gönderimi ağ hatasında TAMAMEN sessiz kalıyor

**Belirti.** Metin yazılır, gönder'e basılır, gösterge bir an döner, sonra düğme
yeniden etkinleşir. Metin kutuda kalır, **hiçbir mesaj çıkmaz**, mesaj da
gönderilmemiştir. Kullanıcı için bu, "gönderdim sandım" ile ayırt edilemez.

**Kanıt.**
- `app/lib/features/classroom/widgets/class_chat_card.dart:202` → `} on ChatException {`
  (yalnız bu tip yakalanıyor; `finally` yalnız `_sending = false` yapıyor)
- `app/lib/data/repositories/supabase/supabase_chat_repository.dart:34`
  → `} on PostgrestException catch (e) {` — yalnız Postgrest sarılıyor
- Ağ hatasının sarılmadan çıktığı bu depoda **ölçülmüş**:
  `app/lib/core/l10n/group_error_text.dart:32-36` → "Supabase repository yalnız
  `PostgrestException`ı sarıyor, bağlantı kopunca `SocketException` /
  `ClientException` sarılmadan yukarı çıkar. Eski `on GroupException` blokları
  bunu hiç yakalamıyordu."
  Aynı tespit `app/lib/features/classroom/widgets/group_discovery_screen.dart:107-111`
  (WP-551) — keşif ekranında düzeltildi, sohbette düzeltilmedi.
- Ölçmeyen kapı: `app/test/features/error_retry_wp560_test.dart` sohbetin yalnız
  **okuma** dalını sınıyor (`_FlakyChatRepository.watchGroupMessages` hata
  veriyor); gönderim dalı yok.
  `app/test/features/group_admin_feedback_wp540_test.dart:15` yalnız "boş mesaj"
  vakasını sınıyor.

**Etki.** Sohbet, kapalı testin ana sosyal kanalı. Zayıf ağda "yazdım, gitmedi,
uygulama hiçbir şey demedi" doğrudan bu yoldan çıkar.

**Öncelik:** KANAMA

---

### K3 — Dürtme ve "dürtmesini sustur" da aynı sessiz dalı taşıyor

**Belirti.** Dürtme düğmesine basılır, gösterge döner, biter — ne "dürtüldü" ne
hata. Susturma/susturmayı kaldırma da aynı.

**Kanıt.**
- `app/lib/features/classroom/widgets/nudge_action.dart:137` → `} on NudgeException catch (error) {`
- `app/lib/data/repositories/supabase/supabase_nudge_repository.dart:45`
  → `} on PostgrestException catch (e) {`
- `app/lib/features/classroom/widgets/class_detail_screen.dart:1139`
  (`_MuteNudgeButton._toggle`) → yine yalnız `on NudgeException`

Karşılaştırma: aynı dosyadaki `_UnbanButton._run`
(`class_detail_screen.dart:1267`) ve `_actionDialog`
(`class_detail_screen.dart:1350`) **çıplak `catch (failure)`** kullanıp
`groupActionErrorText` ile çeviriyor. Yani doğru desen aynı dosyada var, iki
düğme onu kullanmıyor.

**Etki.** Dürtme, kamp ateşindeki tek etkileşim (bkz. R4). Sessiz düğme, "ölü
düğme" olarak okunur — WP-484/WP-511'in kapatmaya çalıştığı hissin ta kendisi.

**Öncelik:** KANAMA

---

## RİSK

### R1 — Gruba katılmadan ÖNCE başlayan çalışma o grupta hiç görünmez, kimse söylemez

**Belirti.** Kullanıcı uygulamayı açar, ana ekrandaki sayacı başlatır, sonra
grubu bulur/kurar/katılır, sonra sayacı durdurur. Kendi istatistiğinde süre
görünür; **grubun sıralamasında, grup hedefinde ve kamp ateşindeki "bugünkü
toplam"da 0 görünür.** Ekranda bunu açıklayan tek bir cümle yok.

**Kanıt.**
- Sıralama/kamp ateşi kaynağı: `app/lib/data/providers/study_providers.dart:207`
  (`groupDailyStatsProvider`) → `supabase_study_repository.dart:291`
  (`rpc('group_daily_totals')`)
- `supabase/migrations/0011_group_daily_totals_v2.sql:37-38`
  → `where s.start_time >= gm.joined_at and (gm.left_at is null or s.start_time < gm.left_at)`
- Grup ilerlemesi/başarım tarafı da aynı: `supabase/migrations/0080_session_group_attribution.sql`
  `capture_study_session_group_attribution` → `primary_group_at(user, new.start_time)`;
  katılımdan önce `user_group_preference_history` satırı yoktur → `group_id` NULL
  → `groups_for_session_progression` boş küme döner.
- Oturum sunucuya **durdurmada** yazılıyor ama `start_time` gerçek başlangıç:
  `app/lib/data/repositories/supabase/supabase_study_repository.dart:151-157`.
- Kamp ateşindeki sayı da bu RPC'den: `study_providers.dart:255`
  (`groupTodaySecondsProvider`) → `campfire_scene.dart:83,128`.

**Etki.** İlk 10 dakikanın en olası sırası tam bu. "40 dakika çalıştım, grup beni
sıfır gösteriyor" ilk gün 13 kişide birden yaşanabilir ve hata gibi okunur.
Davranış savunulabilir (henüz üye değildi) ama **sessiz** olması savunulamaz.

**Öncelik:** RİSK (yüksek)

---

### R2 — Grup sahibinin gruptan çıkma yolu yok; hata metni **var olmayan** bir özelliği işaret ediyor

**Belirti.** Grubu kuran kişi için "Gruptan çık" satırı hiç çizilmiyor; tek
seçenek "Grubu sil" (herkesin grup verisi gider). Sunucu tarafındaki hata metni
ise "önce devret ya da grubu sil" diyor — **devretme diye bir özellik hiçbir
yerde yok.**

**Kanıt.**
- `app/lib/features/classroom/widgets/class_detail_screen.dart:304`
  → `if (!isAdmin && userId != null) _LeaveGroupTile(...)` (sahip görmüyor)
- `app/lib/data/repositories/supabase/supabase_group_repository.dart:477-481`
  → `owner_must_transfer_or_delete` / `last_admin_must_transfer` →
  `'Grup sahibi gruptan çıkamaz: önce devret ya da grubu sil.'`
- `supabase/migrations/0108_leave_group_command.sql:116,127` ve
  `supabase/migrations/0111_group_membership_departure_guard.sql:41,141,152`
  aynı hatayı fırlatıyor.
- `grep -rni "transfer\|devret" app/lib` → yalnız bu hata metinleri ve yorumlar;
  `grep -rn "transfer" supabase/migrations/*.sql` → yalnız `raise exception`
  satırları. **Devretme RPC'si ve arayüzü yok.**

**Etki.** Kapalı testte grubu kuran kişi çekilmek isterse tek yolu grubu silmek.
Ayrıca `GroupOwnerCannotLeaveException` hiçbir zaman ekrana çıkamaz (düğme zaten
gizli) → ölü hata yolu.

**Öncelik:** RİSK

---

### R3 — Kamp ateşinden ve üye listesinden şikâyet/engelleme yolu YOK

**Belirti.** Gruplar sekmesinin ana yüzeyi kamp ateşi. Bir hayvana dokununca
açılan sayfada yalnız istatistik ve "Dürt" var; profil bağlantısı, şikâyet ve
engelleme yok. Grup ayarlarındaki üye listesinde satıra dokunulunca açılan
diyalogda da yok. Rahatsız eden kişi **sohbete hiç yazmamışsa** (kötü ad, kötü
avatar/hayvan, sadece varlığıyla) kullanıcının Gruplar sekmesinden yapabileceği
hiçbir şey yok.

**Kanıt.**
- Kamp ateşi üye sayfası: `app/lib/features/classroom/widgets/campfire_scene.dart:918-1000`
  — içerik: `CritterPainter`, ad, durum, `_StatRow`'lar, `NudgeAction`. Başka
  eylem yok.
- Üye satırı: `app/lib/features/classroom/widgets/class_detail_screen.dart:902`
  → `SocialProfileDialog.show(context, member)`;
  `app/lib/features/profile/widgets/social_profile_dialog.dart` içinde
  `showReportSheet` / `confirmAndBlockUser` **geçmiyor**.
- Tüm giriş noktaları: `grep -rn "showReportSheet(" app/lib` →
  `class_chat_card.dart:284`, `class_detail_screen.dart:59` (grup),
  `class_detail_screen.dart:94` (grup adı), `social_profile_screen.dart:141`.
  `grep -rn "confirmAndBlockUser(" app/lib` → `class_chat_card.dart:299`,
  `social_profile_screen.dart:151`.
- `SocialProfileScreen` (şikâyet/engelleme **olan** yüzey) gruplar tarafında
  yalnız sohbet avatarından (`class_chat_card.dart:364`) ve ana ekrandaki "Şu an
  çalışanlar" satırından (`active_members_card.dart:311`) açılıyor.

**Etki.** Play'e "engelleme ve şikâyet var" beyanı veriliyor; kullanıcı için en
görünür sosyal yüzeyde ikisi de yok. WP-446'nın kendi dersi ("uzun basma TEK
keşif yolu olamaz") burada uygulanmamış.

**Öncelik:** RİSK

---

### R4 — İki hata dalı hâlâ "doğru cümle + hiçbir düğme"

**Belirti.** Ağ hatasında kamp ateşi ve "Şu an çalışanlar" kartı bir cümle yazıp
duruyor. Aşağı çekerek yenileme kabuk tarafında var (yani mutlak çıkmaz sokak
değil), ama ekranda **görünür bir çıkış yok** — kardeş kapılar WP-560/WP-589'da
"Tekrar dene" aldı, bu ikisi almadı.

**Kanıt.**
- `app/lib/features/classroom/widgets/campfire_scene.dart:98-110`
  → `error: (_, _) => _SceneFrame(... Text(authBeklenmeyenBirHataOlustu) ...)`
- `app/lib/features/home/widgets/active_members_card.dart:152-157`
  → `failed ? groupCardMessage(context, homeCalisanlarYuklenemedi) : GroupCardSkeleton`
- Karşılaştırma (düzeltilmiş kardeşler):
  `app/lib/features/home/widgets/card_data_gate.dart:46-58` ve
  `app/lib/features/home/widgets/group_card_shell.dart:54-68` → `ErrorRetryView`
  + `refreshAppData`.
- Kaçış gerçekten var mı: `classroom_screen.dart:94` gövdeyi `AppPullToRefresh`
  ile sarıyor ve `_GroupView` bir `ListView` (`classroom_screen.dart:261`);
  `app_pull_to_refresh.dart:139-141` `groupMembersProvider` ve
  `groupPresenceProvider`'ı tazeliyor. Yani jest çalışır — sadece kimse söylemez.

**Öncelik:** RİSK

---

### R5 — Grup saat dilimi ayarı, sıralamanın "bugün"ünü etkilemiyor

**Belirti.** Yönetici grubun saat dilimini New York seçer. Arayüz bunun grup gün
sınırını değiştirdiğini söyler. Ama sıralama / grup hedefi / kamp ateşi "bugünkü
toplam" hâlâ **İstanbul gece yarısında** sıfırlanır; hedef-tamamlandı olayı ve
grup serisi ise New York gününü kullanır. İki sayı aynı ekranda birbirini
tutmaz.

**Kanıt.**
- Sıralama kaynağı sabit İstanbul:
  `supabase/migrations/0011_group_daily_totals_v2.sql:32` ve `:39`
  → `(s.start_time at time zone 'Europe/Istanbul')::date`
- Hedef/seri grubun kendi dilimini kullanıyor:
  `supabase/migrations/0120_goal_completion_writer.sql:231`
  → `v_day := (new.start_time at time zone v_group.time_zone)::date;`
  ve `:323`, `:332`
- Arayüzdeki iddia: `app/lib/data/repositories/group_repository.dart:129-130`
  ("sadece gelecekteki grup gün sınırlarını etkiler") ve
  `app/lib/features/classroom/widgets/class_detail_screen.dart:247-264`
  (`groupTimeZoneDescription` ile birlikte).

**Etki.** 13 kişilik test Türkiye'deyse görünmez. Farklı bölge seçen tek bir
grup bunu doğrudan görür. Keşif ekranı bölgeye göre sıraladığı için
(`0078_discover_groups_by_tz.sql`) bölge seçimi teşvik ediliyor.

**Öncelik:** RİSK

---

## TEMİZLİK

### T1 — Keşifte "Katıl" oturum okunamazsa sessizce hiçbir şey yapmıyor
`app/lib/features/classroom/widgets/group_discovery_screen.dart:127`
→ `if (user == null || _joiningIds.contains(group.id)) return;`
Aynı tuzak `class_switcher.dart`ta iki kez (WP-535, WP-540) düzeltildi ve orada
artık **yazılı hata** çıkıyor (`class_switcher.dart:214-218` ve `:435-439`).
Pratik risk düşük (ekrana `AuthGate` arkasından geliniyor, `authStateProvider`
`autoDispose` değil), ama desen bilinen tuzağın kendisi.

### T2 — Üye sınırını değiştiren kol yazılmış, çağıran yok
`app/lib/data/repositories/group_repository.dart:133-138` "üye sınırını
değiştirmesi" diyor; tek çağıran `class_detail_screen.dart:490` mevcut değeri
geri yolluyor. `create_group` da `memberLimit` parametresini hiç almıyor
(`class_switcher.dart:224-231`). (K1 ile aynı kök.)

### T3 — Kod yorumu ile migration çelişiyor (realtime publication)
`app/lib/features/classroom/widgets/class_detail_screen.dart:383-385`
→ "groups tablosu realtime publication'da degil".
`supabase/migrations/0001_initial_schema.sql:211`
→ `alter publication supabase_realtime add table public.groups;` (hiçbir
migration bunu geri almıyor). Yorumun **sonucu** doğru (elle `invalidate`
gerekiyor, çünkü `watchUserGroups` `group_members` akıtıyor —
`supabase_group_repository.dart:224-238`), **gerekçesi** yanlış.

### T4 — Şikâyet ekranı ham sunucu metnini kullanıcıya gösteriyor
`app/lib/features/safety/report_sheet.dart:140` → `Text(e.message)`;
mesaj `supabase_moderation_repository.dart:47,216` içinde
`ModerationException(e.message)` ile doğrudan Postgres'ten geliyor. Grup
tarafındaki `groupActionErrorText` / `nudge_error_text.dart` deseni burada yok.

### T5 — `user_blocks` okuması tek hata noktası
`app/lib/data/repositories/supabase/supabase_moderation_repository.dart:137-140`
(`listBlockedUserIds`) hiç `try/catch` taşımıyor → `blockedUserIdsProvider`
patlar → WP-538'in fail-closed sözleşmesi gereği sohbet **tamamen** kilitlenir
(`class_chat_card.dart:67-104`). Sözleşme bilinçli, ama tek dalgalı istek =
sohbet kapalı demek; en azından `ErrorRetryView` metni bunu söylemiyor.

### T6 — `notified_nudge_ids` sınırsız büyüyor
`app/lib/data/providers/nudge_notification_listener.dart:83`
→ `prefs.setStringList(_kNotifiedNudgeIdsKey, notified.toList())`; hiçbir yerde
budanmıyor. Uzun vadede SharedPreferences'te kontrolsüz büyüyen tek liste.

---

## 13 testçinin ilk 10 dakikası — adım adım kodda

| # | Adım | Durum | Dayanak |
|---|------|-------|---------|
| 1 | Kayıt / giriş → `AuthGate` | **Çalışıyor** (bu denetimin alanı değil; oturum akışı çevrimdışı yedeği ile açılıyor) | `data/providers/auth_providers.dart:217-235` |
| 2 | Gruplar sekmesi, grup yok | **Çalışıyor.** "Grup oluştur" · "Koda katıl" · "Grupları keşfet" üçü de var, ekran kaydırılabilir (büyük yazı ölçeğinde düğmeler ekran dışında kalmıyor) | `classroom_screen.dart:177-232` |
| 3 | Grup kur | **Çalışıyor.** İstek diyaloğun içinde koşuyor, düğme kilitleniyor, `PopScope` ile yarıda kapanmıyor → çift grup imkânsız. Hata diyalogda yazılı çıkıyor | `class_switcher.dart:203-246, 348-365` |
| 4 | Davet kodunu paylaş | **Çalışıyor.** Paylaşılan metin grup adı **ve** kodu taşıyor; paylaşım açılamazsa SnackBar var | `class_detail_screen.dart:335-352` |
| 5 | Kodla katıl | **Çalışıyor.** Sunucu doğruluyor (`join_group` RPC), beş ayrı sebep ayrı cümleye çevriliyor (yanlış kod / yasaklı / dolu / oturum yok / ağ) | `supabase_group_repository.dart:150-167`, `core/l10n/group_error_text.dart` |
| 6 | **9. kişi katılmaya çalışır** | **KIRIK — K1.** `Grup dolu.` Sınır 8, yükseltilemiyor | `0071:53,83` · `0093:190,219` |
| 7 | Keşiften katıl | **Çalışıyor** (liste boşsa bile çıkış var: kaydırılabilir boş ekran + "Grup oluştur" / "Koda katıl"). Not: yeni grup varsayılan **Özel**, yani keşifte hiç görünmez — 13 kişi keşiften buluşmayı planlıyorsa grubun açık kurulması gerekir | `group_discovery_screen.dart:318-380`, `class_switcher.dart:191` (varsayılan `GroupVisibility.private`) |
| 8 | Sayacı başlat → kamp ateşinde görün | **Çalışıyor.** 20 sn heartbeat / 70 sn lease; bayat satır istemcide çevrimdışına düşüyor; projeksiyon realtime publication'da | `presence_providers.dart:36,41,107-133` · `presence_lifecycle.dart:36-40` · `0081:180,335` · `0086:40` |
| 9 | **Gruba katılmadan önce başlatılan oturum** | **KIRIK — R1.** Grup sıralamasında ve kamp ateşinde 0 görünür, kimse söylemez | `0011:37-38` · `0080` |
| 10 | Sohbet et | **Yarısı kırık — K2.** Okuma dalı sağlam (hata → "Tekrar dene"); **gönderim** ağ hatasında sessiz | `class_chat_card.dart:88-104` (sağlam) vs `:202` (kırık) |
| 11 | Birbirini dürt | **Yarısı kırık — K3.** Kapılar (kendine dürtme, çalışan kişiyi dürtme, cooldown) doğru; ağ hatası sessiz | `nudge_action.dart:86-142` |
| 12 | Rahatsız edeni engelle/şikâyet et | **Eksik — R3.** Yalnız sohbet mesajından mümkün; kamp ateşinden ve üye listesinden yol yok | `campfire_scene.dart:918-1000`, `class_detail_screen.dart:902` |
| 13 | Ağ koparsa geri dön | **Çoğunlukla çalışıyor.** Gruplar sekmesi, grup kartları ve sohbet okuması "Tekrar dene" veriyor; kamp ateşi ve "Şu an çalışanlar" vermiyor (R4) | `classroom_screen.dart:111-132`, `group_card_shell.dart:54-68` |

**Sonuç:** yolculuk 6. adımda ürün sınırına (8 kişi), 9./10./11. adımlarda sessiz
hatalara çarpıyor. 1–5 ve 7–8 adımları koddan doğrulandı, sağlam.

---

## Kontrol ettim, SAĞLAM çıktı

- **Sunucu otoritesi.** Grup kurma, davet koduyla katılma ve açık gruba katılma
  yalnız `SECURITY DEFINER` RPC'lerle; istemci `group_members`'a doğrudan
  `insert` atmıyor, davet kodunu tabloya sorgulamıyor.
  `supabase_group_repository.dart:131,159,210` · `0093_group_bans.sql:166-224`
- **Davet kodu ifşası kapalı.** `groups_select` üye-yalnız
  (`0012_group_join_hardening.sql:136-137`); keşif RPC'si kod döndürmüyor
  (`0078_discover_groups_by_tz.sql:18-28` dönen sütunlar).
- **Gruptan çıkışın tek kapısı var.** `leave_group` idempotent (`command_id`) +
  advisory lock; `0111` trigger'ı hem doğrudan `left_at` UPDATE'ini hem de
  sahipsiz grup oluşmasını yazma yolundan **bağımsız** kapatıyor. İstemci tek
  hareket için tek `commandId` üretip retry'da aynısını yolluyor.
  `0108`, `0111:36-62`, `class_detail_screen.dart:1480-1530`
- **Engellenen üye roster'dan düşmüyor, anonimleşiyor.** `group_member_directory`
  satırı koruyup kimliği sunucuda boşaltıyor → kamp ateşinde katılımcı sayısı
  bozulmuyor. `supabase_group_repository.dart:288-309` · `0095`/`0115`
- **Sohbette engelleme fail-closed.** Engelli kümesi bilinmiyorsa mesaj
  çizilmiyor; önceki değer varsa onunla süzülüyor. `class_chat_card.dart:67-104`
- **Riverpod 3 "hata taşıyan AsyncLoading" tuzağı iki yerde de kapalı.**
  `group_providers.dart:142-147` ve `group_card_shell.dart:51-56` `.when(error:)`
  yerine `hasError && !hasValue` ölçüyor.
- **Çift gönderim yapısal olarak imkânsız.** Kurma/katılma/yönetici eylemleri
  isteği diyaloğun içinde koşuyor: `onPressed: running ? null : submit` **+**
  `submit` içinde `if (running) return` **+** `barrierDismissible: false` **+**
  `PopScope(canPop: !running)`. `class_switcher.dart:203-246,425-461` ·
  `class_detail_screen.dart:1315-1423`
- **RLS.** `presence` yazımı aktif üyelik istiyor (`0013:27-45`);
  `group_live_presence` okuması aktif üyelik istiyor (`0081:62-65`);
  `user_group_preferences` yalnız sahibine okunur, yazımı RPC
  (`0079:33-41`); `group_members` okuması `is_group_member` ile sınırlı
  (`0001:156-157`).
- **Birincil grup otomatiği tek üyelikte doğru.** `reconcile_user_primary_group`
  tek aktif üyelikte otomatik atıyor, çoklu üyelikte mevcut seçimi koruyor;
  seçim boşsa profil sekmesinde rozet çıkıyor
  (`0079:100-140` · `home_shell.dart:82` · `features/profile/widgets/primary_group_entry.dart:16`).
  13 kişilik tek-grup senaryosunda sessiz kayıp **yok**.
- **Presence kademesi.** `ROLLOUT_PRESENCE_MODE` hiçbir CI/işakışı/script'te
  tanımlı değil → yayınlanan değer `shadow` (`core/config/rollout_config.dart:26`),
  yani legacy + projeksiyon birlikte okunuyor. Sürüm karışıklığında kullanıcılar
  birbirini görmeye devam eder.
- **Dürtme susturması yan kanal sızdırmıyor.** Yaptırım sunucuda; gönderene
  normal satır dönüyor, istemci tercihi okuyamıyor
  (`supabase_nudge_repository.dart:30-44`, `0107_nudge_mutes.sql`).
- **WP-588 ve WP-589 iddiaları koddan doğrulandı** (bugün düzeltilmiş, tekrar
  raporlanmadı): boş keşif ekranı artık kaydırılabilir ve iki çıkış düğmesi
  taşıyor; grup kartları ağ hatasında iskelet yerine "Tekrar dene" veriyor.

---

## Emin olamadıklarım

- K2/K3'teki "ağ hatası sarılmadan çıkar" iddiası, bu deponun kendi ölçümüne
  dayanıyor (`group_error_text.dart:32-36`, `group_discovery_screen.dart:107-111`).
  Ben `postgrest`/`http` paketlerinin kaynağını okumadım, cihazda da
  denemedim — yalnız aynı zincirin sohbet ve dürtme kollarında **kapatılmadığını**
  doğruladım.
- R5'in kullanıcıda görünür karşılığını (aynı ekranda iki farklı "bugün")
  ölçmedim; iki SQL yolunun farklı saat dilimi kullandığını okudum.
- Kamp ateşinin hata dalına gerçekte hangi sıklıkta düşüldüğünü ölçmedim;
  yalnız o dalda çıkış düğmesi olmadığını doğruladım.
