// Kablo testleri — yönetici moderasyon yüzeyi ve başarı motoru.
//
// Şablon ve gerekçe: `supabase_wire_contract_test.dart` başlığı.
//
// Yönetici yüzeyinin invariant'ı: **yetki sunucudadır.** İstemcideki
// kapılar yalnız yöneticiye *nedenini* söyler; sunucu aynı kararı
// bağımsız olarak tekrar verir. Testler istemci kapısının sunucuya
// gereksiz/yetkisiz çağrı üretmediğini sabitler.

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/moderation_appeal.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/moderation_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_achievement_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_admin_repository.dart';

import '../support/supabase_wire_harness.dart';

ModerationAppeal _appeal({bool decidable = true}) => ModerationAppeal.fromWire({
      'id': 'ap1',
      'sanction_id': 's1',
      'statement': 'itiraz metni',
      'status': 'open',
      'created_at': '2026-08-01T10:00:00Z',
      'decidable': decidable,
    });

void main() {
  late SupabaseWireHarness wire;
  setUp(() => wire = SupabaseWireHarness());

  group('SupabaseAdminModerationRepository — itiraz karari', () {
    test('karar admin_decide_moderation_appeal RPC adiyla gider', () async {
      wire.respond('admin_decide_moderation_appeal', {
        'id': 'ap1',
        'sanction_id': 's1',
        'statement': 'itiraz metni',
        'status': 'overturned',
        'created_at': '2026-08-01T10:00:00Z',
      });
      final repo = SupabaseAdminModerationRepository(wire.client());

      await repo.decideAppeal(
        appeal: _appeal(),
        overturn: true,
        note: '  gerekce  ',
      );

      final json = wire.rpc('admin_decide_moderation_appeal').json;
      expect(json['p_appeal_id'], 'ap1');
      expect(json['p_outcome'], 'overturned');
      expect(json['p_note'], 'gerekce');
    });

    test('reddedilen itirazda sonuc `upheld` gider', () async {
      wire.respond('admin_decide_moderation_appeal', {
        'id': 'ap1',
        'sanction_id': 's1',
        'statement': 'itiraz metni',
        'status': 'upheld',
        'created_at': '2026-08-01T10:00:00Z',
      });
      final repo = SupabaseAdminModerationRepository(wire.client());

      await repo.decideAppeal(
        appeal: _appeal(),
        overturn: false,
        note: 'gerekce',
      );

      expect(wire.rpc('admin_decide_moderation_appeal').json['p_outcome'],
          'upheld');
    });

    test('gerekcesiz karar sunucuya hic gitmez', () async {
      final repo = SupabaseAdminModerationRepository(wire.client());

      await expectLater(
        repo.decideAppeal(appeal: _appeal(), overturn: true, note: '   '),
        throwsA(isA<ModerationException>()),
      );
      expect(wire.calls, isEmpty);
    });

    // 🔴 Kendi verdigi yaptirimin itirazini karara baglamak cikar catismasi.
    // Sunucu da reddeder ama istemci kapisi bos cagri uretmemeli.
    test('karar veremeyecegi itiraz icin sunucuya cagri gitmez', () async {
      final repo = SupabaseAdminModerationRepository(wire.client());

      await expectLater(
        repo.decideAppeal(
          appeal: _appeal(decidable: false),
          overturn: true,
          note: 'gerekce',
        ),
        throwsA(isA<ModerationException>()),
      );
      expect(wire.calls, isEmpty);
    });

    test('itiraz listesi admin_moderation_appeals RPC adiyla cekilir',
        () async {
      wire.respond('admin_moderation_appeals', const []);
      final repo = SupabaseAdminModerationRepository(wire.client());

      await repo.fetchAppeals();

      expect(wire.rpc('admin_moderation_appeals').json, isEmpty);
    });
  });

  group('SupabaseAdminRepository — yetki ve destek kutusu', () {
    // 🔴 Yetki sorgusu parametresiz: sunucu `auth.uid()` kullanir. `userId`
    // gonderilseydi istemci baskasinin yetkisini sorgulayabilirdi.
    test('yetki sorgusu kullanici kimligi gondermez', () async {
      wire.respond('is_super_admin', true);
      final repo = SupabaseAdminRepository(wire.client());

      final isAdmin = await repo.isSuperAdmin('u1');

      expect(wire.rpc('is_super_admin').json, isEmpty);
      expect(isAdmin, isTrue);
    });

    // Sunucu `true` disinda bir sey dondurdugunde (null, string, hata
    // govdesi) yetki VERILMEMELI — fail-closed.
    test('yetki sorgusu true disinda her sey icin false doner', () async {
      wire.respond('is_super_admin', null);
      final repo = SupabaseAdminRepository(wire.client());

      expect(await repo.isSuperAdmin('u1'), isFalse);
    });

    test('yetki hatasi AdminException olur, sessizce false donmez', () async {
      wire.failWith('is_super_admin', status: 500, message: 'boom');
      final repo = SupabaseAdminRepository(wire.client());

      await expectLater(
        repo.isSuperAdmin('u1'),
        throwsA(isA<AdminException>()),
      );
    });

    test('bilet durumu guncellemesi db degeriyle gider', () async {
      wire.respond('admin_update_feedback_status', null);
      final repo = SupabaseAdminRepository(wire.client());

      await repo.updateFeedbackStatus(
        userId: 'admin',
        ticketId: 't1',
        status: FeedbackTicketStatus.closed,
      );

      final json = wire.rpc('admin_update_feedback_status').json;
      expect(json['p_ticket_id'], 't1');
      expect(json['p_status'], FeedbackTicketStatus.closed.dbValue);
    });

    // 🔴 WP-438: istemci uretimi `p_client_message_id` idempotans anahtari.
    // Dusmesi, ag tekrar denemesinde ayni mesajin iki kez yazilmasi demek.
    test('bilet mesaji istemci idempotans anahtari tasir', () async {
      wire.respond('send_feedback_ticket_message', {
        'id': 'm1',
        'ticket_id': 't1',
        'sender_id': 'u1',
        'sender_role': 'user',
        'message': 'merhaba',
        'created_at': '2026-08-01T10:00:00Z',
        'message_seq': 1,
        'client_message_id': 'cm-1',
      });
      final repo = SupabaseAdminRepository(wire.client());

      await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: 't1',
        message: 'merhaba',
        clientMessageId: 'cm-1',
      );

      final json = wire.rpc('send_feedback_ticket_message').json;
      expect(json['p_ticket_id'], 't1');
      expect(json['p_client_message_id'], 'cm-1');
    });

    test('idempotans anahtari verilmezse istemci kendisi uretir', () async {
      wire.respond('send_feedback_ticket_message', {
        'id': 'm1',
        'ticket_id': 't1',
        'sender_id': 'u1',
        'sender_role': 'user',
        'message': 'merhaba',
        'created_at': '2026-08-01T10:00:00Z',
        'message_seq': 1,
      });
      final repo = SupabaseAdminRepository(wire.client());

      await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: 't1',
        message: 'merhaba',
      );

      final sent =
          wire.rpc('send_feedback_ticket_message').json['p_client_message_id'];
      expect(sent, isA<String>());
      expect((sent as String).isNotEmpty, isTrue);
    });

    test('okundu isareti yalniz bilet kimligi tasir', () async {
      wire.respond('mark_feedback_ticket_messages_read', null);
      final repo = SupabaseAdminRepository(wire.client());

      await repo.markTicketMessagesRead(userId: 'u1', ticketId: 't1');

      expect(wire.rpc('mark_feedback_ticket_messages_read').json,
          {'p_ticket_id': 't1'});
    });

    test('denetim kayitlari yeniden eskiye ve 100 ile sinirli cekilir',
        () async {
      wire.respond('admin_audit_logs', const []);
      final repo = SupabaseAdminRepository(wire.client());

      await repo.fetchAuditLogs();

      final call = wire.last;
      expect(call.table, 'admin_audit_logs');
      expect(call.url.query, contains('created_at.desc'));
      expect(call.url.query, contains('limit=100'));
    });
  });

  group('SupabaseAchievementRepository', () {
    // 🔴 WP-56 sunucu-otoriter: oturum metrikleri SUNUCUDA hesaplanir.
    // `sessions` istemciden gonderilseydi XP sisirmek mumkun olurdu.
    test('basari olayi oturum listesini kabloya koymaz', () async {
      wire.respond('process_achievement_event', {
        'event_type': 'session_finalized',
        'awarded': [],
        'total_xp': 120,
        'crown_rank': 'bronze_beginner',
      });
      final repo = SupabaseAchievementRepository(wire.client());

      await repo.processEvent(
        eventType: 'session_finalized',
        payload: const {'session_id': 's1'},
        dailyGoalMinutes: 360,
      );

      final json = wire.rpc('process_achievement_event').json;
      expect(json.keys.toSet(), {'p_event_type', 'p_payload'});
      expect(json.containsKey('p_sessions'), isFalse);
      expect(json.containsKey('p_daily_goal_minutes'), isFalse);
    });

    test('sunucu beklenmedik sekil dondurunce guvenli bos sonuc uretilir',
        () async {
      wire.respond('process_achievement_event', const []);
      final repo = SupabaseAchievementRepository(wire.client());

      final result = await repo.processEvent(eventType: 'noop');

      expect(result.awarded, isEmpty);
      expect(result.totalXp, 0);
    });
  });
}
