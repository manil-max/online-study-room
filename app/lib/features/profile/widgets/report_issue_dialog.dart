import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feedback_ticket.dart';
import '../../../data/providers/admin_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/repositories/admin_repository.dart';

class ReportIssueDialog extends ConsumerStatefulWidget {
  const ReportIssueDialog({super.key});

  @override
  ConsumerState<ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends ConsumerState<ReportIssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  var _kind = FeedbackTicketKind.feedback;
  var _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(authStateProvider).value;
    if (profile == null) {
      _showError('Geri bildirim göndermek için giriş yapmalısın.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .submitFeedback(
            userId: profile.id,
            kind: _kind,
            subject: _subjectController.text,
            message: _messageController.text,
          );
      ref.invalidate(myFeedbackTicketsProvider);
      ref.invalidate(adminDashboardSummaryProvider);
      ref.invalidate(adminFeedbackTicketsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on AdminException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Geri bildirim gönderilemedi.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Geri bildirim gönder'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<FeedbackTicketKind>(
                segments: const [
                  ButtonSegment(
                    value: FeedbackTicketKind.feedback,
                    icon: Icon(Icons.lightbulb_outline),
                    label: Text('Öneri'),
                  ),
                  ButtonSegment(
                    value: FeedbackTicketKind.bug,
                    icon: Icon(Icons.bug_report_outlined),
                    label: Text('Hata'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _isSubmitting
                    ? null
                    : (values) => setState(() => _kind = values.single),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                enabled: !_isSubmitting,
                maxLength: kMaxFeedbackSubjectLength,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Konu',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  try {
                    normalizeFeedbackSubject(value ?? '');
                    return null;
                  } on AdminException catch (e) {
                    return e.message;
                  }
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                enabled: !_isSubmitting,
                minLines: 4,
                maxLines: 7,
                maxLength: kMaxFeedbackMessageLength,
                decoration: const InputDecoration(
                  labelText: 'Mesaj',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  try {
                    normalizeFeedbackMessage(value ?? '');
                    return null;
                  } on AdminException catch (e) {
                    return e.message;
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gönder'),
        ),
      ],
    );
  }
}
