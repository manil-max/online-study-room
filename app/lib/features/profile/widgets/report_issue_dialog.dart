import 'package:online_study_room/l10n/app_localizations.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

  final _imagePicker = ImagePicker();
  Uint8List? _attachmentBytes;
  String? _attachmentExt;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Optimize size
      );
      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();
      // Simple 5MB check
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        _showError(l10n.profileDosyaBoyutu5mbdanKucuk);
        return;
      }

      String ext = xFile.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        ext = 'jpg'; // Fallback
      }

      setState(() {
        _attachmentBytes = bytes;
        _attachmentExt = ext;
      });
    } catch (_) {
      _showError(l10n.profileResimSecilemedi);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    final profile = ref.read(authStateProvider).value;
    if (profile == null) {
      _showError(l10n.profileGeriBildirimGondermekIcin);
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
            attachmentBytes: _attachmentBytes,
            attachmentExt: _attachmentExt,
          );
      ref.invalidate(myFeedbackTicketsProvider);
      ref.invalidate(adminDashboardSummaryProvider);
      ref.invalidate(adminFeedbackTicketsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on AdminException catch (e, st) {
      // WP-168: gerçek hata kDebugMode'da; oturum hataları net UX, diğerleri jenerik.
      if (kDebugMode) {
        debugPrint(
          'ReportIssueDialog AdminException code=${e.code} message=${e.message}',
        );
        debugPrint('$st');
      }
      if (e.code == 'session_required' || e.code == 'session_or_rls') {
        _showError(
          e.message.isNotEmpty
              ? e.message
              : l10n.profileGeriBildirimGondermekIcin,
        );
      } else {
        _showError(l10n.profileGeriBildirimGonderilemedi);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ReportIssueDialog unexpected: $e');
        debugPrint('$st');
      }
      _showError(l10n.profileGeriBildirimGonderilemedi);
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
      title: Text(AppLocalizations.of(context).profileGeriBildirimGonder),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<FeedbackTicketKind>(
                segments: [
                  ButtonSegment(
                    value: FeedbackTicketKind.feedback,
                    icon: Icon(Icons.lightbulb_outline),
                    label: Text(AppLocalizations.of(context).profileOneri),
                  ),
                  ButtonSegment(
                    value: FeedbackTicketKind.bug,
                    icon: Icon(Icons.bug_report_outlined),
                    label: Text(AppLocalizations.of(context).profileHata),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _isSubmitting
                    ? null
                    : (values) => setState(() => _kind = values.single),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                enabled: !_isSubmitting,
                maxLength: kMaxFeedbackSubjectLength,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).profileKonu,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  try {
                    normalizeFeedbackSubject(value ?? '');
                    return null;
                  } on AdminException {
                    return AppLocalizations.of(
                      context,
                    ).profileBeklenmeyenBirHataOlustu;
                  }
                },
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                enabled: !_isSubmitting,
                minLines: 4,
                maxLines: 7,
                maxLength: kMaxFeedbackMessageLength,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).profileMesaj,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? AppLocalizations.of(context).profileMesajGerekli
                    : null,
              ),
              SizedBox(height: 16),
              if (_attachmentBytes != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        image: DecorationImage(
                          image: MemoryImage(_attachmentBytes!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).coreKapat,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: Icon(
                        Icons.cancel,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                              _attachmentBytes = null;
                              _attachmentExt = null;
                            }),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickImage,
                  icon: Icon(Icons.attach_file),
                  label: Text(
                    AppLocalizations.of(
                      context,
                    ).profileEkranGoruntusuEkleOpsiyonel,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).profileIptal),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context).profileGonder),
        ),
      ],
    );
  }
}
