import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/safety/muted_nudges_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  late InMemoryNudgeRepository repository;

  Widget harness() {
    return ProviderScope(
      overrides: [nudgeRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MutedNudgesScreen(),
      ),
    );
  }

  setUp(() {
    repository = InMemoryNudgeRepository(currentUserId: 'alpha');
  });

  testWidgets('boş listede kapsam açıklaması ve boş metni birlikte görünür', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Kapsam açıklaması boş listede de görünür: kullanıcı susturmayı
    // engellemeyle karıştırmasın.
    expect(find.textContaining('engellenmez'), findsOneWidget);
    expect(find.text('Dürtmesi susturulan kimse yok.'), findsOneWidget);
  });

  testWidgets('susturulan kişi listelenir; ad okunamazsa maskeli ad kullanılır', (
    tester,
  ) async {
    await repository.muteNudgesFrom('beta');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Susturulan kullanıcı'), findsOneWidget);
    expect(find.text('Susturmayı kaldır'), findsOneWidget);
    expect(find.text('Dürtmesi susturulan kimse yok.'), findsNothing);
  });

  testWidgets('susturma kaldırılınca satır düşer ve tercih repository\'den silinir', (
    tester,
  ) async {
    await repository.muteNudgesFrom('beta');

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Susturmayı kaldır'));
    await tester.pumpAndSettle();

    expect(await repository.listMutedNudgeSenderIds(), isEmpty);
    expect(find.text('Susturma kaldırıldı.'), findsOneWidget);
    expect(find.text('Dürtmesi susturulan kimse yok.'), findsOneWidget);
  });
}
