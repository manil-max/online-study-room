import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-D (`docs/design/ADMIN-PANEL-PLAN.md` §2.4 / §5 WP-D kabul 6) — ozet
/// izgarasi.
///
/// 🔴 Duzeltilen kusur: `GridView.count(crossAxisCount: 2)` — genislik ne
/// olursa olsun **sabit iki sutun** ve doseme tavani **yok**. Bu, `DESKTOP-UI-
/// SPEC §3 A2`de adi konmus kusurun aynisidir: 2000 px'lik bir pencerede iki
/// doseme 1000'er px'e gerilir, tek sayilik bir kart icin bu olcunun uc kati.
///
/// Sutun sayisi artik **kabin** genisliginden turer (WP-686 dersi: pencereden
/// degil, kaptan; serit ve bolmeler dusuldukten sonra kalan yer kaptir) ve her
/// doseme `DesktopBreakpoints.maxStatTileWidth` (320) ile tavanlanir.
const IconData _kUsersIcon = Icons.people_outline;

/// SPEC §2.2: izgara olugu 24.
const double kAdminSummaryGridGap = 24;

/// Pencere sinifi merdiveninden (SPEC §1.2) sutun sayisi. PLAN §4.5 tablosu:
/// `minimal` tek sutun, `compact` 2, `expanded`/`large` 4, `xlarge` 6.
///
/// Yeni sayi uretilmedi; esikler `DesktopBreakpoints`ten okunur.
int adminSummaryColumns(double width) {
  return switch (DesktopBreakpoints.windowClass(width)) {
    DesktopNavigationMode.minimal => 1,
    DesktopNavigationMode.compact => 2,
    DesktopNavigationMode.expanded => 4,
    DesktopNavigationMode.large => 4,
    DesktopNavigationMode.xlarge => 6,
  };
}

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminDashboardSummaryProvider);
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardSummaryProvider);
        await ref.read(adminDashboardSummaryProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          summary.when(
            loading: () => const _SummarySkeleton(),
            error: (error, _) =>
                Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
            data: (value) => _SummaryGrid(summary: value),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final AdminDashboardSummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value =
        summary ??
        const AdminDashboardSummary(
          userCount: 0,
          groupCount: 0,
          sessionCount: 0,
          openTicketCount: 0,
        );

    final tiles = <(String, String, IconData)>[
      (l10n.adminKullanicilar, value.userCount.toString(), _kUsersIcon),
      (l10n.adminGruplar, value.groupCount.toString(), Icons.groups_outlined),
      (l10n.adminOturumlar, value.sessionCount.toString(), Icons.timer_outlined),
      (
        l10n.adminAcikRaporlar,
        value.openTicketCount.toString(),
        Icons.report_problem_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = adminSummaryColumns(available);
        final cell =
            (available - kAdminSummaryGridGap * (columns - 1)) / columns;
        // 🔴 Tavan: SPEC §2.3 tek sayilik doseme 320'yi asamaz. `floor` ondalik
        // yuvarlamanin son dosemeyi bir alt satira itmesini engeller.
        final tileWidth = math
            .min(cell, DesktopBreakpoints.maxStatTileWidth)
            .floorToDouble();

        return Wrap(
          spacing: kAdminSummaryGridGap,
          runSpacing: kAdminSummaryGridGap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: _SummaryTile(
                  label: tile.$1,
                  value: tile.$2,
                  icon: tile.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 156,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
