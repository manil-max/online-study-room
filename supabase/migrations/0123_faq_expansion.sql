-- 0123_faq_expansion.sql
-- WP-522: SSS içeriği genişletme (sahip v60 cihaz geri bildirimi).
--
-- Sahip 2026-08-08'de v60'ı telefonda denedikten sonra: "SSS kısmında daha
-- fazla soru cevap olabilir, eksik bence şuanda." `0091` 12 + `0118` 1 satır
-- eklemişti; bu migration her dile **20 satır** daha ekliyor (toplam 33/dil).
--
-- 🔴 Cevaplar plandan değil KODDAN yazıldı. Her satırın dayanağı:
--   * davet kodu 6 karakter, I/L/O/0/1 yok   → 0012_group_join_hardening.sql:35-41
--   * sayaç modları kronometre/geri sayım/pomodoro → study_providers.dart:187
--   * "Durduruluyor…" aşaması (sunucuya yazma) → study_timer_card.dart:399
--   * günlük hedef sayaç kartındaki satıra dokunarak → study_timer_card.dart:638
--   * grup hedefi yalnız yöneticide                → class_detail_screen.dart:197
--   * taç: 2 başarım bronz / 3 gümüş / 4+ altın   → gamification.dart:124-128
--   * ad sınırı kişi 24 grup 30                    → 0122_name_length_limits.sql
--   * dürtme susturma üye satırındaki simgede      → class_detail_screen.dart:1204
--   * sohbet üst şeritteki simgeden tam ekran      → classroom_screen.dart:271-275
--   * mesaja uzun basınca bildir/engelle sayfası   → class_chat_card.dart:200-226
--   * hesap silme Ayarlar > Hesabımı yönet altında → settings_screen.dart:208
--   * sekme adları Ana Sayfa/Araçlar/Gruplar/İstatistik/Profil → home_shell.dart:181-197
-- Bu dayanaklar değişirse ilgili SSS satırı da değişmelidir; yanlış SSS
-- destek yükü üretir.
--
-- 🔴 TR ve EN **birlikte** eklenir (`0118`'in dersi). `faq_entries` yalnız
-- `locale` sütununa göre süzülür; tek dil eklemek diğer dilde sessiz bir
-- eksik bırakır. `048_faq_expansion.test.sql` iki dilin sayısını eşitliyor.
--
-- Sıralama: mevcut satırlar 10,15,20,...,120 değerlerinde. Yeni satırlar
-- **aradaki boşluklara** yerleştirildi; hiçbir mevcut satır güncellenmiyor.
--
-- Idempotenslik: `0091` tabloyu benzersiz kısıtsız kurdu, bu yüzden
-- `on conflict do nothing` işe yaramaz. `0118` gibi varlık kontrolü kullanılır.
--
-- Bu migration **yalnız içerik** ekler; şema değişmez. SSS satırları
-- sunucudan okunduğu için apply sonrası yeni APK gerekmez — v60 kurulu
-- cihazda ekran yenilenince görünür.
--
-- Geri alma (Rollback):
--   delete from public.faq_entries where sort_order in (
--     2,4,6,8,12,22,25,35,45,55,65,75,85,95,105,115,125,130,135,140
--   ) and created_at >= '2026-08-08';

insert into public.faq_entries (locale, question, answer, sort_order, is_published)
select v.locale, v.question, v.answer, v.sort_order, true
from (
  values
    -- ==================== TR ====================
    (
      'tr',
      'Uygulamaya nasıl başlarım?',
      'Gruplar sekmesinden yeni bir grup oluştur ya da arkadaşının davet '
      'koduyla var olan bir gruba katıl. Davet kodu 6 karakterdir ve '
      'karıştırılan harfleri (I, L, O, 0, 1) içermez. Grup olmadan da sayacı '
      'çalıştırabilirsin; seri, lider tablosu ve kamp ateşi gruplu kullanımda '
      'anlam kazanır.',
      2
    ),
    (
      'tr',
      'Sayacın modları ne işe yarar?',
      'Üç mod var. Kronometre yukarı doğru sayar, ne kadar çalıştığını '
      'ölçer. Geri sayım verdiğin süreden aşağı iner. Pomodoro çalışma ve '
      'mola fazlarını sırayla yürütür; her faz bitişinde uyarır. Modu sayaç '
      'kartının üstündeki seçiciden değiştirirsin.',
      4
    ),
    (
      'tr',
      'Uygulamayı kapatınca sayaç durur mu?',
      'Durmaz. Sayaç çalışırken Android bildirim alanında canlı bir süre '
      'gösterilir ve uygulama arka plana alınsa da sayma devam eder. '
      'Telefonu yeniden başlatırsan ya da sistem uygulamayı zorla kapatırsa '
      'süre son bilinen noktadan sunucuyla eşitlenir.',
      6
    ),
    (
      'tr',
      'Durdur''a bastığımda neden kısa bir bekleme oluyor?',
      'Durdur, oturumu sunucuya yazar ve doğrulanmasını bekler; bu sırada '
      'düğme "Durduruluyor…" durumuna geçer ve dönen bir halka gösterir. '
      'Bekleme ağ hızına bağlıdır, genelde bir iki saniyedir. Süren '
      'kaybolmaz: yazma tamamlanınca kayıt kesinleşir.',
      8
    ),
    (
      'tr',
      'Günlük hedefimi nasıl değiştiririm?',
      'Sayaç kartındaki "Günlük hedef" satırına dokun ve yeni süreyi seç. '
      'Bu senin kişisel hedefindir. Grubun ortak hedefini yalnız grup '
      'yöneticisi değiştirir (grup ekranındaki kalem simgesi).',
      12
    ),
    (
      'tr',
      'Sayaç bildirimini göremiyorum, ne yapmalıyım?',
      'Önce bildirim iznini ver: telefon ayarlarında Odak Kampı için '
      'bildirimler açık olmalı. Bazı markalarda ayrıca pil optimizasyonundan '
      'çıkarman gerekir, aksi halde sistem bildirimi yenilemeyi durdurabilir. '
      'İkisi de açıkken sayaç çalıştığı sürece bildirim canlı kalır.',
      22
    ),
    (
      'tr',
      'Kamp ateşi nedir?',
      'Kamp ateşi, grubundaki kişilerin o an çalışıp çalışmadığını tek '
      'bakışta gösteren sahnedir; Gruplar sekmesinde bulunur. Herkes '
      'seçtiği hayvanla ateşin başında durur; çalışan kişiler ayrı görünür. '
      'Kendi hayvanını Ayarlar > Kamp hayvanın bölümünden değiştirirsin.',
      25
    ),
    (
      'tr',
      'Grup sohbeti nerede?',
      'Gruplar sekmesinin üst şeridindeki sohbet simgesine dokun; sohbet tam '
      'ekran açılır, uzun yazışmada okumak kolaylaşır. Bir mesaja uzun '
      'basarsan bildir ve engelle seçenekleri çıkar.',
      35
    ),
    (
      'tr',
      'Ad yazarken neden bir yerde duruyor?',
      'Adlar için üst sınır var: kişi adı 24, grup adı 30 karakter. Sınır '
      'hem uygulamada hem sunucuda uygulanır, yani daha uzun bir ad '
      'kaydedilemez. Amaç saçma uzunluktaki adların listeleri ve grup '
      'başlıklarını bozmasını engellemek.',
      45
    ),
    (
      'tr',
      'Grup yöneticisi ne yapabilir?',
      'Grubun günlük hedefini değiştirir, davet kodunu yeniler (eski kod o '
      'anda geçersiz olur), üyeyi gruptan çıkarır veya tekrar katılamayacak '
      'şekilde yasaklar. Grubu kuran kişi baştan yöneticidir.',
      55
    ),
    (
      'tr',
      'Bir kişinin dürtmelerini nasıl susturursum?',
      'Grup ekranındaki üye satırında bildirim-kapalı simgesine dokun; '
      'susturulan üyede simge dolu ve vurgulu görünür. Susturmak engellemek '
      'değildir: kişinin mesajları, profili ve gruptaki varlığı normal '
      'kalır, yalnız dürtmesi sana ulaşmaz. Listeyi Ayarlar > Dürtmesi '
      'susturulanlar bölümünden yönetirsin.',
      65
    ),
    (
      'tr',
      'Profilimdeki taç ne anlama geliyor?',
      'Taç, açtığın başarım sayısını gösterir: 2 başarımda bronz, 3 '
      'başarımda gümüş, 4 ve üzerinde altın taç. Hangi başarımın hangi '
      'koşulla açıldığını Başarımlar ekranında görebilirsin.',
      75
    ),
    (
      'tr',
      'Uygulamanın görünümünü değiştirebilir miyim?',
      'Evet. Ayarlar > Görünüm ve atmosfer bölümünde hazır temalar var; '
      'ayrıca "Kendi Temanı Oluştur" ile renk ve atmosferini kendin '
      'kurabilir, kaydedip uygulayabilirsin. Açık/koyu tema modu da aynı '
      'bölümdedir.',
      85
    ),
    (
      'tr',
      'İstatistiklerimi ve geçmiş oturumlarımı nerede görürüm?',
      'Genel görünüm için İstatistik sekmesine bak: günlük, haftalık ve '
      'grup kırılımlarını orada bulursun. Tek tek oturumları görmek, '
      'birini silmek veya elle kayıt eklemek için Profil ekranındaki '
      'oturum geçmişini aç.',
      95
    ),
    (
      'tr',
      'Rahatsız eden birini nasıl bildirir veya engellerim?',
      'Mesajı, profili ya da grubu bildirmek için ilgili ekrandaki bildir '
      'seçeneğini kullan; istersen ekran görüntüsü ekleyebilirsin. '
      'Engellemek kişinin sana ulaşmasını kapatır. Engellediklerini '
      'Ayarlar > Engellenen kullanıcılar bölümünden geri alabilirsin.',
      105
    ),
    (
      'tr',
      'Verilerimi indirebilir miyim?',
      'Evet. Ayarlar > Verilerimi dışa aktar ile profilin, oturumların ve '
      'grup bilgilerin makine okunur bir dosya olarak indirilir. Dosyayı '
      'telefonunda saklayabilir veya paylaşabilirsin.',
      115
    ),
    (
      'tr',
      'Hesabımı nasıl silerim?',
      'Ayarlar > Hesabımı yönet > Hesabı sil. Güvenlik için şifreni yeniden '
      'sorar. Silme isteği 14 günlük bir bekleme süresiyle başlar; bu süre '
      'içinde tekrar giriş yaparsan istek iptal olur. Süre dolduğunda '
      'hesabın ve kişisel verilerin sunucudan kalıcı olarak silinir.',
      125
    ),
    (
      'tr',
      'Şifremi unuttum, ne yapmalıyım?',
      'Giriş ekranındaki "Şifremi unuttum"a dokun ve hesabının e-posta '
      'adresini yaz. Gelen e-postadaki bağlantıya telefonundan dokunursan '
      'uygulama yeni şifre ekranıyla açılır. E-posta gelmezse gereksiz '
      '(spam) klasörüne bak.',
      130
    ),
    (
      'tr',
      'Güncellemeler nasıl geliyor?',
      'Uygulama şu an mağazadan değil, doğrudan yayın sayfasından '
      'dağıtılıyor. Yeni sürüm çıktığında uygulama açılışta haber verir ve '
      'indirmeyi başlatabilirsin. Hakkında ekranından sürümünü ve o '
      'sürümde nelerin değiştiğini görebilirsin.',
      135
    ),
    (
      'tr',
      'Araçlar sekmesinde ne var?',
      'Araçlar sekmesi çalışma dışındaki yardımcıları toplar: alarm, '
      'bağımsız zamanlayıcı ve görev listesi. Bunlar çalışma oturumundan '
      'ayrıdır; buradaki zamanlayıcı çalışma süresi olarak sayılmaz.',
      140
    ),
    -- ==================== EN ====================
    (
      'en',
      'How do I get started?',
      'From the Groups tab, create a new group or join an existing one with '
      'a friend''s invite code. Invite codes are 6 characters and never '
      'contain the confusable characters I, L, O, 0 or 1. You can run the '
      'timer without a group, but streaks, the leaderboard and the campfire '
      'only make sense with one.',
      2
    ),
    (
      'en',
      'What are the timer modes for?',
      'There are three. Stopwatch counts up and measures how long you '
      'studied. Countdown runs down from a duration you set. Pomodoro runs '
      'work and break phases in turn and alerts you at the end of each '
      'phase. Switch modes from the selector at the top of the timer card.',
      4
    ),
    (
      'en',
      'Does the timer stop when I close the app?',
      'No. While the timer runs, Android shows a live duration in the '
      'notification area and counting continues in the background. If you '
      'restart the phone or the system force-stops the app, the time is '
      'synced with the server from the last known point.',
      6
    ),
    (
      'en',
      'Why is there a short wait when I press Stop?',
      'Stop writes the session to the server and waits for it to be '
      'confirmed; during that the button shows "Stopping…" with a spinner. '
      'The wait depends on your connection and is usually a second or two. '
      'Your time is not lost: the record is final once the write completes.',
      8
    ),
    (
      'en',
      'How do I change my daily goal?',
      'Tap the "Daily goal" row on the timer card and pick a new duration. '
      'That is your personal goal. Only the group admin can change the '
      'shared group goal (the pencil icon on the group screen).',
      12
    ),
    (
      'en',
      'I cannot see the timer notification, what should I do?',
      'First grant the notification permission: notifications for Focus '
      'Camp must be enabled in your phone settings. On some brands you also '
      'need to exclude the app from battery optimisation, otherwise the '
      'system can stop refreshing the notification. With both enabled the '
      'notification stays live while the timer runs.',
      22
    ),
    (
      'en',
      'What is the campfire?',
      'The campfire is a scene in the Groups tab that shows at a glance who '
      'in your group is studying right now. Everyone stands by the fire as '
      'their chosen animal, and people who are studying look different. '
      'Change your own animal in Settings > Camp animal.',
      25
    ),
    (
      'en',
      'Where is the group chat?',
      'Tap the chat icon in the top bar of the Groups tab; the chat opens '
      'full screen, which makes long conversations easier to read. Press and '
      'hold a message to get the report and block options.',
      35
    ),
    (
      'en',
      'Why does typing a name stop at some point?',
      'Names have an upper limit: 24 characters for a person, 30 for a '
      'group. The limit is enforced both in the app and on the server, so a '
      'longer name cannot be saved. The point is to keep absurdly long '
      'names from breaking lists and group headers.',
      45
    ),
    (
      'en',
      'What can a group admin do?',
      'Change the group daily goal, regenerate the invite code (the old '
      'code stops working immediately), remove a member, or ban a member so '
      'they cannot rejoin. Whoever created the group is admin from the '
      'start.',
      55
    ),
    (
      'en',
      'How do I mute someone''s nudges?',
      'Tap the notifications-off icon on their row in the group screen; for '
      'a muted member the icon is filled and highlighted. Muting is not '
      'blocking: their messages, profile and presence in the group stay '
      'normal, only their nudges stop reaching you. Manage the list in '
      'Settings > Muted nudges.',
      65
    ),
    (
      'en',
      'What does the crown on my profile mean?',
      'The crown reflects how many achievements you have unlocked: bronze '
      'at 2, silver at 3, gold at 4 or more. The Achievements screen shows '
      'which condition unlocks each one.',
      75
    ),
    (
      'en',
      'Can I change how the app looks?',
      'Yes. Settings > Appearance and atmosphere has ready-made themes, and '
      '"Create your own theme" lets you build your own colours and '
      'atmosphere, then save and apply it. Light/dark theme mode is in the '
      'same section.',
      85
    ),
    (
      'en',
      'Where do I see my statistics and past sessions?',
      'For the overview, open the Statistics tab: daily, weekly and '
      'per-group breakdowns are there. To see individual sessions, delete '
      'one, or add a record manually, open the session history from the '
      'Profile screen.',
      95
    ),
    (
      'en',
      'How do I report or block someone?',
      'Use the report option on the relevant screen to report a message, a '
      'profile or a group; you can attach a screenshot. Blocking stops that '
      'person from reaching you. You can undo blocks in Settings > Blocked '
      'users.',
      105
    ),
    (
      'en',
      'Can I download my data?',
      'Yes. Settings > Export my data downloads your profile, sessions and '
      'group information as a machine-readable file. You can keep it on '
      'your phone or share it.',
      115
    ),
    (
      'en',
      'How do I delete my account?',
      'Settings > Manage my account > Delete account. Your password is '
      'requested again for safety. The request starts a 14-day waiting '
      'period; signing in again during it cancels the request. When the '
      'period ends, your account and personal data are permanently removed '
      'from the server.',
      125
    ),
    (
      'en',
      'I forgot my password, what now?',
      'Tap "Forgot my password" on the sign-in screen and enter your '
      'account e-mail. Opening the link from the e-mail on your phone takes '
      'you straight to the new-password screen. If the e-mail does not '
      'arrive, check your spam folder.',
      130
    ),
    (
      'en',
      'How do updates arrive?',
      'The app is currently distributed from its release page rather than a '
      'store. When a new version is out, the app tells you at launch and '
      'you can start the download. The About screen shows your version and '
      'what changed in it.',
      135
    ),
    (
      'en',
      'What is in the Tools tab?',
      'The Tools tab collects helpers outside studying: an alarm, a '
      'standalone timer and a task list. They are separate from study '
      'sessions — the timer there does not count as study time.',
      140
    )
) as v(locale, question, answer, sort_order)
where not exists (
  select 1
  from public.faq_entries existing
  where existing.locale = v.locale
    and existing.question = v.question
);
