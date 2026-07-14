import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/study_records.dart';
import '../dashboard_card.dart';
import 'card_scaffold.dart';

/// "Rekorlar" kartı (§3.11): toplam, rekor seri, en verimli gün, aktif gün,
/// en çok çalışılan ders — renkli stat döşemeleri.
class RecordsCard extends ConsumerWidget {
  const RecordsCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(userSessionsProvider).value ?? const [];

    return CardScaffold(
      header: cardTitle(context, AppLocalizations.of(context).homeRekorlar),
      bodyBuilder: (context, bodyHeight) => SizedBox(
        height: bodyHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 400
                ? 3
                : (constraints.maxWidth > 250 ? 2 : 1);
            return SingleChildScrollView(
              child: StudyRecords(sessions: sessions, columns: cols),
            );
          },
        ),
      ),
    );
  }
}
