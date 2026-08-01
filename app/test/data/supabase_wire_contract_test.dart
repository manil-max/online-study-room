// Supabase repository'lerinin **kablo davranışı** — gerçek PostgREST üreticisi.
//
// 🔴 Bu dosyanın varlık sebebi: 22 `Supabase*Repository` sınıfının hiçbiri
// hiçbir testte örneklenmiyordu. Kapsam %0'dı ve sahaya giden kod hiç
// çalıştırılmıyordu. `get_user_study_summary` bu yüzden WP-152'den beri
// tanımsız bir RPC'yi çağırabildi ve hiçbir kapı görmedi.
//
// `scripts/backend_contract_audit.py` statik olarak "bu RPC var mı, bu
// parametre imzaya uyuyor mu" sorusunu yanıtlar. Buradaki testler **çalışma
// zamanını** kapsar: doğru ad kabloya gidiyor mu, yanıt doğru ayrıştırılıyor
// mu, sunucu hata dönerse repository onu doğru istisnaya çeviriyor mu.
// İkisi birlikte seam'i kapatır; tek başına ikisi de yetmez.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/repositories/data_export_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_data_export_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_goal_streak_repository.dart';

import '../support/supabase_wire_harness.dart';

void main() {
  group('SupabaseGoalStreakRepository — kablo', () {
    late SupabaseWireHarness wire;

    setUp(() => wire = SupabaseWireHarness());

    test('readProjection kabloya goal_streak_projection RPC adini gonderir',
        () async {
      wire.respond('goal_streak_projection', const []);
      final repo = SupabaseGoalStreakRepository(wire.client());

      await repo.readProjection(
        const GoalStreakScope.personal('u1'),
        asOfDay: DateTime.utc(2026, 8, 1),
      );

      // Ad yanlis yazilirsa (`get_` oneki gibi) bu satir duser.
      final call = wire.rpc('goal_streak_projection');
      expect(call.method, 'POST');
      expect(call.json.keys, isNotEmpty,
          reason: 'RPC parametresiz gonderilmemeli');
    });

    test('sunucu bos liste dondurunce kanonik bos projeksiyon uretilir',
        () async {
      wire.respond('goal_streak_projection', const []);
      final repo = SupabaseGoalStreakRepository(wire.client());

      final result = await repo.readProjection(
        const GoalStreakScope.personal('u1'),
        asOfDay: DateTime.utc(2026, 8, 1),
      );

      expect(result.currentStreak, 0);
      expect(result.completionCount, 0);
      expect(result.lastCompletedDay, isNull);
    });

    test('last_completed_day null ise sunucu sayi dondurse bile seri bos',
        () async {
      // Sunucu sozlesmesi: hic tamamlama yoksa olcek alanlari anlamsizdir.
      // Istemci bu durumda ekranda seri gostermemeli.
      wire.respond('goal_streak_projection', [
        {
          'current_streak': 7,
          'completion_count': 9,
          'last_completed_day': null,
        }
      ]);
      final repo = SupabaseGoalStreakRepository(wire.client());

      final result = await repo.readProjection(
        const GoalStreakScope.personal('u1'),
        asOfDay: DateTime.utc(2026, 8, 1),
      );

      expect(result.currentStreak, 0);
    });

    test('sunucu hata dondurunce istisna yutulmaz', () async {
      wire.failWith(
        'goal_streak_projection',
        status: 404,
        message: 'Could not find the function',
        code: 'PGRST202',
      );
      final repo = SupabaseGoalStreakRepository(wire.client());

      // Sessiz `catch (_)` ile null'a dusulurse bu test duser — tam olarak
      // `get_user_study_summary`de olan buydu.
      await expectLater(
        repo.readProjection(
          const GoalStreakScope.personal('u1'),
          asOfDay: DateTime.utc(2026, 8, 1),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('SupabaseDataExportRepository — kablo', () {
    late SupabaseWireHarness wire;

    setUp(() => wire = SupabaseWireHarness());

    // 🔴 REGRESYON: repo `get_user_study_summary` cagiriyordu; boyle bir
    // fonksiyon hicbir migration'da yok. Cagri PGRST202 aliyor, `catch (_)`
    // yutuyor ve disa aktarim JSON'undaki `summary` HER ZAMAN null kaliyordu.
    test('ozet icin user_study_summary kullanilir ve disa aktarima yazilir',
        () async {
      wire.respond('profiles', {
        'id': 'u1',
        'display_name': 'Ada',
        'daily_goal_minutes': 60,
        'animal': 'fox',
        'monthly_report_opt_in': false,
        'created_at': '2026-01-01T00:00:00Z',
      });
      wire.respond('user_study_summary', {
        'lifetime_seconds': 3600,
        'year_seconds': 1800,
        'hot_window_seconds': 900,
      });

      final repo = SupabaseDataExportRepository(wire.client());
      final bundle = await repo.buildExport(
        userId: 'u1',
        range: DataExportRange.all,
      );

      final names = wire.calls.map((c) => c.rpcName).toList();
      expect(names, contains('user_study_summary'),
          reason: 'ozet RPC adi kabloya dogru gitmeli');
      expect(names, isNot(contains('get_user_study_summary')),
          reason: 'tanimsiz `get_` onekli ad bir daha kullanilmamali');

      final summary = bundle.payload['summary'] as Map?;
      expect(summary, isNotNull,
          reason: 'ozet artik null olmamali (WP-152 regresyonu)');
      expect(summary!['lifetime_seconds'], 3600);
    });

    test('disa aktarim e-posta ve token sizdirmaz', () async {
      wire.respond('profiles', {
        'id': 'u1',
        'display_name': 'Ada',
        'daily_goal_minutes': 60,
        'animal': 'fox',
        'monthly_report_opt_in': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      final repo = SupabaseDataExportRepository(wire.client());
      final bundle = await repo.buildExport(
        userId: 'u1',
        range: DataExportRange.all,
      );

      final serialized = bundle.payload.toString().toLowerCase();
      expect(serialized, isNot(contains('@')));
      expect(serialized, isNot(contains('token')));
    });
  });
}
