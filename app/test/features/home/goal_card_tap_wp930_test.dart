// WP-930 — hedef kartına dokununca hedef düzenleme penceresi açılır.
//
// 🔴 Kusur: "Günlük hedef" kartı tamamen bilgilendiriciydi; dokununca hiçbir
// şey olmuyordu. Hedefi değiştirmenin tek yolu sayaç kartının (telefonda hiç
// görünmeyen) hedef çubuğuydu. Kart artık AYNI düzenleme akışını açar
// (`editDailyGoalFlow`: aynı pencere, aynı kayıt, aynı onay/hata şeridi).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/home/widgets/goal_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

class _RecordingAuthRepository extends InMemoryAuthRepository {
  final saved = <int>[];

  @override
  Future<void> updateDailyGoal(int minutes) async => saved.add(minutes);
}

Future<_RecordingAuthRepository> _pump(WidgetTester tester) async {
  final repo = _RecordingAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream<Profile?>.value(null)),
        dailyGoalMinutesProvider.overrideWithValue(120),
        userSessionsProvider.overrideWith(
          (ref) => Stream.value(const <StudySession>[]),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(width: 360, height: 320, child: GoalCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return repo;
}

void main() {
  late AppLocalizations tr;

  setUpAll(() async {
    tr = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() => setActiveAppLocale(const Locale('tr')));

  testWidgets('karta dokununca hedef penceresi acilir ve kayit yazilir', (
    tester,
  ) async {
    final repo = await _pump(tester);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byType(GoalCard));
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'Hedef kartina dokunmak hicbir sey yapmiyor.',
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(tr.profileGunlukHedef),
      ),
      findsWidgets,
    );

    await tester.tap(find.text(tr.profileKaydet));
    await tester.pumpAndSettle();
    expect(repo.saved, [120], reason: 'Kayit mevcut akisla yazilmali.');
    expect(
      find.text(tr.profileGunlukHedefGuncellendi),
      findsOneWidget,
      reason: 'Sayac kartindaki akisla ayni onay seridi.',
    );
  });

  testWidgets('vazgecince hicbir sey yazilmaz', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byType(GoalCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.profileVazgec));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.saved, isEmpty);
  });
}
