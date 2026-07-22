import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../data/providers/group_providers.dart';
import '../../data/providers/gamification_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/achievement_reward_provider.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';
import '../../data/providers/device_integration_listener.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/nudge_notification_listener.dart';
import '../../data/providers/presence_lifecycle.dart';
import '../../features/classroom/classroom_screen.dart';
import '../../features/classroom/widgets/class_switcher.dart';
import '../../features/clock/clock_screen.dart';
import '../../features/desktop/desktop_home_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/widgets/reward_toast.dart';
import '../../features/stats/stats_screen.dart';
import '../desktop/desktop_window.dart';
import 'nav_index.dart';

export 'nav_index.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    final groupsTabIndex = AppTab.groups.index;
    assert(_screens.length == AppTab.values.length);

    final rewardSummary = ref
        .watch(pendingAchievementRewardSummaryProvider)
        .asData
        ?.value;
    final pendingRewardCount = rewardSummary?.pendingCount ?? 0;
    final pendingRewardXp = rewardSummary?.pendingXp ?? 0;
    final selfId = ref.watch(authStateProvider).asData?.value?.id;
    final crownRank = selfId == null
        ? null
        : ref
              .watch(gamificationProfileProvider(selfId))
              .asData
              ?.value
              .crownRank;
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
    // Hatırlatıcı planlamasını tercih/veri değiştikçe senkron tut (§WP-36).
    ref.watch(reminderSyncListenerProvider);

    if (isDesktopWindow) {
      return Stack(
        fit: StackFit.expand,
        children: [
          DesktopHomeShell(
            selectedIndex: index,
            screens: _screens,
            onDestinationSelected: ref.read(navIndexProvider.notifier).setIndex,
            onRefresh: () {
              ref.invalidate(userSessionsProvider);
              ref.invalidate(groupDailyStatsProvider);
              ref.invalidate(userGroupsProvider);
              ref.invalidate(groupMembersProvider);
              ref.invalidate(userSubjectsProvider);
              ref.invalidate(pendingAchievementRewardSummaryProvider);
            },
          ),
          rewardToast,
        ],
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(index: index, children: _screens),
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
              icon: Badge.count(
                count: pendingRewardCount,
                isLabelVisible: pendingRewardCount > 0,
                child: const Icon(Icons.person_outline),
              ),
              selectedIcon: Badge.count(
                count: pendingRewardCount,
                isLabelVisible: pendingRewardCount > 0,
                child: const Icon(Icons.person),
              ),
              label: AppLocalizations.of(context).profileProfil,
            ),
          ],
        ),
      ),
    );
  }
}
