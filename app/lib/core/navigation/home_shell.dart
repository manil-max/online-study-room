import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../data/providers/group_providers.dart';
import '../../data/providers/gamification_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/achievement_reward_provider.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/device_integration_listener.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/nudge_notification_listener.dart';
import '../../data/providers/presence_lifecycle.dart';
import '../../features/android_widgets/widget_deep_link.dart';
import '../../features/classroom/classroom_screen.dart';
import '../../features/classroom/widgets/class_switcher.dart';
import '../../features/clock/clock_screen.dart';
import '../../features/desktop/desktop_home_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/widgets/reward_toast.dart';
import '../../features/stats/stats_screen.dart';
import '../desktop/desktop_window.dart';
import '../widgets/app_pull_to_refresh.dart';
import 'nav_index.dart';
import 'profile_tab_badge.dart';

export 'nav_index.dart';
export 'profile_tab_badge.dart';

/// Uygulamanın ana kabuğu: alt menüde 4 sekme (Ana Sayfa / Sınıflar / İstatistik
/// / Profil). Ekranlar IndexedStack ile tutulur, böylece sekme değişince durum korunur.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const List<Widget> _screens = [
    // AppTab.values ile birebir aynı kanonik sıra.
    HomeScreen(),
    ClockScreen(),
    ClassroomScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  /// WP-378: noktayı besleyen ikinci kaynak okunmamış duyurulardır. Öncesinde
  /// duyuru işareti yalnız **Ayarlar'ın içindeki** satırda duruyordu; kullanıcı
  /// oraya girmeden yeni duyuruyu fark etmiyordu.
  ///
  /// 🔴 WP-594: rozet kararı buradan [ProfileTabBadge]'e taşındı. Öncesi bu
  /// metot yalnız **mobil** koldan çağrılıyordu; masaüstü kolu hiçbir rozet
  /// geçmiyordu ve Windows kullanıcısı bekleyen ödülünü, okunmamış duyurusunu
  /// ve eksik birincil grup uyarısını hiç görmüyordu. Artık iki kol da aynı
  /// nesneyi alır — kopya mantık tutulmaz (bkz. WP-550 aynı ders).
  static Widget _profileTabIcon(
    IconData icon, {
    required ProfileTabBadge badge,
    required Color surface,
    required Color announcementColor,
  }) {
    return badge.wrap(
      Icon(icon),
      surface: surface,
      announcementColor: announcementColor,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    final groupsTabIndex = AppTab.groups.index;
    assert(_screens.length == AppTab.values.length);

    // WP-495B: `asData` yeniden yüklemede boşalır ve rozet bir kare 0'a düşer;
    // `value` önceki değeri korur (bkz. docs/qa/V58-ASYNC-EMPTY-AUDIT.md §1).
    final rewardSummary = ref
        .watch(pendingAchievementRewardSummaryProvider)
        .value;
    final pendingRewardCount = rewardSummary?.pendingCount ?? 0;
    final pendingRewardXp = rewardSummary?.pendingXp ?? 0;
    // WP-352: birincil grup seçilmemişse grup ilerlemesi sessizce durur. Seçim
    // Profil→Başarımlar altındaki kartta olduğu için sekmede nokta gösterilir;
    // yoksa kullanıcı kartı hiç açmadan kaybı fark etmez.
    final missingPrimaryGroup = ref.watch(primaryGroupSelectionMissingProvider);
    // WP-459: Zincir kurali — alt seviyede gorunen her sinyal ust seviyede de
    // gorunur. Sekme noktasi yalnizca duyuruyu degil okunmamis yonetici
    // yanitini da tasir; ikisi de `settingsBadgeCountProvider`in ayaklaridir.
    final unreadProfileSignals = ref.watch(settingsBadgeCountProvider);
    // 🔴 WP-594: rozet TEK yerde çözülür ve iki kola da aynı nesne gider.
    // Masaüstü kolu eskiden hiçbirini almıyordu.
    final profileBadge = ProfileTabBadge(
      pendingRewardCount: pendingRewardCount,
      missingPrimaryGroup: missingPrimaryGroup,
      unreadProfileSignals: unreadProfileSignals,
    );
    // Duyuru bir uyarı değil, yeni içerik — rengi uyarı token'ından değil
    // temanın birincil renginden gelir (WP-378).
    final announcementDotColor = Theme.of(context).colorScheme.primary;
    final selfId = ref.watch(authStateProvider).value?.id;
    // Sekme çubuğundaki taç `crowned_avatar.dart` ile aynı hatayı taşıyordu:
    // provider yeniden yüklenince `asData` boşalıyor, taç bir kare sönüyordu.
    final crownRank = selfId == null
        ? null
        : ref.watch(gamificationProfileProvider(selfId)).value?.crownRank;
    final rewardToast = RewardToast(
      pendingCount: pendingRewardCount,
      pendingXp: pendingRewardXp,
      crownRank: crownRank,
      onOpenProfile: () =>
          ref.read(navIndexProvider.notifier).setTab(AppTab.profile),
    );

    // Presence heartbeat/yaşam-döngüsünü oturum boyunca diri tut (§WP-5): çalışma
    // sürerken satırı düzenli tazeler, uygulama öldürülünce karşı taraf çevrimdışı
    // görür. Kabuk her zaman monte olduğu için burada izlenir.
    ref.watch(presenceLifecycleProvider);
    // WP-105: oturum bitince XP/başarım RPC — profil ekranı açılmadan tetiklenir.
    ref.watch(achievementProgressLifecycleProvider);
    ref.watch(nudgeNotificationListenerProvider);
    ref.watch(deviceIntegrationListenerProvider);
    // WP-700: widget'a dokununca ILGILI bolum acilir. Dinleyici burada
    // izlenir cunku kabuk uygulama boyunca monte kalir; soguk baslangicta
    // (surec widget intent'iyle DOGDUGUNDA) rotayi soracak olan da odur.
    ref.watch(widgetDeepLinkListenerProvider);
    // Hatırlatıcı planlamasını tercih/veri değiştikçe senkron tut (§WP-36).
    ref.watch(reminderSyncListenerProvider);

    // 🔴 WP-682 — ODUL BANNERI ARTIK KABUGUN USTUNE BINMIYOR.
    //
    // Onceki hali: `Stack(fit: expand, children: [kabuk, rewardToast])`. Banner
    // `Alignment.topCenter`da durdugu icin ust seridin uzerine oturuyordu.
    // OLCULDU (gercek kabuk, widget testi):
    //   masaustu 1920 → banner (680, 8)–(1240, 48); "Timer" serit ogesi
    //     (552.7, 22)–(751.3, 72); olu kesisim (680, 22)–(751.3, 48).
    //     (715.7, 35) noktasina yapilan `tester.tap` HIC ulasmiyordu.
    //   mobil 393   → banner (12, 8)–(381, 56); ayni oge (134.3, 14)–(258.7, 64)
    //     TAMAMEN altta kaliyordu; merkez dokunusu bile yutuluyordu.
    // Kutlamadan farki: kutlama 1800 ms sonra kendi kalkar, banner **kullanici
    // kapatana kadar** durur — yani serit ogesi SURESIZ erisilemezdi.
    //
    // Cozum neden `IgnorePointer` DEGIL: bannerin kendi Topla/Kapat dugmeleri
    // var, onlari oldururdu (WP-681 bu yuzden bannerı disarida birakti).
    // Cozum neden `Scaffold.bottomSheet` DEGIL: o da govdenin USTUNU orter,
    // yer ayirmaz (depoda kayitli tuzak). Dogrusu `Column` + `Expanded`:
    // banner kendi seridini ALIR, kimsenin uzerine binmez. Gorunur degilken
    // sifir yukseklik kaplar (bkz. `reward_toast.dart` konum sozlesmesi).
    if (isDesktopWindow) {
      return ColoredBox(
        // Kabuk artik pencerenin tamamini kaplamiyor; bannerin cevresindeki
        // bant da kabukla ayni zemini kullanir.
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: DesktopHomeShell(
                selectedIndex: index,
                screens: _screens,
                onDestinationSelected: ref
                    .read(navIndexProvider.notifier)
                    .setIndex,
                // 🔴 WP-594: mobil kolun bastığı rozetin aynısı. Buradan
                // çıkarılırsa Windows kullanıcısı bekleyen ödülünü ve okunmamış
                // duyurusunu bir daha göremez.
                profileBadge: profileBadge,
                // 🔴 WP-550: burada eskiden **ikinci bir** provider listesi
                // vardı ve eksikti (`userStudySummary`, `groupPresence`,
                // duyurular yoktu). Masaüstü ve mobil artık aynı tek kaynağı
                // çağırır; ikinci listeyi geri getirme, iki ayrı yenileme
                // gerçeği bu hatanın kök nedeniydi.
                onRefresh: () => refreshAppData(ref),
              ),
            ),
            // Serit KABUGUN ALTINDA, ustunde degil (WP-682).
            rewardToast,
          ],
        ),
      );
    }

    return Scaffold(
      // 🔴 WP-682: mobil kol da ayni yapiyi kullanir — banner ekranin ust
      // seridini (Araclar ikon seridi, ekran baslıklari) ortmez, kendi yerini
      // icerik ile `NavigationBar` arasindan alir.
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: index, children: _screens),
          ),
          rewardToast,
        ],
      ),
      // "Sınıflar" ikonuna basılı tutunca sınıf değiştirici açılır (§3.8).
      // NavigationBar tek tek destination'a long-press vermediği için basışın
      // x konumundan hangi sekme olduğunu hesaplıyoruz.
      bottomNavigationBar: GestureDetector(
        onLongPressStart: (details) {
          final width = MediaQuery.of(context).size.width;
          final tab =
              (details.globalPosition.dx / (width / AppTab.values.length))
                  .floor();
          if (tab == groupsTabIndex) {
            ref.read(navIndexProvider.notifier).setTab(AppTab.groups);
            // Menü basılan konumda açılır (§3.12).
            showClassSwitcher(context, ref, at: details.globalPosition);
          }
        },
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: ref.read(navIndexProvider.notifier).setIndex,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: AppLocalizations.of(context).homeAnaSayfa,
            ),
            NavigationDestination(
              // WP-264: Araçlar yalnız Alarm, Timer ve Görevler içerir.
              icon: const Icon(Icons.handyman_outlined),
              selectedIcon: const Icon(Icons.handyman),
              label: AppLocalizations.of(context).navTools,
            ),
            NavigationDestination(
              icon: const Icon(Icons.groups_outlined),
              selectedIcon: const Icon(Icons.groups),
              label: AppLocalizations.of(context).desktopGruplar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: AppLocalizations.of(context).statsIstatistik,
            ),
            NavigationDestination(
              icon: _profileTabIcon(
                Icons.person_outline,
                badge: profileBadge,
                surface: Theme.of(context).colorScheme.surface,
                announcementColor: announcementDotColor,
              ),
              selectedIcon: _profileTabIcon(
                Icons.person,
                badge: profileBadge,
                surface: Theme.of(context).colorScheme.surface,
                announcementColor: announcementDotColor,
              ),
              label: AppLocalizations.of(context).profileProfil,
            ),
          ],
        ),
      ),
    );
  }
}
