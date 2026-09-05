import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/feedback_ticket.dart';
import '../../../data/models/moderation_case.dart';
import '../../../data/models/moderation_sanction.dart';
import '../../../data/models/report_target.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/providers/admin_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../../../data/repositories/admin_repository.dart';
import '../queue/moderation_attachment_preview.dart';
import '../queue/moderation_dialogs.dart';
import '../sanctions/admin_sanction_actions.dart';
import '../sanctions/sanction_ladder.dart';
import '../ticket/admin_ticket_detail_page.dart';

/// WP-769 — sikayetin **kendi tam sayfasi**.
///
/// 🔴 Sahip karari: *"her kartta sadece detayli incele butonu olsun, basinca
/// ayri bir sayfa acilsin o karta ozel ve her sey orada olsun; baska bir
/// ekrani istemiyorum."*
///
/// Bunun oncesinde inceleme, kuyrugun **yanindaki bolmede** aciliyordu
/// (`queue/moderation_review_view.dart`, WP-B). O tasarim kaniti ve karari ayni
/// anda ekranda tutuyordu ama sahip icin hala "parca parca"ydi: kanit dar
/// bolmede, hedefin gecmisi baska bir yuzeyde (Kisiler & Gruplar), sikayet
/// edenle yazisma bambaska bir sekmedeydi.
///
/// Bu sayfa o dagilmayi kapatir. Tek sayfada:
///   1. kanit (icerik, **ek gorsel**, aciklama, gerekce, zaman, baglam),
///   2. taraflar (kim sikayet etti, kim edildi),
///   3. hedefin dosyasi (aktif kisit + ceza gecmisi + kisit uygula/kaldir),
///   4. yazisma (sikayet edene yanit) ve kullaniciya bildirim,
///   5. **karar seridi** — sayfanin altina sabit.
///
/// 🔴 Serit `Scaffold.bottomSheet` ile kurulmaz (depoda kayitli tuzak: govdeyi
/// orter, yer ayirmaz). `Column` + `Expanded` kullanilir.
const Key kAdminCaseDetailKey = Key('admin-case-detail');

/// Kanit listesi — anahtar WP-B'den korunur, testler bunu ariyor.
const Key kModerationEvidenceKey = Key('moderation-evidence');

const Key kModerationDecisionBarKey = Key('moderation-decision-bar');
const Key kModerationDecisionReasonKey = Key('moderation-decision-reason');
const Key kModerationDecisionResolvedKey = Key('moderation-decision-resolved');
const Key kModerationDecisionRejectedKey = Key('moderation-decision-rejected');
const Key kModerationDecisionQuarantineKey = Key(
  'moderation-decision-quarantine',
);
const Key kModerationDecisionSanctionKey = Key('moderation-decision-sanction');
const Key kModerationUndoBarKey = Key('moderation-undo-bar');
const Key kModerationUndoButtonKey = Key('moderation-undo-button');

/// Hedefin dosyasi — sayfanin **icinde**, ayri ekran degil.
const Key kAdminCaseTargetSummaryKey = Key('admin-case-target-summary');
const Key kAdminCaseSanctionApplyKey = Key('admin-case-sanction-apply');
const Key kAdminCaseSanctionRevokeKey = Key('admin-case-sanction-revoke');

/// Sikayet edenle yazisma (aynali destek kaydi).
const Key kAdminCaseReplyKey = Key('admin-case-reply');

/// Hedefe dogrudan bildirim (kullaniciya ozel duyuru).
const Key kAdminCaseNoticeTitleKey = Key('admin-case-notice-title');
const Key kAdminCaseNoticeBodyKey = Key('admin-case-notice-body');
const Key kAdminCaseNoticeSendKey = Key('admin-case-notice-send');

/// PLAN §4.4.2: geri alinabilir karar teyit istemez, **10 saniyelik** serit
/// acar. Teyit enflasyonu teyidi oldurur.
const Duration kModerationUndoWindow = Duration(seconds: 10);

/// Kuyruk satirindaki tek dugmenin actigi yer.
Future<void> openAdminCaseDetail(
  BuildContext context, {
  required ModerationCase moderationCase,
  FeedbackTicket? mirrorTicket,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminCaseDetailPage(
        moderationCase: moderationCase,
        mirrorTicket: mirrorTicket,
      ),
    ),
  );
}

class AdminCaseDetailPage extends ConsumerStatefulWidget {
  const AdminCaseDetailPage({
    super.key,
    required this.moderationCase,
    this.mirrorTicket,
  });

  final ModerationCase moderationCase;

  /// `report_ugc` her sikayet icin bir destek kaydi da acar. Sikayet edenle
  /// yazismanin tek kanali odur; kuyruk onu listede gizler ve buraya verir.
  final FeedbackTicket? mirrorTicket;

  @override
  ConsumerState<AdminCaseDetailPage> createState() =>
      _AdminCaseDetailPageState();
}

class _UndoEntry {
  const _UndoEntry({
    required this.previousStatus,
    required this.appliedStatus,
  });

  final ModerationCaseStatus previousStatus;
  final ModerationCaseStatus appliedStatus;
}

class _AdminCaseDetailPageState extends ConsumerState<AdminCaseDetailPage> {
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _noticeTitle = TextEditingController();
  final TextEditingController _noticeBody = TextEditingController();

  late ModerationCase _case = widget.moderationCase;
  _UndoEntry? _undo;
  Timer? _undoTimer;

  /// Ayni sayfa farkli bir vakayla yeniden kurulursa yerel kopya tazelenir.
  /// Her vaka kendi rotasinda acildigi icin uretimde nadirdir; testte ve
  /// gelecekteki bir liste-detay kullaniminda sessiz yanlis vakayi engeller.
  @override
  void didUpdateWidget(AdminCaseDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moderationCase.caseKey != widget.moderationCase.caseKey) {
      _undoTimer?.cancel();
      _undo = null;
      _case = widget.moderationCase;
      _reason.clear();
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _reason.dispose();
    _noticeTitle.dispose();
    _noticeBody.dispose();
    super.dispose();
  }

  String? get _reportId =>
      _case.reportIds.isEmpty ? null : _case.reportIds.first;

  String? get _targetUserId {
    final identity = _case.targetIdentity;
    if (identity == null || identity.isDeleted) return null;
    return identity.id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: kAdminCaseDetailKey,
      appBar: AppBar(title: Text(l10n.adminVakaDetayBaslik)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // SPEC §3: form/okuma sutunu tavani 760.
            constraints: const BoxConstraints(
              maxWidth: DesktopBreakpoints.maxFormWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_undo != null) _undoBar(context),
                Expanded(child: _body(context)),
                _DecisionBar(
                  moderationCase: _case,
                  reason: _reason,
                  onStatus: _applyStatus,
                  onQuarantine: _quarantineFromBar,
                  onSanction: _targetUserId == null ? null : _openSanctions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Govde ------------------------------------------------------------

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reportId = _reportId;
    if (reportId == null) {
      // 🔴 Eskiden bu vakada kart hic acilmiyordu ve NEDEN acilmadigini
      // soylemiyordu (PLAN §2.2 "sessiz olu dokunus").
      return ListView(
        key: kModerationEvidenceKey,
        padding: const EdgeInsets.all(16),
        children: [
          _header(context),
          const SizedBox(height: 12),
          Text(l10n.adminIncelemeDetayYok),
          const SizedBox(height: 24),
          ..._parties(context),
          ..._targetDossier(context),
          ..._contact(context),
        ],
      );
    }

    final detail = ref.watch(moderationCaseDetailProvider(reportId));
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(l10n.profileBeklenmeyenBirHataOlustu)),
      data: (data) => ListView(
        key: kModerationEvidenceKey,
        padding: const EdgeInsets.all(16),
        children: [
          _header(context),
          const SizedBox(height: 16),
          ..._evidence(context, data),
          const SizedBox(height: 24),
          ..._parties(context, detail: data),
          ..._targetDossier(context),
          ..._history(context, data),
          ..._contact(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final identity = _case.targetIdentity;
    final name = identity == null || identity.isDeleted
        ? l10n.adminUgcDeletedUser
        : identity.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.adminUgcTarget}: $name',
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          _targetTypeLabel(l10n, _case.targetType),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _evidence(BuildContext context, ModerationCaseDetail data) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      _section(context, l10n.adminIncelemeIcerik),
      SelectableText(
        data.snapshot.trim().isEmpty
            ? l10n.adminIncelemeIcerikYok
            : data.snapshot,
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      _section(context, l10n.adminIncelemeEk),
      if (data.attachmentPath != null)
        ModerationAttachmentButton(path: data.attachmentPath!)
      else
        Text(l10n.adminIncelemeEkYok, style: theme.textTheme.bodySmall),
      if ((data.details ?? '').isNotEmpty) ...[
        const SizedBox(height: 16),
        _section(context, l10n.adminIncelemeAciklama),
        SelectableText(data.details!),
      ],
      const SizedBox(height: 16),
      _meta(context, data),
      if (data.contextMessages.isNotEmpty) ...[
        const SizedBox(height: 16),
        _section(context, l10n.adminIncelemeBaglam),
        for (final message in data.contextMessages)
          ListTile(
            dense: true,
            title: Text(message.displayName),
            subtitle: Text(message.body),
            selected: message.isTarget,
          ),
      ],
    ];
  }

  /// Gerekce · gelis zamani · rapor sayisi.
  Widget _meta(BuildContext context, ModerationCaseDetail data) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final createdAt = data.createdAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.adminIncelemeGerekce}: '
          '${_reasonLabel(l10n, data.reason ?? '')}',
          style: theme.textTheme.bodyMedium,
        ),
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          Text(
            '${l10n.adminIncelemeGelisZamani}: '
            '${MaterialLocalizations.of(context).formatFullDate(createdAt)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  /// Kim sikayet etti, kim edildi — kuyruk kartindan **kopya degil**, kararin
  /// verildigi yerde durur.
  List<Widget> _parties(BuildContext context, {ModerationCaseDetail? detail}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final identity = _case.targetIdentity;
    final targetName = identity == null || identity.isDeleted
        ? l10n.adminUgcDeletedUser
        : identity.displayName;
    final count = detail?.reportCount ?? _case.reportCount;
    return [
      _section(context, l10n.adminVakaTaraflar),
      _partyRow(context, l10n.adminUgcTarget, targetName, _case.targetId),
      for (final reporter in _case.reporters)
        _partyRow(
          context,
          l10n.adminUgcReporter,
          reporter.isDeleted ? l10n.adminUgcDeletedUser : reporter.displayName,
          reporter.id,
        ),
      const SizedBox(height: 4),
      Text(
        l10n.adminVakaSikayetSayisi(count),
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _partyRow(
    BuildContext context,
    String role,
    String name,
    String id,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$role: $name',
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SelectableText(
            id,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔴 Sahibin sarti: *"bu panele hic ihtiyacim olmasin gelenleri
  /// degerlendirirken."* Hedefin aktif kisiti, ceza gecmisi ve yaptirim yolu
  /// bu yuzden **bu sayfada** durur; Kisiler & Gruplar yuzeyine gitmek
  /// gerekmez.
  List<Widget> _targetDossier(BuildContext context) {
    final targetUserId = _targetUserId;
    if (targetUserId == null) return const [];
    return [
      _section(context, AppLocalizations.of(context).adminSanctionDossierTitle),
      _TargetSanctions(
        key: kAdminCaseTargetSummaryKey,
        targetUserId: targetUserId,
        caseId: _case.caseId,
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _history(BuildContext context, ModerationCaseDetail data) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      _section(context, l10n.adminIncelemeGecmis),
      if (data.sanctions.isEmpty)
        Text(l10n.adminIncelemeGecmisYok, style: theme.textTheme.bodySmall)
      else
        for (final entry in data.sanctions) _historyRow(context, entry),
      const SizedBox(height: 24),
    ];
  }

  Widget _historyRow(
    BuildContext context,
    ModerationSanctionHistoryEntry entry,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final action = entry.moderationAction;
    // Merdivene oturmayan denetim satiri ham adiyla gosterilir; yutulmaz.
    final label = action == null
        ? (entry.action ?? '—')
        : moderationActionLabel(l10n, action);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        (entry.reason ?? '').isEmpty ? label : '$label — ${entry.reason}',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  /// Yazisma + bildirim: karari **anlatmanin** iki yolu da sayfada.
  List<Widget> _contact(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ticket = widget.mirrorTicket;
    final targetUserId = _targetUserId;
    return [
      _section(context, l10n.adminVakaYanitBaslik),
      if (ticket == null)
        Text(l10n.adminVakaYanitYok, style: theme.textTheme.bodySmall)
      else
        OutlinedButton.icon(
          key: kAdminCaseReplyKey,
          onPressed: () =>
              openAdminTicketDetail(context: context, ticket: ticket),
          icon: const Icon(Icons.forum_outlined, size: 20),
          label: Text(l10n.adminVakaYanitBaslik),
        ),
      if (targetUserId != null) ...[
        const SizedBox(height: 24),
        _section(context, l10n.adminVakaBildirimBaslik),
        TextField(
          key: kAdminCaseNoticeTitleKey,
          controller: _noticeTitle,
          decoration: InputDecoration(
            labelText: l10n.adminBaslik,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: kAdminCaseNoticeBodyKey,
          controller: _noticeBody,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.adminMesaj,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: kAdminCaseNoticeSendKey,
            onPressed: () => _sendNotice(targetUserId),
            icon: const Icon(Icons.campaign_outlined, size: 20),
            label: Text(l10n.adminGonder),
          ),
        ),
      ],
    ];
  }

  Widget _undoBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: kModerationUndoBarKey,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusText(l10n, _undo!.appliedStatus),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(
            key: kModerationUndoButtonKey,
            onPressed: _undoLastDecision,
            child: Text(l10n.adminIncelemeGeriAl),
          ),
        ],
      ),
    );
  }

  // --- Kararlar ---------------------------------------------------------

  /// Durum degisimi.
  ///
  /// 🔴 WP-769 hata (a): `setCaseStatus` **etkilenen satir sayisini** donuyor
  /// (`admin_set_ugc_report_group_status` `returns bigint`), ekran bu sayiyi
  /// hic okumuyordu. `0104` oncesi kapanmis raporlarin vakasi yok; RPC sifir
  /// satir gunceller ve ekran yine "Cozuldu" yazip geri alma seridi acardi.
  /// Artik sifir satirda **basari iddia edilmez**.
  Future<void> _applyStatus(ModerationCaseStatus status) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final previous = _case.status;
    final int affected;
    try {
      affected = await ref
          .read(adminModerationRepositoryProvider)
          .setCaseStatus(moderationCase: _case, status: status);
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
    _refresh();
    setState(() => _case = _case.copyWith(status: status));
    _armUndo(_UndoEntry(previousStatus: previous, appliedStatus: status));
    messenger.showSnackBar(SnackBar(content: Text(_statusText(l10n, status))));
  }

  void _armUndo(_UndoEntry entry) {
    _undoTimer?.cancel();
    setState(() => _undo = entry);
    _undoTimer = Timer(kModerationUndoWindow, () {
      if (!mounted) return;
      setState(() => _undo = null);
    });
  }

  Future<void> _undoLastDecision() async {
    final entry = _undo;
    if (entry == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .setCaseStatus(
            moderationCase: _case,
            status: entry.previousStatus,
          );
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _undoTimer?.cancel();
    _refresh();
    if (!mounted) return;
    setState(() {
      _case = _case.copyWith(status: entry.previousStatus);
      _undo = null;
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminIncelemeKararGeriAlindi)),
    );
  }

  /// Karar seridindeki **tek** gerekce alanini kullanir; ikinci diyalog acmaz.
  Future<void> _quarantineFromBar() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final next = !_case.quarantined;
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .setQuarantine(
            moderationCase: _case,
            quarantined: next,
            reason: reason,
          );
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _refresh();
    if (!mounted) return;
    setState(() => _case = _case.copyWith(quarantined: next));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          next
              ? l10n.adminModerationQuarantined
              : l10n.adminModerationQuarantineRelease,
        ),
      ),
    );
  }

  Future<void> _openSanctions() async {
    final targetUserId = _targetUserId;
    if (targetUserId == null) return;
    await AdminSanctionActions.chooseAndApply(
      context,
      ref,
      targetUserId: targetUserId,
      // Sert teyit yalniz kalici yasakta calisir; kimlik dizinden gelmezse
      // kullanicinin kendi kimligi yazdirilir.
      confirmationPhrase: targetUserId,
      // Tam katalog: uyari ve isim sifirlama da bu sayfadan uygulanir.
      ladder: kAdminSanctionLadder,
      caseId: _case.caseId,
    );
    _refresh();
  }

  /// Kullaniciya dogrudan bildirim — hedefe ozel duyuru
  /// (`announcements.target_type = 'user'`).
  Future<void> _sendNotice(String targetUserId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = _noticeTitle.text.trim();
    final message = _noticeBody.text.trim();
    if (title.isEmpty || message.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminGerekliAlanlarDoldurulmalidir)),
      );
      return;
    }
    final admin = ref.read(authStateProvider).value;
    if (admin == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .createAnnouncement(
            title: title,
            message: message,
            targetType: 'user',
            targetId: targetUserId,
            adminId: admin.id,
          );
    } on AdminException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(adminAnnouncementsProvider);
    if (!mounted) return;
    _noticeTitle.clear();
    _noticeBody.clear();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminVakaBildirimGonderildi)),
    );
  }

  /// 🔴 WP-769 hata (b): kanit panosu **hicbir eylemden sonra tazelenmiyordu**.
  /// `moderationCaseDetailProvider` autoDispose degil ve depoda tek bir
  /// `invalidate` cagrisi yoktu; yaptirim uygulandiktan sonra "Gecmis" blogu
  /// hala yaptirim oncesi listeyi cizip yoneticiyi ikinci kez uygulamaya
  /// itiyordu.
  void _refresh() {
    ref.invalidate(moderationQueueProvider);
    final reportId = _reportId;
    if (reportId != null) {
      ref.invalidate(moderationCaseDetailProvider(reportId));
    }
    final targetUserId = _targetUserId;
    if (targetUserId != null) {
      ref.invalidate(moderationSanctionsProvider(targetUserId));
    }
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

/// Hedefin aktif kisiti + ceza gecmisi + yaptirim yolu.
///
/// `moderationSanctionsProvider` burada **`ref.watch`** edilir: yaptirim
/// uygulanip geri alindiginda blok kendiliginden tazelenir.
class _TargetSanctions extends ConsumerWidget {
  const _TargetSanctions({
    super.key,
    required this.targetUserId,
    required this.caseId,
  });

  final String targetUserId;
  final String? caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sanctions = ref.watch(moderationSanctionsProvider(targetUserId));

    return sanctions.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Text(l10n.authBeklenmeyenBirHataOlustu),
      data: (items) {
        final now = DateTime.now();
        ModerationSanction? active;
        for (final sanction in items) {
          if (sanction.isActive(now)) {
            active = sanction;
            break;
          }
        }
        final current = active;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current == null)
              Text(
                l10n.adminSanctionNoActiveRestriction,
                style: theme.textTheme.bodyMedium,
              )
            else
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.adminModerationSanctionActive(
                          adminSanctionLabel(l10n, current.action),
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current.expiresAt == null
                            ? l10n.adminSanctionNoExpiry
                            : l10n.adminSanctionExpiresAt(
                                _stamp(current.expiresAt!),
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: kAdminCaseSanctionRevokeKey,
                        onPressed: () => AdminSanctionActions.revoke(
                          context,
                          ref,
                          sanction: current,
                        ),
                        icon: const Icon(Icons.undo, size: 20),
                        label: Text(l10n.adminSanctionLiftRestriction),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: kAdminCaseSanctionApplyKey,
                onPressed: () => AdminSanctionActions.chooseAndApply(
                  context,
                  ref,
                  targetUserId: targetUserId,
                  confirmationPhrase: targetUserId,
                  ladder: kAdminSanctionLadder,
                  caseId: caseId,
                ),
                icon: const Icon(Icons.gavel_outlined, size: 20),
                label: Text(l10n.adminSanctionApplyRestriction),
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.adminSanctionHistoryEmpty,
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminSanctionHistoryTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    for (final sanction in items)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${adminSanctionLabel(l10n, sanction.action)} · '
                          '${adminSanctionStateLabel(l10n, sanction.state)}'
                          '${sanction.appliedAt == null ? '' : ' · ${_stamp(sanction.appliedAt!)}'}',
                          style: theme.textTheme.bodySmall,
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

  static String _stamp(DateTime value) =>
      value.toLocal().toString().substring(0, 16);
}

/// Karar seridi — sayfanin **altina sabit**.
class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.moderationCase,
    required this.reason,
    required this.onStatus,
    required this.onQuarantine,
    required this.onSanction,
  });

  final ModerationCase moderationCase;
  final TextEditingController reason;
  final ValueChanged<ModerationCaseStatus> onStatus;
  final VoidCallback onQuarantine;
  final VoidCallback? onSanction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: kModerationDecisionBarKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.adminIncelemeKarar, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            key: kModerationDecisionReasonKey,
            controller: reason,
            decoration: InputDecoration(
              labelText: l10n.adminGerekceZorunlu,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: reason,
            builder: (context, value, _) {
              // Gerekce sunucuya GERCEKTEN giden eylemlerde zorunludur;
              // gitmedigi yerde zorunlu gostermek yalan etiket olurdu.
              final hasReason = value.text.trim().isNotEmpty;
              final canQuarantine =
                  hasReason && moderationCase.supportsCaseActions;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: kModerationDecisionQuarantineKey,
                    onPressed: canQuarantine ? onQuarantine : null,
                    child: Text(
                      moderationCase.quarantined
                          ? l10n.adminModerationQuarantineRelease
                          : l10n.adminModerationQuarantine,
                    ),
                  ),
                  Tooltip(
                    message: onSanction == null
                        ? l10n.adminKullaniciBulunamadi
                        : l10n.adminModerationSanctionTitle,
                    child: OutlinedButton(
                      key: kModerationDecisionSanctionKey,
                      onPressed: onSanction,
                      child: Text(l10n.adminModerationSanctionTitle),
                    ),
                  ),
                  OutlinedButton(
                    key: kModerationDecisionRejectedKey,
                    onPressed: () => onStatus(ModerationCaseStatus.rejected),
                    child: Text(l10n.adminUgcStatusRejected),
                  ),
                  FilledButton(
                    key: kModerationDecisionResolvedKey,
                    onPressed: () => onStatus(ModerationCaseStatus.resolved),
                    child: Text(l10n.adminUgcStatusResolved),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _statusText(AppLocalizations l10n, ModerationCaseStatus status) =>
    switch (status) {
      ModerationCaseStatus.open => l10n.adminAcik,
      ModerationCaseStatus.inReview => l10n.adminUgcStatusInReview,
      ModerationCaseStatus.resolved => l10n.adminUgcStatusResolved,
      ModerationCaseStatus.rejected => l10n.adminUgcStatusRejected,
    };

String _targetTypeLabel(AppLocalizations l10n, ReportTargetType type) =>
    switch (type) {
      ReportTargetType.message => l10n.classroomSohbet,
      ReportTargetType.profile => l10n.adminUgcTarget,
      ReportTargetType.group => l10n.classroomGrup,
      ReportTargetType.groupName => l10n.classroomGrupAdi,
    };

String _reasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
  'harassment' => l10n.safetyReasonHarassment,
  'spam' => l10n.safetyReasonSpam,
  'hate' => l10n.safetyReasonHate,
  'illegal' => l10n.safetyReasonIllegal,
  'other' => l10n.safetyReasonOther,
  _ => reason.isEmpty ? '—' : reason,
};
