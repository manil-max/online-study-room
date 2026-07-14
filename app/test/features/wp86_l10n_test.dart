import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/stats/widgets/stats_period_bar.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('tr')]) {
    for (final width in const [360.0, 600.0, 1200.0]) {
      testWidgets(
        'WP-86 ${locale.languageCode} ${width.toInt()}px overflow olmadan render',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final errors = <FlutterErrorDetails>[];
          final previousHandler = FlutterError.onError;
          FlutterError.onError = errors.add;
          addTearDown(() => FlutterError.onError = previousHandler);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                userGroupProvider.overrideWithValue(
                  const AsyncData<StudyGroup?>(null),
                ),
              ],
              child: MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text(DashboardCardType.today.title(context)),
                        const StatsPeriodBar(),
                        const Expanded(child: ClassroomScreen()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          if (locale.languageCode == 'tr') {
            expect(find.text('Bugün özeti'), findsOneWidget);
            expect(find.text('Henüz bir grupta değilsin'), findsOneWidget);
            expect(find.text('Kişisel'), findsNothing);
            expect(find.text('Bugün'), findsOneWidget);
          } else {
            expect(find.text("Today's summary"), findsOneWidget);
            expect(find.text("You're not in a group yet"), findsOneWidget);
            expect(find.text('Today'), findsOneWidget);
          }
          expect(
            errors.where(
              (error) => error.exceptionAsString().contains('overflowed'),
            ),
            isEmpty,
          );
        },
      );
    }
  }
}
