import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';

/// §2E — Her kart tüm en-boy oranlarında taşma/clipping olmadan çizilmeli.
/// Kartları çok küçük, orta ve büyük bounded kutularda gerçek veriyle render eder
/// ve hiçbir RenderFlex/overflow istisnası atılmadığını doğrular.
void main() {
  final now = DateTime.now();

  // Birçok gün + saat + derse yayılmış örnek oturumlar (grafiklerin dolu çizmesi
  // için). Boş veri çoğu kartı "kayıt yok" kısa yoluna sokar; dolu veri gerçek
  // yerleşimi zorlar.
  final sessions = <StudySession>[
    for (var d = 0; d < 40; d++)
      StudySession(
        id: 's$d',
        userId: 'u1',
        start: DateTime(
          now.year,
          now.month,
          now.day,
          8 + (d % 12),
        ).subtract(Duration(days: d)),
        end: DateTime(
          now.year,
          now.month,
          now.day,
          9 + (d % 12),
        ).subtract(Duration(days: d)),
        durationSeconds: 1800 + (d % 5) * 900,
        source: StudySource.live,
        subjectId: d.isEven ? 'sub1' : (d % 3 == 0 ? 'sub2' : null),
      ),
  ];

  const subjects = <Subject>[
    Subject(id: 'sub1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
    Subject(id: 'sub2', userId: 'u1', name: 'Fizik', color: 'chart-3'),
  ];

  final overrides = [
    userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
    userSubjectsProvider.overrideWith((ref) => Stream.value(subjects)),
    dailyGoalMinutesProvider.overrideWithValue(240),
    // Grup kartları deterministik olarak "grup yok" (GroupCardShell) yoluna gitsin.
    userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
  ];

  // (etiket, genişlik, yükseklik) — 1x1 minik hücreden geniş+uzun karta kadar.
  // 'kisa' = telefonda tam genişlik ama h=1 (cell≈48) hücresi: sabit başlıklı
  // kartların (bugün/sıralama/aktif üyeler) taşmadığını doğrular (§2E regresyon).
  const sizes = <(String, double, double)>[
    ('minik', 150, 90),
    ('kisa', 328, 48),
    ('orta', 320, 200),
    ('genis', 700, 520),
  ];

  for (final type in DashboardCardType.values) {
    // Sayaç kartı (2H) kendi periyodik timer'ıyla gelir; render testi askıda
    // kalmasın diye dışarıda tutulur (boyut davranışı 2H'de kapsanır).
    if (type == DashboardCardType.timer) continue;

    for (final (label, w, h) in sizes) {
      testWidgets('${type.name} kartı $label boyutta taşmaz', (tester) async {
        final details = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = details.add;
        addTearDown(() => FlutterError.onError = prev);

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    child: dashboardCardFor(
                      type,
                      DashboardCardSize.medium,
                      height: h,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Stream sağlayıcılarının veriyi yayması için bir kare ilerlet.
        await tester.pump();

        FlutterError.onError = prev;

        expect(
          details.map((d) => d.exceptionAsString()),
          isEmpty,
          reason: '${type.name} @ $label ($w x $h) taşma/istisna üretti',
        );
      });
    }
  }

  testWidgets('grup boş durum kartları hızlı eylemleri gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: dashboardCardFor(
                  DashboardCardType.groupGoal,
                  DashboardCardSize.medium,
                  height: 180,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Grup oluştur'), findsOneWidget);
    expect(find.text('Koda katıl'), findsOneWidget);
  });

  // Grup kartları: yukarıdaki test grubu grubu `null` yaptığı için grup kartları
  // "grup yok" (GroupCardShell) yoluna gider ve GERÇEK içerikleri hiç çizilmez.
  // Burada gerçek grup + üye + presence + günlük istatistikle çizip her boyutta
  // (özellikle 'kisa' h=1 hücresinde) taşma olmadığını doğruluyoruz.
  final group = StudyGroup(
    id: 'g1',
    name: 'Sınav Grubu',
    inviteCode: 'ABC123',
    createdBy: 'u1',
    createdAt: DateTime(2024, 1, 1),
    dailyGoalMinutes: 360,
  );

  final members = <Profile>[
    for (var i = 0; i < 8; i++)
      Profile(
        id: 'u$i',
        displayName: 'Üye $i',
        createdAt: DateTime(2024, 1, 1),
        // Bir üye "eski grup üyesi" (ayrılmış) yolunu tetiklesin.
        isActive: i != 7,
      ),
  ];

  final presence = <Presence>[
    for (var i = 0; i < 5; i++)
      Presence(
        userId: 'u$i',
        groupId: 'g1',
        status: PresenceStatus.studying,
        todaySeconds: 3600 + i * 600,
        startedAt: now.subtract(Duration(minutes: 10 + i * 7)),
      ),
  ];

  final groupStats = <DailyStat>[
    for (var d = 0; d < 20; d++)
      for (var u = 0; u < 6; u++)
        DailyStat(
          userId: 'u$u',
          day: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: d)),
          seconds: 1800 + ((d + u) % 5) * 900,
        ),
  ];

  final me = Profile(
    id: 'u1',
    displayName: 'Ben',
    createdAt: DateTime(2024, 1, 1),
  );

  final groupOverrides = [
    userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
    userSubjectsProvider.overrideWith((ref) => Stream.value(subjects)),
    dailyGoalMinutesProvider.overrideWithValue(240),
    userGroupProvider.overrideWithValue(AsyncData<StudyGroup?>(group)),
    groupMembersProvider.overrideWith((ref) => Stream.value(members)),
    groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
    groupDailyStatsProvider.overrideWith((ref) => Stream.value(groupStats)),
    authStateProvider.overrideWith((ref) => Stream.value(me)),
  ];

  const groupCardTypes = <DashboardCardType>[
    DashboardCardType.leaderboard,
    DashboardCardType.groupGoal,
    DashboardCardType.groupTrend,
    DashboardCardType.activeMembers,
  ];

  for (final type in groupCardTypes) {
    for (final (label, w, h) in sizes) {
      testWidgets('${type.name} kartı (grup dolu) $label boyutta taşmaz', (
        tester,
      ) async {
        final details = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = details.add;
        addTearDown(() => FlutterError.onError = prev);

        await tester.pumpWidget(
          ProviderScope(
            overrides: groupOverrides,
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    child: dashboardCardFor(
                      type,
                      DashboardCardSize.medium,
                      height: h,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        FlutterError.onError = prev;

        expect(
          details.map((d) => d.exceptionAsString()),
          isEmpty,
          reason:
              '${type.name} (grup dolu) @ $label ($w x $h) taşma/istisna üretti',
        );
      });
    }
  }
}
