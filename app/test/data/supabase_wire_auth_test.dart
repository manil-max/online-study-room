// Supabase auth repository'sinin profil yazmalarını gerçek PostgREST sorgu
// üreticisi üzerinden doğrulayan dar kablo testleri.

import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';

import '../support/supabase_wire_harness.dart';

const _userId = 'user-1';

Map<String, dynamic> _authResponse() => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': _userId,
    'email': 'ali@example.com',
    'aud': 'authenticated',
    'created_at': '2026-08-01T10:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': {'display_name': 'Ali'},
  },
};

Future<SupabaseAuthRepository> _signedInRepository(
  SupabaseWireHarness wire,
) async {
  wire.respond('token', _authResponse());
  wire.respond('profiles', [
    {
      'id': _userId,
      'display_name': 'Ali',
      'avatar_url': null,
      'created_at': '2026-08-01T10:00:00Z',
      'title_achievement_id': null,
    },
  ]);
  final repository = SupabaseAuthRepository(wire.client());
  await repository.signIn(email: 'ali@example.com', password: 'guvenli123');
  wire.calls.clear();
  return repository;
}

void main() {
  late SupabaseWireHarness wire;
  late SupabaseAuthRepository repository;

  setUp(() async {
    wire = SupabaseWireHarness();
    repository = await _signedInRepository(wire);
  });

  group('SupabaseAuthRepository.updateTitle', () {
    test(
      'kazanılmış ünvan profiles satırına yazılır ve currentUser güncellenir',
      () async {
        await repository.updateTitle('marathon_total');

        final call = wire.last;
        expect(call.method, 'PATCH');
        expect(call.table, 'profiles');
        expect(call.json, {'title_achievement_id': 'marathon_total'});
        expect(call.url.queryParameters['id'], 'eq.$_userId');
        expect(repository.currentUser?.titleAchievementId, 'marathon_total');
      },
    );

    test('null ünvanı kaldırır ve currentUser alanını temizler', () async {
      await repository.updateTitle('marathon_total');
      wire.calls.clear();

      await repository.updateTitle(null);

      final call = wire.last;
      expect(call.method, 'PATCH');
      expect(call.table, 'profiles');
      expect(call.json, {'title_achievement_id': null});
      expect(call.url.queryParameters['id'], 'eq.$_userId');
      expect(repository.currentUser?.titleAchievementId, isNull);
    });

    test(
      'title_not_earned AuthException olur ve currentUser değişmez',
      () async {
        await repository.updateTitle('marathon_total');
        wire.calls.clear();
        wire.failWith('profiles', status: 400, message: 'title_not_earned');

        await expectLater(
          repository.updateTitle('unearned_title'),
          throwsA(
            isA<AuthException>().having(
              (error) => error.message,
              'message',
              'title_not_earned',
            ),
          ),
        );

        expect(wire.last.json, {'title_achievement_id': 'unearned_title'});
        expect(repository.currentUser?.titleAchievementId, 'marathon_total');
      },
    );
  });
}
