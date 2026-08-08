// WP-515: "Bugünün özeti" kartı **geniş + sınırsız yükseklikli** bir bağlamda
// hiç çizilmiyordu.
//
// 🔴 Kök neden: kartın compact olmayan dalı bir `Column` içinde `Expanded`
// kuruyor. `isCompact` yükseklik eşiğini yalnız yükseklik **sınırlıyken**
// uyguluyor (`constraints.maxHeight.isFinite && maxHeight < 140`), yani
// `maxWidth >= 180` + `maxHeight == infinity` kombinasyonunda bu dala sonsuz
// yükseklikle giriliyordu. Sonsuz yükseklikte flex'li çocuk `RenderFlex`
// hatası verir; içindeki `ListView` de kendi yüksekliğini bilemez.
//
// ⚠️ Bu dosya "sınırsızda compact'a düş" çözümünü **kabul etmiyor**: o yol
// hatayı susturur ama ders dağılımını ekrandan siler. Ölçülen şey ikisi
// birden — hata yok **ve** içerik yerinde.
//
// Bulgu WP-508 turunda çıktı ve o WP'nin kapsamı dışında bırakıldı
// (`card_scroll_gesture_wp508_test.dart` yalnız **sınırlı** hücreyi ölçer).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/widgets/card_data_gate.dart';
import 'package:online_study_room/features/home/widgets/today_summary_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

List<Override> _statsOverrides() => [
  authStateProvider.overrideWith(
    (ref) => Stream.value(
      Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026, 1, 1)),
    ),
  ),
  userSessionsProvider.overrideWith(
    (ref) => Stream.value(<StudySession>[
      StudySession(
        id: 's1',
        userId: 'u1',
        subjectId: 'sub-1',
        start: DateTime.now().subtract(const Duration(hours: 1)),
        end: DateTime.now(),
        durationSeconds: 3600,
        source: StudySource.live,
      ),
      StudySession(
        id: 's2',
        userId: 'u1',
        subjectId: 'sub-2',
        start: DateTime.now().subtract(const Duration(minutes: 30)),
        end: DateTime.now(),
        durationSeconds: 1800,
        source: StudySource.live,
      ),
    ]),
  ),
  userSubjectsProvider.overrideWith(
    (ref) => Stream.value(<Subject>[
      const Subject(
        id: 'sub-1',
        userId: 'u1',
        name: 'Matematik',
        color: 'chart-1',
      ),
      const Subject(id: 'sub-2', userId: 'u1', name: 'Fizik', color: 'chart-2'),
    ]),
  ),
];

/// Yakalanan çizim hatalarını döndürür (boş liste = temiz kare).
Future<List<String>> _pump(
  WidgetTester tester, {
  required Widget body,
}) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;

  await tester.pumpWidget(
    ProviderScope(
      overrides: _statsOverrides(),
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );
  // Akışlar yerine otursun; `pumpAndSettle` yok (kartlar periyodik timer taşır).
  await tester.pump();
  await tester.pump();

  FlutterError.onError = previous;
  return errors.map((detail) => detail.exceptionAsString()).toList();
}

void main() {
  testWidgets('geniş ve sınırsız yükseklikte çizim hatası üretmez', (
    tester,
  ) async {
    // Gruplar listesindeki gerçek bağlam: dikey `ListView` çocuğuna sonsuz
    // yükseklik + **tam genişlik** verir (180 dp eşiğinin çok üstünde), yani
    // compact olmayan dal seçilir.
    final errors = await _pump(
      tester,
      body: ListView(children: const [TodaySummaryCard()]),
    );

    expect(
      errors,
      isEmpty,
      reason:
          'Sınırsız yükseklikte kart RenderFlex hatası verdi — compact olmayan '
          'dal hâlâ koşulsuz `Expanded` kuruyor (WP-515).',
    );
    // 🔴 Bu iddia olmadan test sahte yeşil verirdi: akışlar hiç oturmasaydı
    // ekranda yalnız `cardDataGate` iskeleti olurdu, iskelet de hata üretmez.
    // Ders adı yalnız kartın **kendi** gövdesinde çizilir.
    expect(
      find.byKey(kCardSkeletonKey),
      findsNothing,
      reason: 'Veri kapısı hâlâ açık — test kartın gövdesini ölçmüyor.',
    );
    expect(find.text('Matematik'), findsOneWidget);
  });

  testWidgets('sınırsızda ders dağılımı kaybolmuyor (compact\'a düşmüyor)', (
    tester,
  ) async {
    await _pump(
      tester,
      body: ListView(children: const [TodaySummaryCard()]),
    );

    // Tam düzenin kanıtı: ders adları ve tam başlık görünür.
    expect(find.text('Bugün özeti'), findsOneWidget);
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Fizik'), findsOneWidget);
    // Compact düzenin imzası görünmemeli — görünürse hata "compact'a düşerek"
    // susturulmuş demektir ve sahip ders dağılımını kaybetmiş olur.
    expect(find.text('2 ders'), findsNothing);
  });

  testWidgets('sınırlı ızgara hücresinde davranış değişmedi', (tester) async {
    final errors = await _pump(
      tester,
      body: const Center(
        child: SizedBox(width: 360, height: 260, child: TodaySummaryCard()),
      ),
    );

    expect(errors, isEmpty);
    expect(find.text('Bugün özeti'), findsOneWidget);
    expect(find.text('Matematik'), findsOneWidget);
  });

  testWidgets('dar ve sınırsız hücrede compact düzen korunuyor', (
    tester,
  ) async {
    // `maxWidth < 180` → compact dal. WP-508'de doğru kurulmuştu; WP-515'in
    // değişikliği buraya dokunmamalı.
    //
    // ⚠️ `Align` şart: `ListView` çocuklarına **sıkı** genişlik kısıtı verir,
    // yani çıplak `SizedBox(width: 140)` ezilir ve kart 800 dp genişlikte
    // ölçülür — test dar hücreyi hiç sınamamış olur.
    final errors = await _pump(
      tester,
      body: ListView(
        children: const [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 140, child: TodaySummaryCard()),
          ),
        ],
      ),
    );

    expect(errors, isEmpty);
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('2 ders'), findsOneWidget);
  });
}
