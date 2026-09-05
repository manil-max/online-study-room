import 'package:flutter/foundation.dart';

import '../../../data/models/feedback_ticket.dart';
import '../../../data/models/moderation_appeal.dart';
import '../../../data/models/moderation_case.dart';

/// WP-768 — panele **tek** kuyruk.
///
/// 🔴 Neden: panelde bekleyen is iki ayri listede duruyordu (`Raporlar` =
/// destek biletleri, `Icerik Sikayetleri` = UGC vakalari) ve sahip ikisini
/// ayri ayri gezmek zorundaydi. Daha kotusu, ayni sikayet **iki listede
/// birden** goruluyordu: `report_ugc` her UGC sikayeti icin bir destek bileti
/// de aciyor (`0110_moderation_report_block_immunity.sql:160-167`) ve bilet
/// `ugc_report_id` ile sikayete baglaniyor. Sunucu bu alani zaten
/// donduruyordu (`0090_support_inbox.sql:118`), istemci atiyordu.
///
/// Bu dosya saf birlestirme mantigidir: widget yok, sunucu cagrisi yok. Kural
/// testi bu yuzden ekran kurmadan kosar.
enum AdminQueueCategory {
  /// UGC sikayeti (vaka) **ya da** destek formundan gelen `report` bileti.
  complaint,

  /// Destek formundan gelen `feedback` bileti.
  suggestion,

  /// Destek formundan / SSS'ten gelen `question` bileti.
  question,

  /// Yaptirima itiraz.
  appeal,
}

/// Kuyruktaki tek satir. Tur farki **veriyle** anlatilir; her satir ayni kart
/// dilini kullanir (`cards/admin_work_card.dart`).
@immutable
sealed class AdminQueueEntry {
  const AdminQueueEntry();

  /// Liste anahtari — tur onekiyle tekillestirilir ki bilet ve vaka
  /// kimlikleri carpismasin.
  String get id;

  AdminQueueCategory get category;

  /// Siralama ani: en son hareket.
  DateTime get sortAt;

  /// Kapanmis is listenin dibine iner; kuyruk **bekleyen** isin listesidir.
  bool get isClosed;
}

class AdminQueueCaseEntry extends AdminQueueEntry {
  const AdminQueueCaseEntry(this.moderationCase);

  final ModerationCase moderationCase;

  @override
  String get id => 'case:${moderationCase.caseKey}';

  @override
  AdminQueueCategory get category => AdminQueueCategory.complaint;

  @override
  DateTime get sortAt => moderationCase.latestAt;

  @override
  bool get isClosed => moderationCase.status.isClosed;
}

class AdminQueueTicketEntry extends AdminQueueEntry {
  const AdminQueueTicketEntry(this.ticket);

  final FeedbackTicket ticket;

  @override
  String get id => 'ticket:${ticket.id}';

  @override
  AdminQueueCategory get category => switch (ticket.type) {
    FeedbackTicketType.report => AdminQueueCategory.complaint,
    FeedbackTicketType.question => AdminQueueCategory.question,
    FeedbackTicketType.feedback => AdminQueueCategory.suggestion,
  };

  @override
  DateTime get sortAt => ticket.updatedAt;

  @override
  bool get isClosed =>
      ticket.archivedAt != null ||
      ticket.status == FeedbackTicketStatus.closed;
}

class AdminQueueAppealEntry extends AdminQueueEntry {
  const AdminQueueAppealEntry(this.appeal);

  final ModerationAppeal appeal;

  @override
  String get id => 'appeal:${appeal.id}';

  @override
  AdminQueueCategory get category => AdminQueueCategory.appeal;

  @override
  DateTime get sortAt => appeal.createdAt;

  @override
  bool get isClosed => appeal.status.isDecided;
}

/// Uc kaynagi tek listeye indirger.
///
/// Kurallar (hepsi testle sabit):
///   1. **Ayna bilet elenir.** `ugcReportId` dolu bilet, kuyrukta zaten vaka
///      olarak duran bir sikayetin kopyasidir; ikinci kez gosterilmez.
///      Yazismasi kaybolmaz — vaka detayi onu [adminMirrorTicket] ile bulur.
///   2. **Karara baglanmis itiraz** kuyrukta durmaz.
///   3. Siralama: once acik isler, sonra en yeni hareket.
List<AdminQueueEntry> buildAdminQueue({
  required List<ModerationCase> cases,
  required List<FeedbackTicket> tickets,
  required List<ModerationAppeal> appeals,
}) {
  final entries = <AdminQueueEntry>[
    for (final moderationCase in cases) AdminQueueCaseEntry(moderationCase),
    for (final ticket in tickets)
      if (ticket.ugcReportId == null) AdminQueueTicketEntry(ticket),
    for (final appeal in appeals)
      if (!appeal.status.isDecided) AdminQueueAppealEntry(appeal),
  ];
  entries.sort((a, b) {
    if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
    return b.sortAt.compareTo(a.sortAt);
  });
  return entries;
}

/// Vakanin destek yazismasi.
///
/// Sikayet eden kisiyle yazismanin **tek** kanali budur: `report_ugc` sikayeti
/// acarken bir de bilet aciyor ve yonetici o bilete yanit yazinca kullanici
/// bildirim aliyor. Kuyruk bileti gizledigi icin bagi burada kuruyoruz.
FeedbackTicket? adminMirrorTicket(
  List<FeedbackTicket> tickets,
  ModerationCase moderationCase,
) {
  if (moderationCase.reportIds.isEmpty) return null;
  final reportIds = moderationCase.reportIds.toSet();
  for (final ticket in tickets) {
    final reportId = ticket.ugcReportId;
    if (reportId != null && reportIds.contains(reportId)) return ticket;
  }
  return null;
}
