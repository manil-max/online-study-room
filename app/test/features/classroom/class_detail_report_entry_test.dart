import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  final group = StudyGroup(
    id: 'group-1',
    name: 'Odak Grubu',
    inviteCode: 'KAMP42',
    createdBy: 'owner-1',
    createdAt: DateTime(2026, 1, 1),
  );

  Widget harness() {
    final repository = InMemoryGroupRepository();
    return ProviderScope(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClassDetailScreen(group: group),
      ),
    );
  }

  testWidgets('grup ve grup adı için ayrı şikâyet girişleri görünür', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byKey(const ValueKey('report-group-action')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report-group-name-action')),
      findsOneWidget,
    );
  });

  testWidgets('grup şikâyeti sınırlı kategori sayfasını açar', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('report-group-action')));
    await tester.pump();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
