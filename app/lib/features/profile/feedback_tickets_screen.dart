import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/feedback_ticket.dart';
import '../../data/models/feedback_ticket_message.dart';
import '../../data/models/feedback_ticket_thread_summary.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/admin_repository.dart';
import '../../l10n/app_localizations.dart';
// WP-770: kuyruk tazeleme kurali tek yerde (yazma sonrasi ekranin **izledigi**
// saglayicilar).
import '../admin/ticket/admin_ticket_actions.dart';
// WP-679: ortak masaustu olculeri (`ProfileDesktopBody`) Ayarlar'da durur.
import 'settings_screen.dart';

class FeedbackTicketsScreen extends StatelessWidget {
  const FeedbackTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).feedbackMyTickets),
      ),
      body: const MyFeedbackTicketsView(),
    );
  }
}

String feedbackTicketStatusLabel(
  AppLocalizations l10n,
  FeedbackTicketStatus status,
) {
  return switch (status) {
    FeedbackTicketStatus.open => l10n.adminAcik,
    FeedbackTicketStatus.inProgress => l10n.adminInceleniyor,
    FeedbackTicketStatus.closed => l10n.adminKapali,
  };
}

String feedbackTicketTypeLabel(AppLocalizations l10n, FeedbackTicketType type) {
  return switch (type) {
    FeedbackTicketType.feedback => l10n.supportTicketTypeFeedback,
    FeedbackTicketType.question => l10n.supportTicketTypeQuestion,
    FeedbackTicketType.report => l10n.supportTicketTypeReport,
  };
}

String feedbackTicketTimestampLabel(AppLocalizations l10n, DateTime value) {
  return DateFormat.yMMMd(l10n.localeName).add_Hm().format(value.toLocal());
}

/// Kullanicinin kendi biletleri, **en yeni en ustte**.
///
/// WP-420: Ayni liste hem kendi ekraninda (duyurulardan gelen yol) hem de
/// Geri bildirim ekraninin ikinci sekmesinde kullanilir; iki kopya tutulmaz.
/// WP-437: Satir artik biletin ilk mesajini degil konusmanin son halini
/// (son mesaj, tarih, durum, okunmamis sayisi) gosterir.
class MyFeedbackTicketsView extends ConsumerWidget {
  const MyFeedbackTicketsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaries = ref.watch(myFeedbackTicketSummariesProvider);
    return summaries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.authBeklenmeyenBirHataOlustu,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('feedback-tickets-retry'),
              onPressed: () =>
                  ref.invalidate(myFeedbackTicketSummariesProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.updaterTekrarDene),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(l10n.feedbackNoTickets));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myFeedbackTicketSummariesProvider);
            await ref.read(myFeedbackTicketSummariesProvider.future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            // WP-679: SPEC §2.3 form sutunu tavani. Sarmalayici `itemBuilder`
            // icinde ki `ListView.separated` tembel kalsin.
            itemBuilder: (context, index) => ProfileDesktopBody.form(
              child: _TicketSummaryTile(summary: items[index]),
            ),
          ),
        );
      },
    );
  }
}

class _TicketSummaryTile extends StatelessWidget {
  const _TicketSummaryTile({required this.summary});

  final FeedbackTicketThreadSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final ticket = summary.ticket;
    final senderLabel = summary.lastSenderRole == FeedbackTicketSenderRole.admin
        ? l10n.feedbackAdmin
        : l10n.feedbackYou;
    return Card(
      child: InkWell(
        key: Key('feedback-ticket-${ticket.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            showFeedbackTicketConversation(context: context, ticket: ticket),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ticket.kind == FeedbackTicketKind.bug
                    ? Icons.bug_report_outlined
                    : Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.feedbackThreadPreview(
                        senderLabel,
                        summary.lastMessage,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          feedbackTicketTimestampLabel(
                            l10n,
                            summary.lastMessageAt,
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          feedbackTicketStatusLabel(l10n, ticket.status),
                          style: theme.textTheme.labelSmall,
                        ),
                        if (summary.hasUnread)
                          _UnreadBadge(
                            key: Key('feedback-ticket-unread-${ticket.id}'),
                            count: summary.unreadCount,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.feedbackThreadUnreadCount(count),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
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

/// Gonderilmeyi bekleyen ya da basarisiz olan yanit.
///
/// WP-437: Basarisiz mesaj **kaybolmaz** ve sahte "gonderildi" gorunmez;
/// ayni istemci komut kimligiyle yeniden denenir (WP-435 idempotency).
class _PendingReply {
  _PendingReply({required this.clientMessageId, required this.text});

  final String clientMessageId;
  final String text;
  bool failed = false;
}

/// Kullanici tarafinin kabugu: diyalog. WP-770'te **govde** ortak widget'a
/// tasindi ([FeedbackTicketConversationView]); yonetim panelinin tam sayfa
/// bilet detayi ayni govdeyi kullanir, iki kopya yazisma yuzeyi tutulmaz.
/// Kabuk (anahtar, baslik, "Kapat", olculer) aynen korunur.
class _FeedbackTicketConversationDialog extends StatelessWidget {
  const _FeedbackTicketConversationDialog({required this.ticket});

  final FeedbackTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final width = (media.size.width - 80).clamp(260.0, 520.0);
    final height = (media.size.height * 0.7).clamp(240.0, 440.0);
    return AlertDialog(
      key: Key('feedback-conversation-${ticket.id}'),
      title: Text(l10n.feedbackConversation),
      content: SizedBox(
        width: width,
        height: height,
        child: FeedbackTicketConversationView(ticket: ticket),
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

/// Bir biletin admin↔kullanici yazismasi: sabit thread baglami, mesaj listesi
/// ve gonderme satiri. Kabuktan bagimsizdir; kendisine verilen alani doldurur.
class FeedbackTicketConversationView extends ConsumerStatefulWidget {
  const FeedbackTicketConversationView({super.key, required this.ticket});

  final FeedbackTicket ticket;

  @override
  ConsumerState<FeedbackTicketConversationView> createState() =>
      _FeedbackTicketConversationViewState();
}

class _FeedbackTicketConversationViewState
    extends ConsumerState<FeedbackTicketConversationView> {
  static const _uuid = Uuid();

  final _controller = TextEditingController();
  // WP-374 (V51-3): sohbet dizilimi -- yeni mesaj altta, gorunum sona kayar.
  // Liste sirasi zaten artan (`order('created_at')`); eksik olan yalnizca
  // gorunen pencerenin en eskide takili kalmasiydi.
  final _scrollController = ScrollController();
  final List<_PendingReply> _pending = [];
  List<FeedbackTicketMessage>? _messages;
  StreamSubscription<List<FeedbackTicketMessage>>? _messageSubscription;
  bool _loading = true;
  bool _failedToLoad = false;

  @override
  void initState() {
    super.initState();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
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

  Future<void> _subscribeToMessages() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() {
      _loading = true;
      _failedToLoad = false;
    });
    final repository = ref.read(adminRepositoryProvider);
    await _messageSubscription?.cancel();
    _messageSubscription = repository
        .watchTicketMessages(userId: user.id, ticketId: widget.ticket.id)
        .listen(
          (messages) => _replaceMessages(messages, animated: _messages != null),
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _failedToLoad = _messages == null;
            });
          },
        );
  }

  void _replaceMessages(
    List<FeedbackTicketMessage> messages, {
    required bool animated,
  }) {
    // WP-437: Akis baska bir biletin satirlarini tasirsa bu konusmaya
    // cizilmez; thread baglami sabittir.
    final ordered =
        messages
            .where((message) => message.ticketId == widget.ticket.id)
            .toList()
          ..sort((a, b) => a.messageSeq.compareTo(b.messageSeq));
    if (!mounted) return;
    final delivered = ordered
        .map((message) => message.clientMessageId)
        .whereType<String>()
        .toSet();
    setState(() {
      _messages = ordered;
      _loading = false;
      _failedToLoad = false;
      _pending.removeWhere(
        (reply) => delivered.contains(reply.clientMessageId),
      );
    });
    _scrollToBottom(animated: animated);
    _acknowledgeVisibleThread();
  }

  void _acknowledgeVisibleThread() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _messages == null) return;
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      try {
        await ref
            .read(adminRepositoryProvider)
            .markTicketMessagesRead(
              userId: user.id,
              ticketId: widget.ticket.id,
            );
        ref.invalidate(unreadFeedbackReplyCountProvider);
        ref.invalidate(myFeedbackTicketSummariesProvider);
      } on AdminException {
        // Görüntülenen mesajı yeniden denemek için akışı açık tutarız; hata
        // kullanıcıyı konuşmadan çıkarmamalı.
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final reply = _PendingReply(clientMessageId: _uuid.v4(), text: text);
    setState(() => _pending.add(reply));
    _controller.clear();
    _scrollToBottom(animated: true);
    await _deliver(reply);
  }

  Future<void> _deliver(_PendingReply reply) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    if (reply.failed && mounted) {
      setState(() => reply.failed = false);
    }
    try {
      await ref
          .read(adminRepositoryProvider)
          .sendTicketMessage(
            userId: user.id,
            ticketId: widget.ticket.id,
            message: reply.text,
            clientMessageId: reply.clientMessageId,
          );
      if (mounted) {
        setState(() => _pending.remove(reply));
      }
      ref.invalidate(myFeedbackTicketsProvider);
      ref.invalidate(myFeedbackTicketSummariesProvider);
      ref.invalidate(unreadFeedbackReplyCountProvider);
      // 🔴 WP-770 (a): burada yalniz `adminFeedbackTicketsProvider(null)`
      // tazeleniyordu. Panel arsiv gorunumundeyse ya da tur filtresi seciliyse
      // ekranin **izledigi** aile baskaydi ve liste bayat kaliyordu.
      refreshFeedbackTicketQueues(ref, widget.ticket.type);
    } on AdminException {
      if (!mounted) return;
      // Mesaj listede kalir; kullanici dokunarak ayni komut kimligiyle
      // yeniden dener.
      setState(() => reply.failed = true);
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

  Widget _bubble({
    required BuildContext context,
    required bool own,
    required String senderLabel,
    required String body,
    required double maxWidth,
    String? statusLabel,
    Color? statusColor,
    VoidCallback? onTap,
    Key? key,
  }) {
    final theme = Theme.of(context);
    return Align(
      key: key,
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: own
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(senderLabel, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(body, softWrap: true),
                  if (statusLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(adminIsSuperAdminProvider).value ?? false;
    final messages = _messages ?? const <FeedbackTicketMessage>[];
    final rowCount = messages.length + _pending.length;
    // Balon genisligi kabugun verdigi alandan turer; diyalogda bu deger
    // eskiden oldugu gibi govde genisligidir.
    return LayoutBuilder(
      builder: (context, constraints) {
        final bubbleWidth = constraints.maxWidth - 100;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // WP-437: Sabit thread baglami — konu, durum ve tur her zaman
            // gorunur; kullanici hangi bileti okudugunu kaybetmez.
            Text(
              widget.ticket.subject,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  feedbackTicketStatusLabel(l10n, widget.ticket.status),
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  feedbackTicketTypeLabel(l10n, widget.ticket.type),
                  style: theme.textTheme.labelSmall,
                ),
                if (messages.isNotEmpty)
                  Text(
                    l10n.feedbackThreadMessageCount(messages.length),
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failedToLoad
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.authBeklenmeyenBirHataOlustu,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('feedback-conversation-retry'),
                            onPressed: _subscribeToMessages,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.updaterTekrarDene),
                          ),
                        ],
                      ),
                    )
                  : rowCount == 0
                  ? Center(child: Text(l10n.feedbackNoReplies))
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: rowCount,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index >= messages.length) {
                          final reply = _pending[index - messages.length];
                          return _bubble(
                            key: Key(
                              'feedback-pending-${reply.clientMessageId}',
                            ),
                            context: context,
                            own: true,
                            senderLabel: l10n.feedbackYou,
                            body: reply.text,
                            maxWidth: bubbleWidth,
                            statusLabel: reply.failed
                                ? l10n.feedbackMessageFailed
                                : l10n.feedbackMessageSending,
                            statusColor: reply.failed
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                            onTap: reply.failed ? () => _deliver(reply) : null,
                          );
                        }
                        final message = messages[index];
                        return _bubble(
                          context: context,
                          // 🔴 `senderId != null` sarti sart: WP-464/`0114`
                          // sonrasi silinen gonderici NULL gelir ve oturum
                          // acilmamissa `user?.id` de NULL'dir -- cipla
                          // karsilastirmada `null == null` dogru cikar ve
                          // baskasinin mesaji "benim" gibi hizalanirdi.
                          own:
                              message.senderId != null &&
                              message.senderId == user?.id,
                          senderLabel: _senderLabel(l10n, message, isAdmin),
                          body: message.message,
                          maxWidth: bubbleWidth,
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
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
