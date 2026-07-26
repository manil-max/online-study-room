import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/features/profile/widgets/primary_group_selector_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-352: Birincil grup seçilmediğinde grup ilerlemesi hiçbir gruba yazılmaz
/// (`0080_session_group_attribution.sql`). Kayıp başka hiçbir yüzeyde
/// görünmediği için uyarının seçim kartında durması regresyona kapalı olmalı.
void main() {
  const warningKey = ValueKey('primary-group-missing-warning');

  StudyGroup studyGroup(String id, String name) => StudyGroup(
    id: id,
    name: name,
    inviteCode: 'INV$id',
    createdBy: 'owner-1',
    createdAt: DateTime.utc(2026, 7, 1),
    timeZone: 'Europe/Istanbul',
  );

  Widget card({
    required List<StudyGroup> groups,
    required String? primaryGroupId,
  }) {
    return ProviderScope(
      overrides: [
        userGroupsProvider.overrideWith((ref) => Stream.value(groups)),
        primaryGroupPreferenceProvider.overrideWith(
          (ref) => Stream.value(
            PrimaryGroupPreference(
              primaryGroupId: primaryGroupId,
              selectionRevision: primaryGroupId == null ? 0 : 1,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: PrimaryGroupSelectorCard()),
        ),
      ),
    );
  }

  testWidgets('birincil grup seçiliyken uyarı yok', (tester) async {
    await tester.pumpWidget(
      card(
        groups: [studyGroup('g1', 'Kamp A'), studyGroup('g2', 'Kamp B')],
        primaryGroupId: 'g1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(warningKey), findsNothing);
    expect(find.text('Kamp A'), findsOneWidget);
    expect(find.text('Kamp B'), findsOneWidget);
  });

  testWidgets('iki grup + seçim yoksa uyarı görünür', (tester) async {
    await tester.pumpWidget(
      card(
        groups: [studyGroup('g1', 'Kamp A'), studyGroup('g2', 'Kamp B')],
        primaryGroupId: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(warningKey), findsOneWidget);
    // Ölü string değil: uyarı metni gerçekten l10n anahtarından geliyor.
    expect(
      find.text(
        'Hesap genelindeki hedef ve ilerleme için bir grup seçin.',
      ),
      findsOneWidget,
    );
    // Uyarı seçimi engellemez; kullanıcı aynı kartta düzeltebilir.
    expect(find.text('Kamp A'), findsOneWidget);
  });

  testWidgets('hiç grup yoksa uyarı yok, boş durum korunur', (tester) async {
    await tester.pumpWidget(card(groups: const [], primaryGroupId: null));
    await tester.pumpAndSettle();

    expect(find.byKey(warningKey), findsNothing);
    expect(find.text('Birincil grup seçmek için bir gruba katılın.'),
        findsOneWidget);
  });

  group('primaryGroupSelectionMissingProvider', () {
    ProviderContainer containerFor({
      List<StudyGroup>? groups,
      PrimaryGroupPreference? preference,
    }) {
      final container = ProviderContainer(
        overrides: [
          userGroupsProvider.overrideWith(
            (ref) => groups == null
                ? const Stream<List<StudyGroup>>.empty()
                : Stream.value(groups),
          ),
          primaryGroupPreferenceProvider.overrideWith(
            (ref) => preference == null
                ? const Stream<PrimaryGroupPreference>.empty()
                : Stream.value(preference),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur ve
      // regresyon testini sessizce etkisizleştirir.
      container.listen(primaryGroupSelectionMissingProvider, (_, _) {});
      return container;
    }

    Future<bool> read({
      List<StudyGroup>? groups,
      PrimaryGroupPreference? preference,
    }) async {
      final container = containerFor(groups: groups, preference: preference);
      if (groups != null) await container.read(userGroupsProvider.future);
      if (preference != null) {
        await container.read(primaryGroupPreferenceProvider.future);
      }
      return container.read(primaryGroupSelectionMissingProvider);
    }

    test('üyelik var + seçim yok → true', () async {
      expect(
        await read(
          groups: [studyGroup('g1', 'Kamp A')],
          preference: const PrimaryGroupPreference(
            primaryGroupId: null,
            selectionRevision: 0,
          ),
        ),
        isTrue,
      );
    });

    test('seçim var → false', () async {
      expect(
        await read(
          groups: [studyGroup('g1', 'Kamp A')],
          preference: const PrimaryGroupPreference(
            primaryGroupId: 'g1',
            selectionRevision: 1,
          ),
        ),
        isFalse,
      );
    });

    test('üyelik yok → false', () async {
      expect(
        await read(
          groups: const <StudyGroup>[],
          preference: const PrimaryGroupPreference(
            primaryGroupId: null,
            selectionRevision: 0,
          ),
        ),
        isFalse,
      );
    });

    test('yükleme sırasında olmayan kayıp ilan edilmez', () async {
      // Hiçbir akış emit etmedi: kayıp olduğunu iddia etmeyiz.
      expect(await read(), isFalse);
    });
  });
}
