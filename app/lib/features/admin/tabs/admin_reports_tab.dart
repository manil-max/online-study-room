import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_note.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class AdminReportsTab extends ConsumerStatefulWidget {
  const AdminReportsTab({super.key});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  var _showArchive = false;
  FeedbackTicketType? _type;

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(
      _showArchive
          ? adminArchivedFeedbackTicketsProvider(_type)
          : adminFeedbackTicketsProvider(_type),
    );
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
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
              ? items.where((ticket) => ticket.archivedAt != null).toList()
              : items;
          if (visibleItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.adminHenuzRaporYok),
                  IconButton.outlined(
                    icon: Icon(
                      _showArchive
                          ? Icons.inventory_2
                          : Icons.inventory_2_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _showArchive = !_showArchive),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: visibleItems.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    for (final type in FeedbackTicketType.values)
                      FilterChip(
                        label: Text(_typeLabel(l10n, type)),
                        selected: _type == type,
                        onSelected: (selected) =>
                            setState(() => _type = selected ? type : null),
                      ),
                    IconButton.outlined(
                      icon: Icon(
                        _showArchive
                            ? Icons.inventory_2
                            : Icons.inventory_2_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _showArchive = !_showArchive),
                    ),
                  ],
                );
              }
              return _TicketCard(
                ticket: visibleItems[index - 1],
                showArchived: _showArchive,
              );
            },
          );
        },
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket, required this.showArchived});

  final FeedbackTicket ticket;
  final bool showArchived;

  void _showNotesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _TicketNotesDialog(ticket: ticket),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ticket.type == FeedbackTicketType.report
                      ? Icons.bug_report_outlined
                      : ticket.type == FeedbackTicketType.question
                      ? Icons.question_answer_outlined
                      : Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusMenu(ticket: ticket),
              ],
            ),
            const SizedBox(height: 6),
            Text(ticket.message, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // WP-437: Yonetici karti zaman cizgisini de okur; "ne zaman
            // acildi, en son ne zaman hareket etti" karti terk etmeden gorunur.
            Text(
              l10n.feedbackTicketTimeline(
                feedbackTicketTimestampLabel(l10n, ticket.createdAt),
                feedbackTicketTimestampLabel(l10n, ticket.updatedAt),
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_statusLabel(l10n, ticket.status)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_typeLabel(l10n, ticket.type)),
                ),
                if (ticket.reporterDisplayName?.isNotEmpty == true)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(ticket.reporterDisplayName!),
                  ),
                if (ticket.attachmentPath != null)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: Text(l10n.adminEkranGoruntusu),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => _AttachmentPreviewDialog(
                          path: ticket.attachmentPath!,
                        ),
                      );
                    },
                  ),
                ActionChip(
                  key: Key('feedback-reply-${ticket.id}'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  avatar: Icon(
                    Icons.forum_outlined,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  label: Text(
                    l10n.feedbackWriteReply,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  onPressed: () => showFeedbackTicketConversation(
                    context: context,
                    ticket: ticket,
                  ),
                ),
                ActionChip(
                  key: Key('feedback-notes-${ticket.id}'),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.lock_outline, size: 18),
                  label: Text(l10n.adminIcNotlar),
                  onPressed: () => _showNotesDialog(context, ref),
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    showArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 18,
                  ),
                  label: Text(l10n.profileTamamland),
                  onPressed: () async {
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
                    ref.invalidate(
                      adminArchivedFeedbackTicketsProvider(ticket.type),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMenu extends ConsumerWidget {
  const _StatusMenu({required this.ticket});

  final FeedbackTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<FeedbackTicketStatus>(
      tooltip: l10n.adminDurumuDegistir,
      initialValue: ticket.status,
      onSelected: (status) async {
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
      },
      itemBuilder: (context) => [
        for (final status in FeedbackTicketStatus.values)
          PopupMenuItem(value: status, child: Text(_statusLabel(l10n, status))),
      ],
    );
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
