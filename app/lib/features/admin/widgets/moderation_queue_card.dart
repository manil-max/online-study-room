import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/core/widgets/user_avatar.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../sanctions/admin_case_target_link.dart';

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
    this.onSelect,
    this.selected = false,
    this.onSanction,
    this.onQuarantineToggle,
  });

  final ModerationCase moderationCase;
  final ValueChanged<ModerationCaseStatus> onStatusSelected;

  /// WP-B: kart artik **secilebilir liste satiri**dir. Eskiden govde dokunusu
  /// bir alt sayfa aciyordu ve o sayfada tek karar dugmesi yoktu
  /// (`ADMIN-PANEL-PLAN.md` §2.2); simdi dokunus vakayi yandaki inceleme
  /// panosuna baglar.
  final VoidCallback? onSelect;

  /// Su an incelenen vaka bu mu? (SPEC §4: gorunur secim + hover/focus.)
  final bool selected;

  /// WP-441: Basamaklı yaptırım sayfasını açar.
  final VoidCallback? onSanction;

  /// WP-441: Karantinayı açar/kapatır — geri alınabilir olduğu için tek düğme.
  final ValueChanged<bool>? onQuarantineToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reporter = moderationCase.reporters.isEmpty
        ? null
        : moderationCase.reporters.first;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: onSelect,
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        focusColor: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                  _SecondaryActions(
                    moderationCase: moderationCase,
                    onSanction: onSanction,
                    onQuarantineToggle: onQuarantineToggle,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _IdentityLine(
                label: l10n.adminUgcTarget,
                identity: moderationCase.targetIdentity,
                // 🔴 PLAN §2.3 / WP-C ölçüt 5: vakadan kişiye köprü yoktu. Tek
                // yardım üç noktadaki "Kopyala" idi — UUID'yi panoya alıp sekme
                // değiştirip aramasız listede gözle arıyordun. WP-C varış
                // noktasını (kişi dosyası) kurdu; köprü burada bağlanır.
                //
                // Neden başlık satırında değil: ölçüldü — 280 px'lik kuyruk
                // sütununda başlık satırı (metin + durum çipi + üç nokta) zaten
                // 240 px'i doldurmuş; oraya 48 px eklemek "RenderFlex
                // overflowed" veriyordu. Kimlik satırında `Expanded` metin
                // esniyor, taşma olmuyor. Grup hedefinde çizilecek kişi yok.
                trailing: moderationCase.targetIdentity == null
                    ? null
                    : AdminCaseTargetLink(
                        targetUserId: moderationCase.targetIdentity!.id,
                        compact: true,
                      ),
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
              _CaseBadges(moderationCase: moderationCase),
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

  /// Bekleme süresi + rapor sayısı. Önem/SLA rozetleri artık `0105` ile
  /// sunucudan geliyor ve ayrı satırda gösteriliyor.
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

/// Sunucudan gelen önem/SLA/karantina rozetleri.
///
/// Rozetler yalnız **sunucunun bildiği** alanlardan çizilir; istemci risk
/// uydurmaz. Hiçbiri tek başına yaptırım anlamına gelmez.
class _CaseBadges extends StatelessWidget {
  const _CaseBadges({required this.moderationCase});

  final ModerationCase moderationCase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overdue = moderationCase.isOverdue(DateTime.now());
    final labels = <(String, Color, Color)>[
      if (moderationCase.severity == ModerationSeverity.high)
        (l10n.adminModerationSeverityHigh, scheme.errorContainer, scheme.onErrorContainer),
      if (overdue)
        (l10n.adminModerationOverdue, scheme.tertiaryContainer, scheme.onTertiaryContainer),
      if (moderationCase.quarantined)
        (
          l10n.adminModerationQuarantined,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('moderation-case-badges'),
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final (label, background, foreground) in labels)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }
}

/// Üç nokta yalnız ikincil eylemleri taşır — durum değişimi çipte.
class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.moderationCase,
    this.onSanction,
    this.onQuarantineToggle,
  });

  final ModerationCase moderationCase;
  final VoidCallback? onSanction;
  final ValueChanged<bool>? onQuarantineToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Karantina vaka kimliği ister; `0104` öncesi tarihsel satırlarda seçenek
    // hiç gösterilmez — ölü menü girdisi bırakmıyoruz.
    final canQuarantine =
        onQuarantineToggle != null && moderationCase.supportsCaseActions;
    return PopupMenuButton<String>(
      key: const Key('moderation-secondary-actions'),
      onSelected: (value) async {
        switch (value) {
          case 'sanction':
            onSanction?.call();
          case 'quarantine':
            onQuarantineToggle?.call(!moderationCase.quarantined);
          case 'copy':
            // Değişmez hedef kimliği: destek yazışmasında vakayı bu id
            // tekilleştirir.
            await Clipboard.setData(
              ClipboardData(text: moderationCase.targetId),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.adminUgcIdCopied)));
        }
      },
      itemBuilder: (_) => [
        if (onSanction != null)
          PopupMenuItem(
            value: 'sanction',
            child: Text(l10n.adminModerationSanctionTitle),
          ),
        if (canQuarantine)
          PopupMenuItem(
            value: 'quarantine',
            child: Text(
              moderationCase.quarantined
                  ? l10n.adminModerationQuarantineRelease
                  : l10n.adminModerationQuarantine,
            ),
          ),
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
    this.trailing,
  });

  final String label;
  final ModerationIdentity? identity;
  final int extraCount;

  /// Satırın sağ ucundaki tek eylem (bugün: hedefin dosyasına köprü).
  final Widget? trailing;

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
        ?trailing,
      ],
    );
  }
}
