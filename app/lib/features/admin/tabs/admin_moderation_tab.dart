import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/moderation_appeal.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../cards/admin_work_card.dart';
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

/// WP-703: itiraz karti da **tek kart dilinden** turer.
///
/// WP-698 panelde ortak kart dilini kurdu (`cards/admin_work_card.dart`) ve
/// sikayet + destek bileti kartlarini oraya tasidi; itiraz karti o turda
/// atlandi ve kendi `Card > Column`unda kaldi. Alan esleme (islev kaybi yok):
///
/// | eski | yeni |
/// | --- | --- |
/// | `appeal-sanction-action` satiri | `metaLine` (ayni metin, tek olcek) |
/// | yaptirim gerekcesi (`titleSmall`) | `title` |
/// | itiraz metni (`bodyMedium`, 4 satir) | `excerpt` (2 satir) |
/// | `appeal-conflict-note` (kirmizi metin) | isaret seridi, ayni anahtar |
/// | `appeal-uphold-*` / `appeal-overturn-*` | eylem seridi, ayni anahtarlar |
///
/// 🔴 Iki bilinen odun, gizlenmesin diye burada yazili:
///   * Cakisma notu artik bir isaret hapidir ve 280 px'lik kuyruk sutununda
///     tek satira kirpilir (390 px'te tam sigar). Anahtarin ve kirmizi tonun
///     korunmasi, cumlenin dar sutunda tam okunmasindan once geldi: eylemler
///     zaten hic cizilmiyor, hap ise **neden** cizilmedigini isaretliyor.
///   * Durum hapi bu kartta karar kontroludur. Karara baglayamayan yoneticiye
///     secenek verilmez; liste bos kalir ve `PopupMenuButton` menuyu hic acmaz
///     (Flutter `showButtonMenu` bos listede geri doner). Sunucunun
///     reddedecegi bir eylemi vaat etmemek WP-442 kabulunun aynisidir.
class _AppealCard extends ConsumerWidget {
  const _AppealCard({required this.appeal});

  final ModerationAppeal appeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final action = appeal.sanctionAction;
    final decidable = appeal.canBeDecidedNow;
    final reason = (appeal.sanctionReason ?? '').trim();
    final tone = decidable ? AdminWorkTone.open : AdminWorkTone.waiting;

    return AdminWorkCard(
      typeIcon: Icons.gavel_outlined,
      // "Ne hakkinda": yaptirimin gerekcesi. Eski kartta da en buyuk satir
      // buydu; sunucu gerekce gondermezse baslik bos kutu olmasin diye tire.
      title: reason.isEmpty ? '—' : reason,
      tone: tone,
      status: AdminWorkStatusPill<ModerationAppealStatus>(
        label: l10n.adminAcik,
        tone: tone,
        options: decidable
            ? const [
                ModerationAppealStatus.upheld,
                ModerationAppealStatus.overturned,
              ]
            : const <ModerationAppealStatus>[],
        optionLabel: (status) => status == ModerationAppealStatus.overturned
            ? l10n.adminModerationAppealOverturn
            : l10n.adminModerationAppealUphold,
        onSelected: (status) => _decide(
          context,
          ref,
          overturn: status == ModerationAppealStatus.overturned,
        ),
        tooltip: decidable ? null : l10n.adminModerationAppealOwnSanction,
      ),
      // Kullanicinin kendi yazdigi itiraz metni.
      excerpt: appeal.statement,
      // 🔴 WP-B kabul 5 (`ADMIN-PANEL-PLAN.md` §2.1): model `sanctionAction`
      // tasiyordu ama kart onu HIC cizmiyordu; yonetici **hangi cezaya**
      // itiraz edildigini gormeden "Yaptirimi koru / kaldir"a basiyordu.
      metaLine: action == null
          ? null
          : '${l10n.adminItirazEdilenYaptirim}: '
                '${moderationActionLabel(l10n, action)}',
      flagsKey: const Key('appeal-conflict-note'),
      flags: decidable
          ? const <AdminWorkFlag>[]
          : [
              AdminWorkFlag(
                l10n.adminModerationAppealOwnSanction,
                tone: AdminWorkTone.urgent,
              ),
            ],
      actions: decidable
          ? [
              AdminWorkAction(
                buttonKey: Key('appeal-uphold-${appeal.id}'),
                label: l10n.adminModerationAppealUphold,
                icon: Icons.shield_outlined,
                onPressed: () => _decide(context, ref, overturn: false),
              ),
              AdminWorkAction(
                buttonKey: Key('appeal-overturn-${appeal.id}'),
                label: l10n.adminModerationAppealOverturn,
                icon: Icons.undo,
                primary: true,
                onPressed: () => _decide(context, ref, overturn: true),
              ),
            ]
          : const <AdminWorkAction>[],
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
