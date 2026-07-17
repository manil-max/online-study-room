import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../data/providers/moderation_providers.dart';
import '../../data/repositories/moderation_repository.dart';
import '../profile/legal_documents.dart';

/// WP-116 / WP-125 / WP-130: UGC rapor bottom sheet.
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
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _ReportSheet(
        targetType: targetType,
        targetId: targetId,
        snapshot: snapshot,
      ),
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
  final _details = TextEditingController();

  static const int _maxDetails = 500;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

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
    final detailsRaw = _details.text.trim();
    final String? details = detailsRaw.isEmpty
        ? null
        : (detailsRaw.length > _maxDetails
            ? detailsRaw.substring(0, _maxDetails)
            : detailsRaw);
    try {
      await ref.read(moderationRepositoryProvider).acceptCommunityTerms(
            LegalDocuments.communityVersion,
          );
      await ref.read(moderationRepositoryProvider).reportUgc(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            details: details,
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
    final theme = Theme.of(context);
    final otherSelected = _reason == 'other';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.safetyReportTitle,
            style: theme.textTheme.titleMedium,
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
          // WP-130: opsiyonel serbest açıklama (RPC p_details ≤500).
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: otherSelected
                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                  : null,
            ),
            padding: otherSelected ? const EdgeInsets.all(4) : EdgeInsets.zero,
            child: TextField(
              controller: _details,
              enabled: !_busy,
              maxLines: 3,
              maxLength: _maxDetails,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: l10n.safetyReportDetailsLabel,
                hintText: l10n.safetyReportDetailsHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
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
