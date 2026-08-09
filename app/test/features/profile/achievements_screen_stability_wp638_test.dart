import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/achievement_ledger.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/achievement_provider.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-638 — "başarımlar ekranındayken belli saniyede bir sayfa yineleniyor".
///
/// Kök neden: [gamificationProgressSyncProvider] `userSessionsProvider`'ı
/// `await ref.watch(...future)` ile izliyordu. O bir **realtime akış**:
/// cache→remote çift emit, realtime yeniden abonelik ve offline hub push
/// aynı içeriği yeni bir `List` olarak tekrar tekrar yayınlar. Her yayın
/// FutureProvider'ı yeniden kurar → `process_achievement_event` RPC'si
/// (**yazma**) yeniden koşar → ekran yeniden çizilir.
///
/// Bu dosya iki yönü birden kilitler:
///  1. Katalogda gezerken (aynı oturum içeriği yeniden yayınlanınca) senkron
///     TEKRAR koşmaz.
///  2. Gerçekten bir oturum tamamlanınca senkron HÂLÂ koşar — yoksa "hiç
///     koşturma" da testi geçer ve ödüller ölür.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late StreamController<List<StudySession>> sessions;
  late List<String> calls;
  late String userId;

  Future<void> settle([int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  StudySession session(String id, {int seconds = 1800}) {
    final start = DateTime.now().toUtc().subtract(const Duration(hours: 2));
    return StudySession(
      id: id,
      userId: userId,
      start: start,
      end: start.add(Duration(seconds: seconds)),
      durationSeconds: seconds,
      source: StudySource.live,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = InMemoryAuthRepository();
    await auth.signUp(
      email: 'wp638@ornek.com',
      password: '123456',
      displayName: 'WP638',
    );
    sessions = StreamController<List<StudySession>>.broadcast();
    calls = <String>[];

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        // Realtime akışın yerine elle sürdüğümüz bir kanal.
        userSessionsProvider.overrideWith((ref) => sessions.stream),
        processAchievementEventProvider.overrideWith((ref) {
          return ({
            required String eventType,
            Map<String, dynamic> payload = const {},
          }) async {
            calls.add(eventType);
            // xp/crownRank profilin başlangıç değerleriyle aynı: in-memory
            // projeksiyon yazma yapmasın, sayaç yalnız RPC'yi ölçsün.
            return const AchievementEventResult(
              eventType: 'session_completed',
              awarded: [],
              totalXp: 0,
              crownRank: 'bronze',
            );
          };
        }),
      ],
    );
    // Sira onemli (LIFO): once container dispose olsun, sonra kanal kapansin.
    // Ters sirada `close()` future'i acik Riverpod aboneligi yuzunden asla
    // cozulmez ve test 30 sn timeout'a duser.
    addTearDown(() async => sessions.close());
    addTearDown(container.dispose);

    final authSub = container.listen(
      authStateProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(authSub.close);
    for (var i = 0; i < 100 && !container.read(authStateProvider).hasValue; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    userId = container.read(authStateProvider).value!.id;

    // Riverpod 3 auto-dispose: dinleyicisiz StreamProvider'ın `.future`'ı
    // çözülmez, in-memory projeksiyon askıda kalır (WP-235 dersi).
    final profileSub = container.listen(
      gamificationProfileProvider(userId),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(profileSub.close);
  });

  test(
    'WP-638: katalogda gezerken aynı oturum listesi yeniden yayınlansa '
    'başarım senkronu TEKRAR koşmaz',
    () async {
      final syncSub = container.listen(
        gamificationProgressSyncProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(syncSub.close);

      sessions.add([session('s1')]);
      await settle();
      expect(
        calls.length,
        1,
        reason: 'ekran açılınca bir kez değerlendirme beklenir',
      );

      // Realtime yeniden abonelik / cache→remote çift emit / hub push:
      // içerik aynı, `List` kimliği yeni.
      for (var i = 0; i < 3; i++) {
        sessions.add([session('s1')]);
        await settle();
      }

      expect(
        calls.length,
        1,
        reason:
            'WP-638: aynı oturum içeriği yeniden yayınlandığında ekran '
            'sunucuya tekrar yazmamalı (sayfa kendini yenilemesin)',
      );
    },
  );

  test(
    'WP-638 ters iddia: oturum gerçekten tamamlanınca senkron HÂLÂ koşar '
    '(ödül akışı ölmez)',
    () async {
      final syncSub = container.listen(
        gamificationProgressSyncProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(syncSub.close);

      sessions.add([session('s1')]);
      await settle();
      expect(calls.length, 1);

      // Gürültü turu: hiçbir şey değişmedi.
      sessions.add([session('s1')]);
      await settle();
      expect(calls.length, 1);

      // Yeni oturum bitti → değerlendirme ŞART.
      sessions.add([session('s1'), session('s2')]);
      await settle();
      expect(
        calls.length,
        2,
        reason:
            'yeni oturum eklendiğinde process_achievement_event koşmalı; '
            'yoksa rozet/XP hiç gelmez',
      );
      expect(calls.last, 'session_completed');

      // Süre değişimi de (aynı oturum sayısı) yeni bir değerlendirme demektir.
      sessions.add([session('s1'), session('s2', seconds: 3600)]);
      await settle();
      expect(
        calls.length,
        3,
        reason: 'oturum sayısı aynı kalsa da toplam süre arttıysa yeniden '
            'değerlendirilmeli',
      );
    },
  );
}
