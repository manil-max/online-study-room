import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/navigation/tab_action_bar.dart';
import '../../core/widgets/app_pull_to_refresh.dart';

import '../../data/models/study_group.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/study_providers.dart';
import '../classroom/widgets/class_switcher.dart';
import '../classroom/widgets/group_discovery_screen.dart';
import '../desktop/desktop_page_scaffold.dart';
import 'widgets/class_stats_view.dart';
import 'widgets/personal_stats_view.dart';
import 'widgets/stats_period_bar.dart';
import 'widgets/stats_range_navigator.dart';

/// Sekme sırası: 0 Kişisel, 1 Grup.
const int kStatsGroupTabIndex = 1;

/// İstatistik sekmesi: Kişisel + Grup (klasik ListView — WP-170).
/// Özelleştirilebilir ızgara kaldırıldı; zenginleştirme WP-175 planında.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 🔴 WP-673 / SPEC §3 A2: masaüstünde sekme şeridi gövdenin İÇİNE, içerik
    // bandının altına iner ve sola yaslı akıcı hâle gelir.
    //
    // ÖLÇÜM (WP-671 kapısı, `desktop_stretch_contract_test.dart`, ekran
    // pikseli): şerit `AppBar.bottom`da tam pencere genişliğindeydi, iki sekme
    // etiketi pencerenin iki yarısının ortasına dağılıyordu —
    //   1920 px pencere → "Kişisel" → "Grup" satırı **950 px**
    //   2560 px pencere → **1270 px** ve tüm içerik aralığı **1744 px**
    // yani SPEC KURAL 2.2'nin 600 px sert tavanı ve §2.3'ün 1440 px ızgara
    // tavanı birlikte aşılıyordu. Kusur şeridin kendisinde değil, şeridin
    // **kabında**: `AppBar` pencereyi doldurur, [DesktopContent] doldurmaz.
    final desktop = isDesktopWindow;
    final tabs = <Widget>[
      Tab(text: l10n.statsKisisel),
      // WP-743: grup sekmesi aynı zamanda grup değiştiricidir; "Değiştir"
      // düğmesini kartın içinde aramak yerine sekmenin okuna dokunulur.
      // Yükseklik 48'e çıkıyor çünkü ok gerçek bir dokunma hedefi.
      Tab(height: 48, child: _GroupTabLabel(label: l10n.statsGrup)),
    ];
    const body = AppPullToRefresh(
      child: TabBarView(children: [_PersonalTab(), _ClassTab()]),
    );

    final page = DefaultTabController(
      length: 2,
      child: Scaffold(
        // WP-460: "İstatistik" başlığı alt menüde zaten yazılı; sekmenin
        // gerçek üst öğesi kişisel/grup TabBar'ıdır.
        appBar: desktop
            ? null
            : buildTabActionBar(bottom: TabBar(tabs: tabs)),
        body: desktop
            ? SafeArea(
                bottom: false,
                // SPEC §2.3 "Izgara / pano toplamı": 1440 px. Artan yer sola ve
                // sağa eşit boşluk olur — [DesktopContent] tam olarak budur ve
                // SPEC §6 "BAĞLA, ATMA" tablosunda ekranlara bağlanması istenen
                // yüzeydir (bugüne dek `lib/` içinde tek çağrı yeri yoktu).
                child: DesktopContent(
                  maxWidth: DesktopBreakpoints.maxContentWidth,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sola yaslı, akıcı sekmeler: iki etiket yan yana durur,
                      // pencerenin iki ucuna dağılmaz.
                      TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: tabs,
                      ),
                      const StatsPeriodBar(),
                      // Tek gezinme çubuğu iki sekmenin ORTAK'ıdır: dönem
                      // seçimi zaten paylaşılıyor, kopyası sekme başına
                      // ayrı bir "nerede olduğun" doğurur.
                      const StatsRangeNavigator(),
                      const Expanded(child: body),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StatsPeriodBar(),
                  const StatsRangeNavigator(),
                  // 🔴 WP-550: sarmalayıcı dönem şeridinin **altında** durur,
                  // böylece spinner şeridi örtmez. `AppPullToRefresh` yalnız
                  // dikey eksen bildirimlerini dinlediği için sekmeler arası
                  // yatay kaydırma yenilemeyi tetiklemez.
                  const Expanded(child: body),
                ],
              ),
      ),
    );

    // 🔴 WP-417: dönem tanıtım turu kaldırıldı (sahip isteğini geri aldı).
    return page;
  }
}

/// "Grup" sekmesi: metin + aşağı ok. Ok, katılınan grupları **basılan yerde**
/// listeler (`showClassSwitcher(..., switchOnly: true)` — §3.12; yeni bir menü
/// yazılmadı, Sınıflar sekmesindeki menünün ta kendisi kullanılıyor, o yüzden
/// seçim `activeGroupIdProvider` üzerinden iki sekmede de aynı grubu gösterir).
///
/// Sekme seçili DEĞİLKEN metne dokunmak normal sekme geçişidir; menü açılmaz.
/// Seçiliyken metin de menüyü açar (kullanıcı zaten oradadır).
class _GroupTabLabel extends ConsumerWidget {
  const _GroupTabLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = DefaultTabController.of(context);
    // 🔴 Bu `watch` süs değil, çubuğun ÇALIŞMA koşulu. `TabBarView` yalnız
    // görünen sekmeyi kurar; Kişisel sekmesindeyken `_ClassTab` hiç
    // build edilmez ve `userGroupsProvider`ı dinleyen kimse kalmaz. Riverpod 3
    // dinleyicisiz provider'ı ayakta tutmadığı için `showClassSwitcher`
    // içindeki `ref.read` taze bir `AsyncLoading` görüp menüyü BOŞ açıyordu
    // (ölçüldü: `statsGroupTabCaret` → "Henüz grup yok").
    final groups = ref.watch(userGroupsProvider).value ?? const <StudyGroup>[];
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selected = controller.index == kStatsGroupTabIndex;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Builder(
                builder: (textContext) => GestureDetector(
                  onTap: selected && groups.isNotEmpty
                      ? () => showClassSwitcher(
                          textContext,
                          ref,
                          switchOnly: true,
                        )
                      : null,
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
            // Menü basılan düğmeye göre konumlanır, bu yüzden
            // `showClassSwitcher` düğmenin **kendi** context'ini almalı
            // (`class_switcher.dart`, `classroom_screen.dart` deseni).
            //
            // Grubu olmayan kullanıcıya ok çizilmez: geçilecek grup yokken
            // açılan bir "grup değiştirici" ölü anahtardır.
            if (groups.isNotEmpty)
              Builder(
                builder: (caretContext) => IconButton(
                  key: const Key('statsGroupTabCaret'),
                  icon: const Icon(Icons.arrow_drop_down),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  visualDensity: VisualDensity.standard,
                  tooltip: AppLocalizations.of(context).classroomGrupDegistir,
                  onPressed: () =>
                      showClassSwitcher(caretContext, ref, switchOnly: true),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PersonalTab extends ConsumerWidget {
  const _PersonalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    final summaryAsync = ref.watch(userStudySummaryProvider);
    final l10n = AppLocalizations.of(context);
    return sessionsAsync.when(
      loading: () => const RefreshableBody(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => RefreshableBody(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.authBeklenmeyenBirHataOlustu,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(userSessionsProvider),
                  child: Text(l10n.classroomYenile),
                ),
              ],
            ),
          ),
        ),
      ),
      // WP-495B: `asData` yeniden yüklemede boşalır, özet bir kare kaybolurdu.
      data: (sessions) =>
          PersonalStatsView(sessions: sessions, summary: summaryAsync.value),
    );
  }
}

class _ClassTab extends ConsumerWidget {
  const _ClassTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final groupAsync = ref.watch(userGroupProvider);
    final group = groupAsync.value;
    if (group == null) {
      // WP-495B: veri gelmeden "bir gruba katıl" demek grubu olan kullanıcıya
      // yanlış iddiadır; sekmenin geri kalanı gibi önce yükleme/hata gösterilir.
      if (!groupAsync.hasValue) {
        // 🔴 WP-550: hata dalı çıkışsızdı — "Grup bilgisi yüklenemedi" yazıp
        // duruyor, kullanıcıya tekrar deneme yolu vermiyordu. Kaynak
        // `userGroupsProvider` (bkz. `userGroupProvider` türetimi).
        return RefreshableBody(
          child: Center(
            child: groupAsync.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.homeGrupBilgisiYuklenemedi,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('stats-group-error-retry'),
                          onPressed: () => ref.invalidate(userGroupsProvider),
                          child: Text(l10n.classroomYenile),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        );
      }
      // WP-596: bu dal "önce bir gruba katıl" diyordu ama KATILMANIN YOLUNU
      // vermiyordu -- kullanıcı doğru talimatı okuyup çıkmaz sokakta kalıyordu.
      // Aynı ekranın hata dalı (yukarıda) zaten bir çıkış sunuyor; boş dal
      // unutulmuştu.
      return RefreshableBody(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.statsGrupIstatistikleriniGormekIcin,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('stats-group-empty-join'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GroupDiscoveryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(l10n.commonBirGrubaKatil),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final statsAsync = ref.watch(groupDailyStatsProvider);
    final members = ref.watch(groupMembersProvider).value ?? const [];
    final currentUserId = ref.watch(authStateProvider).value?.id ?? '';

    return statsAsync.when(
      loading: () => const RefreshableBody(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => RefreshableBody(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.authBeklenmeyenBirHataOlustu,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(groupDailyStatsProvider),
                  child: Text(l10n.classroomYenile),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (stats) => ClassStatsView(
        stats: stats,
        members: members,
        currentUserId: currentUserId,
        groupName: group.name,
        groupGoalMinutes: group.dailyGoalMinutes,
        groupAvatarPath: group.avatarPath,
        groupAvatarUpdatedAt: group.avatarUpdatedAt,
      ),
    );
  }
}
