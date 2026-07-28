import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/feedback_ticket.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/admin_repository.dart';
import '../../l10n/app_localizations.dart';
import 'feedback_tickets_screen.dart';

/// Ayarlar -> Geri bildirim.
///
/// WP-420: Eskiden bu bir `AlertDialog`'du ve **uc dugmesi alt alta** diziliyordu
/// (Geri bildirimlerim / Iptal / Gonder). Dar telefonda klavye acilinca yazilan
/// metin dugmelerin altinda kaliyordu. Ucuncu dugme artik bir **sekme**, form
/// tam ekran ve alt serit sabit.
///
/// Sabit alt serit icin `Scaffold.bottomSheet` **kullanilmiyor**: o govdeye yer
/// ayirmaz, ustune biner. Dogrusu `Column` + `Expanded` -- kaydirilabilir govde
/// yeri paylasir, serit her zaman altta kalir ve klavye acildiginda
/// `resizeToAvoidBottomInset` govdeyi kisaltir.
class FeedbackScreen extends ConsumerWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // WP-421: zincirin ucuncu halkasi -- sekmenin uzerinde renkli sayi rozeti.
    final unreadReplies =
        ref.watch(unreadFeedbackReplyCountProvider).value ?? 0;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.feedbackTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                key: const Key('feedback-tab-compose'),
                text: l10n.feedbackTabCompose,
              ),
              Tab(
                key: const Key('feedback-tab-tickets'),
                // Rozet sekme metninin **ustune** biner: yan yana dizilirse dar
                // telefonda sekme genisligi yetmiyor ve Row tasiyor.
                child: unreadReplies > 0
                    ? Badge(
                        key: const Key('feedback-tab-reply-badge'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        textColor: Theme.of(context).colorScheme.onPrimary,
                        label: Text(
                          unreadReplies > 99 ? '99+' : '$unreadReplies',
                        ),
                        child: Text(l10n.feedbackMyTickets),
                      )
                    : Text(l10n.feedbackMyTickets),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [FeedbackComposeView(), MyFeedbackTicketsView()],
        ),
      ),
    );
  }
}

class FeedbackComposeView extends ConsumerStatefulWidget {
  const FeedbackComposeView({super.key});

  @override
  ConsumerState<FeedbackComposeView> createState() =>
      _FeedbackComposeViewState();
}

class _FeedbackComposeViewState extends ConsumerState<FeedbackComposeView> {
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
      ref.invalidate(adminFeedbackTicketsProvider(null));
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _attachmentBytes = null;
        _attachmentExt = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileGeriBildiriminGonderildi)),
      );
      // Gonderilen kayit hemen gorulebilsin: "Geri bildirimlerim" sekmesine gec.
      DefaultTabController.maybeOf(context)?.animateTo(1);
    } on AdminException catch (e, st) {
      // WP-177/193: net mesaj + ham detay her zaman (release dahil).
      if (kDebugMode) {
        debugPrint(
          'FeedbackComposeView AdminException '
          'code=${e.code} message=${e.message}',
        );
        debugPrint('$st');
      }
      final msg = e.message.isNotEmpty
          ? e.message
          : l10n.profileGeriBildirimGonderilemedi;
      // Kod message icinde yoksa ekle (eski yollar).
      final withCode =
          e.code != null && e.code!.isNotEmpty && !msg.contains(e.code!)
          ? '$msg\nDetay: ${e.code}'
          : msg;
      _showError(withCode);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('FeedbackComposeView unexpected: $e');
        debugPrint('$st');
      }
      // WP-193: beklenmeyen hatada da ham metin gorunur olsun.
      _showError('${l10n.profileGeriBildirimGonderilemedi}\nDetay: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 🔴 Riverpod 3 auto-dispose: dinleyicisi olmayan provider her `read`'de
    // yeniden kurulur ve yükleme durumunda döner — form gönderimi "giriş
    // yapmalısın" diye reddedilirdi. Burada `watch` ile dinleyici tutulur,
    // böylece `_submit` içindeki `read` gerçek profili görür.
    final profile = ref.watch(authStateProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kaydirilabilir govde: klavye acildiginda Scaffold burayi kisaltir ve
        // odaklanan alan gorunur kalir.
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                SegmentedButton<FeedbackTicketKind>(
                  segments: [
                    ButtonSegment(
                      value: FeedbackTicketKind.feedback,
                      icon: const Icon(Icons.lightbulb_outline),
                      label: Text(l10n.profileOneri),
                    ),
                    ButtonSegment(
                      value: FeedbackTicketKind.bug,
                      icon: const Icon(Icons.bug_report_outlined),
                      label: Text(l10n.profileHata),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: _isSubmitting
                      ? null
                      : (values) => setState(() => _kind = values.single),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('feedback-subject-field'),
                  controller: _subjectController,
                  enabled: !_isSubmitting,
                  maxLength: kMaxFeedbackSubjectLength,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.profileKonu,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    try {
                      normalizeFeedbackSubject(value ?? '');
                      return null;
                    } on AdminException {
                      return l10n.profileBeklenmeyenBirHataOlustu;
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('feedback-message-field'),
                  controller: _messageController,
                  enabled: !_isSubmitting,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: kMaxFeedbackMessageLength,
                  decoration: InputDecoration(
                    labelText: l10n.profileMesaj,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? l10n.profileMesajGerekli
                      : null,
                ),
                const SizedBox(height: 16),
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
                        tooltip: l10n.coreKapat,
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
                    icon: const Icon(Icons.attach_file),
                    label: Text(l10n.profileEkranGoruntusuEkleOpsiyonel),
                  ),
              ],
            ),
          ),
        ),
        // Sabit alt serit -- iki dugme **yan yana**.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('feedback-cancel'),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(l10n.profileIptal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('feedback-submit'),
                    onPressed: _isSubmitting || profile == null ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.profileGonder),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
