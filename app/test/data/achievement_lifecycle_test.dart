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
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-105: oturum sonrası process_achievement_event yolu (profil UI olmadan).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runAchievementSessionCompletedSync process çağırır', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = InMemoryAuthRepository();
    await auth.signUp(
      email: 'xp-sync@ornek.com',
      password: '123456',
      displayName: 'XP Sync',
    );
    final study = InMemoryStudyRepository();
    final calls = <String>[];

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        studyRepositoryProvider.overrideWithValue(study),
        processAchievementEventProvider.overrideWith((ref) {
          return ({
            required String eventType,
            Map<String, dynamic> payload = const {},
          }) async {
            calls.add(eventType);
            return AchievementEventResult(
              eventType: eventType,
              awarded: const [],
              totalXp: 50,
              crownRank: 'bronze_beginner',
            );
          };
        }),
      ],
    );
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
    expect(container.read(authStateProvider).value, isNotNull);
    final user = container.read(authStateProvider).value!;

    // WP-235: gamificationProfileProvider bir StreamProvider; Riverpod 3
    // auto-dispose yüzünden dinleyici tutulmazsa `.future` asla çözülmez ve
    // runAchievementSessionCompletedSync içindeki projection sonsuza dek
    // asılı kalır (30 sn timeout). Gerçek app'te UI dinler; testte biz tutarız.
    final profileSub = container.listen(
      gamificationProfileProvider(user.id),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(profileSub.close);

    // Ref üzerinden sync — ProviderScope/container'da FutureProvider ile sarmala.
    final syncProvider = FutureProvider<AchievementEventResult?>((ref) {
      return runAchievementSessionCompletedSync(ref);
    });
    final result = await container.read(syncProvider.future);

    expect(calls, ['session_completed']);
    expect(result, isNotNull);
    expect(result!.totalXp, 50);
  });

  test('lifecycle oturum listesi değişince debounce sonrası process tetikler',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = InMemoryAuthRepository();
    await auth.signUp(
      email: 'xp-life@ornek.com',
      password: '123456',
      displayName: 'XP Life',
    );
    final study = InMemoryStudyRepository();
    final calls = <String>[];

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        studyRepositoryProvider.overrideWithValue(study),
        processAchievementEventProvider.overrideWith((ref) {
          return ({
            required String eventType,
            Map<String, dynamic> payload = const {},
          }) async {
            calls.add(eventType);
            return const AchievementEventResult(
              eventType: 'session_completed',
              awarded: [],
              totalXp: 10,
              crownRank: 'bronze_beginner',
            );
          };
        }),
      ],
    );
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
    final profile = container.read(authStateProvider).value!;

    // StreamProvider'ı aktif tut (lifecycle listen'inden önce/sonra).
    final sessionsSub = container.listen(
      userSessionsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sessionsSub.close);
    await container.read(userSessionsProvider.future);

    // WP-235: profil StreamProvider'ını da tut — yoksa lifecycle debounce
    // callback'i içindeki projection `.future`'da asılı kalıp teardown'da
    // "Cannot use Ref after dispose" atardı (Riverpod 3 auto-dispose).
    final profileSub = container.listen(
      gamificationProfileProvider(profile.id),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(profileSub.close);

    // Lifecycle provider'ı dispose olmasın diye listen.
    final lifeSub = container.listen(
      achievementProgressLifecycleProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(lifeSub.close);

    await Future<void>.delayed(const Duration(milliseconds: 1000));
    final baseline = calls.length;

    final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    await study.addSession(
      StudySession(
        id: 's-life-1',
        userId: profile.id,
        start: start,
        end: start.add(const Duration(hours: 1)),
        durationSeconds: 3600,
        source: StudySource.live,
      ),
    );

    // Stream emit + debounce 800ms.
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    expect(
      calls.length,
      greaterThan(baseline),
      reason: 'WP-105: oturum eklenince session_completed tetiklenmeli',
    );
    expect(calls.contains('session_completed'), isTrue);
  });
}
