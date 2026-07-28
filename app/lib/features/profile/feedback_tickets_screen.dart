import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/feedback_ticket.dart';
import '../../data/models/feedback_ticket_message.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/admin_repository.dart';
import '../../l10n/app_localizations.dart';

class FeedbackTicketsScreen extends StatelessWidget {
  const FeedbackTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).feedbackMyTickets)),
      body: const MyFeedbackTicketsView(),
    );
  }
}

/// Kullanicinin kendi biletleri, **en yeni en ustte**.
///
/// WP-420: Ayni liste hem kendi ekraninda (duyurulardan gelen yol) hem de
/// Geri bildirim ekraninin ikinci sekmesinde kullanilir; iki kopya tutulmaz.
class MyFeedbackTicketsView extends ConsumerWidget {
  const MyFeedbackTicketsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tickets = ref.watch(myFeedbackTicketsProvider);
    return tickets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(l10n.feedbackNoTickets));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final ticket = items[index];
            return Card(
              child: ListTile(
                key: Key('feedback-ticket-${ticket.id}'),
                leading: Icon(
                  ticket.kind == FeedbackTicketKind.bug
                      ? Icons.bug_report_outlined
                      : Icons.lightbulb_outline,
                ),
                title: Text(ticket.subject),
                subtitle: Text(
                  ticket.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showFeedbackTicketConversation(
                  context: context,
                  ticket: ticket,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> showFeedbackTicketConversation({
  required BuildContext context,
  required FeedbackTicket ticket,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FeedbackTicketConversationDialog(ticket: ticket),
  );
}

class _FeedbackTicketConversationDialog extends ConsumerStatefulWidget {
  const _FeedbackTicketConversationDialog({required this.ticket});

  final FeedbackTicket ticket;

  @override
  ConsumerState<_FeedbackTicketConversationDialog> createState() =>
      _FeedbackTicketConversationDialogState();
}

class _FeedbackTicketConversationDialogState
    extends ConsumerState<_FeedbackTicketConversationDialog> {
  final _controller = TextEditingController();
  // WP-374 (V51-3): sohbet dizilimi -- yeni mesaj altta, gorunum sona kayar.
  // Liste sirasi zaten artan (`order('created_at')`); eksik olan yalnizca
  // gorunen pencerenin en eskide takili kalmasiydi.
  final _scrollController = ScrollController();
  List<FeedbackTicketMessage>? _messages;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Listeyi sona kaydirir. Ilk yuklemede animasyonsuz (kullanici zaten sonu
  /// gormeli), yeni mesaj gonderilince animasyonlu.
  void _scrollToBottom({required bool animated}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _load() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final repository = ref.read(adminRepositoryProvider);
      final messages = await repository.fetchTicketMessages(
        userId: user.id,
        ticketId: widget.ticket.id,
      );
      await repository.markTicketMessagesRead(
        userId: user.id,
        ticketId: widget.ticket.id,
      );
      // WP-421: okununca zincirin **tamami** temizlenir; ust seviyelerde
      // (Ayarlar satiri, Profil satiri) rozet asili kalmaz.
      ref.invalidate(unreadFeedbackReplyCountProvider);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _scrollToBottom(animated: false);
    } on AdminException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final user = ref.read(authStateProvider).value;
    final text = _controller.text.trim();
    if (user == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .sendTicketMessage(
            userId: user.id,
            ticketId: widget.ticket.id,
            message: text,
          );
      _controller.clear();
      ref.invalidate(myFeedbackTicketsProvider);
      ref.invalidate(unreadFeedbackReplyCountProvider);
      ref.invalidate(adminFeedbackTicketsProvider(null));
      await _load();
      _scrollToBottom(animated: true);
    } on AdminException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).authBeklenmeyenBirHataOlustu,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _senderLabel(
    AppLocalizations l10n,
    FeedbackTicketMessage message,
    bool viewingAsAdmin,
  ) {
    if (viewingAsAdmin) {
      return message.senderRole == FeedbackTicketSenderRole.admin
          ? l10n.feedbackYou
          : l10n.feedbackUser;
    }
    return message.senderRole == FeedbackTicketSenderRole.admin
        ? l10n.feedbackAdmin
        : l10n.feedbackYou;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(adminIsSuperAdminProvider).value ?? false;
    return AlertDialog(
      title: Text(l10n.feedbackConversation),
      content: SizedBox(
        width: 520,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.ticket.subject,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages == null || _messages!.isEmpty
                  ? Center(child: Text(l10n.feedbackNoReplies))
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: _messages!.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final message = _messages![index];
                        final own = message.senderId == user?.id;
                        return Align(
                          alignment: own
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: own
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _senderLabel(l10n, message, isAdmin),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(message.message),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: kMaxFeedbackTicketReplyLength,
                    decoration: InputDecoration(
                      hintText: l10n.feedbackReplyHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('feedback-send-reply'),
                  tooltip: l10n.profileGonder,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.coreKapat),
        ),
      ],
    );
  }
}
