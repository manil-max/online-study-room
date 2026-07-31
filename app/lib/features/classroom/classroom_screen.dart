import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/nav_index.dart';
import '../../core/navigation/tab_action_bar.dart';
import '../../core/tour/tour_controller.dart';
import '../../core/tour/tour_host.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/study_group.dart';
import '../../data/providers/group_providers.dart';
import '../home/dashboard_providers.dart';
import '../home/widgets/group_goal_card.dart';
import '../home/widgets/group_trend_card.dart';
import '../home/widgets/leaderboard_card.dart';
import '../tours/app_tours.dart';
import 'widgets/campfire_scene.dart';
import 'widgets/class_chat_screen.dart';
import 'widgets/class_detail_screen.dart';
import 'widgets/group_discovery_screen.dart';
import 'widgets/group_avatar.dart';
import 'widgets/class_switcher.dart';
import 'widgets/study_timer_card.dart';

/// Sınıflar sekmesi: aktif sınıfın canlı ekranı + çoklu sınıf değiştirici.
/// Bkz. project.md §3.0/§3.5/§3.8. Sınıf yoksa oluştur/katıl; varsa sayaç +
/// canlı üye listesi. Başlığa (sınıf adına) dokununca sınıf değiştirici açılır.
class ClassroomScreen extends ConsumerStatefulWidget {
  const ClassroomScreen({super.key});

  @override
  ConsumerState<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends ConsumerState<ClassroomScreen> {
  final _scrollController = ScrollController();
  final _groupsTourAnchor = GlobalKey();
  final _groupSwitcherTourAnchor = GlobalKey();
  final _campfireTourAnchor = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _withIntroductionTours(
    BuildContext context,
    AsyncValue<StudyGroup?> groupAsync,
    Widget child,
  ) {
    if (ref.watch(navIndexProvider) != AppTab.groups.index ||
        groupAsync.asData == null) {
      return child;
    }

    ref.watch(tourControllerProvider);
    final group = groupAsync.asData?.value;
    final l10n = AppLocalizations.of(context);
    final groups = AppTours.groups(
      l10n,
      contentAnchor: _groupsTourAnchor,
      switcherAnchor: _groupSwitcherTourAnchor,
      hasGroup: group != null,
    );
    final definition = groups;

    return TourHost(
      key: ValueKey(definition.storageId),
      definition: definition,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navReselectProvider, (previous, next) {
      if (next.tabIndex != AppTab.groups.index ||
          next.tick <= (previous?.tick ?? 0) ||
          !_scrollController.hasClients ||
          _scrollController.offset <= 0) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    final groupAsync = ref.watch(userGroupProvider);
    final body = groupAsync.when(
      data: (group) => group == null
          ? const _NoGroupView()
          : _GroupView(
              group: group,
              controller: _scrollController,
              campfireKey: _campfireTourAnchor,
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Text(AppLocalizations.of(context).authBeklenmeyenBirHataOlustu),
      ),
    );

    // Windows: sol rail yeter; büyük başlık/sağ panel yok.
    final page = Scaffold(
      // WP-460: başlık yok, yalnız gerçek eylem (grup değiştir) kalır.
      appBar: buildTabActionBar(
        actions: [
          Builder(
            builder: (iconContext) => IconButton(
              key: _groupSwitcherTourAnchor,
              tooltip: AppLocalizations.of(context).classroomGrupDegistir,
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => showClassSwitcher(iconContext, ref),
            ),
          ),
        ],
      ),
      body: KeyedSubtree(key: _groupsTourAnchor, child: body),
    );
    return _withIntroductionTours(context, groupAsync, page);
  }
}

/// Henüz sınıfı olmayan kullanıcı: oluştur veya koda katıl.
class _NoGroupView extends ConsumerWidget {
  const _NoGroupView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: getSafeVerticalPadding(context, horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).classroomHenuzBirGruptaDegilsin,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).classroomYeniBirGrupOlustur,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => createGroupFlow(context, ref),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).classroomGrupOlustur),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => joinGroupFlow(context, ref),
              icon: const Icon(Icons.login),
              label: Text(AppLocalizations.of(context).classroomKodaKatil),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GroupDiscoveryScreen()),
              ),
              icon: const Icon(Icons.travel_explore),
              label: Text(AppLocalizations.of(context).groupDiscoveryAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kullanıcının sınıfı: ad, davet kodu ve üyeler.
/// WP-172: sabit ListView — kartlar nested scroll kullanmaz (unbounded yükseklik);
/// Home dashboard sürükle-bırak burada YOK.
class _GroupView extends ConsumerWidget {
  const _GroupView({
    required this.group,
    required this.controller,
    required this.campfireKey,
  });

  final StudyGroup group;
  final ScrollController controller;
  final Key campfireKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sayaç varsayılan olarak Ana Sayfa'dadır; isteyen Sınıflar'a ekler (§3.9).
    final showTimer = ref.watch(classroomShowTimerProvider);

    // Sıra (KALITE-PROGRAMI §8.3 Gruplar): kamp ateşi → hedef → sıralama → trend.
    return ListView(
      controller: controller,
      // Kartlar üzerindeki jestler de dikey kaydırmaya gitsin.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: getSafeVerticalPadding(context, horizontal: 16, vertical: 16),
      children: [
        if (showTimer) ...[const StudyTimerCard(), const SizedBox(height: 8)],
        _CompactGroupHeader(group: group),
        const SizedBox(height: 8),
        CampfireScene(key: campfireKey),
        const SizedBox(height: 16),
        const GroupGoalCard(),
        const SizedBox(height: 16),
        const LeaderboardCard(),
        const SizedBox(height: 16),
        const GroupTrendCard(),
        // Alt menü için nefes payı
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Kamp ateşinin üstünde yalnız tek satır kaplayan kompakt başlık: grup adı +
/// sohbet/ayarlar kısayolları. Davet kodu bu ekranda hiç görünmez.
///
/// WP-446: kod eskiden hem burada (`_GroupManagementTile`) hem de
/// `ClassDetailScreen` → Bilgiler kartında duruyordu. İki kopya aynı değildi:
/// alttaki yalnız kopyalayabiliyor, detaydaki ayrıca **kodu yenileyebiliyordu**.
/// Tek kanonik yer artık detay ekranı; ayarlar simgesi zaten oraya götürüyor.
class _CompactGroupHeader extends StatelessWidget {
  const _CompactGroupHeader({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        GroupAvatar(
          name: group.name,
          avatarPath: group.avatarPath,
          avatarUpdatedAt: group.avatarUpdatedAt,
          radius: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            group.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).classroomSohbet,
          icon: const Icon(Icons.forum_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClassChatScreen(group: group)),
          ),
        ),
        IconButton(
          tooltip: AppLocalizations.of(context).classroomAyarlar,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClassDetailScreen(group: group)),
          ),
        ),
      ],
    );
  }
}
