import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/moderation_appeal.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../queue/moderation_dialogs.dart';

/// WP-769 — itirazin **kendi tam sayfasi**.
///
/// Kuyruk kartinda artik tek dugme var ("Detayli incele"); karar dugmeleri
/// karttan kalkti. Kor onay riski bu yuzden buyudu, o yuzden sayfa **once**
/// itiraz edilen yaptirimi ve gerekcesini yazar, karar dugmeleri en altta
/// durur.
///
/// Cikar catismasi kapisi korunur: yaptirimi uygulayan yonetici kendi
/// kararinin itirazini karara baglayamaz — sunucu reddeder, sayfa dugmeleri
/// hic cizmez ve nedenini yazar (WP-442).
const Key kAdminAppealDetailKey = Key('admin-appeal-detail');
const Key kAdminAppealConflictKey = Key('appeal-conflict-note');

Key adminAppealUpholdKey(String appealId) => Key('appeal-uphold-$appealId');
Key adminAppealOverturnKey(String appealId) => Key('appeal-overturn-$appealId');

Future<void> openAdminAppealDetail(
  BuildContext context, {
  required ModerationAppeal appeal,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminAppealDetailPage(appeal: appeal),
    ),
  );
}

class AdminAppealDetailPage extends ConsumerWidget {
  const AdminAppealDetailPage({super.key, required this.appeal});

  final ModerationAppeal appeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final action = appeal.sanctionAction;
    final sanctionReason = (appeal.sanctionReason ?? '').trim();

    return Scaffold(
      key: kAdminAppealDetailKey,
      appBar: AppBar(title: Text(l10n.adminModerationAppeals)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: DesktopBreakpoints.maxFormWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 🔴 WP-B kabul 5: model `sanctionAction` tasiyordu ama hicbir
                // yuzey cizmiyordu; yonetici **hangi cezaya** itiraz edildigini
                // gormeden karar veriyordu.
                _section(context, l10n.adminItirazEdilenYaptirim),
                Text(
                  action == null
                      ? '—'
                      : moderationActionLabel(l10n, action),
                  style: theme.textTheme.titleMedium,
                ),
                if (sanctionReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    sanctionReason,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                _section(context, l10n.adminMesaj),
                SelectableText(
                  appeal.statement,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (!appeal.canBeDecidedNow)
                  Text(
                    key: kAdminAppealConflictKey,
                    l10n.adminModerationAppealOwnSanction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: adminAppealUpholdKey(appeal.id),
                        onPressed: () => _decide(context, ref, overturn: false),
                        icon: const Icon(Icons.shield_outlined, size: 20),
                        label: Text(l10n.adminModerationAppealUphold),
                      ),
                      FilledButton.icon(
                        key: adminAppealOverturnKey(appeal.id),
                        onPressed: () => _decide(context, ref, overturn: true),
                        icon: const Icon(Icons.undo, size: 20),
                        label: Text(l10n.adminModerationAppealOverturn),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref, {
    required bool overturn,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final note = await askModerationReason(
      context,
      l10n.adminModerationAppeals,
    );
    if (note == null) return;
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .decideAppeal(appeal: appeal, overturn: overturn, note: note);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(moderationAppealsProvider);
    ref.invalidate(moderationQueueProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminModerationAppealDecided)),
    );
    // Karara baglanan itiraz kuyruktan duser; sayfa da kapanir ki yonetici
    // sonraki ise donsun.
    if (navigator.canPop()) navigator.pop();
  }

  static Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
