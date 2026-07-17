import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/moderation_providers.dart';
import '../../data/repositories/moderation_repository.dart';
import '../profile/legal_documents.dart';

/// WP-116: basit UGC rapor bottom sheet.
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

  static const _reasons = {
    'harassment': 'Taciz / harassment',
    'spam': 'Spam',
    'hate': 'Nefret / hate',
    'illegal': 'Yasa dışı / illegal',
    'other': 'Diğer / other',
  };

  Future<void> _submit() async {
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
          const SnackBar(content: Text('Rapor alındı / Report received')),
        );
      }
    } on ModerationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İçerik bildir / Report',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _reason,
            items: [
              for (final e in _reasons.entries)
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
                : const Text('Gönder / Submit'),
          ),
        ],
      ),
    );
  }
}
