import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

  // WP-423: tek ve opsiyonel foto eki.
  final _imagePicker = ImagePicker();
  Uint8List? _attachmentBytes;
  String? _attachmentExt;

  static const int _maxDetails = 500;
  static const int _maxAttachmentBytes = 5 * 1024 * 1024;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final xFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();
      // Asıl sınır sunucuda (bucket 5 MB + `assert_report_attachment_allowed`);
      // buradaki kontrol yalnız boşa yükleme yapmamak için.
      if (bytes.lengthInBytes > _maxAttachmentBytes) {
        _showError(l10n.profileDosyaBoyutu5mbdanKucuk);
        return;
      }

      var ext = xFile.name.split('.').last.toLowerCase();
      if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        ext = 'jpg';
      }

      if (!mounted) return;
      setState(() {
        _attachmentBytes = bytes;
        _attachmentExt = ext;
      });
    } catch (_) {
      _showError(l10n.profileResimSecilemedi);
    }
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
            attachmentBytes: _attachmentBytes,
            attachmentExt: _attachmentExt,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.safetyReportReceived} ${l10n.safetyReportReviewing}',
            ),
          ),
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
          // WP-423: ek opsiyoneldir — seçilmezse veya yüklenemezse şikâyet
          // yine de gönderilir.
          if (_attachmentBytes != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                    image: DecorationImage(
                      image: MemoryImage(_attachmentBytes!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.coreKapat,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: Icon(
                    Icons.cancel,
                    color: theme.colorScheme.onInverseSurface,
                  ),
                  onPressed: _busy
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
              onPressed: _busy ? null : _pickImage,
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.profileEkranGoruntusuEkleOpsiyonel),
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
