import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/admin_case_timeline_event.dart';
import '../../../data/models/moderation_case.dart';
import '../../../data/models/moderation_sanction.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../profile/feedback_tickets_screen.dart'
    show feedbackTicketTimestampLabel;
import '../sanctions/sanction_ladder.dart';

/// Bolumun govdesi.
const Key kAdminCaseTimelineKey = Key('admin-case-timeline');

/// Tek olay satiri; olay kimligiyle tekil.
Key adminCaseTimelineRowKey(String eventId) =>
    Key('admin-case-timeline-row-$eventId');

/// Yeniden dene (okuma dusunce).
const Key kAdminCaseTimelineRetryKey = Key('admin-case-timeline-retry');

/// WP-796 — vakanin zaman cizelgesi.
///
/// Sahibin onayladigi onizleme: "kim, ne zaman, ne yapti" tek listede,
/// eskiden yeniye. Kaynak `moderation_audit_events` zinciri (0106); istemci
/// bu zinciri ilk kez okuyor.
///
/// 🔴 Yazma yok, yorumlama az: durum/onem/itiraz degerleri sunucunun ham
/// metniyle gosterilir (bilinen vaka durumlari yerellestirilir). Sunucu bir
/// eylemi yeniden adlandirirsa satir "other" olur ve ham `action` gorunur;
/// yanlis bir dala yuvarlanmaz.
class AdminCaseTimelineSection extends ConsumerWidget {
  const AdminCaseTimelineSection({super.key, required this.caseId});

  /// `null` = tarihsel kayit (0104 oncesi), vaka satiri yok: zincirde de yok.
  final String? caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final id = caseId;
    if (id == null) {
      return Text(l10n.adminZamanCizelgesiBos, style: theme.textTheme.bodySmall);
    }
    final events = ref.watch(adminCaseTimelineProvider(id));
    final me = ref.watch(authStateProvider).value?.id;
    return events.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      // Yutulmaz: okunamayan cizelge ile bos cizelge ayni sey degildir.
      error: (_, _) => Row(
        children: [
          Expanded(child: Text(l10n.adminZamanCizelgesiOkunamadi)),
          IconButton(
            key: kAdminCaseTimelineRetryKey,
            tooltip: l10n.updaterTekrarDene,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminCaseTimelineProvider(id)),
          ),
        ],
      ),
      data: (list) {
        if (list.isEmpty) {
          return Text(
            l10n.adminZamanCizelgesiBos,
            style: theme.textTheme.bodySmall,
          );
        }
        return Column(
          key: kAdminCaseTimelineKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final event in list)
              _TimelineRow(
                key: adminCaseTimelineRowKey(event.id),
                event: event,
                isMe: me != null && event.actorId == me,
              ),
          ],
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({super.key, required this.event, required this.isMe});

  final AdminCaseTimelineEvent event;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actor = isMe
        ? l10n.feedbackYou
        : event.actorId == null
        ? l10n.adminZcSilinmisYonetici
        : l10n.adminDenetimYonetici(_shortId(event.actorId!));
    final reason = event.reason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 10),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotColor(scheme),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timelineEventLabel(l10n, event), style: theme.textTheme.bodyMedium),
                if (reason != null)
                  Text(
                    reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  '$actor · ${feedbackTicketTimestampLabel(l10n, event.occurredAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _dotColor(ColorScheme scheme) => switch (event.kind) {
    AdminCaseTimelineKind.caseOpened ||
    AdminCaseTimelineKind.appealSubmitted => scheme.error,
    AdminCaseTimelineKind.sanctionApplied ||
    AdminCaseTimelineKind.statusChanged => scheme.primary,
    _ => scheme.outline,
  };

  static String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;
}

/// Olayin tek satirlik metni. **Saf**; testte ekran kurmadan olculur.
///
/// Bilinen vaka durumlari yerellestirilir; digerleri (onem, itiraz karari)
/// sunucunun ham degeriyle gecer -- uydurma ceviri yok.
String timelineEventLabel(AppLocalizations l10n, AdminCaseTimelineEvent event) {
  switch (event.kind) {
    case AdminCaseTimelineKind.caseOpened:
      return l10n.adminZcVakaAcildi;
    case AdminCaseTimelineKind.statusChanged:
      return l10n.adminZcDurum(_statusLabel(l10n, event.newField('status')));
    case AdminCaseTimelineKind.quarantineChanged:
      return event.newField('quarantined') == 'true'
          ? l10n.adminZcKarantinaAlindi
          : l10n.adminZcKarantinaCikti;
    case AdminCaseTimelineKind.severityChanged:
      return l10n.adminZcOnem(event.newField('severity') ?? '—');
    case AdminCaseTimelineKind.sanctionApplied:
      return l10n.adminZcYaptirim(_actionLabel(l10n, event.newField('action')));
    case AdminCaseTimelineKind.sanctionStateChanged:
      return l10n.adminZcYaptirimDurum(_stateLabel(l10n, event.newField('state')));
    case AdminCaseTimelineKind.appealSubmitted:
      return l10n.adminZcItirazGonderildi;
    case AdminCaseTimelineKind.appealDecided:
      return l10n.adminZcItirazKarar(event.newField('status') ?? '—');
    case AdminCaseTimelineKind.other:
      return '${event.entityType}:${event.action}';
  }
}

String _statusLabel(AppLocalizations l10n, String? wire) {
  if (wire == null) return '—';
  try {
    return switch (ModerationCaseStatus.fromWire(wire)) {
      ModerationCaseStatus.open => l10n.adminAcik,
      ModerationCaseStatus.inReview => l10n.adminUgcStatusInReview,
      ModerationCaseStatus.resolved => l10n.adminUgcStatusResolved,
      ModerationCaseStatus.rejected => l10n.adminUgcStatusRejected,
    };
  } catch (_) {
    return wire;
  }
}

String _actionLabel(AppLocalizations l10n, String? wire) {
  if (wire == null) return '—';
  try {
    return adminSanctionLabel(l10n, ModerationAction.fromWire(wire));
  } catch (_) {
    return wire;
  }
}

String _stateLabel(AppLocalizations l10n, String? wire) {
  if (wire == null) return '—';
  try {
    return adminSanctionStateLabel(l10n, ModerationSanctionState.fromWire(wire));
  } catch (_) {
    return wire;
  }
}
