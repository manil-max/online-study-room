import 'package:flutter/material.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../cards/admin_work_card.dart';

/// WP-440 / WP-698 / **WP-768**: icerik sikayeti karti.
///
/// WP-698 kart dilini tek yerde topladi; bu dosyada kalan is **vakayi o dilin
/// alanlarina cevirmektir**.
///
/// 🔴 WP-768 sahip karari: *"her kartta sadece detayli incele butonu olsun."*
/// Karttan kalkan uc kontrol ve gittikleri yer:
///
/// | eski kontrol | nereye gitti |
/// | --- | --- |
/// | durum hapi (`moderation-status-chip`, `PopupMenuButton`) | detay sayfasinin karar seridi; kartta artik **okunur** hap |
/// | `…` menusu (`moderation-secondary-actions`): Yaptirim · Karantina · Kopyala | detay sayfasi: yaptirim blogu, karar seridi, taraflar bolumundeki secilebilir kimlik |
/// | taraf satirindaki kisi dosyasi kopru dugmesi | detay sayfasinin "Hedefin dosyasi" blogu (ayni sayfada) |
///
/// Kart artik bir **ozet**tir: kim, neyi, ne zaman, ne kadar acil. Karar
/// yuzeyi tek: vakanin kendi sayfasi.
///
/// Korunanlar: rozet seridi `moderation-case-badges` anahtarini korur; durum
/// degistiginde kart yuksekligi sicramaz (her satir `maxLines` ile kilitli,
/// hap her durumda ayni `labelSmall` + tek satir).
class ModerationQueueCard extends StatelessWidget {
  const ModerationQueueCard({
    super.key,
    required this.moderationCase,
    required this.onOpenDetail,
    required this.openKey,
  });

  final ModerationCase moderationCase;

  /// Karttaki **tek** dugme: vakanin kendi sayfasini acar.
  final VoidCallback onOpenDetail;

  final Key openKey;

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
      status: AdminWorkStatusLabel(
        key: const Key('moderation-status-chip'),
        label: _statusLabel(l10n, moderationCase.status),
        tone: _statusTone(moderationCase.status),
      ),
      participants: [
        AdminWorkParticipant(
          roleLabel: l10n.adminUgcTarget,
          name: _name(l10n, moderationCase.targetIdentity),
          avatarUrl: moderationCase.targetIdentity?.avatarUrl,
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
          AdminWorkFlag(
            l10n.adminModerationOverdue,
            tone: AdminWorkTone.urgent,
          ),
        if (moderationCase.quarantined)
          AdminWorkFlag(
            l10n.adminModerationQuarantined,
            tone: AdminWorkTone.done,
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

  String _typeLabel(AppLocalizations l10n) =>
      switch (moderationCase.targetType) {
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
