import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/clock/clock_screen.dart';
import 'package:online_study_room/features/clock/tasks_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('TasksScreen add via actions and show active', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryUserTaskRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const TasksScreen(embedded: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TasksScreen), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TasksScreen)),
    );
    await container.read(userTaskActionsProvider).add(
          rawTitle: 'Shop',
          dueAt: DateTime.now().add(const Duration(days: 1)),
        );
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsOneWidget);
  });

  test('ClockTab includes tasks', () {
    expect(ClockTab.values, contains(ClockTab.tasks));
  });
}
