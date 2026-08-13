import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_note.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../cards/admin_work_card.dart';
import '../directory/admin_search_field.dart';

/// WP-D (`docs/design/ADMIN-PANEL-PLAN.md` §2.4) — destek bileti kuyrugu.
///
/// WP-D'de iki kusur duzeltildi ve **korunur**:
///   1. 🔴 **Filtre cikmazi.** Tur cipleri listenin **disinda** durur; bos
///      sonucta ayrica "Filtreyi temizle" kalir.
///   2. 🔴 **Yalan etiket.** Arsiv eylemi "Arsivle" / "Arsivden cikar" yazar,
///      profil katalogundan gelen "Tamamlandi" degil.
///
/// **WP-698 — kart sifirdan.** Sahip: *"sikayet, oneri, istek vs hepsinde
/// sisteme dusen kart sistemi ayni"*. Olculdu: bu dosyadaki `_TicketCard`
/// 280 px'te **610 px** yuksekligindeydi (vaka karti 242 px) — tek bilet bir
/// telefon ekranini doldururdu. Icinde 7 cip vardi; 3'u bilgi, 4'u eylemdi ve
/// hepsi ayni 34 px'lik pilldi, yani neye basilabilecegi gorunmuyordu. Kartin
/// sekiz dokunma hedefinin sekizi de 48 px'in altindaydi.
///
/// Kart artik [AdminWorkCard]'dir — moderasyon kuyruguyla **ayni** bilesen.
/// Tur farki veriyle anlatilir: ikon, meta satirindaki tur adi, taraf listesi.
/// Bilgi cip degildir (durum hapte, tur metada, gonderen taraf satirinda);
/// cip gorunumu yalniz *istisnai* isaretlere (arsiv) kalir. Eylemler tek
/// ritimli bir seritte, 48 px yuksekliginde ve tek vurgulu ("Yanit yaz").

class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  var _showArchive = false;
  FeedbackTicketType? _type;

  bool get _hasFilter => _type != null || _showArchive;

  void _clearFilter() => setState(() {
    _type = null;
    _showArchive = false;
  });

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(
      _showArchive
          ? adminArchivedFeedbackTicketsProvider(_type)
          : adminFeedbackTicketsProvider(_type),
    );
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _filterBar(l10n),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminFeedbackTicketsProvider(_type));
              ref.invalidate(adminArchivedFeedbackTicketsProvider(_type));
              await ref.read(
                (_showArchive
                        ? adminArchivedFeedbackTicketsProvider(_type)
                        : adminFeedbackTicketsProvider(_type))
                    .future,
              );
            },
            child: tickets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
              data: (items) {
                final visibleItems = _showArchive
                    ? items
                          .where((ticket) => ticket.archivedAt != null)
                          .toList()
                    : items;
                if (visibleItems.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    children: [
                      AdminEmptyResult(
                        message: _hasFilter
                            ? l10n.adminSonucYok
                            : l10n.adminHenuzRaporYok,
                        onClearFilter: _hasFilter ? _clearFilter : null,
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    return _TicketCard(
                      ticket: visibleItems[index],
                      showArchived: _showArchive,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Tur cipleri + arsiv gorunumu. Listenin **disinda** durur; bos sonucta da
  /// ekranda kalir (PLAN §2.4).
  Widget _filterBar(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in FeedbackTicketType.values) ...[
            FilterChip(
              visualDensity: VisualDensity.compact,
              label: Text(_typeLabel(l10n, type)),
              selected: _type == type,
              onSelected: (selected) =>
                  setState(() => _type = selected ? type : null),
            ),
            const SizedBox(width: 6),
          ],
          IconButton.outlined(
            tooltip: _showArchive
                ? l10n.adminAktifleriGoster
                : l10n.adminArsiviGoster,
            icon: Icon(
              _showArchive ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchive = !_showArchive),
          ),
        ],
      ),
    );
  }
}

/// Destek bileti = **ayni** kart dili, farkli veri.
class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket, required this.showArchived});

  final FeedbackTicket ticket;
  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reporter = ticket.reporterDisplayName;

    return AdminWorkCard(
      typeIcon: _typeIcon(ticket.type),
      title: ticket.subject,
      tone: _tone(),
      // Kullanicinin yazdigi metnin ilk iki satiri: "ne hakkinda" sorusu
      // karti terk etmeden yanitlanir.
      excerpt: ticket.message,
      status: AdminWorkStatusPill<FeedbackTicketStatus>(
        label: _statusLabel(l10n, ticket.status),
        tone: _statusTone(ticket.status),
        options: FeedbackTicketStatus.values,
        optionLabel: (status) => _statusLabel(l10n, status),
        onSelected: (status) => _setStatus(context, ref, l10n, status),
      ),
      participants: [
        if (reporter != null && reporter.isNotEmpty)
          AdminWorkParticipant(
            roleLabel: l10n.adminWorkCardSubmitter,
            name: reporter,
          ),
      ],
      // WP-437: "ne zaman acildi, en son ne zaman hareket etti" karti terk
      // etmeden gorunur — artik tur adiyla ayni satirda.
      metaLine:
          '${_typeLabel(l10n, ticket.type)} · '
          '${l10n.feedbackTicketTimeline(feedbackTicketTimestampLabel(l10n, ticket.createdAt), feedbackTicketTimestampLabel(l10n, ticket.updatedAt))}',
      flags: [
        if (ticket.archivedAt != null)
          AdminWorkFlag(l10n.adminWorkCardArchived, tone: AdminWorkTone.done),
      ],
      overflowKey: Key('feedback-more-${ticket.id}'),
      overflowItems: [
        if (ticket.type == FeedbackTicketType.report)
          AdminWorkMenuItem(
            label: l10n.adminSanctionApplyRestriction,
            // Destek bileti semasi yalniz gondereni tasir; sikayet edilen
            // hedefi tasimaz. Gondereni yanlislikla cezalandirmak yerine yol
            // gorunur ama acik neden ile devre disidir.
            onSelected: null,
            disabledReason: l10n.adminKullaniciBulunamadi,
          ),
        AdminWorkMenuItem(
          label: showArchived ? l10n.adminArsivdenCikar : l10n.adminArsivle,
          onSelected: () => _setArchived(ref),
        ),
      ],
      actions: [
        // Tek vurgulu eylem: kullaniciya giden yol. Ic notlardan **once**.
        AdminWorkAction(
          buttonKey: Key('feedback-reply-${ticket.id}'),
          label: l10n.feedbackWriteReply,
          icon: Icons.forum_outlined,
          primary: true,
          onPressed: () =>
              showFeedbackTicketConversation(context: context, ticket: ticket),
        ),
        AdminWorkAction(
          buttonKey: Key('feedback-notes-${ticket.id}'),
          label: l10n.adminIcNotlar,
          icon: Icons.lock_outline,
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _TicketNotesDialog(ticket: ticket),
          ),
        ),
        if (ticket.attachmentPath != null)
          AdminWorkAction(
            label: l10n.adminEkranGoruntusu,
            icon: Icons.image_outlined,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  _AttachmentPreviewDialog(path: ticket.attachmentPath!),
            ),
          ),
      ],
    );
  }

  AdminWorkTone _tone() {
    if (showArchived || ticket.archivedAt != null) return AdminWorkTone.done;
    return _statusTone(ticket.status);
  }

  static AdminWorkTone _statusTone(FeedbackTicketStatus status) =>
      switch (status) {
        FeedbackTicketStatus.open => AdminWorkTone.open,
        FeedbackTicketStatus.inProgress => AdminWorkTone.waiting,
        FeedbackTicketStatus.closed => AdminWorkTone.done,
      };

  static IconData _typeIcon(FeedbackTicketType type) => switch (type) {
    FeedbackTicketType.report => Icons.bug_report_outlined,
    FeedbackTicketType.question => Icons.question_answer_outlined,
    FeedbackTicketType.feedback => Icons.lightbulb_outline,
  };

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    FeedbackTicketStatus status,
  ) async {
    final profile = ref.read(authStateProvider).value;
    if (profile == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateFeedbackStatus(
            userId: profile.id,
            ticketId: ticket.id,
            status: status,
          );
      ref.invalidate(adminFeedbackTicketsProvider(null));
      ref.invalidate(adminFeedbackTicketsProvider(ticket.type));
    } on AdminException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
      );
    }
  }

  Future<void> _setArchived(WidgetRef ref) async {
    final profile = ref.read(authStateProvider).value;
    if (profile == null) return;
    await ref
        .read(adminRepositoryProvider)
        .setFeedbackArchived(
          userId: profile.id,
          ticketId: ticket.id,
          archived: !showArchived,
        );
    ref.invalidate(adminFeedbackTicketsProvider(null));
    ref.invalidate(adminFeedbackTicketsProvider(ticket.type));
    ref.invalidate(adminArchivedFeedbackTicketsProvider(null));
    ref.invalidate(adminArchivedFeedbackTicketsProvider(ticket.type));
  }
}

String _statusLabel(AppLocalizations l10n, FeedbackTicketStatus status) {
  return switch (status) {
    FeedbackTicketStatus.open => l10n.adminAcik,
    FeedbackTicketStatus.inProgress => l10n.adminInceleniyor,
    FeedbackTicketStatus.closed => l10n.adminKapali,
  };
}

String _typeLabel(AppLocalizations l10n, FeedbackTicketType type) {
  return switch (type) {
    FeedbackTicketType.feedback => l10n.supportTicketTypeFeedback,
    FeedbackTicketType.question => l10n.supportTicketTypeQuestion,
    FeedbackTicketType.report => l10n.supportTicketTypeReport,
  };
}

class _AttachmentPreviewDialog extends ConsumerStatefulWidget {
  const _AttachmentPreviewDialog({required this.path});
  final String path;

  @override
  ConsumerState<_AttachmentPreviewDialog> createState() =>
      _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState
    extends ConsumerState<_AttachmentPreviewDialog> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _url = null;
      });
    }
    try {
      final url = await ref
          .read(adminRepositoryProvider)
          .getFeedbackAttachmentUrl(widget.path);
      if (!mounted) return;
      setState(() {
        _url = url;
        _loading = false;
      });
    } on AdminException {
      if (!mounted) return;
      setState(() {
        _url = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _url = null;
        _loading = false;
      });
    }
  }

  Widget _loadFailure(AppLocalizations l10n) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.adminGorselYuklenemedi),
            const SizedBox(height: 8),
            IconButton(
              tooltip: l10n.updaterTekrarDene,
              icon: const Icon(Icons.refresh),
              onPressed: _loadUrl,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          if (_loading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_url == null)
            _loadFailure(l10n)
          else
            InteractiveViewer(
              child: Image.network(
                _url!,
                key: ValueKey(_url),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _loadFailure(l10n),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.54),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: AppLocalizations.of(context).coreKapat,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketNotesDialog extends ConsumerStatefulWidget {
  const _TicketNotesDialog({required this.ticket});
  final FeedbackTicket ticket;

  @override
  ConsumerState<_TicketNotesDialog> createState() => _TicketNotesDialogState();
}

class _TicketNotesDialogState extends ConsumerState<_TicketNotesDialog> {
  final _noteController = TextEditingController();
  List<FeedbackTicketNote>? _notes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      final notes = await ref
          .read(adminRepositoryProvider)
          .fetchTicketNotes(widget.ticket.id);
      if (mounted) {
        setState(() {
          _notes = notes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
        );
      }
    }
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    final adminId = ref.read(authStateProvider).value?.id;
    if (adminId == null) return;

    try {
      await ref
          .read(adminRepositoryProvider)
          .addTicketNote(
            ticketId: widget.ticket.id,
            note: text,
            adminId: adminId,
          );
      _noteController.clear();
      await _loadNotes();
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.adminIcNotlar,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  tooltip: l10n.coreKapat,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                l10n.adminIcNotlarGizli,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(),
            if (_loading)
              const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_notes != null && _notes!.isEmpty)
              SizedBox(
                height: 100,
                child: Center(child: Text(l10n.adminHenuzNotYok)),
              )
            else if (_notes != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _notes!.length,
                  itemBuilder: (context, index) {
                    final note = _notes![index];
                    return ListTile(
                      title: Text(note.note),
                      subtitle: Text(
                        l10n.adminAdminIdNoteadminidNotecreatedattostringsubstring0(
                          // WP-464: silinen admin icin `0114` bu alani
                          // NULL'lar; kanit `admin_hash` ile durur.
                          note.adminId ?? l10n.adminUgcDeletedUser,
                          note.createdAt.toString().substring(0, 16),
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: l10n.adminYeniNot,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l10n.adminGonder,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: _addNote,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
