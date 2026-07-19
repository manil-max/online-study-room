import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/widgets/tasks_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('TasksCard empty + toggle (no add UI)', (tester) async {
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
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              height: 420,
              child: TasksCard(size: DashboardCardSize.large),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    // Home kartında ekleme yok
    expect(find.byIcon(Icons.add), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TasksCard)),
    );
    await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle: 'Read',
          dueAt: DateTime.now().add(const Duration(hours: 2)),
        );
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsOneWidget);
    await container
        .read(userTaskActionsProvider)
        .toggle((await container.read(userTasksProvider.future)).first.id);
    await tester.pumpAndSettle();
    // Tamamlanınca aktif listeden düşer
    expect(find.text('Read'), findsNothing);

    final daily = await container
        .read(userTaskActionsProvider)
        .add(rawTitle: 'Daily review', recurrence: UserTaskRecurrence.daily);
    await tester.pumpAndSettle();
    await container.read(userTaskActionsProvider).toggle(daily!.id);
    await tester.pumpAndSettle();
    expect(find.text('Daily review'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('DashboardCardType.tasks builds TasksCard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(
            InMemoryUserTaskRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('tr'),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 400,
              child: dashboardCardFor(
                DashboardCardType.tasks,
                DashboardCardSize.medium,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TasksCard), findsOneWidget);
    expect(find.text('Görevler'), findsOneWidget);
  });
}
