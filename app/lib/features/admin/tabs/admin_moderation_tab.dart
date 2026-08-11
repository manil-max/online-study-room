import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/moderation_appeal.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../queue/moderation_dialogs.dart';
import '../queue/moderation_review_view.dart';

/// WP-424 / WP-440: UGC moderasyon kuyruğu (super-admin, RLS).
///
/// WP-440 kod borcu: ekran artık `Supabase.instance.client` ile konuşmuyor.
/// Okuma `admin_ugc_report_groups()`, yazma `admin_set_ugc_report_group_status()`
/// RPC'lerinden `AdminModerationRepository` üzerinden geçiyor; doğrudan tablo
/// UPDATE'i kalktı.
///
/// WP-B (`docs/design/ADMIN-PANEL-PLAN.md` §4.2): kuyruğun **gövdesi** artık
/// [ModerationReviewView]'dır — kanıt ve karar aynı ekranda. Bu dosya yalnız
/// veri kapısını ve itiraz bölümünü tutar; karar akışı `queue/` altındadır.
class AdminModerationTab extends ConsumerWidget {
  const AdminModerationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(moderationQueueProvider);

    return queue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text(l10n.profileBeklenmeyenBirHataOlustu),
            TextButton(
              onPressed: () => ref.invalidate(moderationQueueProvider),
              child: Text(l10n.taskListRetry),
            ),
          ],
        ),
      ),
      data: (cases) => ModerationReviewView(
        cases: cases,
        header: const _AppealQueue(),
        onRefresh: () async {
          ref.invalidate(moderationQueueProvider);
          ref.invalidate(moderationAppealsProvider);
        },
      ),
    );
  }

  /// Gerekçe zorunludur; boş gerekçe sessizce "gerekçe belirtilmedi"ye
  /// çevrilmez, işlem hiç yapılmaz.
  ///
  /// Gövde `queue/moderation_dialogs.dart`e taşındı: aynı diyaloğu karar şeridi
  /// de kullanıyor ve private kaldığı sürece oradan çağrılamıyordu.
  @visibleForTesting
  static Future<String?> askReason(BuildContext context, String title) =>
      askModerationReason(context, title);
}

/// WP-442: İtiraz kuyruğu.
///
/// Yaptırımı uygulayan yönetici kendi kararının itirazını karara bağlayamaz;
/// sunucu reddeder, kart da eylemleri hiç göstermez ve nedenini yazar.
class _AppealQueue extends ConsumerWidget {
  const _AppealQueue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appeals = ref.watch(moderationAppealsProvider);

    return Padding(
      key: const Key('moderation-appeal-queue'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.adminModerationAppeals, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          appeals.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(l10n.profileBeklenmeyenBirHataOlustu),
            data: (items) {
              final open = [
                for (final appeal in items)
                  if (!appeal.status.isDecided) appeal,
              ];
              if (open.isEmpty) {
                return Text(
                  l10n.adminModerationAppealEmpty,
                  style: theme.textTheme.bodySmall,
                );
              }
              return Column(
                children: [for (final appeal in open) _AppealCard(appeal: appeal)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AppealCard extends ConsumerWidget {
  const _AppealCard({required this.appeal});

  final ModerationAppeal appeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final action = appeal.sanctionAction;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔴 WP-B kabul 5 (`ADMIN-PANEL-PLAN.md` §2.1): model
            // `sanctionAction` taşıyordu ama kart onu HİÇ çizmiyordu; yönetici
            // **hangi cezaya** itiraz edildiğini görmeden "Yaptırımı koru /
            // kaldır" düğmesine basıyordu.
            if (action != null)
              Text(
                '${l10n.adminItirazEdilenYaptirim}: '
                '${moderationActionLabel(l10n, action)}',
                key: const Key('appeal-sanction-action'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              appeal.sanctionReason ?? '',
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              appeal.statement,
              style: theme.textTheme.bodyMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (!appeal.canBeDecidedNow)
              Text(
                l10n.adminModerationAppealOwnSanction,
                key: const Key('appeal-conflict-note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else
              // 🔴 `Row` degil `Wrap`: WP-B ile itiraz kutusu 280 px'lik kuyruk
              // sutununda da duruyor ve `Row` orada 279 px tasiyordu (olcum:
              // `moderation_review_flow_test.dart` ilk yesil kosumunda
              // "RenderFlex overflowed by 279 pixels").
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: Key('appeal-uphold-${appeal.id}'),
                    onPressed: () => _decide(context, ref, overturn: false),
                    child: Text(l10n.adminModerationAppealUphold),
                  ),
                  FilledButton(
                    key: Key('appeal-overturn-${appeal.id}'),
                    onPressed: () => _decide(context, ref, overturn: true),
                    child: Text(l10n.adminModerationAppealOverturn),
                  ),
                ],
              ),
          ],
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
  }
}
