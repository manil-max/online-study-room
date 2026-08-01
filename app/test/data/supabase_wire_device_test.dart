// Kablo testleri — cihaz/push/sayaç repository'leri.
//
// Şablon ve gerekçe: `supabase_wire_contract_test.dart` başlığı.
//
// Bu grup özellikle önemli: push kaydı ve global sayaç, sunucuya giden
// parametreleri en kalabalık olan iki yüzey. WP-373'te tam bu yüzeyde
// Dart ucu ile SQL ucu sessizce ayrışmıştı.

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/push_notification.dart';
import 'package:online_study_room/data/repositories/chat_repository.dart';
import 'package:online_study_room/data/repositories/push_registration_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_chat_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_global_timer_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_push_registration_repository.dart';

import '../support/supabase_wire_harness.dart';

const _registration = PushDeviceRegistration(
  installationId: 'inst-1',
  fcmToken: 'tok-1',
  appChannel: 'beta',
  appVersion: '1.0.57',
  buildNumber: 5701,
  locale: 'tr',
  timeZone: 'Europe/Istanbul',
  nudgeEnabled: true,
  announcementEnabled: true,
  updateEnabled: true,
  quietHoursEnabled: false,
  quietStartMinutes: 0,
  quietEndMinutes: 0,
);

void main() {
  late SupabaseWireHarness wire;
  setUp(() => wire = SupabaseWireHarness());

  group('SupabasePushRegistrationRepository', () {
    test('cihaz kaydi register_push_device RPC adiyla ve tam parametreyle gider',
        () async {
      wire.respond('register_push_device', [
        {'device_id': 'dev-1'}
      ]);
      final repo = SupabasePushRegistrationRepository(wire.client());

      final id = await repo.registerDevice(_registration);

      final call = wire.rpc('register_push_device');
      expect(id, 'dev-1');
      // Sunucu imzasindaki 12 parametrenin hepsi zorunlu (default'suz);
      // biri eksik giderse PostgREST cagriyi hic eslestirmez.
      expect(call.json['p_installation_id'], 'inst-1');
      expect(call.json['p_fcm_token'], 'tok-1');
      expect(call.json['p_app_channel'], 'beta');
      expect(call.json['p_build_number'], 5701);
      expect(call.json['p_time_zone'], 'Europe/Istanbul');
      expect(call.json['p_quiet_hours_enabled'], false);
    });

    // 🔴 FCM token'i bir sir. Hata mesaji ust katmana tasinirsa log'a ve
    // muhtemelen Sentry'ye dusrer.
    test('sunucu hatasinda FCM token veya backend ayrintisi sizmaz', () async {
      wire.failWith('register_push_device',
          status: 400, message: 'duplicate key tok-1 at https://xyz.supabase.co');
      final repo = SupabasePushRegistrationRepository(wire.client());

      await expectLater(
        repo.registerDevice(_registration),
        throwsA(
          isA<PushRegistrationException>().having(
            (e) => e.toString(),
            'mesaj',
            allOf(isNot(contains('tok-1')), isNot(contains('supabase.co'))),
          ),
        ),
      );
    });

    test('cooldown hatasi ayri koda cevrilir (genel hataya dusmez)', () async {
      wire.failWith('request_push_self_test',
          status: 400, message: 'push_test_cooldown');
      final repo = SupabasePushRegistrationRepository(wire.client());

      await expectLater(
        repo.requestSelfTest('dev-1'),
        throwsA(
          isA<PushRegistrationException>()
              .having((e) => e.code, 'code', 'push_test_cooldown'),
        ),
      );
    });

    test('kayitli olmayan cihaz ayri koda cevrilir', () async {
      wire.failWith('request_push_self_test',
          status: 400, message: 'push_test_target_device_required');
      final repo = SupabasePushRegistrationRepository(wire.client());

      await expectLater(
        repo.requestSelfTest('dev-1'),
        throwsA(
          isA<PushRegistrationException>()
              .having((e) => e.code, 'code', 'device_not_registered'),
        ),
      );
    });

    test('kayit silme installation id ile gider', () async {
      wire.respond('unregister_push_device', null);
      final repo = SupabasePushRegistrationRepository(wire.client());

      await repo.unregisterDevice('inst-1');

      expect(wire.rpc('unregister_push_device').json['p_installation_id'],
          'inst-1');
    });
  });

  group('SupabaseGlobalTimerRepository', () {
    test('snapshot get_global_timer_v2_snapshot RPC adiyla cekilir', () async {
      wire.respond('get_global_timer_v2_snapshot', {
        'user_id': 'u1',
        'state_version': 3,
        'server_time': '2026-08-01T10:00:00Z',
        'run': null,
        'result_code': 'ok',
      });
      final repo = SupabaseGlobalTimerRepository(wire.client());

      final snapshot = await repo.fetchSnapshot(deviceId: 'dev-1');

      expect(wire.rpc('get_global_timer_v2_snapshot').json['p_device_id'],
          'dev-1');
      expect(snapshot.stateVersion, 3);
      expect(snapshot.resultCode, 'ok');
    });

    // 🔴 `p_protocol_version` sabit 2. Sunucu bu alani surum ayrimi icin
    // kullaniyor; dusmesi eski protokol yoluna sessizce geri donmek demek.
    test('komut protocol_version 2 ile ve tam parametreyle gider', () async {
      wire.respond('apply_global_timer_command', {
        'user_id': 'u1',
        'state_version': 4,
        'server_time': '2026-08-01T10:00:00Z',
        'run': null,
      });
      final repo = SupabaseGlobalTimerRepository(wire.client());

      await repo.applyCommand(
        commandId: 'cmd-1',
        deviceId: 'dev-1',
        action: 'start',
        runId: 'run-1',
        expectedRunRevision: 7,
        clientOccurredAt: DateTime.utc(2026, 8, 1, 9),
      );

      final json = wire.rpc('apply_global_timer_command').json;
      expect(json['p_command_id'], 'cmd-1');
      expect(json['p_action'], 'start');
      expect(json['p_expected_run_revision'], 7);
      expect(json['p_protocol_version'], 2);
      // UTC ISO-8601 gonderilmeli; yerel saat gonderilirse sunucu gun
      // sinirini yanlis hesaplar (Europe/Istanbul kurali).
      expect(json['p_client_occurred_at'], '2026-08-01T09:00:00.000Z');
    });

    test('ack durum ve surum bilgisini birlikte tasir', () async {
      wire.respond('ack_global_timer_v2_snapshot', {
        'user_id': 'u1',
        'state_version': 5,
        'server_time': '2026-08-01T10:00:00Z',
        'run': null,
      });
      final repo = SupabaseGlobalTimerRepository(wire.client());

      await repo.acknowledge(
        deviceId: 'dev-1',
        stateVersion: 5,
        status: 'applied',
        runId: 'run-1',
        runRevision: 2,
      );

      final json = wire.rpc('ack_global_timer_v2_snapshot').json;
      expect(json['p_state_version'], 5);
      expect(json['p_status'], 'applied');
      expect(json['p_run_revision'], 2);
    });
  });

  group('SupabaseChatRepository', () {
    final sender = Profile(
      id: 'u1',
      displayName: 'Ada',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    test('mesaj class_messages tablosuna govde ile yazilir', () async {
      wire.respond('class_messages', const []);
      final repo = SupabaseChatRepository(wire.client());

      await repo.sendMessage(groupId: 'g1', sender: sender, text: '  selam  ');

      final call = wire.last;
      expect(call.table, 'class_messages');
      expect(call.method, 'POST');
      expect(call.json['group_id'], 'g1');
      expect(call.json['user_id'], 'u1');
      // Normalizasyon kabloya gitmeden once uygulanmali.
      expect(call.json['body'], 'selam');
    });

    test('sunucu hatasi ChatException olur', () async {
      wire.failWith('class_messages', status: 403, message: 'not a member');
      final repo = SupabaseChatRepository(wire.client());

      await expectLater(
        repo.sendMessage(groupId: 'g1', sender: sender, text: 'selam'),
        throwsA(isA<ChatException>()),
      );
    });
  });
}
