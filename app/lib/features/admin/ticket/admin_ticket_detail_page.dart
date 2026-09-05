import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_note.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'admin_ticket_actions.dart';

/// Sayfanin govdesi — kuyruktan gelen tek dokunusun varis noktasi.
const Key kAdminTicketDetailKey = Key('admin-ticket-detail');

/// Ek gorsel yuzeyi. Yol bossa bu anahtar **hic** cizilmez.
const Key kAdminTicketAttachmentKey = Key('admin-ticket-attachment');

/// Durum kontrolu (uc durum tek seritte).
const Key kAdminTicketStatusKey = Key('admin-ticket-status');

/// Arsivle / arsivden cikar.
const Key kAdminTicketArchiveKey = Key('admin-ticket-archive');

/// Ic not girisi + gonderme.
const Key kAdminTicketNoteFieldKey = Key('admin-ticket-note-field');
const Key kAdminTicketNoteSendKey = Key('admin-ticket-note-send');

/// WP-770 — destek kaydinin **tam sayfa** detayi.
///
/// Sahip: *"kartta yalniz 'Detayli incele' olsun, basinca o kayda ozel ayri
/// bir tam sayfa acilsin ve her sey orada olsun; baska bir ekrani
/// istemiyorum."* Eski akista bir bileti incelemek uc ayri diyalog aciyordu
/// (yanit, ic notlar, ek onizleme) ve hicbiri otekini gormuyordu. Artik biletin
/// mesaji, ek gorseli, kullaniciyla yazismasi, ic notlari ve durumu **ayni**
/// sayfanin govdesindedir.
///
/// Rota deseni depodaki `sanctions/admin_person_dossier.dart:34-47` ile ayni.
Future<void> openAdminTicketDetail({
  required BuildContext context,
  required FeedbackTicket ticket,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminTicketDetailPage(ticket: ticket),
    ),
  );
}

class AdminTicketDetailPage extends ConsumerStatefulWidget {
  const AdminTicketDetailPage({super.key, required this.ticket});

  final FeedbackTicket ticket;

  @override
  ConsumerState<AdminTicketDetailPage> createState() =>
      _AdminTicketDetailPageState();
}

class _AdminTicketDetailPageState extends ConsumerState<AdminTicketDetailPage> {
  late FeedbackTicketStatus _status = widget.ticket.status;
  late bool _archived = widget.ticket.archivedAt != null;

  Future<void> _changeStatus(FeedbackTicketStatus status) async {
    if (status == _status) return;
    final written = await setFeedbackTicketStatus(
      context: context,
      ref: ref,
      ticket: widget.ticket,
      status: status,
    );
    if (written && mounted) setState(() => _status = status);
  }

  Future<void> _toggleArchive() async {
    final written = await setFeedbackTicketArchived(
      context: context,
      ref: ref,
      ticket: widget.ticket,
      archived: !_archived,
    );
    if (written && mounted) setState(() => _archived = !_archived);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ticket = widget.ticket;
    final attachmentPath = ticket.attachmentPath;
    // Yazisma kendi listesini kaydirir; sayfa icinde sinirli bir pencere alir.
    final conversationHeight = (MediaQuery.sizeOf(context).height * 0.55).clamp(
      280.0,
      440.0,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminBiletDetayBaslik)),
      body: SafeArea(
        child: ListView(
          key: kAdminTicketDetailKey,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _identity(l10n),
            _section(
              title: l10n.adminBiletMesajBaslik,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    ticket.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(ticket.message),
                ],
              ),
            ),
            if (attachmentPath != null)
              _section(
                key: kAdminTicketAttachmentKey,
                title: l10n.adminEkranGoruntusu,
                child: _TicketAttachment(path: attachmentPath),
              ),
            _section(
              title: l10n.adminBiletYazismaBaslik,
              child: SizedBox(
                height: conversationHeight,
                child: FeedbackTicketConversationView(ticket: ticket),
              ),
            ),
            _section(
              title: l10n.adminIcNotlar,
              child: _TicketNotes(ticketId: ticket.id),
            ),
            _section(
              title: l10n.adminBiletDurumBaslik,
              child: _statusBlock(l10n),
            ),
          ],
        ),
      ),
    );
  }

  /// Kim yazdi, ne turu, ne zaman geldi, hangi durumda.
  Widget _identity(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final ticket = widget.ticket;
    final reporter = ticket.reporterDisplayName?.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _typeIcon(ticket.type),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feedbackTicketTypeLabel(l10n, ticket.type),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  feedbackTicketStatusLabel(l10n, _status),
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.adminWorkCardSubmitter,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SelectableText(
              reporter == null || reporter.isEmpty ? ticket.userId : reporter,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.feedbackTicketTimeline(
                feedbackTicketTimestampLabel(l10n, ticket.createdAt),
                feedbackTicketTimestampLabel(l10n, ticket.updatedAt),
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBlock(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<FeedbackTicketStatus>(
            key: kAdminTicketStatusKey,
            showSelectedIcon: false,
            segments: [
              for (final status in FeedbackTicketStatus.values)
                ButtonSegment<FeedbackTicketStatus>(
                  value: status,
                  label: Text(feedbackTicketStatusLabel(l10n, status)),
                ),
            ],
            selected: {_status},
            onSelectionChanged: (selection) => _changeStatus(selection.first),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: kAdminTicketArchiveKey,
          onPressed: _toggleArchive,
          icon: Icon(
            _archived ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
          ),
          label: Text(_archived ? l10n.adminArsivdenCikar : l10n.adminArsivle),
        ),
      ],
    );
  }

  Widget _section({Key? key, required String title, required Widget child}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

IconData _typeIcon(FeedbackTicketType type) => switch (type) {
  FeedbackTicketType.report => Icons.bug_report_outlined,
  FeedbackTicketType.question => Icons.question_answer_outlined,
  FeedbackTicketType.feedback => Icons.lightbulb_outline,
};

/// Ek gorsel — **sayfanin icinde**, ayri bir kabuk acmadan.
///
/// URL'yi sunucu imzalar (bucket private). Imzalama basarisiz olursa yeniden
/// deneme yolu kalir; eski diyalogdaki davranis korunur.
class _TicketAttachment extends ConsumerStatefulWidget {
  const _TicketAttachment({required this.path});

  final String path;

  @override
  ConsumerState<_TicketAttachment> createState() => _TicketAttachmentState();
}

class _TicketAttachmentState extends ConsumerState<_TicketAttachment> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _url = null;
    });
    String? url;
    try {
      url = await ref
          .read(adminRepositoryProvider)
          .getFeedbackAttachmentUrl(widget.path);
    } catch (_) {
      url = null;
    }
    if (!mounted) return;
    setState(() {
      _url = url;
      _loading = false;
    });
  }

  Widget _failure(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(child: Text(l10n.adminGorselYuklenemedi)),
        IconButton(
          tooltip: l10n.updaterTekrarDene,
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.refresh),
          onPressed: _load,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final url = _url;
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (url == null) return _failure(l10n);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: InteractiveViewer(
        child: Image.network(
          url,
          key: ValueKey(url),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _failure(l10n),
        ),
      ),
    );
  }
}

/// Ic notlar — **sayfanin govdesinde**, diyalog degil.
class _TicketNotes extends ConsumerStatefulWidget {
  const _TicketNotes({required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<_TicketNotes> createState() => _TicketNotesState();
}

class _TicketNotesState extends ConsumerState<_TicketNotes> {
  final _controller = TextEditingController();
  List<FeedbackTicketNote>? _notes;
  bool _loading = true;

  /// 🔴 Okuma hatasi ile "not yok" ayri durumlardir. Eski diyalogda okuma
  /// hatasinda `_notes` null kaliyor, uc dal da `false` oluyordu ve govde
  /// **bos** ciziliyordu (`tabs/admin_reports_tab.dart:476` + `:552-584`).
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final notes = await ref
          .read(adminRepositoryProvider)
          .fetchTicketNotes(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notes = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final adminId = ref.read(authStateProvider).value?.id;
    if (adminId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .addTicketNote(
            ticketId: widget.ticketId,
            note: text,
            adminId: adminId,
          );
    } on AdminException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _controller.clear();
    await _load();
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed) {
      return Row(
        children: [
          Expanded(child: Text(l10n.adminBiletNotOkunamadi)),
          IconButton(
            tooltip: l10n.updaterTekrarDene,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      );
    }
    final notes = _notes ?? const <FeedbackTicketNote>[];
    if (notes.isEmpty) return Text(l10n.adminHenuzNotYok);
    return Column(
      children: [
        for (final note in notes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(note.note),
            subtitle: Text(
              l10n.adminAdminIdNoteadminidNotecreatedattostringsubstring0(
                // WP-464: silinen admin icin `0114` bu alani NULL'lar.
                note.adminId ?? l10n.adminUgcDeletedUser,
                note.createdAt.toString().substring(0, 16),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminIcNotlarGizli,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _body(l10n),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: kAdminTicketNoteFieldKey,
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l10n.adminYeniNot,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: kAdminTicketNoteSendKey,
              tooltip: l10n.adminGonder,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.send, size: 20),
              onPressed: _add,
            ),
          ],
        ),
      ],
    );
  }
}
