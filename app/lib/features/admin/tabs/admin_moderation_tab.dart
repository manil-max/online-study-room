import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/moderation_appeal.dart';
import '../../../data/models/moderation_case.dart';
import '../../../data/models/moderation_sanction.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../widgets/moderation_queue_card.dart';

/// WP-424 / WP-440: UGC moderasyon kuyruğu (super-admin, RLS).
///
/// WP-440 kod borcu: ekran artık `Supabase.instance.client` ile konuşmuyor.
/// Okuma `admin_ugc_report_groups()`, yazma `admin_set_ugc_report_group_status()`
/// RPC'lerinden `AdminModerationRepository` üzerinden geçiyor; doğrudan tablo
/// UPDATE'i kalktı.
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
      data: (cases) {
        if (cases.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(moderationQueueProvider);
              ref.invalidate(moderationAppealsProvider);
            },
            child: ListView(
              children: [
                const _AppealQueue(),
                const SizedBox(height: 120),
                Center(child: Text(l10n.adminUgcNoReports)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(moderationQueueProvider);
            ref.invalidate(moderationAppealsProvider);
          },
          child: ListView.builder(
            // WP-442: itiraz kuyruğu kartların üstünde ilk sırada durur;
            // bekleyen itiraz vaka kartlarının arasında kaybolmasın.
            itemCount: cases.length + 1,
            itemBuilder: (context, rawIndex) {
              if (rawIndex == 0) return const _AppealQueue();
              final index = rawIndex - 1;
              final moderationCase = cases[index];
              return ModerationQueueCard(
                key: ValueKey(moderationCase.caseKey),
                moderationCase: moderationCase,
                onStatusSelected: (status) => _applyStatus(
                  context,
                  ref,
                  moderationCase: moderationCase,
                  status: status,
                ),
                onOpenDetail: moderationCase.reportIds.isEmpty
                    ? null
                    : () => _openDetail(context, moderationCase.reportIds.first),
                onSanction: moderationCase.targetIdentity == null
                    // Grup hedefinde yaptırım uygulanacak kişi yok; menüde ölü
                    // seçenek bırakmıyoruz.
                    ? null
                    : () => _openSanctionSheet(context, ref, moderationCase),
                onQuarantineToggle: (quarantined) => _applyQuarantine(
                  context,
                  ref,
                  moderationCase: moderationCase,
                  quarantined: quarantined,
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Durum değişimi.
  ///
  /// **Yanlışlıkla kapatma geri alınabilir:** kapatılan vaka kuyruktan
  /// düşmez, durum çipi etkin kalır ve tek dokunuşla `İnceleniyor`a döner.
  /// Geri almayı ayrı bir "geri al" şeridine bağlamıyoruz; şerit kaybolduktan
  /// sonra da geri dönüş yolu açık kalsın diye kalıcı olan çipe bağlı.
  /// Sunucu RPC'si `open` yazamadığı için başlangıçta `open` olan vaka
  /// `in_review` olarak geri gelir; tam `open` restorasyonu `0105` yaptırım
  /// diliminde RPC allow-list'ine eklenecek.
  Future<void> _applyStatus(
    BuildContext context,
    WidgetRef ref, {
    required ModerationCase moderationCase,
    required ModerationCaseStatus status,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(adminModerationRepositoryProvider);

    try {
      await repository.setCaseStatus(
        moderationCase: moderationCase,
        status: status,
      );
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(moderationQueueProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(_StatusText.of(l10n, status))),
    );
  }

  /// WP-441: Basamaklı yaptırım.
  ///
  /// Gerekçe zorunludur ve idempotency anahtarı **sayfa açılışında bir kez**
  /// üretilir: aynı sayfadan yapılan yeniden deneme sunucuda ikinci yaptırım
  /// açmaz.
  Future<void> _openSanctionSheet(
    BuildContext context,
    WidgetRef ref,
    ModerationCase moderationCase,
  ) async {
    final targetId = moderationCase.targetIdentity?.id;
    if (targetId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final request = await showModalBottomSheet<ModerationSanctionRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SanctionSheet(
        targetUserId: targetId,
        caseId: moderationCase.caseId,
      ),
    );
    if (request == null) return;

    final repository = ref.read(adminModerationRepositoryProvider);
    try {
      await repository.applySanction(request);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(moderationQueueProvider);
    ref.invalidate(moderationSanctionsProvider(targetId));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminModerationSanctionApplied)),
    );
  }

  /// Karantina geri alınabilir olduğu için tek düğmede toggle edilir.
  Future<void> _applyQuarantine(
    BuildContext context,
    WidgetRef ref, {
    required ModerationCase moderationCase,
    required bool quarantined,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final reason = await askReason(context, l10n.adminModerationQuarantine);
    if (reason == null) return;
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .setQuarantine(
            moderationCase: moderationCase,
            quarantined: quarantined,
            reason: reason,
          );
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(moderationQueueProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          quarantined
              ? l10n.adminModerationQuarantined
              : l10n.adminModerationQuarantineRelease,
        ),
      ),
    );
  }

  /// Gerekçe zorunludur; boş gerekçe sessizce "gerekçe belirtilmedi"ye
  /// çevrilmez, işlem hiç yapılmaz.
  @visibleForTesting
  static Future<String?> askReason(BuildContext context, String title) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(title: title),
    );
    if (reason == null || reason.trim().isEmpty) return null;
    return reason.trim();
  }

  void _openDetail(BuildContext context, String reportId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ModerationDetailSheet(reportId: reportId),
    );
  }
}

class _StatusText {
  static String of(AppLocalizations l10n, ModerationCaseStatus status) =>
      switch (status) {
        ModerationCaseStatus.open => l10n.adminAcik,
        ModerationCaseStatus.inReview => l10n.adminUgcStatusInReview,
        ModerationCaseStatus.resolved => l10n.adminUgcStatusResolved,
        ModerationCaseStatus.rejected => l10n.adminUgcStatusRejected,
      };
}

class _ModerationDetailSheet extends ConsumerWidget {
  const _ModerationDetailSheet({required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(moderationCaseDetailProvider(reportId));
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .9,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(l10n.profileBeklenmeyenBirHataOlustu)),
          data: (data) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SelectableText(
                data.snapshot,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if ((data.details ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(data.details!),
              ],
              const Divider(height: 32),
              for (final message in data.contextMessages)
                ListTile(
                  dense: true,
                  title: Text(message.displayName),
                  subtitle: Text(message.body),
                  selected: message.isTarget,
                ),
              const Divider(height: 32),
              Text('${l10n.adminRaporlar}: ${data.reportCount}'),
              for (final reason in data.sanctionReasons) Text(reason),
            ],
          ),
        ),
      ),
    );
  }
}


/// Basamaklı yaptırım sayfası.
///
/// Basamaklar **sunucudaki sırayla** listelenir; gerekçe boşken uygula düğmesi
/// çalışmaz. Idempotency anahtarı sayfa açılışında bir kez üretilir, böylece
/// aynı sayfadan yapılan yeniden deneme ikinci yaptırım açmaz.
class _SanctionSheet extends StatefulWidget {
  const _SanctionSheet({required this.targetUserId, this.caseId});

  final String targetUserId;
  final String? caseId;

  @override
  State<_SanctionSheet> createState() => _SanctionSheetState();
}

class _SanctionSheetState extends State<_SanctionSheet> {
  final TextEditingController _reason = TextEditingController();
  late final String _idempotencyKey =
      'sanction-${widget.targetUserId}-${DateTime.now().microsecondsSinceEpoch}';
  ModerationAction _action = ModerationAction.warn;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.adminModerationSanctionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ModerationAction>(
              key: const Key('moderation-sanction-action'),
              initialValue: _action,
              items: [
                for (final action in ModerationAction.values)
                  DropdownMenuItem(
                    value: action,
                    child: Text(_actionLabel(l10n, action)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _action = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('moderation-sanction-reason'),
              controller: _reason,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.adminGerekceZorunlu,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('moderation-sanction-submit'),
              onPressed: _reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      ModerationSanctionRequest(
                        targetUserId: widget.targetUserId,
                        action: _action,
                        reason: _reason.text.trim(),
                        idempotencyKey: _idempotencyKey,
                        caseId: widget.caseId,
                      ),
                    ),
              child: Text(l10n.adminOnayla),
            ),
          ],
        ),
      ),
    );
  }

  static String _actionLabel(AppLocalizations l10n, ModerationAction action) =>
      switch (action) {
        ModerationAction.noAction => l10n.adminModerationSanctionNoAction,
        ModerationAction.warn => l10n.adminModerationSanctionWarn,
        ModerationAction.nameReset => l10n.adminModerationSanctionNameReset,
        ModerationAction.mute24h => l10n.adminModerationSanctionMute24h,
        ModerationAction.suspend24h => l10n.adminModerationSanctionSuspend24h,
        ModerationAction.suspend7d => l10n.adminModerationSanctionSuspend7d,
        ModerationAction.suspend14d => l10n.adminModerationSanctionSuspend14d,
        ModerationAction.suspend30d => l10n.adminModerationSanctionSuspend30d,
        ModerationAction.banPermanent => l10n.adminModerationSanctionBan,
      };
}


/// Gerekçe soran diyalog.
///
/// Controller'ı diyalogun kendisi tutar: çağıran tarafta `dispose` etmek,
/// diyalog kapanış animasyonu sürerken denetleyiciyi öldürüp çerçeveyi
/// düşürüyordu.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('moderation-reason-field'),
        controller: _controller,
        decoration: InputDecoration(
          labelText: l10n.adminGerekceZorunlu,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminIptal),
        ),
        FilledButton(
          key: const Key('moderation-reason-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.adminOnayla),
        ),
      ],
    );
  }
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: Key('appeal-uphold-${appeal.id}'),
                    onPressed: () => _decide(context, ref, overturn: false),
                    child: Text(l10n.adminModerationAppealUphold),
                  ),
                  const SizedBox(width: 8),
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
    final note = await AdminModerationTab.askReason(
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
