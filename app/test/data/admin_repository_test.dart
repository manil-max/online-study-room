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

  test('destek bileti türü sunucu satırından güvenle okunur', () {
    final ticket = FeedbackTicket.fromMap({
      'id': 'ticket-1',
      'user_id': 'user-1',
      'kind': 'feedback',
      'ticket_type': 'question',
      'subject': 'Soru',
      'message': 'Bir sorum var.',
      'status': 'open',
      'created_at': '2026-07-28T00:00:00.000Z',
      'updated_at': '2026-07-28T00:00:00.000Z',
    });

    expect(ticket.type, FeedbackTicketType.question);
    expect(ticket.toMap()['ticket_type'], 'question');
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

  test(
    'bilet yazışması iki yönlü, yetkili ve okunma bilgili çalışır',
    () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'Yazışma',
        message: 'İlk mesaj',
      );

      final userMessage = await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: '  Ek bilgi  ',
      );
      expect(userMessage.message, 'Ek bilgi');
      expect(userMessage.senderRole.dbValue, 'user');
      expect(
        (await repo.fetchMyFeedbackTickets('u1')).single.status,
        FeedbackTicketStatus.inProgress,
      );
      expect(
        () => repo.fetchTicketMessages(userId: 'outsider', ticketId: ticket.id),
        throwsA(isA<AdminException>()),
      );

      final adminMessage = await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'İnceliyoruz.',
      );
      expect(adminMessage.senderRole.dbValue, 'admin');
      // WP-435/0103: biletin ilk metni ayrı bir alanda saklanmaz, konuşmanın
      // **kanonik ilk mesajı**dır. Bu yüzden yazışma üç mesajdır: bilet gövdesi,
      // kullanıcının eki, adminin yanıtı.
      final thread = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(
        thread.map((message) => message.senderRole.dbValue),
        ['user', 'user', 'admin'],
      );
      expect(
        thread.first.message,
        'İlk mesaj',
        reason: 'bilet gövdesi konuşmanın ilk mesajı olarak görünmeli',
      );

      await repo.markTicketMessagesRead(userId: 'u1', ticketId: ticket.id);
      expect(
        (await repo.fetchTicketMessages(
          userId: 'u1',
          ticketId: ticket.id,
        )).last.readAt,
        isNotNull,
      );
      await repo.markTicketMessagesRead(userId: 'admin', ticketId: ticket.id);
      expect(
        (await repo.fetchTicketMessages(
          userId: 'admin',
          ticketId: ticket.id,
        )).first.readAt,
        isNotNull,
      );
    },
  );

  test(
    'admin archives a ticket without deleting it and can restore it',
    () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'Archive',
        message: 'Must not be deleted.',
      );
      await repo.setFeedbackArchived(
        userId: 'admin',
        ticketId: ticket.id,
        archived: true,
      );
      expect(await repo.fetchFeedbackTickets('admin'), isEmpty);
      expect(
        (await repo.fetchFeedbackTickets(
          'admin',
          includeArchived: true,
        )).single.archivedAt,
        isNotNull,
      );
      await repo.setFeedbackArchived(
        userId: 'admin',
        ticketId: ticket.id,
        archived: false,
      );
      expect((await repo.fetchFeedbackTickets('admin')).single.id, ticket.id);
    },
  );

  group('classifyFeedbackSubmitError (WP-168/177)', () {
    test('RLS / JWT → session_or_rls', () {
      expect(
        classifyFeedbackSubmitError(
          postgrestCode: '42501',
          message: 'new row violates row-level security policy',
        ),
        'session_or_rls',
      );
      expect(
        classifyFeedbackSubmitError(
          postgrestCode: 'PGRST301',
          message: 'JWT expired',
        ),
        'session_or_rls',
      );
      expect(
        classifyFeedbackSubmitError(
          message: 'permission denied for table feedback_tickets',
        ),
        'session_or_rls',
      );
    });

    test('tablo yok → schema_missing (dar kurallar WP-193)', () {
      expect(
        classifyFeedbackSubmitError(
          postgrestCode: '42P01',
          message: 'relation "feedback_tickets" does not exist',
        ),
        'schema_missing',
      );
      expect(
        classifyFeedbackSubmitError(
          postgrestCode: 'PGRST205',
          message: 'Could not find the table in the schema cache',
        ),
        'schema_missing',
      );
      expect(
        classifyFeedbackSubmitError(
          message: 'Could not find the table in the schema cache',
        ),
        'schema_missing',
      );
      // Geniş "relation+feedback" artık RLS'i schema sanmaz
      expect(
        classifyFeedbackSubmitError(
          message: 'permission denied for relation feedback_tickets',
        ),
        'session_or_rls',
      );
    });

    test('feedbackErrorDisplay ham kod ekler', () {
      final s = feedbackErrorDisplay(
        userMessage: 'Sunucu hazır değil',
        postgrestCode: 'PGRST205',
        rawMessage: 'Could not find the table',
      );
      expect(s, contains('Detay:'));
      expect(s, contains('PGRST205'));
      expect(s, contains('Could not find the table'));
    });

    test('feedbackUserMessageForCode net ve kDebug bağımsız', () {
      expect(
        feedbackUserMessageForCode('schema_missing'),
        contains('sunucusu henüz hazır değil'),
      );
      expect(feedbackUserMessageForCode('storage'), contains('Görsel'));
      expect(
        feedbackUserMessageForCode('support_ticket_rate_limited'),
        contains('çok fazla'),
      );
      expect(feedbackUserMessageForCode('session_or_rls'), contains('giriş'));
    });

    test('diğer hatalar null (jenerik UX)', () {
      expect(
        classifyFeedbackSubmitError(
          postgrestCode: '23514',
          message: 'check constraint',
        ),
        isNull,
      );
      expect(classifyFeedbackSubmitError(message: 'network timeout'), isNull);
    });

    test('AdminException code alanı korunur', () {
      const e = AdminException('test', code: 'session_required');
      expect(e.code, 'session_required');
      expect(e.message, 'test');
    });
  });
}
