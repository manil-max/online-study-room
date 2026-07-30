import 'package:flutter/foundation.dart';

import 'feedback_ticket.dart';
import 'feedback_ticket_message.dart';

/// Bir feedback biletinin liste satirinda gosterilecek konusma ozeti.
///
/// WP-437: Liste satiri artik biletin **ilk** mesajini degil, konusmanin son
/// halini gosterir. Ozet tek kaynaktan (kanonik mesaj dizisi + okundu
/// watermark'i) turer; ekranda ikinci bir sayac ya da yerel bayrak tutulmaz.
@immutable
class FeedbackTicketThreadSummary {
  const FeedbackTicketThreadSummary({
    required this.ticket,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderRole,
    required this.messageCount,
    required this.unreadCount,
  });

  final FeedbackTicket ticket;
  final String lastMessage;
  final DateTime lastMessageAt;
  final FeedbackTicketSenderRole lastSenderRole;
  final int messageCount;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  /// Mesaj satiri hic yoksa biletin kendi metni son mesaj sayilir; boylece
  /// eski biletler listede bos gorunmez.
  factory FeedbackTicketThreadSummary.fromMessages({
    required FeedbackTicket ticket,
    required List<FeedbackTicketMessage> messages,
    required int lastReadMessageSeq,
  }) {
    final ordered = [...messages]
      ..sort((a, b) => a.messageSeq.compareTo(b.messageSeq));
    if (ordered.isEmpty) {
      return FeedbackTicketThreadSummary(
        ticket: ticket,
        lastMessage: ticket.message,
        lastMessageAt: ticket.createdAt,
        lastSenderRole: FeedbackTicketSenderRole.user,
        messageCount: 0,
        unreadCount: 0,
      );
    }
    final last = ordered.last;
    final unread = ordered
        .where(
          (message) =>
              message.senderRole == FeedbackTicketSenderRole.admin &&
              message.messageSeq > lastReadMessageSeq,
        )
        .length;
    return FeedbackTicketThreadSummary(
      ticket: ticket,
      lastMessage: last.message,
      lastMessageAt: last.createdAt,
      lastSenderRole: last.senderRole,
      messageCount: ordered.length,
      unreadCount: unread,
    );
  }
}
