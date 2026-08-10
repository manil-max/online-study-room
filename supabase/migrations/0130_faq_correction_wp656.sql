-- 0130_faq_correction_wp656.sql
-- WP-656 (hunter Lane H): SSS metinlerinin KODA karsi denetimi.
--
-- Sahip 2026-08-10: "SSS'leri guncelleyelim; hem eski yanlis bir sey var mi
-- hem de eksik var mi." Bu migration 9 maddeyi (TR+EN = 18 satir) DUZELTIR ve
-- 6 yeni madde (TR+EN = 12 satir) EKLER.
--
-- 🔴 Her duzeltmenin gerekcesi bir `.md` degil, calistirilabilir koddur:
--
-- D1  Gun siniri "grubunun veya hesabinin zaman dilimi" DEGIL, sabit
--     Europe/Istanbul. `study_stats.dart:10` -> `dayOf = istanbulDay`,
--     `istanbul_calendar.dart:60-62` "urunun tek takvim siniri". Hesap
--     duzeyinde saat dilimi sutunu YOK (profiles/users icinde `time_zone` yok);
--     `resolveStudyDayTimeZone` (`istanbul_calendar.dart:83`) ve
--     `calendarDayInTimeZone` (:66) `app/lib` icinde HIC cagrilmiyor.
--     Grup saat dilimi yalnizca sunucudaki hedef olaylarinda kullanilir
--     (`0112_goal_streak_projection.sql:138`); kisisel kapsamda o dosya da
--     `'Europe/Istanbul'` sabitini yazar (`0112:129`).
--
-- D2  Seri: gunun toplami >= gunluk hedef ise +1 (`study_stats.dart:333-342`);
--     "en uzun seri" ayni esikle ve ARDISIK TAKVIM GUNU ile olculur
--     (`study_stats.dart:407-421`, WP-636/WP-637). Gun siniri yine D1.
--
-- D3  Birincil grup Ayarlar'da DEGIL: giris noktasi Profil ekraninin ust
--     seridindeki `PrimaryGroupAppBarAction`
--     (`social_profile_screen.dart:135`). `settings_screen.dart` icinde hicbir
--     `primaryGroup*` etiketi yok. Ayrica acik degisiklikten sonra sunucu
--     24 saat yeni degisiklige izin vermez
--     (`0085_primary_group_change_cooldown.sql:53`).
--
-- D4  XP tek yonlu degil: kayit silinince sunucu yeniden hesaplar, saat XP'si
--     ve hak edilmeyen kademeler geri gider, tac yeniden hesaplanir
--     (`0126_reconcile_gamification_on_session_delete.sql:184`,
--      `0128_reconcile_fix_unlock_row_and_projection.sql:145`).
--
-- D5  Elle eklenen sure oduller acisindan sayacla AYNI sayilir (ayni
--     `study_sessions` satiri; `manual_session_dialog.dart:112-124`). Fakat
--     oturum gecmisinde ikon farklidir (`session_history_screen.dart:256,271`)
--     -- eski cevap "ilgili akista gosterilir" diyerek soruyu hic
--     cevaplamiyordu, yeni cevap ikisini de soyluyor. Sayac calisirken BUGUNE
--     manuel ekleme engellidir (`manual_session_dialog.dart:101-109`).
--
-- D6  Tek bir "Odak Kampi widget'i" yok: alti widget var
--     (`app/android/app/src/main/res/xml/odak_{timer,clock,alarm,group_goal,
--      leaderboard,stats}_widget_info.xml`). Widget'tan baslatma artik
--     kullanicinin sectigi modu kullanir (`TimerStateStore.nativeStartPlan`,
--     WP-645); eskiden sessizce kronometreye donuyordu.
--
-- D7  🔴 EN AGIR HATA. Tac basarim SAYISI degil TOPLAM XP'dir. Eski cevap
--     `gamification.dart:124-128`'e dayaniyordu; o fonksiyonun urettigi
--     `GamificationSummary.crownTier` alanini HICBIR EKRAN OKUMUYOR
--     (`grep -rn "\.crownTier" app/lib` -> yalniz alan tanimi,
--      `gamification_providers.dart:258`). Kullanicinin GORDUGU tac
--     `crownRankForXp` esikleridir: 0 / 20.000 / 75.000 / 200.000 / 500.000 /
--     1.000.000 (`achievement_ledger_engine.dart:311-317, 358-365`), ekranda
--     `crowned_avatar.dart:252-255` ve `crown_tiers_sheet.dart:19,54-61`.
--
-- D8  🔴 GUVENLIK ETKISI OLAN HATA. "Tekrar giris yaparsan istek iptal olur"
--     YANLIS. Iptalin tek yolu `cancelAccountDeletion` cagrisidir ve onu
--     yalniz kullanicinin kendi dokunusu tetikler
--     (`account_settings_screen.dart:443` ve `:596`). Giris akisinda hicbir
--     cagri yeri yok (`grep -rn "cancelAccountDeletion" app/lib`). Bu cumleye
--     guvenen kullanici hesabini kaybeder.
--
-- D9  Guncelleme yolu Windows'ta farkli: uygulama kendi dosyalarinin uzerine
--     yazamaz, kullanici kapat/ZIP-cikar/exe-calistir adimlarini kendi yapar
--     (`app_tr.arb:2038-2041` `updaterWindows*`).
--
-- YENI MADDELER (145..170) -- hepsi urunde var olan bir yuzeyden turedi:
--   145 Ucret/reklam  : `docs/URUN-POLITIKALARI.md §2` bu cumlenin SSS'e
--                       girmesini SART kosuyor; SSS'te hic yoktu.
--   150 Kayit silme   : `0126`/`0127`/`0128` -- kullanicinin en cok soracagi
--                       yeni davranis, karsiligi yoktu.
--   155 Geri sayim    : `dday_card.dart`, `dday_editor_sheet.dart`,
--                       `kMaxExamEntries = 3` (`dday_prefs.dart:20`); WP-652
--                       ile kart artik "Sinav" demiyor.
--   160 Windows       : `app/lib/features/desktop/**`, `updaterWindows*`,
--                       `authSifirlamaMasaustundeCalismiyorGovde`
--                       (`app_tr.arb:2063`).
--   165 Zorlama yok   : `docs/URUN-POLITIKALARI.md §3` (engelleme/kilit/mola
--                       cezasi/idle tespiti/kolektif ceza YASAK).
--   170 Widget-baslat : `TimerActionReceiver.kt:18-25`, WP-644/645.
--
-- Sema degismez; yalniz icerik. Satirlar sunucudan okundugu icin apply sonrasi
-- yeni APK gerekmez (`supabase_support_repository.dart:16-22`).
--
-- Geri alma (Rollback):
--   delete from public.faq_entries where sort_order in (145,150,155,160,165,170);
--   -- duzeltilen 18 satirin eski metni `0091`/`0123` dosyalarindadir; geri
--   -- almak icin oradaki `answer` degerleri ayni `where` ile yazilir.

-- ---------------------------------------------------------------------------
-- 0) Kapi: duzeltilecek 18 satirin hepsi gercekten var mi?
--    Soru metni degisirse UPDATE sessizce 0 satira dokunur ve migration
--    "basarili" gorunur. O sessiz yol burada kapatiliyor.
-- ---------------------------------------------------------------------------
do $$
declare
  v_missing text;
begin
  select string_agg(t.locale || ' :: ' || t.question, ' | ')
    into v_missing
  from (
    values
      ('tr', 'Ana ekrana widget nasıl eklenir?'),
      ('tr', 'Birincil grup nedir?'),
      ('tr', 'Seri kuralları nasıl çalışır?'),
      ('tr', 'XP nasıl kazanılır?'),
      ('tr', 'Gün ne zaman biter?'),
      ('tr', 'Elle eklenen süre sayılır mı?'),
      ('tr', 'Profilimdeki taç ne anlama geliyor?'),
      ('tr', 'Hesabımı nasıl silerim?'),
      ('tr', 'Güncellemeler nasıl geliyor?'),
      ('en', 'How do I add a home-screen widget?'),
      ('en', 'What is a primary group?'),
      ('en', 'How do streak rules work?'),
      ('en', 'How do I earn XP?'),
      ('en', 'When does the day end?'),
      ('en', 'Does manually added time count?'),
      ('en', 'What does the crown on my profile mean?'),
      ('en', 'How do I delete my account?'),
      ('en', 'How do updates arrive?')
  ) as t(locale, question)
  where not exists (
    select 1 from public.faq_entries e
    where e.locale = t.locale and e.question = t.question
  );

  if v_missing is not null then
    raise exception 'faq_correction_target_missing: %', v_missing;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1) DUZELTMELER (D1..D9) -- TR
-- ---------------------------------------------------------------------------

update public.faq_entries set answer =
  'Telefonunun widget ekleme ekranını aç; orada tek bir widget değil altı '
  'Odak Kampı widget''ı görürsün: sayaç, saat, alarm, grup hedefi, lider '
  'tablosu ve istatistik. Sayaç widget''ındaki başlat düğmesi uygulamada '
  'seçtiğin modu (kronometre, geri sayım veya pomodoro) ve süresini kullanır. '
  'Bildirim izni kapalıysa veya telefonun Odak Kampı''nı pil optimizasyonuna '
  'aldıysa widget güncel kalmayabilir.',
  updated_at = now()
where locale = 'tr' and question = 'Ana ekrana widget nasıl eklenir?';

update public.faq_entries set answer =
  'Birden fazla grubun varsa grup hedefin, grup başarımların ve grup günün '
  'birincil gruba yazılır. Seçimi Profil ekranının üst şeridindeki grup '
  'simgesinden yaparsın — bu ayar Ayarlar ekranında değildir. Birincil '
  'grubunu elle değiştirdikten sonra sunucu 24 saat boyunca yeni bir '
  'değişikliğe izin vermez; kart sana ne zaman değiştirebileceğini yazar.',
  updated_at = now()
where locale = 'tr' and question = 'Birincil grup nedir?';

update public.faq_entries set answer =
  'Bir günün toplam çalışma süresi günlük hedefine ulaşırsa o gün seriye +1 '
  'yazar; ulaşmazsa seri sıfırlanır. "En uzun seri" de aynı eşikle çalışır: '
  'hedefi tutturduğun ardışık takvim günlerinin en uzun dizisidir, toplam '
  'süreyle değil gün sayısıyla ölçülür. Gün sınırı İstanbul saatiyle gece '
  'yarısıdır; cihazının saat dilimi bu sınırı değiştirmez.',
  updated_at = now()
where locale = 'tr' and question = 'Seri kuralları nasıl çalışır?';

update public.faq_entries set answer =
  'XP''yi sunucu hesaplar: tamamladığın her çalışma saati ve açtığın başarım '
  'kademeleri XP yazar; XP satın alınamaz. XP tek yönlü de değildir — bir '
  'çalışma kaydını silersen sunucu kalan oturumlarını yeniden okur, o '
  'kayıttan gelen saat XP''sini ve artık hak edilmeyen başarım kademelerini '
  'geri alır, tacını yeni XP''ne göre günceller.',
  updated_at = now()
where locale = 'tr' and question = 'XP nasıl kazanılır?';

update public.faq_entries set answer =
  'Uygulamanın tek takvim sınırı Europe/Istanbul''dur: gün, İstanbul saatiyle '
  'gece yarısında biter. Bu sınır bilinçli olarak sabittir; cihazının saat '
  'diliminden ve hesabından bağımsızdır, başka bir ülkedeysen de çalışma '
  'günün İstanbul gününe yazılır. Grubun zaman dilimi ayrı bir ayardır ve '
  'yalnız sunucudaki grup hedefi olaylarında kullanılır.',
  updated_at = now()
where locale = 'tr' and question = 'Gün ne zaman biter?';

update public.faq_entries set answer =
  'Evet. Elle eklenen kayıt ödüller açısından sayaçla tutulan süreyle aynı '
  'sayılır: günlük hedefe, seriye, XP''ye, başarımlara ve grup katkına aynı '
  'şekilde girer. Oturum geçmişinde elle eklenen kayıt farklı bir simgeyle '
  'listelenir. İki kez sayılmasın diye, sayaç çalışırken bugüne elle kayıt '
  'eklenemez; geçmiş bir güne her zaman ekleyebilirsin.',
  updated_at = now()
where locale = 'tr' and question = 'Elle eklenen süre sayılır mı?';

update public.faq_entries set answer =
  'Taç, açtığın başarım sayısını değil toplam XP''ni gösterir. Altı kademe '
  'vardır: Bronz Taç 0, Gümüş Taç 20.000, Altın Taç 75.000, Elmas Taç '
  '200.000, Zümrüt Taç 500.000 ve Ölümsüz Taç 1.000.000 XP. Tacına '
  'dokunursan bütün kademeleri, eşiklerini ve hangisinde olduğunu görürsün.',
  updated_at = now()
where locale = 'tr' and question = 'Profilimdeki taç ne anlama geliyor?';

update public.faq_entries set answer =
  'Ayarlar > Hesabımı Yönet > Hesabı sil. Güvenlik için şifreni yeniden '
  'sorar. Silme 14 gün sonrasına planlanır. Dikkat: yalnızca tekrar giriş '
  'yapmak isteği İPTAL ETMEZ. İptal etmek için aynı sayfaya dönüp "Silme '
  'planlandı — iptal et" satırına dokunman gerekir. 14 gün dolduğunda iptal '
  'penceresi kapanır ve hesabın ile kişisel verilerin sunucudan kalıcı olarak '
  'silinir.',
  updated_at = now()
where locale = 'tr' and question = 'Hesabımı nasıl silerim?';

update public.faq_entries set answer =
  'Uygulama şu an mağazadan değil doğrudan yayın sayfasından dağıtılıyor. '
  'Yeni sürüm çıktığında uygulama açılışta haber verir. Android''de indirmeyi '
  'uygulamanın kendisi başlatır. Windows''ta uygulama kendi dosyalarının '
  'üzerine yazamaz, son adımları sen tamamlarsın: Odak Kampı''nı tamamen '
  'kapat, indirdiğin ZIP''i boş bir klasöre çıkar ve oradaki '
  'online_study_room.exe dosyasını çalıştır. Hakkında ekranı sürümünü ve o '
  'sürümde nelerin değiştiğini gösterir.',
  updated_at = now()
where locale = 'tr' and question = 'Güncellemeler nasıl geliyor?';

-- ---------------------------------------------------------------------------
-- 2) DUZELTMELER (D1..D9) -- EN
-- ---------------------------------------------------------------------------

update public.faq_entries set answer =
  'Open your phone''s widget picker: there is not one Focus Camp widget but '
  'six — timer, clock, alarm, group goal, leaderboard and statistics. The '
  'start button on the timer widget uses the mode you picked in the app '
  '(stopwatch, countdown or pomodoro) and its duration. If notification '
  'permission is off, or your phone keeps Focus Camp under battery '
  'optimisation, the widget may stop staying up to date.',
  updated_at = now()
where locale = 'en' and question = 'How do I add a home-screen widget?';

update public.faq_entries set answer =
  'If you belong to more than one group, your group goal, group achievements '
  'and group day are recorded in the primary group. You choose it from the '
  'group icon in the top bar of the Profile screen — it is not in Settings. '
  'After you change it explicitly the server blocks another change for 24 '
  'hours, and the card tells you when you can change it again.',
  updated_at = now()
where locale = 'en' and question = 'What is a primary group?';

update public.faq_entries set answer =
  'If a day''s total study time reaches your daily goal, that day adds +1 to '
  'your streak; otherwise the streak resets. "Longest streak" uses the same '
  'threshold: it is the longest run of consecutive calendar days on which you '
  'met the goal — it counts days, not hours. The day boundary is midnight '
  'Istanbul time and your device time zone does not change it.',
  updated_at = now()
where locale = 'en' and question = 'How do streak rules work?';

update public.faq_entries set answer =
  'The server calculates XP: every study hour you complete and every '
  'achievement tier you unlock writes XP, and XP cannot be bought. XP is not '
  'one-way either — if you delete a study record, the server recomputes from '
  'your remaining sessions, takes back the hour XP from that record and any '
  'achievement tiers you no longer qualify for, and updates your crown to '
  'match the new XP.',
  updated_at = now()
where locale = 'en' and question = 'How do I earn XP?';

update public.faq_entries set answer =
  'The app has a single calendar boundary, Europe/Istanbul: the day ends at '
  'midnight Istanbul time. That boundary is fixed on purpose and does not '
  'depend on your device time zone or your account — if you are in another '
  'country, your study day is still recorded on the Istanbul day. A group '
  'time zone is a separate setting, used only for group goal events on the '
  'server.',
  updated_at = now()
where locale = 'en' and question = 'When does the day end?';

update public.faq_entries set answer =
  'Yes. For rewards a manually added record counts exactly like timer-tracked '
  'time: it feeds the daily goal, the streak, XP, achievements and your group '
  'contribution the same way. In session history a manual record is listed '
  'with a different icon. To stop time being counted twice, you cannot add a '
  'record for today while the timer is running; a past day is always allowed.',
  updated_at = now()
where locale = 'en' and question = 'Does manually added time count?';

update public.faq_entries set answer =
  'The crown reflects your total XP, not how many achievements you have '
  'unlocked. There are six tiers: Bronze Crown at 0, Silver Crown at 20,000, '
  'Golden Crown at 75,000, Diamond Crown at 200,000, Emerald Crown at 500,000 '
  'and Immortal Crown at 1,000,000 XP. Tap your crown to see every tier, its '
  'threshold and where you stand.',
  updated_at = now()
where locale = 'en' and question = 'What does the crown on my profile mean?';

update public.faq_entries set answer =
  'Settings > Manage my account > Delete account. Your password is requested '
  'again for safety. Deletion is scheduled 14 days ahead. Important: simply '
  'signing in again does NOT cancel the request. To cancel it you must come '
  'back to the same page and tap the "Deletion scheduled — cancel" row. Once '
  'the 14 days are over the cancellation window closes and your account and '
  'personal data are permanently removed from the server.',
  updated_at = now()
where locale = 'en' and question = 'How do I delete my account?';

update public.faq_entries set answer =
  'The app is currently distributed from its release page rather than a '
  'store. When a new version is out, the app tells you at launch. On Android '
  'the app starts the download itself. On Windows the app cannot overwrite '
  'its own files, so you finish the last steps: close Focus Camp completely, '
  'extract the downloaded ZIP into an empty folder and run '
  'online_study_room.exe from there. The About screen shows your version and '
  'what changed in it.',
  updated_at = now()
where locale = 'en' and question = 'How do updates arrive?';

-- ---------------------------------------------------------------------------
-- 3) YENI MADDELER (145..170) -- TR + EN birlikte (`0118`/`0123` dersi:
--    `faq_entries` yalniz `locale` ile suzulur, tek dil eklemek digerinde
--    sessiz bir eksik birakir).
--
--    Idempotenslik: tabloda benzersiz kisit YOK (`0091`), bu yuzden
--    `on conflict` korumaz; varlik kontrolu kullanilir.
-- ---------------------------------------------------------------------------

insert into public.faq_entries (locale, question, answer, sort_order, is_published)
select v.locale, v.question, v.answer, v.sort_order, true
from (
  values
    -- ==================== TR ====================
    (
      'tr',
      'Uygulama ücretli mi, reklam var mı?',
      'Hayır. Sayaç, gruplar, istatistikler ve bildirimler kalıcı olarak '
      'ücretsiz ve reklamsızdır. İlerlemeni parayla hızlandıran hiçbir '
      'mekanik yok: XP satın alınamaz, hiçbir çalışma özelliği ödeme duvarının '
      'arkasında değildir. İleride ücretli bir şey gelirse yalnız kozmetik '
      'olur ve çalışarak da kazanılabilir.',
      145
    ),
    (
      'tr',
      'Bir çalışma kaydını silersem XP ve başarımlarıma ne olur?',
      'Kazanımlar da geri gider. Sunucu kalan oturumlarını yeniden okur; o '
      'kayıttan gelen saat XP''si düşer, artık hak edilmeyen başarım '
      'kademeleri kapanır ve tacın yeni XP''ne göre yeniden hesaplanır. '
      'Gerçekten hak ettiğin kademeler yerinde kalır. Böylece sayacı '
      'yanlışlıkla gece boyu açık bırakıp sildiğin bir kayıt profilinde iz '
      'bırakmaz.',
      150
    ),
    (
      'tr',
      'Geri sayım kartı ne işe yarar?',
      'Geri sayım kartı seçtiğin bir tarihe kalan günü ana ekranda gösterir. '
      'Sınav, tatil, doğum günü, teslim tarihi — hangi tarihi girersen onu '
      'sayar; kart tek bir olay türüne bağlı değildir. En fazla üç tarih '
      'tutabilir, her birine ad verebilir ve birini öne çıkarabilirsin. '
      'Tarihleri kartın başlığındaki kalem simgesinden ya da Ayarlar > '
      'Çalışma tercihleri bölümünden düzenlersin.',
      155
    ),
    (
      'tr',
      'Uygulamayı bilgisayarda kullanabilir miyim?',
      'Evet, bir Windows sürümü var ve aynı yayın sayfasından indirilir; '
      'hesabın, oturumların ve grupların ortaktır. İki farkı bilmekte fayda '
      'var: güncellemenin son adımlarını sen yaparsın (uygulamayı kapat, '
      'ZIP''i çıkar, exe''yi çalıştır) ve şifre sıfırlama bağlantısı yalnız '
      'telefondaki Android uygulamasında açılır — şifreni telefonundan '
      'sıfırlayıp bilgisayarda yeni şifrenle giriş yaparsın.',
      160
    ),
    (
      'tr',
      'Uygulama beni çalışmaya zorlar mı, telefonumu kilitler mi?',
      'Hayır. Odak Kampı başka uygulamaları engellemez, telefonunu '
      'kilitlemez, mola verdiğin için ilerlemeni silmez ve boşta kalıp '
      'kalmadığını izlemez. Grup mekaniklerinde kolektif ceza da yoktur: bir '
      'kişinin eksik günü yüzünden herkesin ilerlemesi silinmez. Bu bir '
      'eksiklik değil, bilerek verilmiş bir üründür kararıdır.',
      165
    ),
    (
      'tr',
      'Sayacı uygulamayı açmadan başlatıp durdurabilir miyim?',
      'Evet. Sayaç widget''ındaki düğme ve sayaç çalışırken bildirim '
      'alanındaki düğmeler sayacı başlatır, duraklatır ve durdurur. Bu '
      'yollardan başlattığında da uygulamada seçtiğin mod ve süre kullanılır: '
      'pomodoro seçiliyse molalar yine gelir, mod sessizce kronometreye '
      'dönmez. Bildirim izni kapalıysa bu düğmeler görünmez.',
      170
    ),
    -- ==================== EN ====================
    (
      'en',
      'Is the app paid? Are there ads?',
      'No. The timer, groups, statistics and notifications are permanently '
      'free and ad-free. Nothing speeds up your progress for money: XP cannot '
      'be bought and no study feature sits behind a paywall. If anything paid '
      'ever arrives it will be cosmetic only, and earnable by studying.',
      145
    ),
    (
      'en',
      'What happens to my XP and achievements if I delete a study record?',
      'The rewards are taken back too. The server recomputes from your '
      'remaining sessions: the hour XP from that record is removed, '
      'achievement tiers you no longer qualify for are closed, and your crown '
      'is recalculated from the new XP. Tiers you genuinely earned stay. So a '
      'record you deleted because the timer ran all night leaves no trace on '
      'your profile.',
      150
    ),
    (
      'en',
      'What is the countdown card for?',
      'The countdown card shows the days left until a date you choose, on the '
      'home screen. An exam, a holiday, a birthday, a deadline — it counts '
      'whatever date you enter and is not tied to one kind of event. You can '
      'keep up to three dates, name each one and feature one of them. Edit '
      'them from the pencil icon in the card header or from Settings > Study '
      'preferences.',
      155
    ),
    (
      'en',
      'Can I use the app on a computer?',
      'Yes, there is a Windows build and it is downloaded from the same '
      'release page; your account, sessions and groups are shared. Two '
      'differences are worth knowing: you finish the last update steps '
      'yourself (close the app, extract the ZIP, run the exe), and the '
      'password reset link only opens in the Android app on your phone — '
      'reset it there, then sign in on the computer with the new password.',
      160
    ),
    (
      'en',
      'Will the app force me to study or lock my phone?',
      'No. Focus Camp does not block other apps, does not lock your phone, '
      'does not erase your progress because you took a break and does not '
      'watch whether you are idle. There is no collective punishment in the '
      'group mechanics either: nobody loses progress because someone else '
      'missed a day. This is a deliberate product decision, not a missing '
      'feature.',
      165
    ),
    (
      'en',
      'Can I start and stop the timer without opening the app?',
      'Yes. The button on the timer widget, and the buttons in the timer '
      'notification while it runs, start, pause and stop the timer. Starting '
      'from there uses the mode and duration you picked in the app: if '
      'pomodoro is selected the breaks still arrive and the mode is not '
      'silently switched to stopwatch. If notification permission is off, '
      'those buttons do not appear.',
      170
    )
) as v(locale, question, answer, sort_order)
where not exists (
  select 1
  from public.faq_entries existing
  where existing.locale = v.locale
    and existing.question = v.question
);
