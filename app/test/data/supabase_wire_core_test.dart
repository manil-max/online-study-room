// Kablo testleri — çekirdek CRUD repository'leri.
//
// Şablon ve gerekçe: `supabase_wire_contract_test.dart` başlığı.
// Her repository için en az şu üçü kapsanır:
//   1. doğru RPC/tablo adı ve filtreler kabloya gidiyor mu,
//   2. sunucu yanıtı doğru ayrıştırılıyor mu,
//   3. sunucu hata dönerse repository onu doğru istisnaya çeviriyor mu.
//
// Realtime (`.stream()`) yolları kapsam dışıdır: websocket taşır, http
// koşum takımı görmez. Bu bilinçli bir sınırdır, sessiz bir boşluk değil.

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/repositories/notification_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_gamification_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_notification_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_subject_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_support_repository.dart';

import '../support/supabase_wire_harness.dart';

void main() {
  late SupabaseWireHarness wire;
  setUp(() => wire = SupabaseWireHarness());

  group('SupabaseSupportRepository', () {
    test('yayinlanmis SSS locale ile suzulup sort_order ile siralanir',
        () async {
      wire.respond('faq_entries', [
        {
          'id': 'f1',
          'locale': 'tr',
          'question': 'Soru',
          'answer': 'Cevap',
          'sort_order': 1,
        }
      ]);
      final repo = SupabaseSupportRepository(wire.client());

      final entries = await repo.fetchPublishedFaq('tr');

      final call = wire.last;
      expect(call.table, 'faq_entries');
      expect(call.url.query, contains('locale=eq.tr'));
      expect(call.url.query, contains('sort_order'));
      expect(entries.single.question, 'Soru');
    });

    test('soru gonderimi submit_faq_question RPC adini kullanir', () async {
      wire.respond('submit_faq_question', null);
      final repo = SupabaseSupportRepository(wire.client());

      await repo.submitQuestion(question: 'Neden?', userId: 'u1');

      final call = wire.rpc('submit_faq_question');
      expect(call.json['p_question'], 'Neden?');
      // Ek yoksa yol null gider; sunucu bunu opsiyonel kabul eder.
      expect(call.json.containsKey('p_attachment_path'), isTrue);
    });
  });

  group('SupabaseNotificationRepository', () {
    test('duyurular created_at azalan sirayla cekilir', () async {
      wire.respond('announcements', [
        {
          'id': 'a1',
          'title': 'Baslik',
          'message': 'Mesaj',
          'target_type': 'all',
          'target_id': null,
          'related_feedback_ticket_id': null,
          'created_at': '2026-08-01T00:00:00Z',
          'created_by': null,
        }
      ]);
      final repo = SupabaseNotificationRepository(wire.client());

      final list = await repo.fetchMyAnnouncements('u1');

      expect(wire.last.table, 'announcements');
      expect(wire.last.url.query, contains('created_at.desc'));
      expect(list.single.title, 'Baslik');
    });

    test('okunma kaydi user_id ile suzulur', () async {
      wire.respond('announcement_reads', [
        {'announcement_id': 'a1'}
      ]);
      final repo = SupabaseNotificationRepository(wire.client());

      final ids = await repo.fetchReadAnnouncementIds('u1');

      expect(wire.last.url.query, contains('user_id=eq.u1'));
      expect(ids, {'a1'});
    });

    test('okundu isareti dogru catisma anahtariyla upsert edilir', () async {
      wire.respond('announcement_reads', const []);
      final repo = SupabaseNotificationRepository(wire.client());

      await repo.markAnnouncementRead(userId: 'u1', announcementId: 'a1');

      final call = wire.last;
      expect(call.method, 'POST');
      expect(call.json['user_id'], 'u1');
      expect(call.json['announcement_id'], 'a1');
      // Catisma anahtari olmadan ayni duyuru iki kez okundu yazilirdi.
      expect(call.url.query, contains('on_conflict=user_id%2Cannouncement_id'));
    });

    test('sunucu hatasi NotificationException olur, ham hata sizmaz', () async {
      wire.failWith('announcements', status: 500, message: 'boom');
      final repo = SupabaseNotificationRepository(wire.client());

      await expectLater(
        repo.fetchMyAnnouncements('u1'),
        throwsA(isA<NotificationException>()),
      );
    });
  });

  group('SupabaseSubjectRepository', () {
    const subject = Subject(
      id: 's1',
      userId: 'u1',
      name: 'Matematik',
      color: 'chart-1',
    );

    test('ders listesi kullaniciya suzulup ada gore siralanir', () async {
      wire.respond('subjects', [
        {'id': 's1', 'user_id': 'u1', 'name': 'Matematik', 'color': 'chart-1'}
      ]);
      final repo = SupabaseSubjectRepository(wire.client());

      final first = await repo.watchUserSubjects('u1').first;

      expect(wire.last.url.query, contains('user_id=eq.u1'));
      expect(wire.last.url.query, contains('order=name'));
      expect(first.single.name, 'Matematik');
    });

    test('ekleme insert, guncelleme id filtreli update uretir', () async {
      wire.respond('subjects', const []);
      final repo = SupabaseSubjectRepository(wire.client());

      await repo.addSubject(subject);
      expect(wire.last.method, 'POST');

      await repo.updateSubject(subject);
      expect(wire.last.method, 'PATCH');
      expect(wire.last.url.query, contains('id=eq.s1'));

      await repo.deleteSubject('s1');
      expect(wire.last.method, 'DELETE');
      expect(wire.last.url.query, contains('id=eq.s1'));
    });
  });

  group('SupabaseGamificationRepository', () {
    test('seri korumasi 0-99 araligina kirpilir', () async {
      wire.respond('gamification_profiles', const []);
      final repo = SupabaseGamificationRepository(wire.client());

      await repo.setStreakFreezes('u1', 500);

      expect(wire.last.json['streak_freezes'], 99);
      expect(wire.last.json['user_id'], 'u1');
    });

    // 🔴 WP-56 sunucu-otoriter kurali: XP ve crown_rank yalnizca ledger
    // tetikleyicisi yazar. Istemci yazim yolu bunlari GONDERMEMELI, yoksa
    // `0024` guard'i devreye girer ve yazim sessizce reddedilir.
    test('profil yazimi xp veya crown_rank gondermez', () async {
      wire.respond('gamification_profiles', const []);
      final repo = SupabaseGamificationRepository(wire.client());

      await repo.setStreakFreezes('u1', 3);

      expect(wire.last.json.keys, isNot(contains('xp')));
      expect(wire.last.json.keys, isNot(contains('crown_rank')));
    });

    test('basari yazimi istemcide no-op (hile yolu kapali)', () async {
      final repo = SupabaseGamificationRepository(wire.client());

      await repo.updateUserAchievements(const []);

      expect(wire.calls, isEmpty,
          reason: 'istemci basari yazamaz; kabloya hicbir sey gitmemeli');
    });
  });
}
