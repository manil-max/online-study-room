import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../data/providers/moderation_providers.dart';
import '../../data/repositories/moderation_repository.dart';
import '../profile/legal_documents.dart';

/// WP-116 / WP-125: UGC rapor bottom sheet (sohbet/profil giriş noktaları).
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
  String? snapshot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      snapshot: snapshot,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    this.snapshot,
  });

  final String targetType;
  final String targetId;
  final String? snapshot;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String _reason = 'harassment';
  bool _busy = false;

  Map<String, String> _reasons(AppLocalizations l10n) => {
        'harassment': l10n.safetyReasonHarassment,
        'spam': l10n.safetyReasonSpam,
        'hate': l10n.safetyReasonHate,
        'illegal': l10n.safetyReasonIllegal,
        'other': l10n.safetyReasonOther,
      };

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(moderationRepositoryProvider).acceptCommunityTerms(
            LegalDocuments.communityVersion,
          );
      await ref.read(moderationRepositoryProvider).reportUgc(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            snapshot: widget.snapshot,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.safetyReportReceived)),
        );
      }
    } on ModerationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.safetyActionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasons = _reasons(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.safetyReportTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _reason,
            items: [
              for (final e in reasons.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy
                ? null
                : (v) {
                    if (v != null) setState(() => _reason = v);
                  },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.safetyReportSubmit),
          ),
        ],
      ),
    );
  }
}
