# V58 · "Yükleniyor = veri yok" taraması (WP-495)

> **Kapsam:** `app/lib/**` içindeki **194** `AsyncValue` okuma yeri.
> Bu belge WP-495'in tarama çıktısıdır: her kullanım *zararsız / izlenecek /
> düzeltilecek* diye sınıflanır. **Düzeltmelerin çoğu bu kartta değildir** —
> WP-495 yalnız `crowned_avatar.dart` + `active_members_card.dart` dosyalarını
> sahiplenir; kalanlar buradan ayrı WP olarak alınır.
>
> Kaynak belirti: `docs/V58-SAHIP-GERI-BILDIRIM-RAPORU.md` N02 (açılışta
> "Grup Oluştur" flaşı) ve N07 (aktif üye listesi boş görünüyor);
> teknik bulgu T04.

## 1. Riverpod 3'te durumun ölçülmüş davranışı

WP kartı "`asData` **her yenilemede** null döner" diyordu. Riverpod 3.3.2'de
ölçülen davranış bundan dar: durum sınıfı tetikleyiciye göre değişiyor.

| Tetikleyici | Durum sınıfı | `hasValue` | `asData` | `value` |
|---|---|---|---|---|
| İlk yükleme | `AsyncLoading` | `false` | `null` | `null` |
| `invalidate(provider)` (pull-to-refresh) | `AsyncData` | `true` | **dolu** | önceki |
| İzlenen bağımlılık değişti (`ref.watch`) | `AsyncLoading` | `true` | **null** | **önceki** |

Sonuçlar:

1. `asData?.value` yalnız **üçüncü** satırda veri kaybeder — fakat orada
   kullanıcı gözünde içerik gerçekten kaybolur (taç söner, rozet 0'a düşer).
2. `valueOrNull` **Riverpod 3'te yoktur** (v3'te kaldırıldı); doğru yazım
   `value`'dur ve o zaten null-güvenlidir. WP kartındaki adım bu şekilde
   uygulandı.
3. `.value ?? const []` yenilemeye dayanıklıdır; **ilk yüklemede** yanlış boş
   durum üretir. Bu belgedeki bulguların çoğu bu üçüncü kalıptır.

Ölçüm, `async_empty_state_wp495_test.dart` içindeki taç testine iddia olarak
gömüldü: test önce durumun gerçekten `AsyncLoading + hasValue` olduğunu
doğrular, sonra tacın durduğunu ölçer. Aksi hâlde iddia sessizce yeşil kalırdı.

## 2. Sınıflandırma kuralı

| Sınıf | Ölçüt |
|---|---|
| **Düzeltilecek** | Widget, veri gelmeden kullanıcıya **yanlış bir iddia** çiziyor: "grubun yok", "kayıt yok", boş grafik, 0 sayaç, ya da eksik veriyle dosya üretiyor. |
| **İzlenecek** | Yanlış iddia var ama tek karelik ve düşük etkili (rozet gecikmesi, seçici listesi), ya da düzeltmesi başka bir WP'nin dosyasında. |
| **Zararsız** | Değer yalnız bir karar için okunuyor; kullanıcıya boş durum çizilmiyor. |

Zararsız sınıfı üç kurala dayanır:

- R1 · `authStateProvider` — oturum kabuğu kullanıcı gelmeden sekme kurmaz; `null` yalnız 'oturum yok' demektir.
- R2 · Mantık katmanı (`data/providers`, `core`) — değer bir karar için okunur, kullanıcıya boş durum çizilmez.
- R3 · `ref.read` + kullanıcı eylemi — düğmeye basıldığında veri zaten yüklü.

## 3. Sayılar

| Sınıf | Yer sayısı |
|---|---|
| Düzeltildi (WP-495) | 4 |
| Düzeltilecek (ayrı WP) | 29 |
| İzlenecek | 35 |
| Zararsız | 126 |
| **Toplam** | **194** |

Desen dağılımı: `asData` 25 ·
`.value ?? boş` 53 ·
`.value` 116.

## 4. Düzeltildi — WP-495

| Yer | Desen | Kullanıcının gördüğü |
|---|---|---|
| `core/widgets/crowned_avatar.dart:464` | `.value` | Taç, provider bağımlılık değişimiyle yeniden yüklenirken bir kare kayboluyordu. |
| `features/home/widgets/active_members_card.dart:34` | `.value` | Grup yüklenirken 'Grup Oluştur' daveti flaşı (V58-N02). |
| `features/home/widgets/active_members_card.dart:56` | `.value ?? boş` | Presence yüklenirken 'Şu an çalışan kimse yok' (V58-N07). |
| `features/home/widgets/active_members_card.dart:57` | `.value ?? boş` | Üyeler yüklenirken satırlar 'İsimsiz'. |

## 4b. WP-495B kapanış durumu (2026-08-06)

Aşağıdaki §5 listesi WP-495B ile **kısmen** kapatıldı. Kapananlar:

| Yer | Ne yapıldı |
|---|---|
| `leaderboard_card:29` · `group_goal_card:64` · `group_trend_card:25` | Ortak `groupCardGate` kapısı: yükleniyorken iskelet, hata → metin, gerçekten grup yoksa davet. `active_members_card` da aynı kapıya taşındı — tek uygulama. |
| `stats_screen:99` | Sınıf sekmesi yükleniyorken "bir gruba katıl" demiyor; sekmenin geri kalanı gibi spinner/hata. |
| `stats_screen:87` · `home_shell:84` · `home_shell:103,108` | `asData` → `value`: özet, ödül rozeti ve sekme çubuğundaki taç yeniden yüklemede kaybolmuyor. |
| `data_export_screen:43-48` | `asData?.value ?? []` yerine `await …future`: dışa aktarma artık veriyi bekliyor, eksik dosya üretmiyor. |
| `class_chat_card:71` | Engelli kümesi gelmeden mesaj çizilmiyor (sohbet süzgeci **yalnız istemcide**). Hata dalı bilerek beklemez: küme çağrısı düşerse sohbet kapanmak yerine eski davranışa döner. |

**Kapatılmayan iki gizlilik satırı — gerekçesiyle düşürüldü.**
`campfire_scene:84` ve `class_stats_view:100` ilk taramada "gizlilik" diye
işaretlenmişti. Sunucu sözleşmesi okununca bu **yanlış** çıktı:
`group_member_directory` satırı döndürürken engellenen üyenin
adını/avatarını/hayvanını zaten boşaltıyor (`0095`, `0115`) — gerçek ad istemciye
hiç ulaşmıyor. Sahneyi ve sıralamayı bu ek ağ çağrısına bağlamak ana ekranın
kritik yoluna spinner ekliyor ve **27 mevcut testi** kırıyordu. İkisi de
`İzlenecek`e indirildi.

`session_history_screen:30` de düşürüldü: `hasGroup` bir kare `false` olunca
filtre **geç görünüyor**, yanlış bir iddia üretmiyor.

Kalan `Düzeltilecek` satırları (11 pano kartının boş grafik/0 dk göstermesi)
**WP-495C**'ye bırakıldı: her biri kendi yükleme iskeletini gerektiriyor, yani
tek satırlık değil kart tasarımı işidir ve WP-495'in "kart tasarımları kapsam
dışı" kuralına girer.

## 4c. WP-495C kapanış durumu (2026-08-06)

§5 listesinin kalan tamamı — **13 pano kartı** — WP-495C ile kapandı. Ortak
`cardDataGate` kapısı (`app/lib/features/home/widgets/card_data_gate.dart`):
kaynakların hepsi ilk verisini verene kadar başlığı koruyan bir yer tutucu
çizilir, hata ayrı metinle gösterilir.

| Kart | Yükleme karesinde eskiden ne yazıyordu |
|---|---|
| `today_summary_card` | **"Bugün henüz çalışma kaydın yok. Sayaçtan başla!"** (kırık girdiyle ölçüldü) |
| `records_card` | Boş rekor döşemeleri |
| `heatmap_card` · `rhythm_card` · `scatter_card` · `hour_activity_card` | Tamamen boş grafik |
| `weekly_chart_card` · `line_chart_card` | Düz/boş çizgi = "hiç çalışmadın" |
| `period_summary_card` · `weekday_weekend_card` | 0 dk · 0 gün |
| `leaderboard_card` · `group_goal_card` · `group_trend_card` | Boş sıralama · %0 halka · düz trend |

Böylece §5'te açık madde kalmadı; tablo tarihsel kayıt olarak duruyor.

## 5. Düzeltilecek — ayrı WP gerekiyor (WP-495B/C ile kapandı)

🔴 **En önemli bulgu:** sahibin gördüğü "Grup Oluştur" flaşı **tek kartta
değil**. `active_members_card` düzeltildi, fakat `leaderboard_card`,
`group_goal_card`, `group_trend_card` ve `stats_screen` aynı dalı aynı biçimde
çiziyor. Bu dört yer düzeltilmeden belirti cihazda **sürer**; hepsi WP-495'in
SAHİP listesi dışında olduğu için burada bildiriliyor.

İkinci sırada `data_export_screen`: orada sorun kozmetik değil — kullanıcı
verisi eksik dışa aktarılabilir.

| Yer | Desen | Kullanıcının gördüğü |
|---|---|---|
| `core/navigation/home_shell.dart:84` | `asData?.value` | Ödül rozeti yeniden yüklemede bir kare 0'a düşer. |
| `core/navigation/home_shell.dart:108` | `asData?.value` | Sekme çubuğundaki taç — `crowned_avatar` ile **birebir aynı** hata, farklı dosya. |
| `features/classroom/widgets/campfire_scene.dart:81` | `.value ?? boş` | Kamp ateşi bir kare tamamen boş (hiç hayvan yok). |
| `features/classroom/widgets/campfire_scene.dart:84` | `.value ?? boş` | 🔴 Engelli listesi boş sayılıyor → engellenen kişi bir kare sahnede görünür (gizlilik). |
| `features/classroom/widgets/class_chat_card.dart:71` | `.value ?? boş` | 🔴 Aynı gizlilik sızıntısı: engellenen kişinin mesajı bir kare görünür. |
| `features/home/widgets/group_goal_card.dart:64` | `.value` | Aynı davet flaşı (üçüncü kaynak). |
| `features/home/widgets/group_goal_card.dart:73` | `.value ?? boş` | Grup hedefi bir kare %0. |
| `features/home/widgets/group_trend_card.dart:25` | `.value` | Aynı davet flaşı (dördüncü kaynak). |
| `features/home/widgets/group_trend_card.dart:34` | `.value ?? boş` | Trend grafiği bir kare düz çizgi. |
| `features/home/widgets/heatmap_card.dart:19` | `.value ?? boş` | Isı haritası bir kare tamamen boş. |
| `features/home/widgets/hour_activity_card.dart:21` | `.value ?? boş` | Saat dağılımı bir kare boş. |
| `features/home/widgets/leaderboard_card.dart:29` | `.value` | `userGroupProvider` null → 'Grup Oluştur' daveti; sahibin gördüğü flaşın ikinci kaynağı. |
| `features/home/widgets/leaderboard_card.dart:39` | `.value ?? boş` | Sıralama bir kare boş. |
| `features/home/widgets/leaderboard_card.dart:40` | `.value ?? boş` | Sıralama isimleri bir kare eksik. |
| `features/home/widgets/leaderboard_card.dart:43` | `.value ?? boş` | Alfa skorları bir kare 0. |
| `features/home/widgets/line_chart_card.dart:29` | `.value ?? boş` | Çizgi grafiği bir kare boş. |
| `features/home/widgets/period_summary_card.dart:45` | `.value ?? boş` | Dönem özeti bir kare 0. |
| `features/home/widgets/records_card.dart:19` | `.value ?? boş` | 'Kayıt yok' — kayıt varken. |
| `features/home/widgets/rhythm_card.dart:20` | `.value ?? boş` | Ritim kartı bir kare boş. |
| `features/home/widgets/scatter_card.dart:20` | `.value ?? boş` | Dağılım bir kare boş. |
| `features/home/widgets/today_summary_card.dart:23` | `.value ?? boş` | Bugün özeti bir kare 0 dk. |
| `features/home/widgets/weekday_weekend_card.dart:21` | `.value ?? boş` | Hafta içi/sonu bir kare 0. |
| `features/home/widgets/weekly_chart_card.dart:29` | `.value ?? boş` | Haftalık grafik bir kare boş. |
| `features/profile/data_export_screen.dart:43` | `asData?.value` | 🔴 Dışa aktarma **eksik veriyle** dosya üretebilir; yükleme beklenmiyor. |
| `features/profile/data_export_screen.dart:45` | `asData?.value` | 🔴 Aynı: dersler eksik dışa aktarılır. |
| `features/profile/data_export_screen.dart:46` | `asData?.value` | 🔴 Aynı: özet null dışa aktarılır. |
| `features/profile/data_export_screen.dart:48` | `asData?.value` | 🔴 Aynı: XP null dışa aktarılır. |
| `features/profile/session_history_screen.dart:30` | `.value` | `hasGroup` bir kare false → grup filtresi görünmez. |
| `features/stats/stats_screen.dart:99` | `.value` | 'Grup istatistiklerini görmek için bir gruba katıl' — grubu olan kullanıcıya da gösterilir. |

## 6. İzlenecek

| Yer | Desen | Kullanıcının gördüğü |
|---|---|---|
| `data/providers/analytics_query_providers.dart:44` | `asData?.value` | Sıcak önbellek boşsa sorgu ağa düşer; kullanıcıya yanlış iddia yok. |
| `data/providers/analytics_query_providers.dart:76` | `asData?.value` | Aynı. |
| `data/providers/analytics_query_providers.dart:105` | `asData?.value` | Aynı. |
| `data/providers/analytics_query_providers.dart:121` | `asData?.value` | Aynı. |
| `data/providers/group_providers.dart:95` | `.value` | Birincil grup tercihi yüklenmeden 'seçili grup yok' sayılır. |
| `data/providers/notification_providers.dart:50` | `.value ?? boş` | Okunmamış duyuru sayısı bir kare eksik. |
| `data/providers/notification_providers.dart:51` | `.value ?? boş` | Aynı. |
| `data/providers/study_providers.dart:142` | `.value ?? boş` | Türetilmiş provider: boş oturum listesi tüketici kartlara 'veri yok' olarak iner. |
| `data/providers/study_providers.dart:162` | `.value ?? boş` | Aynı zincir. |
| `data/providers/study_providers.dart:173` | `.value ?? boş` | Aynı zincir. |
| `data/providers/study_providers.dart:181` | `.value ?? boş` | Aynı zincir (grup günlük istatistiği). |
| `features/classroom/widgets/class_detail_screen.dart:859` | `.value ?? boş` | Üye satırları bir kare 'çevrimdışı' görünür. |
| `features/classroom/widgets/class_detail_screen.dart:864` | `.value ?? boş` | Susturulmuş kişi bir kare susturulmamış görünür. |
| `features/classroom/widgets/focus_timer_screen.dart:63` | `.value ?? boş` | Ders seçici bir kare boş. |
| `features/classroom/widgets/group_discovery_screen.dart:125` | `.value` | Zaten üye olunan grup bir kare 'katılınabilir' görünür. |
| `features/classroom/widgets/study_timer_card.dart:232` | `.value ?? boş` | Ders seçici bir kare boş. |
| `features/desktop/compact_focus_view.dart:95` | `.value ?? boş` | Ders seçici bir kare boş. |
| `features/home/widgets/today_summary_card.dart:24` | `.value ?? boş` | Ders renkleri bir kare varsayılan. |
| `features/notifications/announcements_screen.dart:27` | `.value ?? boş` | Okundu işaretleri bir kare eksik → duyuru okunmamış görünür. |
| `features/profile/feedback_tickets_screen.dart:495` | `.value ?? boş` | Admin eylemleri bir kare gizli. |
| `features/profile/session_history_screen.dart:264` | `.value ?? boş` | Ders filtresi bir kare boş. |
| `features/profile/settings_screen.dart:76` | `.value ?? boş` | Admin menüsü bir kare gizli. |
| `features/profile/social_profile_screen.dart:100` | `asData?.value` | Başarım ilerlemesi bir kare boş. |
| `features/profile/social_profile_screen.dart:108` | `asData?.value` | Bekleyen ödüller bir kare boş. |
| `features/profile/social_profile_screen.dart:110` | `asData?.value` | Ödül sayısı bir kare 0. |
| `features/profile/social_profile_screen.dart:112` | `asData?.value` | Ödül XP'si bir kare 0. |
| `features/profile/widgets/gamification_card.dart:35` | `.value` | Bekleyen ödül sayısı bir kare 0. |
| `features/stats/stats_screen.dart:87` | `asData?.value` | Özet bir kare null → başlık boş. |
| `features/stats/stats_screen.dart:116` | `.value ?? boş` | Üye adları bir kare eksik. |
| `features/stats/widgets/class_stats_view.dart:98` | `.value ?? boş` | Alfa skoru bir kare 0. |
| `features/stats/widgets/class_stats_view.dart:100` | `.value ?? boş` | Engelli filtresi bir kare boş (liste ekranında). |
| `features/stats/widgets/goal_streak_flame.dart:241` | `.value` | Seri rozeti bir kare boş; WP-496 aynı dosyayı ele alıyor. |
| `features/stats/widgets/personal_stats_view.dart:846` | `.value ?? boş` | Ders kırılımı bir kare boş. |
| `features/stats/widgets/session_scatter_chart.dart:45` | `.value ?? boş` | Ders renkleri bir kare varsayılan. |
| `features/stats/widgets/study_records.dart:47` | `.value ?? boş` | Ders adları bir kare eksik. |

## 7. Zararsız

### R1 · `authStateProvider` — oturum kabuğu kullanıcı gelmeden sekme kurmaz; `null` yalnız 'oturum yok' demektir.

| Yer | Desen |
|---|---|
| `core/navigation/home_shell.dart:103` | `asData?.value` |
| `core/time_engine/clock_study_recorder.dart:28` | `.value` |
| `core/tour/tour_controller.dart:21` | `asData?.value` |
| `core/widgets/app_pull_to_refresh.dart:58` | `.value` |
| `data/providers/achievement_provider.dart:34` | `.value` |
| `data/providers/achievement_provider.dart:56` | `.value` |
| `data/providers/achievement_reward_provider.dart:23` | `.value` |
| `data/providers/achievement_reward_provider.dart:35` | `.value` |
| `data/providers/achievement_reward_provider.dart:47` | `.value` |
| `data/providers/achievement_reward_provider.dart:69` | `.value` |
| `data/providers/admin_providers.dart:29` | `.value` |
| `data/providers/admin_providers.dart:37` | `.value` |
| `data/providers/admin_providers.dart:49` | `.value` |
| `data/providers/admin_providers.dart:63` | `.value` |
| `data/providers/admin_providers.dart:75` | `.value` |
| `data/providers/admin_providers.dart:86` | `.value` |
| `data/providers/admin_providers.dart:102` | `.value` |
| `data/providers/analytics_query_providers.dart:41` | `.value` |
| `data/providers/analytics_query_providers.dart:73` | `.value` |
| `data/providers/gamification_providers.dart:55` | `.value` |
| `data/providers/gamification_providers.dart:67` | `.value` |
| `data/providers/gamification_providers.dart:251` | `.value` |
| `data/providers/global_timer_providers.dart:187` | `.value` |
| `data/providers/global_timer_providers.dart:242` | `.value` |
| `data/providers/global_timer_providers.dart:463` | `.value` |
| `data/providers/global_timer_providers.dart:553` | `.value` |
| `data/providers/global_timer_providers.dart:608` | `.value` |
| `data/providers/global_timer_providers.dart:639` | `.value` |
| `data/providers/group_providers.dart:56` | `.value` |
| `data/providers/group_providers.dart:66` | `.value` |
| `data/providers/notification_providers.dart:25` | `.value` |
| `data/providers/notification_providers.dart:35` | `.value` |
| `data/providers/nudge_notification_listener.dart:34` | `.value` |
| `data/providers/presence_lifecycle.dart:74` | `.value` |
| `data/providers/push_notification_providers.dart:376` | `.value` |
| `data/providers/study_providers.dart:116` | `.value` |
| `data/providers/study_providers.dart:123` | `.value` |
| `data/providers/study_providers.dart:156` | `.value` |
| `data/providers/study_providers.dart:601` | `.value` |
| `data/providers/study_providers.dart:880` | `.value` |
| `data/providers/study_providers.dart:989` | `.value` |
| `data/providers/study_providers.dart:1340` | `.value` |
| `data/providers/study_providers.dart:1730` | `.value` |
| `data/providers/study_providers.dart:1751` | `.value` |
| `data/providers/study_providers.dart:1755` | `.value` |
| `data/providers/study_providers.dart:1785` | `.value` |
| `data/providers/study_providers.dart:1910` | `.value` |
| `data/providers/study_providers.dart:2344` | `.value` |
| `data/providers/study_providers.dart:2388` | `.value` |
| `data/providers/study_providers.dart:2511` | `.value` |
| `data/providers/subject_providers.dart:23` | `.value` |
| `data/providers/support_providers.dart:42` | `.value` |
| `data/providers/user_task_providers.dart:34` | `.value` |
| `data/providers/user_task_providers.dart:75` | `.value` |
| `features/admin/tabs/admin_announcements_tab.dart:175` | `.value` |
| `features/admin/tabs/admin_reports_tab.dart:242` | `.value` |
| `features/admin/tabs/admin_reports_tab.dart:280` | `.value` |
| `features/admin/tabs/admin_reports_tab.dart:488` | `.value` |
| `features/classroom/widgets/class_chat_card.dart:46` | `.value` |
| `features/classroom/widgets/class_chat_card.dart:129` | `.value` |
| `features/classroom/widgets/class_detail_screen.dart:44` | `.value` |
| `features/classroom/widgets/class_detail_screen.dart:851` | `.value` |
| `features/classroom/widgets/class_switcher.dart:157` | `.value` |
| `features/classroom/widgets/class_switcher.dart:305` | `.value` |
| `features/classroom/widgets/group_discovery_screen.dart:94` | `.value` |
| `features/classroom/widgets/study_timer_card.dart:238` | `.value` |
| `features/home/widgets/goal_card.dart:29` | `.value` |
| `features/home/widgets/leaderboard_card.dart:41` | `.value` |
| `features/notifications/announcements_screen.dart:114` | `.value` |
| `features/notifications/notification_permissions_screen.dart:41` | `.value` |
| `features/onboarding/onboarding_prefs.dart:53` | `asData?.value` |
| `features/onboarding/onboarding_prefs.dart:64` | `asData?.value` |
| `features/profile/achievements_screen.dart:14` | `.value` |
| `features/profile/data_export_screen.dart:33` | `.value` |
| `features/profile/feedback_screen.dart:131` | `.value` |
| `features/profile/feedback_screen.dart:214` | `.value` |
| `features/profile/feedback_tickets_screen.dart:311` | `.value` |
| `features/profile/feedback_tickets_screen.dart:364` | `.value` |
| `features/profile/feedback_tickets_screen.dart:393` | `.value` |
| `features/profile/feedback_tickets_screen.dart:494` | `.value` |
| `features/profile/profile_screen.dart:56` | `.value` |
| `features/profile/settings_screen.dart:45` | `.value` |
| `features/profile/settings_screen.dart:75` | `.value` |
| `features/profile/social_profile_screen.dart:85` | `.value` |
| `features/profile/social_profile_screen.dart:292` | `.value` |
| `features/profile/subjects_screen.dart:23` | `.value` |
| `features/profile/subjects_screen.dart:82` | `.value` |
| `features/profile/widgets/gamification_card.dart:30` | `.value` |
| `features/profile/widgets/manual_session_dialog.dart:80` | `.value` |
| `features/profile/widgets/primary_group_selector_card.dart:180` | `.value` |
| `features/stats/stats_screen.dart:117` | `.value` |
| `features/support/faq_screen.dart:28` | `.value` |

### R2 · Mantık katmanı (`data/providers`, `core`) — değer bir karar için okunur, kullanıcıya boş durum çizilmez.

| Yer | Desen |
|---|---|
| `core/tour/tour_host.dart:81` | `asData?.value` |
| `data/providers/admin_providers.dart:116` | `.value ?? boş` |
| `data/providers/analytics_query_providers.dart:100` | `.value` |
| `data/providers/analytics_query_providers.dart:116` | `.value` |
| `data/providers/analytics_query_providers.dart:134` | `.value` |
| `data/providers/gamification_providers.dart:129` | `asData?.value` |
| `data/providers/group_providers.dart:161` | `.value` |
| `data/providers/nudge_notification_listener.dart:55` | `.value ?? boş` |
| `data/providers/presence_providers.dart:108` | `.value` |
| `data/providers/study_providers.dart:134` | `.value` |
| `data/providers/study_providers.dart:744` | `asData?.value` |

### R3 · `ref.read` + kullanıcı eylemi — düğmeye basıldığında veri zaten yüklü.

| Yer | Desen |
|---|---|
| `data/providers/presence_lifecycle.dart:79` | `.value` |
| `data/providers/study_providers.dart:1933` | `.value` |
| `data/providers/study_providers.dart:2393` | `.value` |
| `data/providers/study_providers.dart:2512` | `.value` |
| `data/providers/study_providers.dart:2513` | `.value ?? boş` |
| `data/providers/study_providers.dart:2515` | `.value ?? boş` |
| `features/classroom/widgets/class_switcher.dart:31` | `.value ?? boş` |
| `features/classroom/widgets/class_switcher.dart:32` | `.value` |
| `features/home/widgets/group_goal_card.dart:50` | `.value ?? boş` |
| `features/profile/session_history_screen.dart:320` | `.value ?? boş` |
| `features/profile/widgets/manual_session_dialog.dart:87` | `.value ?? boş` |

### R4 · Yukarıdakilerin dışında, ayrıca elle bakıldı.

| Yer | Desen | Kullanıcının gördüğü |
|---|---|---|
| `data/providers/gamification_providers.dart:266` | `.value` | **Doğru desen:** `null` → `AsyncValue.loading()` döndürülüyor. |
| `data/providers/gamification_providers.dart:277` | `.value` | Aynı doğru desen. |
| `data/providers/gamification_providers.dart:278` | `.value` | Aynı doğru desen. |
| `data/providers/group_providers.dart:85` | `.value` | **Doğru desen:** `null` → `false`, 'eksik' iddiası üretilmiyor. |
| `data/providers/group_providers.dart:86` | `.value` | Aynı doğru desen. |
| `features/classroom/classroom_screen.dart:53` | `asData?.value` | **Doğru desen:** `asData == null` yükleniyor sayılıyor, tur açılmıyor. |
| `features/classroom/classroom_screen.dart:58` | `asData?.value` | Yukarıdaki kapıdan sonra okunuyor. |
| `features/classroom/widgets/class_detail_screen.dart:869` | `.value` | **Doğru desen (WP-494):** `null` → iskelet/hata, boş liste değil. |
| `features/onboarding/onboarding_prefs.dart:45` | `asData?.value` | 🔴 **BU SATIR YANLIŞ SINIFLANDI (WP-709, 2026-08-11).** "Oturum yoksa akış zaten başlamaz" denmiş; ama sorun oturumun HIÇ olmaması değil, **yeniden kurulması**ydı. `settings_screen.dart` günlük hedefi yazınca `authStateProvider`ı invalidate ediyor; akış ilk `yield`den önce ağdan profil çektiği için pencere bir gidiş-dönüş açık kalıyor ve kapı o karede TANITIM EKRANINI çiziyordu. Sahip bunu cihazda gördü. Aynı yol ad değiştirme, kamp hayvanı değiştirme, sayacı başlatma ve giriş ekranında da tetikleniyordu. **Ders: "zararsız" hükmü, satırın çağrıldığı her yolu saymadan verilemez.** |
| `features/profile/feedback_screen.dart:32` | `.value ?? boş` | Rozetin yokluğu 'yok' iddiası değil; veri gelince belirir. |
| `features/profile/profile_screen.dart:62` | `.value ?? boş` | Aynı. |
| `features/profile/settings_screen.dart:80` | `.value ?? boş` | Aynı. |

## 8. Tekrarını önleyen kalıp

Yeni kod yazarken:

```dart
final async = ref.watch(someProvider);
if (!async.hasValue) {
  return async.hasError ? errorView : skeletonView;   // yükleniyor ≠ boş
}
final data = async.value!;                            // buradan sonra gerçek veri
```

- `asData?.value` **kullanma** — bağımlılık değişiminde veriyi düşürür.
- `.value ?? const []` yalnız gerçekten "boş = yok" demek istediğin yerde;
  kullanıcıya boş durum çizen bir dalın koşulu olarak **kullanma**.
- Hata dalını ayrı tut: hatayı "yükleniyor" saymak sonsuz iskelet üretir.
