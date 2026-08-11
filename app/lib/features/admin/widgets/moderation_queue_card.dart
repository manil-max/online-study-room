import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../cards/admin_work_card.dart';
import '../sanctions/admin_case_target_link.dart';

/// WP-440 / **WP-698**: icerik sikayeti karti.
///
/// WP-698'e kadar bu dosya kendi `Card > Column`unu, kendi durum cipini, kendi
/// rozetlerini ve kendi kimlik satirini cizerdi; destek bileti karti da
/// (`tabs/admin_reports_tab.dart`) tamamen ayrisik bir tasarim kullanirdi.
/// Ayni isi gosteren iki kart **tek widget paylasmiyordu** ve 280 px'te
/// yukseklikleri 242 / 610 px idi. Artik ikisi de [AdminWorkCard]'dan turer;
/// bu dosyada kalan tek is, **vakayi o dilin alanlarina cevirmektir**.
///
/// Korunan kabuller:
///   - Durum secimi hala hapten yapilir (`moderation-status-chip`) ve menu
///     `PopupMenuItem<ModerationCaseStatus>` uretir.
///   - Yaptirim / karantina / kopyala hala `moderation-secondary-actions`
///     menusunde. **Tehlikeli eylem kartin yuzune cikmaz** (WP-B/C: karar
///     seridi inceleme panosunda).
///   - Rozet seridi `moderation-case-badges` anahtarini korur.
///   - Durum degistiginde kart yuksekligi sicramaz: her satir `maxLines` ile
///     kilitli, hap her durumda ayni `labelSmall` + tek satir.
class ModerationQueueCard extends StatelessWidget {
  const ModerationQueueCard({
    super.key,
    required this.moderationCase,
    required this.onStatusSelected,
    this.onSelect,
    this.selected = false,
    this.onSanction,
    this.onQuarantineToggle,
  });

  final ModerationCase moderationCase;
  final ValueChanged<ModerationCaseStatus> onStatusSelected;

  /// WP-B: kart **secilebilir liste satiri**dir; dokunus vakayi yandaki
  /// inceleme panosuna baglar.
  final VoidCallback? onSelect;

  /// Su an incelenen vaka bu mu? (SPEC §4: gorunur secim + hover/focus.)
  final bool selected;

  /// WP-441: Basamakli yaptirim sayfasini acar.
  final VoidCallback? onSanction;

  /// WP-441: Karantinayi acar/kapatir — geri alinabilir oldugu icin tek dugme.
  final ValueChanged<bool>? onQuarantineToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reporter = moderationCase.reporters.isEmpty
        ? null
        : moderationCase.reporters.first;
    final overdue = moderationCase.isOverdue(DateTime.now());

    return AdminWorkCard(
      typeIcon: _typeIcon(moderationCase.targetType),
      title: _reasons(l10n),
      tone: _tone(overdue),
      selected: selected,
      onTap: onSelect,
      status: AdminWorkStatusPill<ModerationCaseStatus>(
        key: const Key('moderation-status-chip'),
        label: _statusLabel(l10n, moderationCase.status),
        tone: _statusTone(moderationCase.status),
        options: ModerationCaseStatus.writableValues,
        optionLabel: (status) => _statusLabel(l10n, status),
        onSelected: onStatusSelected,
      ),
      participants: [
        AdminWorkParticipant(
          roleLabel: l10n.adminUgcTarget,
          name: _name(l10n, moderationCase.targetIdentity),
          avatarUrl: moderationCase.targetIdentity?.avatarUrl,
          // 🔴 PLAN §2.3 / WP-C olcut 5: vakadan kisiye kopru yoktu. Tek yardim
          // uc noktadaki "Kopyala" idi. Kopru taraf satirinda durur: baslik
          // satiri 280 px'te zaten hap + `…` ile dolu.
          trailing: moderationCase.targetIdentity == null
              ? null
              : AdminCaseTargetLink(
                  targetUserId: moderationCase.targetIdentity!.id,
                  compact: true,
                ),
        ),
        AdminWorkParticipant(
          roleLabel: l10n.adminUgcReporter,
          name: _name(l10n, reporter),
          avatarUrl: reporter?.avatarUrl,
          extraCount: moderationCase.reportCount > 1
              ? moderationCase.reportCount - 1
              : 0,
        ),
      ],
      metaLine: _metaLine(context, l10n),
      flagsKey: const Key('moderation-case-badges'),
      flags: [
        if (moderationCase.severity == ModerationSeverity.high)
          AdminWorkFlag(
            l10n.adminModerationSeverityHigh,
            tone: AdminWorkTone.urgent,
          ),
        if (overdue)
          AdminWorkFlag(l10n.adminModerationOverdue, tone: AdminWorkTone.urgent),
        if (moderationCase.quarantined)
          AdminWorkFlag(
            l10n.adminModerationQuarantined,
            tone: AdminWorkTone.done,
          ),
      ],
      overflowKey: const Key('moderation-secondary-actions'),
      overflowItems: [
        if (onSanction != null)
          AdminWorkMenuItem(
            label: l10n.adminModerationSanctionTitle,
            onSelected: () => onSanction!(),
          ),
        // Karantina vaka kimligi ister; `0104` oncesi tarihsel satirlarda
        // secenek hic gosterilmez — olu menu girdisi birakmiyoruz.
        if (onQuarantineToggle != null && moderationCase.supportsCaseActions)
          AdminWorkMenuItem(
            label: moderationCase.quarantined
                ? l10n.adminModerationQuarantineRelease
                : l10n.adminModerationQuarantine,
            onSelected: () => onQuarantineToggle!(!moderationCase.quarantined),
          ),
        AdminWorkMenuItem(
          label: l10n.classroomKopyala,
          onSelected: () => _copyTargetId(context, l10n),
        ),
      ],
      // Yaptirim/karantina gorunur seride **konmaz**: kart bir ozettir.
      actions: const <AdminWorkAction>[],
    );
  }

  Future<void> _copyTargetId(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Degismez hedef kimligi: destek yazismasinda vakayi bu id tekillestirir.
    await Clipboard.setData(ClipboardData(text: moderationCase.targetId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.adminUgcIdCopied)));
  }

  /// Aciliyet: sunucunun bildigi iki sinyal (onem + SLA) disinda istemci risk
  /// uydurmaz.
  AdminWorkTone _tone(bool overdue) {
    if (moderationCase.status.isClosed) return AdminWorkTone.done;
    if (overdue || moderationCase.severity == ModerationSeverity.high) {
      return AdminWorkTone.urgent;
    }
    return moderationCase.status == ModerationCaseStatus.inReview
        ? AdminWorkTone.waiting
        : AdminWorkTone.open;
  }

  static AdminWorkTone _statusTone(ModerationCaseStatus status) =>
      switch (status) {
        ModerationCaseStatus.open => AdminWorkTone.open,
        ModerationCaseStatus.inReview => AdminWorkTone.waiting,
        ModerationCaseStatus.resolved ||
        ModerationCaseStatus.rejected => AdminWorkTone.done,
      };

  static IconData _typeIcon(ReportTargetType type) => switch (type) {
    ReportTargetType.message => Icons.forum_outlined,
    ReportTargetType.profile => Icons.person_outline,
    ReportTargetType.group => Icons.groups_outlined,
    ReportTargetType.groupName => Icons.drive_file_rename_outline,
  };

  static String _name(AppLocalizations l10n, ModerationIdentity? identity) =>
      identity == null || identity.isDeleted
      ? l10n.adminUgcDeletedUser
      : identity.displayName;

  String _typeLabel(AppLocalizations l10n) => switch (moderationCase.targetType) {
    ReportTargetType.message => l10n.classroomSohbet,
    ReportTargetType.profile => l10n.adminUgcTarget,
    ReportTargetType.group => l10n.classroomGrup,
    ReportTargetType.groupName => l10n.classroomGrupAdi,
  };

  String _reasons(AppLocalizations l10n) {
    if (moderationCase.reasons.isEmpty) return '—';
    return moderationCase.reasons.map((r) => _reasonLabel(l10n, r)).join(', ');
  }

  static String _reasonLabel(AppLocalizations l10n, String reason) =>
      switch (reason) {
        'harassment' => l10n.safetyReasonHarassment,
        'spam' => l10n.safetyReasonSpam,
        'hate' => l10n.safetyReasonHate,
        'illegal' => l10n.safetyReasonIllegal,
        'other' => l10n.safetyReasonOther,
        _ => reason,
      };

  static String _statusLabel(
    AppLocalizations l10n,
    ModerationCaseStatus status,
  ) => switch (status) {
    ModerationCaseStatus.open => l10n.adminAcik,
    ModerationCaseStatus.inReview => l10n.adminUgcStatusInReview,
    ModerationCaseStatus.resolved => l10n.adminUgcStatusResolved,
    ModerationCaseStatus.rejected => l10n.adminUgcStatusRejected,
  };

  /// Tur · bekleme suresi · rapor sayisi. Onem/SLA isaret seridinde durur.
  String _metaLine(BuildContext context, AppLocalizations l10n) {
    final waited = moderationCase.waitingFor(DateTime.now());
    final languageCode = Localizations.localeOf(context).languageCode;
    final duration = formatHumanForLocale(waited.inSeconds, languageCode);
    return '${_typeLabel(l10n)} · $duration · '
        '${l10n.adminRaporlar}: ${moderationCase.reportCount}';
  }
}
