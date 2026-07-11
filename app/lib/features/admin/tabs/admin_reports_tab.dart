import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_note.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';

class AdminReportsTab extends ConsumerWidget {
  const AdminReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(adminFeedbackTicketsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminFeedbackTicketsProvider);
        await ref.read(adminFeedbackTicketsProvider.future);
      },
      child: tickets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Henüz rapor yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _TicketCard(ticket: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket});

  final FeedbackTicket ticket;

  void _showNotesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _TicketNotesDialog(ticket: ticket),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ticket.kind == FeedbackTicketKind.bug
                      ? Icons.bug_report_outlined
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_statusLabel(ticket.status)),
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
                    label: const Text('Ekran Görüntüsü'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => _AttachmentPreviewDialog(path: ticket.attachmentPath!),
                      );
                    },
                  ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.note_alt_outlined, size: 18),
                  label: const Text('İç Notlar'),
                  onPressed: () => _showNotesDialog(context, ref),
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
    return PopupMenuButton<FeedbackTicketStatus>(
      tooltip: 'Durumu değiştir',
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
          ref.invalidate(adminFeedbackTicketsProvider);
        } on AdminException catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      },
      itemBuilder: (context) => [
        for (final status in FeedbackTicketStatus.values)
          PopupMenuItem(value: status, child: Text(_statusLabel(status))),
      ],
    );
  }
}

String _statusLabel(FeedbackTicketStatus status) {
  return switch (status) {
    FeedbackTicketStatus.open => 'Açık',
    FeedbackTicketStatus.inProgress => 'İnceleniyor',
    FeedbackTicketStatus.closed => 'Kapalı',
  };
}

class _AttachmentPreviewDialog extends ConsumerStatefulWidget {
  const _AttachmentPreviewDialog({required this.path});
  final String path;

  @override
  ConsumerState<_AttachmentPreviewDialog> createState() => _AttachmentPreviewDialogState();
}

class _AttachmentPreviewDialogState extends ConsumerState<_AttachmentPreviewDialog> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await ref.read(adminRepositoryProvider).getFeedbackAttachmentUrl(widget.path);
    if (mounted) {
      setState(() {
        _url = url;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(
              height: 200,
              child: Center(child: Text('Görsel yüklenemedi.')),
            )
          else
            Image.network(_url!, fit: BoxFit.contain),
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
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
      final notes = await ref.read(adminRepositoryProvider).fetchTicketNotes(widget.ticket.id);
      if (mounted) {
        setState(() {
          _notes = notes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    final adminId = ref.read(authStateProvider).value?.id;
    if (adminId == null) return;

    try {
      await ref.read(adminRepositoryProvider).addTicketNote(
            ticketId: widget.ticket.id,
            note: text,
            adminId: adminId,
          );
      _noteController.clear();
      await _loadNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const Text('İç Notlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(),
            if (_loading)
              const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            else if (_notes != null && _notes!.isEmpty)
              const SizedBox(height: 100, child: Center(child: Text('Henüz not yok.')))
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
                      subtitle: Text('Admin ID: ${note.adminId} • ${note.createdAt.toString().substring(0, 16)}'),
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
                    decoration: const InputDecoration(
                      hintText: 'Yeni not...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
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
