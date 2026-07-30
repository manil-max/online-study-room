import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/core/widgets/user_avatar.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-440: Vaka kartı.
///
/// Kabul kriteri: **durum seçenekleri arasında kart yüksekliği ve tipografisi
/// sıçramaz.** Bunu sabit piksel yüksekliğiyle değil (metin ölçeği 1.3'te
/// taşardı), her satırın `maxLines` ile kilitlenmesi ve durum çipinin her
/// durumda aynı `textStyle` + tek satır kullanmasıyla sağlıyoruz. Böylece
/// yükseklik yalnız font metriklerine bağlı kalır, seçilen duruma değil.
class ModerationQueueCard extends StatelessWidget {
  const ModerationQueueCard({
    super.key,
    required this.moderationCase,
    required this.onStatusSelected,
    this.onOpenDetail,
  });

  final ModerationCase moderationCase;
  final ValueChanged<ModerationCaseStatus> onStatusSelected;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reporter = moderationCase.reporters.isEmpty
        ? null
        : moderationCase.reporters.first;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _targetLine(l10n),
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    status: moderationCase.status,
                    onSelected: onStatusSelected,
                  ),
                  _SecondaryActions(moderationCase: moderationCase),
                ],
              ),
              const SizedBox(height: 6),
              _IdentityLine(
                label: l10n.adminUgcTarget,
                identity: moderationCase.targetIdentity,
              ),
              const SizedBox(height: 4),
              _IdentityLine(
                label: l10n.adminUgcReporter,
                identity: reporter,
                extraCount: moderationCase.reportCount > 1
                    ? moderationCase.reportCount - 1
                    : 0,
              ),
              const SizedBox(height: 6),
              Text(
                _metaLine(context, l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _targetLine(AppLocalizations l10n) {
    final type = switch (moderationCase.targetType) {
      ReportTargetType.message => l10n.classroomSohbet,
      ReportTargetType.profile => l10n.adminUgcTarget,
      ReportTargetType.group => l10n.classroomGrup,
      ReportTargetType.groupName => l10n.classroomGrupAdi,
    };
    return '$type · ${_reasons(l10n)}';
  }

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

  /// Bekleme süresi + rapor sayısı. Risk/SLA/atanan admin alanları şemada
  /// **yok**; uydurma rozet basmak yerine WP-441 severity/SLA migration'ı
  /// geldiğinde bu satıra eklenecek.
  String _metaLine(BuildContext context, AppLocalizations l10n) {
    final waited = moderationCase.waitingFor(DateTime.now());
    final languageCode = Localizations.localeOf(context).languageCode;
    final duration = formatHumanForLocale(waited.inSeconds, languageCode);
    return '$duration · ${l10n.adminRaporlar}: ${moderationCase.reportCount}';
  }
}

/// Durum çipi — seçim doğrudan buradan yapılır (üç nokta değil).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.onSelected});

  final ModerationCaseStatus status;
  final ValueChanged<ModerationCaseStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = switch (status) {
      ModerationCaseStatus.open => (scheme.errorContainer, scheme.onErrorContainer),
      ModerationCaseStatus.inReview => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      ModerationCaseStatus.resolved ||
      ModerationCaseStatus.rejected =>
        (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };

    return PopupMenuButton<ModerationCaseStatus>(
      key: const Key('moderation-status-chip'),
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final option in ModerationCaseStatus.writableValues)
          PopupMenuItem<ModerationCaseStatus>(
            value: option,
            child: Text(_label(l10n, option)),
          ),
      ],
      child: Semantics(
        button: true,
        container: true,
        // Etiket çipin kendisidir; alttaki Text'in düğümü ikinci kez
        // okunmasın diye dışarıda bırakılır.
        excludeSemantics: true,
        label: _label(l10n, status),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32, maxWidth: 148),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            _label(l10n, status),
            // Her durumda aynı stil ve tek satır: yükseklik sıçramaz.
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  static String _label(AppLocalizations l10n, ModerationCaseStatus status) =>
      switch (status) {
        ModerationCaseStatus.open => l10n.adminAcik,
        ModerationCaseStatus.inReview => l10n.adminUgcStatusInReview,
        ModerationCaseStatus.resolved => l10n.adminUgcStatusResolved,
        ModerationCaseStatus.rejected => l10n.adminUgcStatusRejected,
      };
}

/// Üç nokta yalnız ikincil eylemleri taşır — durum değişimi çipte.
class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.moderationCase});

  final ModerationCase moderationCase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      key: const Key('moderation-secondary-actions'),
      onSelected: (value) async {
        if (value != 'copy') return;
        // Değişmez hedef kimliği: destek yazışmasında vakayı bu id tekilleştirir.
        await Clipboard.setData(ClipboardData(text: moderationCase.targetId));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminUgcIdCopied)));
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'copy', child: Text(l10n.classroomKopyala)),
      ],
    );
  }
}

class _IdentityLine extends StatelessWidget {
  const _IdentityLine({
    required this.label,
    required this.identity,
    this.extraCount = 0,
  });

  final String label;
  final ModerationIdentity? identity;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final resolved = identity;
    final name = resolved == null || resolved.isDeleted
        ? l10n.adminUgcDeletedUser
        : resolved.displayName;

    return Row(
      children: [
        UserAvatar(
          displayName: name,
          avatarUrl: resolved?.avatarUrl,
          radius: 14,
          enableZoom: false,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            extraCount > 0 ? '$label: $name (+$extraCount)' : '$label: $name',
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
