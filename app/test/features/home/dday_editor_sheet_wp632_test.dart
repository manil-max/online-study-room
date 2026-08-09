// WP-632 — düzenleme penceresinin KABLOSU.
//
// 🔴 Bu depoda tekrarlayan hata: özellik yazılır, çağıranı olmaz. Bu gece
// üçüncü örneği çıktı (WP-611 Windows alarmı, WP-625 admin işlevleri, WP-629
// yaptırım uzlaştırması). Bu dosya "pencere var mı" değil **karta dokununca
// açılıyor mu ve içindeki düğmeler veriyi gerçekten değiştiriyor mu** diye
// sorar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/features/home/widgets/dday_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 8, 9, 21, 0);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ExamListState? seed,
}) async {
  SharedPreferences.setMockInitialValues({
    if (seed != null) kExamListKey: encodeExamList(seed),
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ddayClockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: defaultCardHeight(DashboardCardSize.large),
              child: const DDayCard(size: DashboardCardSize.large),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

ExamListState _seed(int count, {String? priority}) => ExamListState(
  entries: [
    for (var i = 0; i < count; i++)
      ExamEntry(id: 'e$i', name: 'Sınav $i', day: DateTime(2026, 6, 20 + i)),
  ],
  priorityId: priority,
);

void main() {
  testWidgets('karta dokunmak düzenleme penceresini AÇAR', (tester) async {
    await _pump(tester, seed: _seed(1));
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    expect(find.text(l10n.homeSinavlariDuzenle), findsNothing);
    await tester.tap(find.byKey(const Key('dday-card-open-editor')));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.homeSinavlariDuzenle),
      findsOneWidget,
      reason: 'Kart dokunuşu pencereyi açmıyor: düzenleme yolu KOPUK.',
    );
  });

  testWidgets('yıldız öne çıkarır, ikinci dokunuş kaldırır', (tester) async {
    final c = await _pump(tester, seed: _seed(2));
    await tester.tap(find.byKey(const Key('dday-card-open-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dday-priority-e1')));
    await tester.pumpAndSettle();
    expect(c.read(examListProvider).priority?.id, 'e1');

    // Başkasına basınca öncelik ONA geçer.
    await tester.tap(find.byKey(const Key('dday-priority-e0')));
    await tester.pumpAndSettle();
    expect(c.read(examListProvider).priority?.id, 'e0');

    // Aynısına basınca işaret kalkar.
    await tester.tap(find.byKey(const Key('dday-priority-e0')));
    await tester.pumpAndSettle();
    expect(c.read(examListProvider).priority, isNull);
  });

  testWidgets('oklar sırayı değiştirir, uçlarda devre dışıdır', (tester) async {
    final c = await _pump(tester, seed: _seed(2));
    await tester.tap(find.byKey(const Key('dday-card-open-editor')));
    await tester.pumpAndSettle();

    // İlk kaydın "yukarı" düğmesi devre dışı olmalı.
    final up0 = tester.widget<IconButton>(
      find.byKey(const Key('dday-up-e0')),
    );
    expect(up0.onPressed, isNull);

    await tester.tap(find.byKey(const Key('dday-down-e0')));
    await tester.pumpAndSettle();
    expect(c.read(examListProvider).entries.first.id, 'e1');
  });

  testWidgets('çöp kutusu kaydı siler', (tester) async {
    final c = await _pump(tester, seed: _seed(2));
    await tester.tap(find.byKey(const Key('dday-card-open-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dday-delete-e0')));
    await tester.pumpAndSettle();
    expect(c.read(examListProvider).entries.map((e) => e.id), ['e1']);
  });

  testWidgets('üç kayıtta ekleme düğmesi KAYBOLMAZ, devre dışı kalır', (
    tester,
  ) async {
    // 🔴 Kaybolan düğme kullanıcıya neden ekleyemediğini söylemez; sınır
    // görünür olmalı.
    await _pump(tester, seed: _seed(kMaxExamEntries));
    await tester.tap(find.byKey(const Key('dday-card-open-editor')));
    await tester.pumpAndSettle();

    final add = find.byKey(const Key('dday-add-exam'));
    expect(add, findsOneWidget);
    expect(tester.widget<OutlinedButton>(add).onPressed, isNull);

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.homeSinavSiniriDoldu(kMaxExamEntries)), findsOneWidget);
  });

  testWidgets('ad yazmadan kaydetmek engellenmez (isteğe bağlı)', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const Key('dday-card-open-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dday-add-exam')));
    await tester.pumpAndSettle();
    // Ad alanı boş bırakılıyor.
    await tester.tap(find.byKey(const Key('dday-save')));
    await tester.pumpAndSettle();

    expect(c.read(examListProvider).entries, hasLength(1));
    expect(c.read(examListProvider).entries.single.name, '');
  });

  testWidgets('yazılan ad kaydedilir ve kartta görünür', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const Key('dday-card-open-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dday-add-exam')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('dday-name-field')), 'YKS');
    await tester.tap(find.byKey(const Key('dday-save')));
    await tester.pumpAndSettle();

    expect(c.read(examListProvider).entries.single.name, 'YKS');
  });
}
