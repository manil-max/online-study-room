// WP-596 (WP-593'ün üçüncü, açık kalan maddesi): İstatistik > Grup sekmesinin
// BOŞ dalı çıkmaz sokaktı.
//
// Ekran "Grup istatistiklerini görmek için önce bir gruba katıl." diyordu ve
// orada bitiyordu: katılmanın yolunu vermiyordu. Aynı ekranın HATA dalı
// WP-550'de çıkış kazanmıştı (`stats-group-error-retry`), boş dal unutulmuştu.
// Bu, bu turda dördüncü kez görülen desen: doğru cümle + hiçbir çıkış.
//
// 🔴 İki yönlü iddia zorunlu: düğme grup YOKKEN görünmeli, grup VARKEN hiç
// çizilmemeli. Tek yönlü ölçüm "düğmeyi koşulsuz çiz" sabotajını sessizce
// geçirirdi.
//
// 🔴 "Düğme var mı" ile yetinilmez (WP-560 dersi: dokununca hiçbir şey yapmayan
// düğme hatanın kendisinden kötüdür). Burada gerçekten dokunulur ve gidilen
// ekranın `GroupDiscoveryScreen` olduğu doğrulanır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/group_discovery_screen.dart';
import 'package:online_study_room/features/stats/stats_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Key _kJoinButton = Key('stats-group-empty-join');

final _group = StudyGroup(
  id: 'g-1',
  name: 'Test Grubu',
  inviteCode: 'ABC123',
  createdBy: 'me-1',
  createdAt: DateTime.utc(2026, 1, 1),
);

Future<void> _pumpStatsGroupTab(
  WidgetTester tester, {
  required List<StudyGroup> groups,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Türetilmiş `userGroupProvider` değil KAYNAK override edilir: türetme
        // mantığı (WP-589'da hatayı düşürdüğü bulunan yer) de ölçüme girsin.
        userGroupsProvider.overrideWith((_) => Stream.value(groups)),
        userSessionsProvider.overrideWith(
          (_) => Stream.value(const <StudySession>[]),
        ),
        userSubjectsProvider.overrideWith(
          (_) => Stream.value(const <Subject>[]),
        ),
        groupDailyStatsProvider.overrideWith(
          (_) => Stream.value(const <DailyStat>[]),
        ),
        groupMembersProvider.overrideWith(
          (_) => Stream.value(const <Profile>[]),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StatsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Grup sekmesine geç (varsayılan sekme Kişisel).
  final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  await tester.tap(find.text(l10n.statsGrup));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('grup YOKKEN "Bir gruba katıl" çıkışı görünür', (tester) async {
    await _pumpStatsGroupTab(tester, groups: const <StudyGroup>[]);

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.statsGrupIstatistikleriniGormekIcin), findsOneWidget);
    expect(
      find.byKey(_kJoinButton),
      findsOneWidget,
      reason:
          'Boş dal yine çıkmaz sokak: doğru talimatı veriyor ama uygulamanın '
          'içinden o talimatı yerine getirmenin yolu yok.',
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('düğme ÖLÜ DEĞİL: dokununca grup keşif ekranı açılır', (
    tester,
  ) async {
    await _pumpStatsGroupTab(tester, groups: const <StudyGroup>[]);

    expect(find.byType(GroupDiscoveryScreen), findsNothing);

    await tester.tap(find.byKey(_kJoinButton));
    await tester.pumpAndSettle();

    expect(
      find.byType(GroupDiscoveryScreen),
      findsOneWidget,
      reason:
          'Düğme var ama hiçbir yere götürmüyor -- hatanın kendisinden kötüsü '
          '(WP-560 dersi).',
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('grup VARKEN düğme HİÇ çizilmez (tek yönlü iddia kapanı)', (
    tester,
  ) async {
    await _pumpStatsGroupTab(tester, groups: <StudyGroup>[_group]);

    expect(
      find.byKey(_kJoinButton),
      findsNothing,
      reason:
          'Bu olmadan "düğmeyi koşulsuz çiz" sabotajı testi geçerdi ve grubu '
          'olan kullanıcıya "bir gruba katıl" denirdi.',
    );

    await tester.pumpWidget(const SizedBox());
  });
}
