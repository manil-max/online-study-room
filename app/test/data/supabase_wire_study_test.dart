// Kablo testleri — doğrulanmış çalışma turu, görevler ve analitik.
//
// Şablon ve gerekçe: `supabase_wire_contract_test.dart` başlığı.
//
// Bu grubun invariant'ı: **süre sunucuda ölçülür.** İstemci ne süre ne de
// sahiplik gönderir; `auth.uid()` ve sunucu saati tek gerçektir. Aksi hâlde
// XP/istatistik istemciden şişirilebilirdi (KALITE-PROGRAMI §8.6).

import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_analytics_query_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_study_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_user_task_repository.dart';

import '../support/supabase_wire_harness.dart';

Map<String, dynamic> _runRow() => {
      'id': 'r1',
      'run_token': 'tok-1',
      'user_id': 'u1',
      'group_id_snapshot': null,
      'subject_id_snapshot': null,
      'status': 'running',
      'client_build': 5701,
      'started_at': '2026-08-01T09:00:00Z',
      'finalized_at': null,
      'session_id': null,
    };

void main() {
  late SupabaseWireHarness wire;
  setUp(() => wire = SupabaseWireHarness());

  group('SupabaseStudyRepository — dogrulanmis tur', () {
    // 🔴 `userId` yalniz cift-repository paritesi icin imzada. Sunucuya
    // GONDERILMEZ; sahip `auth.uid()`ten belirlenir. Gonderilseydi istemci
    // baskasi adina tur baslatabilirdi.
    test('tur baslatma sahiplik parametresi gondermez', () async {
      wire.respond('start_verified_live_run', _runRow());
      final repo = SupabaseStudyRepository(wire.client());

      await repo.startLiveRun(
        userId: 'u1',
        clientRequestId: 'req-1',
        clientBuild: 5701,
      );

      final json = wire.rpc('start_verified_live_run').json;
      expect(json['p_client_request_id'], 'req-1');
      expect(json['p_client_build'], 5701);
      expect(json.containsKey('p_user_id'), isFalse);
      expect(json.containsKey('p_owner'), isFalse);
    });

    // Idempotans anahtari: ag tekrar denerse sunucu ayni turu dondurur.
    test('istemci istek kimligi her baslatmada kabloya gider', () async {
      wire.respond('start_verified_live_run', _runRow());
      final repo = SupabaseStudyRepository(wire.client());

      await repo.startLiveRun(userId: 'u1', clientRequestId: 'req-42');

      expect(wire.rpc('start_verified_live_run').json['p_client_request_id'],
          'req-42');
    });

    test('duraklat/devam/bitir yalniz tur jetonu tasir (sure gondermez)',
        () async {
      wire.respond('pause_verified_live_run', _runRow());
      wire.respond('resume_verified_live_run', _runRow());
      final repo = SupabaseStudyRepository(wire.client());

      await repo.pauseLiveRun('tok-1');
      var json = wire.rpc('pause_verified_live_run').json;
      expect(json, {'p_run_token': 'tok-1'});

      await repo.resumeLiveRun('tok-1');
      json = wire.rpc('resume_verified_live_run').json;
      // 🔴 Sure istemciden gitmemeli; sunucu kendi saatiyle olcer.
      expect(json.keys, ['p_run_token']);
    });

    test('yapilandirma RPC parametresiz cagrilir', () async {
      wire.respond('verified_session_client_config', {'enabled': true});
      final repo = SupabaseStudyRepository(wire.client());

      await repo.fetchVerifiedSessionConfig();

      expect(wire.rpc('verified_session_client_config').json, isEmpty);
    });

    test('rollout telemetrisi opsiyonel alanlari null olarak tasir', () async {
      wire.respond('record_verified_session_rollout', null);
      final repo = SupabaseStudyRepository(wire.client());

      await repo.recordVerifiedSessionRollout(
        platform: 'android',
        clientBuild: 5701,
        capability: true,
      );

      final json = wire.rpc('record_verified_session_rollout').json;
      expect(json['p_platform'], 'android');
      expect(json['p_capability'], true);
      expect(json['p_origin'], isNull);
      expect(json['p_outcome'], isNull);
    });
  });

  group('SupabaseUserTaskRepository', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('gorev listesi list_user_tasks RPC adiyla, parametresiz cekilir',
        () async {
      wire.respond('list_user_tasks', const []);
      final repo = SupabaseUserTaskRepository(wire.client(), prefs);

      await repo.load(userKey: 'u1');

      expect(wire.rpc('list_user_tasks').json, isEmpty);
    });

    // 🔴 WP-449/450 regresyonu: istemci `p_interval_days` / `p_anchor_date`
    // gonderiyordu ama sunucuda o parametreler YOKTU; sahadaki her gorev
    // yazimi PGRST202 aliyordu. Artik iki uc de var; bu test kabloda
    // gerceklestigini sabitler.
    test('tekrar alanlari upsert_user_task cagrisinda kabloya gider', () async {
      wire.respond('upsert_user_task', {
        'id': 't1',
        'title': 'Calis',
        'recurrence': 'daily',
        'sort_order': 0,
        'is_completed': false,
        'archived': false,
        'interval_days': 3,
      });
      final repo = SupabaseUserTaskRepository(wire.client(), prefs);

      await repo.upsert(
        userKey: 'u1',
        task: UserTask(
          id: 't1',
          title: 'Calis',
          completed: false,
          createdAt: DateTime.utc(2026, 8, 1),
          sortOrder: 0,
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 3,
        ),
        operationId: 'op-1',
      );

      final json = wire.rpc('upsert_user_task').json;
      expect(json['p_task_id'], 't1');
      expect(json['p_recurrence'], 'daily');
      expect(json['p_interval_days'], 3);
      expect(json['p_client_operation_id'], 'op-1');
    });

    test('tamamlama isareti UTC zaman damgasi ve islem kimligi tasir',
        () async {
      wire.respond('set_user_task_completion', null);
      final repo = SupabaseUserTaskRepository(wire.client(), prefs);

      await repo.setCompleted(
        userKey: 'u1',
        taskId: 't1',
        completed: true,
        occurredAt: DateTime.utc(2026, 8, 1, 9),
        occurrenceDay: DateTime.utc(2026, 8, 1),
        operationId: 'op-2',
      );

      final json = wire.rpc('set_user_task_completion').json;
      expect(json['p_task_id'], 't1');
      expect(json['p_is_completed'], true);
      // Yerel saat gonderilirse sunucu Europe/Istanbul gun sinirini
      // yanlis hesaplar.
      expect(json['p_occurred_at'], '2026-08-01T09:00:00.000Z');
      expect(json['p_client_operation_id'], 'op-2');
    });
  });

  group('SupabaseAnalyticsQueryRepository', () {
    test('tarih araligi saatsiz gun olarak gonderilir', () async {
      wire.respond('get_user_day_totals', const []);
      final repo = SupabaseAnalyticsQueryRepository(wire.client());

      await repo.getUserDayTotals(
        userId: 'u1',
        from: DateTime.utc(2026, 7, 1, 6),
        to: DateTime.utc(2026, 7, 31, 6),
      );

      final json = wire.rpc('get_user_day_totals').json;
      // Sunucu `date` bekliyor; saat gonderilirse tip uyusmazligi olur.
      expect(json['p_from'], '2026-07-01');
      expect(json['p_to'], '2026-07-31');
    });

    // 🔴 Gun siniri her yerde **Europe/Istanbul** (AGENTS.md §2). UTC
    // 22:10 Istanbul'da ertesi gundur; `dayOf` bunu uygular. Bu satir
    // UTC'ye kayarsa gece calisan kullanicinin gunu yanlis kovaya duser.
    test('gun siniri Europe/Istanbul uygulanir, UTC degil', () async {
      wire.respond('get_user_day_totals', const []);
      final repo = SupabaseAnalyticsQueryRepository(wire.client());

      await repo.getUserDayTotals(
        userId: 'u1',
        from: DateTime.utc(2026, 7, 1, 6),
        // 22:10 UTC = 01:10 (ertesi gun) Istanbul.
        to: DateTime.utc(2026, 7, 31, 22, 10),
      );

      expect(wire.rpc('get_user_day_totals').json['p_to'], '2026-08-01');
    });
  });
}
