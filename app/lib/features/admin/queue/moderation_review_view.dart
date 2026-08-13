import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/moderation_case.dart';
import '../../../data/models/moderation_sanction.dart';
import '../../../data/models/report_target.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../sanctions/admin_sanction_actions.dart';
import '../widgets/moderation_queue_card.dart';
import 'moderation_attachment_preview.dart';
import 'moderation_dialogs.dart';

/// WP-B (`docs/design/ADMIN-PANEL-PLAN.md` §4.2) — **kanit ve karar tek
/// ekranda**.
///
/// 🔴 Kok neden (§2.2): eskiden kanitin gorundugu yuzey ile kararin verildigi
/// yuzey ayni anda ekranda degildi. Icerigi alt sayfada okuyordun (4. adim),
/// icinde tek karar dugmesi yoktu; kapatip uc noktaya, oradan ikinci bir alt
/// sayfaya gidip karar veriyordun (6-8. adim) ve o sirada icerigi artik
/// gormuyordun. Sahibin *"bu adam nasil baslayacagimi bilmiyorum"* cumlesinin
/// koddaki karsiligi buydu.
///
/// Simdi: vaka satiri **secilir**, sagda (dar pencerede ayni bolmede) kanit
/// panosu acilir ve **karar seridi onun altina sabitlenir**.
///
/// 🔴 Serit `Scaffold.bottomSheet` ile kurulmaz — depoda kayitli tuzak: govdeyi
/// orter, yer ayirmaz. `Column` + `Expanded` kullanilir; kanit kaydirilirken
/// serit piksel piksel yerinde kalir (`moderation_review_flow_test.dart`
/// bunu `getRect` ile olcer).
///
/// Sayilar `docs/design/DESKTOP-UI-SPEC.md`ten alindi, turetilmedi: kuyruk
/// sutunu 280, bolme araligi 16, iki bolme esigi `expanded` (1008).
///
/// ⚠️ Esik neden `large` (1200) degil: bu widget **pencereyi degil kabini**
/// olcer. Kabuk (WP-A) pencerenin `large` butcesini bolum listesine harcadi ve
/// govdeye `maxFormWidth` (760) kaliyor; burada 1200 istemek iki bolmeyi
/// masaustunde **hic** acmazdi. Ayni ders `settings_screen.dart` WP-686'da
/// odendi.
class ModerationReviewView extends ConsumerStatefulWidget {
  const ModerationReviewView({
    super.key,
    required this.cases,
    required this.header,
    required this.onRefresh,
  });

  /// Kuyruktaki vakalar (en yenisi basta).
  final List<ModerationCase> cases;

  /// Kuyrugun ustunde duran itiraz bolumu.
  final Widget header;

  final Future<void> Function() onRefresh;

  @override
  ConsumerState<ModerationReviewView> createState() =>
      _ModerationReviewViewState();
}

const Key kModerationReviewKey = Key('moderation-review');
const Key kModerationQueueListKey = Key('moderation-queue-list');
const Key kModerationEvidenceKey = Key('moderation-evidence');
const Key kModerationDecisionBarKey = Key('moderation-decision-bar');
const Key kModerationDecisionReasonKey = Key('moderation-decision-reason');
const Key kModerationDecisionResolvedKey = Key('moderation-decision-resolved');
const Key kModerationDecisionRejectedKey = Key('moderation-decision-rejected');
const Key kModerationDecisionQuarantineKey = Key(
  'moderation-decision-quarantine',
);
const Key kModerationDecisionSanctionKey = Key('moderation-decision-sanction');
const Key kModerationBackToQueueKey = Key('moderation-back-to-queue');
const Key kModerationUndoBarKey = Key('moderation-undo-bar');
const Key kModerationUndoButtonKey = Key('moderation-undo-button');

/// Vaka satirinin anahtari — test satiri **kullanicinin dokundugu yerden**
/// bulur, ic yapidan degil.
Key moderationCaseRowKey(ModerationCase moderationCase) =>
    Key('moderation-case-row-${moderationCase.caseKey}');

/// PLAN §4.2 / §4.4.2: geri alinabilir karar teyit istemez, **10 saniyelik**
/// serit acar. Teyit enflasyonu teyidi oldurur.
const Duration kModerationUndoWindow = Duration(seconds: 10);

class _UndoEntry {
  const _UndoEntry({
    required this.moderationCase,
    required this.previousStatus,
    required this.appliedStatus,
  });

  final ModerationCase moderationCase;
  final ModerationCaseStatus previousStatus;
  final ModerationCaseStatus appliedStatus;
}

class _ModerationReviewViewState extends ConsumerState<ModerationReviewView> {
  final TextEditingController _reason = TextEditingController();
  String? _selectedKey;
  _UndoEntry? _undo;
  Timer? _undoTimer;

  @override
  void dispose() {
    _undoTimer?.cancel();
    _reason.dispose();
    super.dispose();
  }

  ModerationCase? _selected({required bool split}) {
    if (widget.cases.isEmpty) return null;
    final key = _selectedKey;
    if (key != null) {
      for (final item in widget.cases) {
        if (item.caseKey == key) return item;
      }
    }
    // Genis pencerede kuyruk bos ekranla acilmaz: ilk vaka zaten incelemeye
    // hazir durur. "Nereden baslayacagim" sorusunun yarisi budur.
    return split ? widget.cases.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: kModerationReviewKey,
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        // Bu widget admin kabugunun kalan alanini olcer. 900 dp, 1366 px
        // masaustunde 280 dp kuyruk + okunabilir karar panosunu yan yana
        // tutarken telefona bolmeli duzeni sizdirmaz.
        final split = width >= 900;
        final selected = _selected(split: split);

        final Widget body;
        if (split) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: _kQueueWidth, child: _queueList(selected)),
              const SizedBox(width: _kPaneSpacing),
              Expanded(
                child: selected == null
                    ? _emptySelection(context)
                    : _panel(selected),
              ),
            ],
          );
        } else if (selected == null) {
          body = _queueList(null);
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: kModerationBackToQueueKey,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: Text(
                    AppLocalizations.of(context).adminIncelemeListeyeDon,
                  ),
                  onPressed: () => setState(() => _selectedKey = null),
                ),
              ),
              Expanded(child: _panel(selected)),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_undo != null) _undoBar(context),
            Expanded(child: body),
          ],
        );
      },
    );
  }

  Widget _emptySelection(BuildContext context) => Center(
    child: Text(
      AppLocalizations.of(context).adminIncelemeVakaSec,
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    ),
  );

  Widget _queueList(ModerationCase? selected) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        key: kModerationQueueListKey,
        // WP-442: itiraz kuyrugu kartlarin ustunde ilk sirada durur.
        itemCount: widget.cases.isEmpty ? 2 : widget.cases.length + 1,
        itemBuilder: (context, rawIndex) {
          if (rawIndex == 0) return widget.header;
          if (widget.cases.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(child: Text(l10n.adminUgcNoReports)),
            );
          }
          final moderationCase = widget.cases[rawIndex - 1];
          return ModerationQueueCard(
            key: moderationCaseRowKey(moderationCase),
            moderationCase: moderationCase,
            selected: moderationCase.caseKey == selected?.caseKey,
            onSelect: () =>
                setState(() => _selectedKey = moderationCase.caseKey),
            onStatusSelected: (status) =>
                _applyStatus(moderationCase, status, advance: false),
            onSanction: _resolvedTargetUserId(moderationCase) == null
                ? null
                : () => _openSanctionSheet(moderationCase),
            onQuarantineToggle: (quarantined) =>
                _askQuarantine(moderationCase, quarantined),
          );
        },
      ),
    );
  }

  Widget _panel(ModerationCase moderationCase) => _CaseReviewPanel(
    moderationCase: moderationCase,
    reason: _reason,
    onStatus: (status) => _applyStatus(moderationCase, status, advance: true),
    onQuarantine: () => _quarantineFromBar(moderationCase),
    onSanction: _resolvedTargetUserId(moderationCase) == null
        ? null
        : () => _openSanctionSheet(moderationCase),
  );

  Widget _undoBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: kModerationUndoBarKey,
      margin: const EdgeInsets.only(bottom: 8),
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
  /// PLAN §4.4.2: geri alinabilir eylem **teyit istemez**; yerine 10 saniyelik
  /// "Geri al" seridi acilir. Sunucu durum RPC'si gerekce almaz, bu yuzden
  /// serit alanindaki gerekce buraya **tasinmaz** — yazilmayan bir gerekceyi
  /// zorunlu gostermek yalan etiket olurdu (§1.2 arsiv cipi dersi).
  Future<void> _applyStatus(
    ModerationCase moderationCase,
    ModerationCaseStatus status, {
    required bool advance,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final previous = moderationCase.status;
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .setCaseStatus(moderationCase: moderationCase, status: status);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(moderationQueueProvider);
    if (!mounted) return;
    if (advance) _advanceFrom(moderationCase);
    _armUndo(
      _UndoEntry(
        moderationCase: moderationCase,
        previousStatus: previous,
        appliedStatus: status,
      ),
    );
    messenger.showSnackBar(SnackBar(content: Text(_statusText(l10n, status))));
  }

  /// Karardan sonra imlec **kendiliginden** siradaki vakaya gecer (PLAN §4.2).
  void _advanceFrom(ModerationCase decided) {
    final index = widget.cases.indexWhere(
      (item) => item.caseKey == decided.caseKey,
    );
    if (index < 0) return;
    final next = index + 1 < widget.cases.length
        ? widget.cases[index + 1]
        : null;
    setState(() {
      _selectedKey = next?.caseKey ?? decided.caseKey;
      _reason.clear();
    });
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
            moderationCase: entry.moderationCase,
            status: entry.previousStatus,
          );
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _undoTimer?.cancel();
    ref.invalidate(moderationQueueProvider);
    if (!mounted) return;
    setState(() => _undo = null);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminIncelemeKararGeriAlindi)),
    );
  }

  /// Karar seridindeki **tek** gerekce alanini kullanir; ikinci bir diyalog
  /// acmaz (§2.2 "ayni sey iki kez yazdiriliyor").
  Future<void> _quarantineFromBar(ModerationCase moderationCase) async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) return;
    await _setQuarantine(moderationCase, !moderationCase.quarantined, reason);
  }

  /// Kart uc noktasindan gelen yol — orada serit yok, gerekce sorulur.
  Future<void> _askQuarantine(
    ModerationCase moderationCase,
    bool quarantined,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askModerationReason(
      context,
      l10n.adminModerationQuarantine,
    );
    if (reason == null || !mounted) return;
    await _setQuarantine(moderationCase, quarantined, reason);
  }

  Future<void> _setQuarantine(
    ModerationCase moderationCase,
    bool quarantined,
    String reason,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
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

  /// WP-441 yaptirim sayfasi. Agir basamaklarin (kalici yasak) yazili teyidi
  /// **WP-C**'nin isi; burada yalnizca serit gerekcesi sayfaya tasinir.
  Future<void> _openSanctionSheet(ModerationCase moderationCase) async {
    final targetId = _resolvedTargetUserId(moderationCase);
    if (targetId == null) return;
    final request = await showModalBottomSheet<ModerationSanctionRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ModerationSanctionSheet(
        targetUserId: targetId,
        caseId: moderationCase.caseId,
        initialReason: _reason.text.trim(),
      ),
    );
    if (request == null || !mounted) return;
    await AdminSanctionActions.applyPrepared(
      context,
      ref,
      request: request,
      confirmationPhrase: targetId,
    );
  }

  String? _resolvedTargetUserId(ModerationCase moderationCase) {
    final identity = moderationCase.targetIdentity;
    if (identity == null || identity.isDeleted) return null;
    return identity.id;
  }
}

const double _kQueueWidth = 280;
const double _kPaneSpacing = 16;

String _statusText(AppLocalizations l10n, ModerationCaseStatus status) =>
    switch (status) {
      ModerationCaseStatus.open => l10n.adminAcik,
      ModerationCaseStatus.inReview => l10n.adminUgcStatusInReview,
      ModerationCaseStatus.resolved => l10n.adminUgcStatusResolved,
      ModerationCaseStatus.rejected => l10n.adminUgcStatusRejected,
    };

/// Kanit (kaydirilir) + karar seridi (sabit).
class _CaseReviewPanel extends StatelessWidget {
  const _CaseReviewPanel({
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
    // 🔴 `Column` + `Expanded`: serit govdeyi ORTMEZ, yer AYIRIR.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _Evidence(moderationCase: moderationCase)),
        _DecisionBar(
          moderationCase: moderationCase,
          reason: reason,
          onStatus: onStatus,
          onQuarantine: onQuarantine,
          onSanction: onSanction,
        ),
      ],
    );
  }
}

class _Evidence extends ConsumerWidget {
  const _Evidence({required this.moderationCase});

  final ModerationCase moderationCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reportId = moderationCase.reportIds.isEmpty
        ? null
        : moderationCase.reportIds.first;

    if (reportId == null) {
      // 🔴 Eskiden bu vakada kart hic acilmiyordu ve NEDEN acilmadigini
      // soylemiyordu (§2.2 "sessiz olu dokunus"). Artik sebebini yaziyor.
      return ListView(
        key: kModerationEvidenceKey,
        padding: const EdgeInsets.all(16),
        children: [
          _header(context),
          const SizedBox(height: 12),
          Text(l10n.adminIncelemeDetayYok),
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
          const SizedBox(height: 16),
          _section(context, l10n.adminIncelemeGecmis),
          if (data.sanctions.isEmpty)
            Text(l10n.adminIncelemeGecmisYok, style: theme.textTheme.bodySmall)
          else
            for (final entry in data.sanctions) _historyRow(context, entry),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final identity = moderationCase.targetIdentity;
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
          _targetType(l10n, moderationCase.targetType),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Gerekce · gelis zamani · rapor sayisi. Ucu de sunucudan geliyordu ve
  /// detayda hic cizilmiyordu (§2.1).
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
        const SizedBox(height: 4),
        Text(
          '${l10n.adminRaporlar}: ${data.reportCount}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
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

  static Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  static String _targetType(AppLocalizations l10n, ReportTargetType type) =>
      switch (type) {
        ReportTargetType.message => l10n.classroomSohbet,
        ReportTargetType.profile => l10n.adminUgcTarget,
        ReportTargetType.group => l10n.classroomGrup,
        ReportTargetType.groupName => l10n.classroomGrupAdi,
      };

  static String _reasonLabel(AppLocalizations l10n, String reason) =>
      switch (reason) {
        'harassment' => l10n.safetyReasonHarassment,
        'spam' => l10n.safetyReasonSpam,
        'hate' => l10n.safetyReasonHate,
        'illegal' => l10n.safetyReasonIllegal,
        'other' => l10n.safetyReasonOther,
        _ => reason.isEmpty ? '—' : reason,
      };
}

/// Karar seridi — detay bolmesinin **altina sabit**.
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
