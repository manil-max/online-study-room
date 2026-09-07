import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/feedback_ticket.dart';
import '../../../data/models/moderation_appeal.dart';
import '../../../data/models/moderation_case.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/providers/admin_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../../../data/repositories/admin_repository.dart';
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
///
/// WP-794 (sahip onayli onizleme): kuyruk iki **gorunume** ayrildi —
/// "Bekleyen N" / "Arsiv N" segmentleri birbirini dislar; tur cipleri sayi
/// tasir; sagda siralama cipi (En yeni <-> En eski). Arsiv, arsivlenmis
/// biletleri de icerir ve karttan geri acma/arsivden cikarma yolu verir;
/// Bekleyen'deki acik vaka karttan "Incelemeye al"inabilir.
const Key kAdminQueueKey = Key('admin-queue');
const Key kAdminQueueListKey = Key('admin-queue-list');
const Key kAdminQueueFilterKey = Key('admin-queue-filter');
const Key kAdminQueueEmptyKey = Key('admin-queue-empty');
const Key kAdminQueueErrorKey = Key('admin-queue-error');

/// Filtre cipi — kullanicinin dokundugu yerden bulunur.
Key adminQueueFilterKey(AdminQueueCategory? category) =>
    Key('admin-queue-filter-${category?.name ?? 'all'}');

/// WP-794: "Bekleyen" segmenti.
const Key kAdminQueueOpenFilterKey = Key('admin-queue-filter-open');

/// WP-792/794: "Arsiv" segmenti. Anahtar adi WP-792'den korunur; testler onu
/// kullanir.
const Key kAdminQueueClosedFilterKey = Key('admin-queue-filter-closed');

/// WP-794: siralama cipi.
const Key kAdminQueueSortKey = Key('admin-queue-sort');

/// Kart uzerindeki **vurgulu** dugme.
Key adminQueueOpenKey(AdminQueueEntry entry) =>
    Key('admin-queue-open-${entry.id}');

Key adminQueueRowKey(AdminQueueEntry entry) =>
    Key('admin-queue-row-${entry.id}');

/// WP-794: Bekleyen'deki acik vakada "Incelemeye al".
Key adminQueueClaimKey(AdminQueueEntry entry) =>
    Key('admin-queue-claim-${entry.id}');

/// WP-794: Arsiv'deki kapali vakada "Geri ac".
Key adminQueueReopenKey(AdminQueueEntry entry) =>
    Key('admin-queue-reopen-${entry.id}');

/// WP-794: Arsiv'deki arsivlenmis bilette "Arsivden cikar".
Key adminQueueUnarchiveKey(AdminQueueEntry entry) =>
    Key('admin-queue-unarchive-${entry.id}');

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
  /// kapananlar varsayilan gorunumden duser, Arsiv segmentinde YALNIZ onlar
  /// gorunur (geri acma yolu oradan yasar).
  bool _showClosed = false;

  /// WP-794: varsayilan en yeni hareket ustte; cip en uzun bekleyeni one alir.
  bool _oldestFirst = false;

  Future<void> _refresh() async {
    ref.invalidate(moderationQueueProvider);
    ref.invalidate(moderationAppealsProvider);
    ref.invalidate(adminFeedbackTicketsProvider(null));
    ref.invalidate(adminArchivedFeedbackTicketsProvider(null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cases = ref.watch(moderationQueueProvider);
    final tickets = ref.watch(adminFeedbackTicketsProvider(null));
    final archivedTickets = ref.watch(adminArchivedFeedbackTicketsProvider(null));
    final appeals = ref.watch(moderationAppealsProvider);

    final ticketList = _mergeTickets(tickets.value, archivedTickets.value);
    final entries = buildAdminQueue(
      cases: cases.value ?? const [],
      tickets: ticketList,
      appeals: appeals.value ?? const [],
      oldestFirst: _oldestFirst,
    );
    final closedCount = entries.where((entry) => entry.isClosed).length;
    final segment = [
      for (final entry in entries)
        if (entry.isClosed == _showClosed) entry,
    ];
    final visible = [
      for (final entry in segment)
        if (_category == null || entry.category == _category) entry,
    ];

    final loading =
        cases.isLoading ||
        tickets.isLoading ||
        archivedTickets.isLoading ||
        appeals.isLoading;
    final failed =
        cases.hasError ||
        tickets.hasError ||
        archivedTickets.hasError ||
        appeals.hasError;

    return Column(
      key: kAdminQueueKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filterBar(
          context,
          openCount: entries.length - closedCount,
          closedCount: closedCount,
          segment: segment,
        ),
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

  /// WP-794: Arsiv, arsivlenmis biletleri de gosterir. Eskiden yalniz
  /// arsivsiz liste okunuyordu ve arsivlenen bilet kuyruktan **tamamen**
  /// kayboluyordu. `includeArchived: true` listesi acik biletleri DE tasir;
  /// kimlikle tekillestirilir ki ayni bilet iki kez cizilmesin.
  static List<FeedbackTicket> _mergeTickets(
    List<FeedbackTicket>? open,
    List<FeedbackTicket>? withArchived,
  ) {
    final merged = <FeedbackTicket>[...?open];
    if (withArchived == null) return merged;
    final seen = {for (final ticket in merged) ticket.id};
    for (final ticket in withArchived) {
      if (seen.add(ticket.id)) merged.add(ticket);
    }
    return merged;
  }

  Widget _filterBar(
    BuildContext context, {
    required int openCount,
    required int closedCount,
    required List<AdminQueueEntry> segment,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Satir 1 — gorunum: Bekleyen N | Arsiv N. Iki cip kendi satirinda;
        // 390dp'de sagdaki siralama cipiyle ayni satiri paylasinca Arsiv cipi
        // onun altina kayiyordu (test yakaladi: dokunus "En yeni"ye dusuyor).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: kAdminQueueOpenFilterKey,
                  label: Text(
                    _counted(l10n, l10n.adminKuyrukBekleyen, openCount),
                  ),
                  selected: !_showClosed,
                  onSelected: (_) => setState(() => _showClosed = false),
                ),
              ),
              ChoiceChip(
                key: kAdminQueueClosedFilterKey,
                label: Text(
                  _counted(l10n, l10n.adminKuyrukKapananlar, closedCount),
                ),
                selected: _showClosed,
                onSelected: (_) => setState(() => _showClosed = true),
              ),
            ],
          ),
        ),
        // Satir 2 — tur cipleri kayar; siralama cipi seridin DISINDA, her
        // zaman gorunur (WP-792 dersi: kaydirilan seridin sonundaki cip
        // 390dp'de x=706'ya dusmustu, telefonda bulunamiyordu).
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: kAdminQueueFilterKey,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
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
                          label: Text(
                            _counted(
                              l10n,
                              _categoryLabel(l10n, category),
                              category == null
                                  ? segment.length
                                  : segment
                                        .where((e) => e.category == category)
                                        .length,
                            ),
                          ),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
              child: ActionChip(
                key: kAdminQueueSortKey,
                avatar: const Icon(Icons.swap_vert, size: 18),
                label: Text(
                  _oldestFirst
                      ? l10n.adminKuyrukSiralaEnEski
                      : l10n.adminKuyrukSiralaEnYeni,
                ),
                onPressed: () =>
                    setState(() => _oldestFirst = !_oldestFirst),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Sayi 0 ise yalniz etiket: "Soru 0" yerine "Soru".
  static String _counted(AppLocalizations l10n, String label, int count) =>
      count == 0 ? label : l10n.adminKuyrukSayili(label, count);

  Widget _row(
    BuildContext context,
    AdminQueueEntry entry,
    List<FeedbackTicket> tickets,
  ) {
    final l10n = AppLocalizations.of(context);
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
        actions: [
          // Zaten inceleniyorsa dugme yok; hap "Inceleniyor" yaziyor.
          // Tarihsel kayit (case_id yok) sunucuda sifir satir gunceller;
          // dugme hic cizilmez.
          if (moderationCase.status == ModerationCaseStatus.open &&
              moderationCase.supportsCaseActions)
            AdminWorkAction(
              buttonKey: adminQueueClaimKey(entry),
              label: l10n.adminKuyrukIncelemeyeAl,
              icon: Icons.visibility_outlined,
              onPressed: () => _setCaseStatus(
                moderationCase,
                ModerationCaseStatus.inReview,
              ),
            ),
          if (moderationCase.status.isClosed)
            AdminWorkAction(
              buttonKey: adminQueueReopenKey(entry),
              label: l10n.adminKuyrukGeriAc,
              icon: Icons.replay,
              onPressed: () =>
                  _setCaseStatus(moderationCase, ModerationCaseStatus.open),
            ),
        ],
      ),
      AdminQueueTicketEntry(:final ticket) => _TicketQueueCard(
        key: adminQueueRowKey(entry),
        ticket: ticket,
        openKey: adminQueueOpenKey(entry),
        onOpenDetail: () =>
            openAdminTicketDetail(context: context, ticket: ticket),
        unarchiveKey: adminQueueUnarchiveKey(entry),
        onUnarchive: ticket.archivedAt == null
            ? null
            : () => _unarchive(ticket),
      ),
      AdminQueueAppealEntry(:final appeal) => _AppealQueueCard(
        key: adminQueueRowKey(entry),
        appeal: appeal,
        openKey: adminQueueOpenKey(entry),
        onOpenDetail: () => openAdminAppealDetail(context, appeal: appeal),
      ),
    };
  }

  /// Karttan durum yazimi (Incelemeye al / Geri ac). Vaka sayfasindaki
  /// `_applyStatus` deseniyle ayni: `setCaseStatus` etkilenen satir sayisini
  /// doner; sifirsa basari iddia edilmez (`0104` oncesi tarihsel kayit).
  Future<void> _setCaseStatus(
    ModerationCase moderationCase,
    ModerationCaseStatus status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final int affected;
    try {
      affected = await ref
          .read(adminModerationRepositoryProvider)
          .setCaseStatus(moderationCase: moderationCase, status: status);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    if (affected == 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminVakaDurumBagimsizUyari)),
      );
      return;
    }
    await _refresh();
  }

  Future<void> _unarchive(FeedbackTicket ticket) async {
    final userId = ref.read(authStateProvider).value?.id;
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setFeedbackArchived(
            userId: userId,
            ticketId: ticket.id,
            archived: false,
          );
    } on AdminException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    await _refresh();
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
    required this.unarchiveKey,
    this.onUnarchive,
  });

  final FeedbackTicket ticket;
  final Key openKey;
  final VoidCallback onOpenDetail;

  /// WP-794: arsivlenmis bilette "Arsivden cikar"; arsivsizde `null`.
  final Key unarchiveKey;
  final VoidCallback? onUnarchive;

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
        if (onUnarchive != null)
          AdminWorkAction(
            buttonKey: unarchiveKey,
            label: l10n.adminArsivdenCikar,
            icon: Icons.unarchive_outlined,
            onPressed: onUnarchive!,
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
