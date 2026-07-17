import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/providers/analytics_layout_providers.dart';
import '../../../data/providers/stats_period_provider.dart';
import 'analytics_card_config.dart';
import 'analytics_card_registry.dart';
import 'analytics_card_type.dart';
import 'analytics_edit_sheet.dart';
import 'analytics_period.dart';

/// WP-158–162: flag açıkken özelleştirilebilir analitik ızgara.
class AnalyticsGridView extends ConsumerWidget {
  const AnalyticsGridView({
    super.key,
    required this.surface,
  });

  final AnalyticsSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layoutAsync = surface == AnalyticsSurface.personalStats
        ? ref.watch(statsLayoutProvider)
        : ref.watch(groupStatsLayoutProvider);
    final statsPeriod = ref.watch(statsPeriodProvider);
    final period = analyticsPeriodFromStats(statsPeriod);

    return layoutAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
      data: (layout) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => showAnalyticsEditSheet(
                      context,
                      ref,
                      surface: surface,
                      current: layout,
                    ),
                    icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
                    label: Text(l10n.homeKartlariDuzenle),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                children: [
                  for (final card in _sorted(layout))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AnalyticsCardRegistry.build(
                        context: context,
                        ref: ref,
                        config: card,
                        surface: surface,
                        period: period,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<AnalyticsCardConfig> _sorted(List<AnalyticsCardConfig> layout) {
    final copy = [...layout]..sort((a, b) {
        final dy = a.y.compareTo(b.y);
        return dy != 0 ? dy : a.x.compareTo(b.x);
      });
    return copy;
  }
}
