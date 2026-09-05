import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/feedback_ticket.dart';
import '../../../data/models/moderation_appeal.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/providers/admin_providers.dart';
import '../cards/admin_work_card.dart';
import '../detail/admin_appeal_detail_page.dart';
import '../detail/admin_case_detail_page.dart';
import '../ticket/admin_ticket_detail_page.dart';
import '../widgets/moderation_queue_card.dart';
import 'admin_queue_entry.dart';
import 'moderation_dialogs.dart';

/// WP-768 — panelin **tek** is kuyrugu.
///
/// 🔴 Sahip karari: *"sikayet/oneri/soru gibi filtrelenebilen bir liste olsun.
/// Orada her kartta sadece detayli incele butonu olsun ve ona basinca ayri bir
/// sayfa acilsin."*
///
/// Oncesinde kuyruk yuzeyi ikiye bolunmustu (`Raporlar` = destek biletleri,
/// `Icerik Sikayetleri` = UGC vakalari); ayni sikayet ikisinde birden
/// gorunuyordu ve kartlarda gizli menuler vardi. Bu ekran ucunu tek listede
/// toplar, aynalari eler ([buildAdminQueue]) ve karttaki tek dugmeyi vakanin
/// kendi sayfasina baglar.
const Key kAdminQueueKey = Key('admin-queue');
const Key kAdminQueueListKey = Key('admin-queue-list');
const Key kAdminQueueFilterKey = Key('admin-queue-filter');
const Key kAdminQueueEmptyKey = Key('admin-queue-empty');
const Key kAdminQueueErrorKey = Key('admin-queue-error');

/// Filtre cipi — kullanicinin dokundugu yerden bulunur.
Key adminQueueFilterKey(AdminQueueCategory? category) =>
    Key('admin-queue-filter-${category?.name ?? 'all'}');

/// WP-792: kapanmis isleri gosteren cip.
const Key kAdminQueueClosedFilterKey = Key('admin-queue-filter-closed');

/// Kart uzerindeki **tek** dugme.
Key adminQueueOpenKey(AdminQueueEntry entry) =>
    Key('admin-queue-open-${entry.id}');

Key adminQueueRowKey(AdminQueueEntry entry) =>
    Key('admin-queue-row-${entry.id}');

class AdminQueueView extends ConsumerStatefulWidget {
  const AdminQueueView({super.key});

  @override
  ConsumerState<AdminQueueView> createState() => _AdminQueueViewState();
}

class _AdminQueueViewState extends ConsumerState<AdminQueueView> {
  AdminQueueCategory? _category;

  /// WP-792 (sahip, cihazda): *"kartlarda resolved isaretliyorum ama
  /// gitmiyor."* Hakliydi. `admin_ugc_report_groups()` durum filtresi
  /// uygulamaz ve [buildAdminQueue] kapanmis isi yalniz DIBE indiriyordu;
  /// cozulen vaka listeden hic cikmiyordu. Kuyruk BEKLEYEN isin listesidir:
  /// kapananlar varsayilan gorunumden duser, bu cip acikken YALNIZ onlar
  /// gorunur (geri acma yolu -- karar + "Geri al" -- oradan yasar).
  bool _showClosed = false;

  Future<void> _refresh() async {
    ref.invalidate(moderationQueueProvider);
    ref.invalidate(moderationAppealsProvider);
    ref.invalidate(adminFeedbackTicketsProvider(null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cases = ref.watch(moderationQueueProvider);
    final tickets = ref.watch(adminFeedbackTicketsProvider(null));
    final appeals = ref.watch(moderationAppealsProvider);

    final ticketList = tickets.value ?? const <FeedbackTicket>[];
    final entries = buildAdminQueue(
      cases: cases.value ?? const [],
      tickets: ticketList,
      appeals: appeals.value ?? const [],
    );
    final visible = [
      for (final entry in entries)
        if (entry.isClosed == _showClosed &&
            (_category == null || entry.category == _category))
          entry,
    ];

    final loading =
        cases.isLoading || tickets.isLoading || appeals.isLoading;
    final failed = cases.hasError || tickets.hasError || appeals.hasError;

    return Column(
      key: kAdminQueueKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filterBar(context),
        // Bir kaynak duserse kuyruk **bos gorunmez**: elde ne varsa cizilir,
        // kayip acikca yazilir ve yeniden denenebilir.
        if (failed)
          Padding(
            key: kAdminQueueErrorKey,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.profileBeklenmeyenBirHataOlustu)),
                TextButton(
                  onPressed: _refresh,
                  child: Text(l10n.taskListRetry),
                ),
              ],
            ),
          ),
        Expanded(
          child: loading && entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: visible.isEmpty
                      ? ListView(
                          key: kAdminQueueListKey,
                          children: [
                            Padding(
                              key: kAdminQueueEmptyKey,
                              padding: const EdgeInsets.only(top: 96),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _showClosed
                                          ? l10n.adminKuyrukKapananBos
                                          : l10n.adminKuyrukBos,
                                    ),
                                    if (_category != null || _showClosed)
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _category = null;
                                          _showClosed = false;
                                        }),
                                        child: Text(l10n.adminFiltreyiTemizle),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          key: kAdminQueueListKey,
                          itemCount: visible.length,
                          itemBuilder: (context, index) => _row(
                            context,
                            visible[index],
                            ticketList,
                          ),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _filterBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: kAdminQueueFilterKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          for (final category in <AdminQueueCategory?>[
            null,
            AdminQueueCategory.complaint,
            AdminQueueCategory.suggestion,
            AdminQueueCategory.question,
            AdminQueueCategory.appeal,
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: adminQueueFilterKey(category),
                label: Text(_categoryLabel(l10n, category)),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
            ),
          // Tur ciplerinden AYRI durur: tur "ne", bu "hangi halde". Ikisi
          // birlikte calisir (kapanmis sikayetler gibi).
          FilterChip(
            key: kAdminQueueClosedFilterKey,
            avatar: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(l10n.adminKuyrukKapananlar),
            selected: _showClosed,
            onSelected: (value) => setState(() => _showClosed = value),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AdminQueueEntry entry,
    List<FeedbackTicket> tickets,
  ) {
    return switch (entry) {
      AdminQueueCaseEntry(:final moderationCase) => ModerationQueueCard(
        key: adminQueueRowKey(entry),
        moderationCase: moderationCase,
        openKey: adminQueueOpenKey(entry),
        onOpenDetail: () => openAdminCaseDetail(
          context,
          moderationCase: moderationCase,
          mirrorTicket: adminMirrorTicket(tickets, moderationCase),
        ),
      ),
      AdminQueueTicketEntry(:final ticket) => _TicketQueueCard(
        key: adminQueueRowKey(entry),
        ticket: ticket,
        openKey: adminQueueOpenKey(entry),
        onOpenDetail: () =>
            openAdminTicketDetail(context: context, ticket: ticket),
      ),
      AdminQueueAppealEntry(:final appeal) => _AppealQueueCard(
        key: adminQueueRowKey(entry),
        appeal: appeal,
        openKey: adminQueueOpenKey(entry),
        onOpenDetail: () => openAdminAppealDetail(context, appeal: appeal),
      ),
    };
  }

  static String _categoryLabel(
    AppLocalizations l10n,
    AdminQueueCategory? category,
  ) => switch (category) {
    null => l10n.adminKuyrukTumu,
    AdminQueueCategory.complaint => l10n.supportTicketTypeReport,
    AdminQueueCategory.suggestion => l10n.adminKuyrukOneri,
    AdminQueueCategory.question => l10n.supportTicketTypeQuestion,
    AdminQueueCategory.appeal => l10n.adminKuyrukItiraz,
  };
}

/// Destek kaydi satiri — vaka kartiyla **ayni kart dili** (WP-698).
class _TicketQueueCard extends StatelessWidget {
  const _TicketQueueCard({
    super.key,
    required this.ticket,
    required this.openKey,
    required this.onOpenDetail,
  });

  final FeedbackTicket ticket;
  final Key openKey;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = _tone();
    final waited = DateTime.now().difference(ticket.updatedAt);
    final languageCode = Localizations.localeOf(context).languageCode;

    return AdminWorkCard(
      typeIcon: _typeIcon(ticket.type),
      title: ticket.subject.trim().isEmpty ? '—' : ticket.subject,
      tone: tone,
      status: AdminWorkStatusLabel(
        label: _statusLabel(l10n, ticket.status),
        tone: tone,
      ),
      excerpt: ticket.message,
      participants: [
        AdminWorkParticipant(
          roleLabel: l10n.adminWorkCardSubmitter,
          name: (ticket.reporterDisplayName ?? '').trim().isEmpty
              ? ticket.userId
              : ticket.reporterDisplayName!,
        ),
      ],
      metaLine:
          '${_typeLabel(l10n, ticket.type)} · '
          '${formatHumanForLocale(waited.inSeconds.abs(), languageCode)}',
      flags: [
        if (ticket.archivedAt != null)
          AdminWorkFlag(l10n.adminWorkCardArchived, tone: AdminWorkTone.done),
      ],
      actions: [
        AdminWorkAction(
          buttonKey: openKey,
          label: l10n.adminDetayliIncele,
          icon: Icons.open_in_new,
          primary: true,
          onPressed: onOpenDetail,
        ),
      ],
    );
  }

  AdminWorkTone _tone() {
    if (ticket.archivedAt != null ||
        ticket.status == FeedbackTicketStatus.closed) {
      return AdminWorkTone.done;
    }
    return ticket.status == FeedbackTicketStatus.inProgress
        ? AdminWorkTone.waiting
        : AdminWorkTone.open;
  }

  static IconData _typeIcon(FeedbackTicketType type) => switch (type) {
    FeedbackTicketType.report => Icons.flag_outlined,
    FeedbackTicketType.question => Icons.help_outline,
    FeedbackTicketType.feedback => Icons.lightbulb_outline,
  };

  static String _typeLabel(AppLocalizations l10n, FeedbackTicketType type) =>
      switch (type) {
        FeedbackTicketType.report => l10n.supportTicketTypeReport,
        FeedbackTicketType.question => l10n.supportTicketTypeQuestion,
        FeedbackTicketType.feedback => l10n.adminKuyrukOneri,
      };

  static String _statusLabel(
    AppLocalizations l10n,
    FeedbackTicketStatus status,
  ) => switch (status) {
    FeedbackTicketStatus.open => l10n.adminAcik,
    FeedbackTicketStatus.inProgress => l10n.adminInceleniyor,
    FeedbackTicketStatus.closed => l10n.adminKapali,
  };
}

/// Itiraz satiri.
///
/// 🔴 Karar dugmeleri karttan **kalkti**: sahip her kartta tek dugme istedi ve
/// "hangi cezaya itiraz edildigini" gormeden onaylamak zaten WP-B'nin kapattigi
/// kusurdu. Karar itirazin kendi sayfasindadir.
class _AppealQueueCard extends StatelessWidget {
  const _AppealQueueCard({
    super.key,
    required this.appeal,
    required this.openKey,
    required this.onOpenDetail,
  });

  final ModerationAppeal appeal;
  final Key openKey;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decidable = appeal.canBeDecidedNow;
    final tone = decidable ? AdminWorkTone.open : AdminWorkTone.waiting;
    final reason = (appeal.sanctionReason ?? '').trim();
    final action = appeal.sanctionAction;

    return AdminWorkCard(
      typeIcon: Icons.gavel_outlined,
      title: reason.isEmpty ? '—' : reason,
      tone: tone,
      status: AdminWorkStatusLabel(label: l10n.adminKuyrukItiraz, tone: tone),
      excerpt: appeal.statement,
      metaLine: action == null
          ? null
          : '${l10n.adminItirazEdilenYaptirim}: '
                '${moderationActionLabel(l10n, action)}',
      flagsKey: kAdminAppealConflictKey,
      flags: decidable
          ? const <AdminWorkFlag>[]
          : [
              AdminWorkFlag(
                l10n.adminModerationAppealOwnSanction,
                tone: AdminWorkTone.urgent,
              ),
            ],
      actions: [
        AdminWorkAction(
          buttonKey: openKey,
          label: l10n.adminDetayliIncele,
          icon: Icons.open_in_new,
          primary: true,
          onPressed: onOpenDetail,
        ),
      ],
    );
  }
}
