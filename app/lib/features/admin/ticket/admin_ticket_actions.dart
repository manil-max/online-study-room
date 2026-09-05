import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';

/// WP-770 — destek biletinin **yazma** yollari tek yerde.
///
/// Eski yer `tabs/admin_reports_tab.dart`'ti ve uc kusuru tasiyordu:
///
///   1. 🔴 **Bayat ekran.** `_setStatus` (`:283-284`) yalniz
///      `adminFeedbackTicketsProvider`i tazeliyordu. Arsiv gorunumunde ekranin
///      izledigi saglayici `adminArchivedFeedbackTicketsProvider`di; yazma
///      sonrasi liste eski haliyle duruyordu. Tazeleme artik **ekranin
///      izleyebilecegi butun** aileleri kapsar ([refreshFeedbackTicketQueues]).
///   2. 🔴 **Sessiz ret.** `_setArchived` (`:293-307`) hic hata yakalamiyordu;
///      yetki reddinde kullaniciya hicbir sey gorunmuyordu.
///   3. 🔴 **Yutulan sunucu mesaji.** `AdminException` yakalanip yerine genel
///      "beklenmeyen hata" yaziliyordu (`:285-290`); edge function'in gercek
///      cevabi kayboluyordu. Desen `sanctions/admin_sanction_actions.dart:168`
///      ile ayni: `e.message` yazilir.

/// Yazma sonrasi kuyruk saglayicilarini tazeler.
///
/// Hem tur filtresiz (`null`) hem biletin turundeki aile, hem aktif hem arsiv
/// listesi: kullanicinin hangi filtreyle baktigini yazma yolu bilemez.
void refreshFeedbackTicketQueues(WidgetRef ref, FeedbackTicketType type) {
  for (final key in <FeedbackTicketType?>{null, type}) {
    ref.invalidate(adminFeedbackTicketsProvider(key));
    ref.invalidate(adminArchivedFeedbackTicketsProvider(key));
  }
}

/// Biletin durumunu yazar. Donus `false` ise yazilamadi ve sebep kullaniciya
/// **sunucunun kendi cumlesiyle** gosterildi.
Future<bool> setFeedbackTicketStatus({
  required BuildContext context,
  required WidgetRef ref,
  required FeedbackTicket ticket,
  required FeedbackTicketStatus status,
}) async {
  final adminId = ref.read(authStateProvider).value?.id;
  if (adminId == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(adminRepositoryProvider)
        .updateFeedbackStatus(
          userId: adminId,
          ticketId: ticket.id,
          status: status,
        );
  } on AdminException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
  refreshFeedbackTicketQueues(ref, ticket.type);
  return true;
}

/// Bileti arsivler ya da arsivden cikarir.
Future<bool> setFeedbackTicketArchived({
  required BuildContext context,
  required WidgetRef ref,
  required FeedbackTicket ticket,
  required bool archived,
}) async {
  final adminId = ref.read(authStateProvider).value?.id;
  if (adminId == null) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(adminRepositoryProvider)
        .setFeedbackArchived(
          userId: adminId,
          ticketId: ticket.id,
          archived: archived,
        );
  } on AdminException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
  refreshFeedbackTicketQueues(ref, ticket.type);
  return true;
}
