import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';

void main() {
  test('normal kullanıcı kendi raporunu oluşturup takip eder', () async {
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);

    final ticket = await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.feedback,
      subject: '  Widget fikri  ',
      message: '  Ana ekran widgetı daha canlı olabilir.  ',
    );

    expect(ticket.subject, 'Widget fikri');
    expect(ticket.message, 'Ana ekran widgetı daha canlı olabilir.');
    expect(ticket.status, FeedbackTicketStatus.open);

    final ownTickets = await repo.fetchMyFeedbackTickets('u1');
    expect(ownTickets, hasLength(1));
    expect(ownTickets.single.id, ticket.id);
  });

  test(
    'normal kullanıcı admin listesini ve durum güncellemesini kullanamaz',
    () async {
      final repo = InMemoryAdminRepository();
      addTearDown(repo.dispose);

      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Bildirim',
        message: 'Durdur aksiyonu çalışmıyor.',
      );

      expect(
        () => repo.fetchFeedbackTickets('u1'),
        throwsA(isA<AdminException>()),
      );
      expect(
        () => repo.updateFeedbackStatus(
          userId: 'u1',
          ticketId: ticket.id,
          status: FeedbackTicketStatus.closed,
        ),
        throwsA(isA<AdminException>()),
      );
    },
  );

  test(
    'süper-admin özet, rapor listesi ve durum güncellemesine erişir',
    () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);

      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Sayaç',
        message: 'Sayaç arka planda durmuyor.',
      );

      final summary = await repo.fetchDashboardSummary('admin');
      expect(summary.openTicketCount, 1);

      await repo.updateFeedbackStatus(
        userId: 'admin',
        ticketId: ticket.id,
        status: FeedbackTicketStatus.inProgress,
      );

      final openTickets = await repo.fetchFeedbackTickets(
        'admin',
        status: FeedbackTicketStatus.open,
      );
      final allTickets = await repo.fetchFeedbackTickets('admin');
      expect(openTickets, isEmpty);
      expect(allTickets.single.status, FeedbackTicketStatus.inProgress);
    },
  );

  test('boş ve çok uzun geri bildirim reddedilir', () async {
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);

    expect(
      () => repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: '',
        message: 'Mesaj var.',
      ),
      throwsA(isA<AdminException>()),
    );

    expect(
      () => repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'Konu',
        message: 'x' * (kMaxFeedbackMessageLength + 1),
      ),
      throwsA(isA<AdminException>()),
    );
  });
}
