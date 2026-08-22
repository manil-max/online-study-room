// WP-743 — İSTATİSTİK KABUĞU: dönem şeridi ile "zamanda nerede olduğun" ayrıldı.
//
// Önceki sözleşme (WP-554): gezinme okları dönem şeridinin İÇİNDEydi ve seçili
// chip aynı zamanda başlıktı ("Hafta" yerine "Geçen hafta" yazıyordu). Sonuç:
// (a) şerit hem tür seçici hem konum göstergesiydi, (b) belirli bir güne/aya
// gitmenin tek yolu oka N kez basmaktı — 2024'e gitmek 2 yıl x 12 = 24 dokunuş.
//
// Yeni sözleşme: şerit YALNIZ dönem türü; altındaki gezinme çubuğu okları,
// başlığı ve döneme özel seçiciyi taşır.
//
// ============================== DİSİPLİN ====================================
//
// 1. Zaman ENJEKTE edilir. `now` bilerek düz bir GÜN ANAHTARI
//    (`DateTime(2026, 8, 22)`): `istanbul_calendar._isDayKey` böyle bir değeri
//    çevirmeden döndürür, yani iddialar koşucunun saat diliminden bağımsızdır.
//    (Depo dersi: CI UTC'de koşuyor ve gün sınırı Europe/Istanbul.)
// 2. Seçiciler UÇTAN UCA kullanılır — `jumpTo` doğrudan çağrılmaz. Doğrudan
//    çağırmak "düğme bağlı mı" sorusunu hiç sormaz (depo dersi: bitmiş backend,
//    bağlanmamış UI).
// 3. Provider CANLI tutulur: `container.listen` + ağaçta `watch` eden widget.
//    Dinleyicisiz bir provider Riverpod 3'te her `read`de yeniden kurulur ve
//    regresyon iddiası sessizce etkisizleşir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/stats/stats_screen.dart';
import 'package:online_study_room/features/stats/widgets/draggable_date_range_picker.dart';
import 'package:online_study_room/features/stats/widgets/stats_period_bar.dart';
import 'package:online_study_room/features/stats/widgets/stats_range_navigator.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 22 Ağustos 2026, **Cumartesi**. Haftanın Pazartesi'si 17 Ağustos.
final DateTime _now = DateTime(2026, 8, 22);

const Key _kPrev = Key('statsPeriodNav_prev');
const Key _kNext = Key('statsPeriodNav_next');
const Key _kTitle = Key('statsPeriodNavTitle');
const Key _kPickerButton = Key('statsPeriodPickerButton');
const Key _kCaret = Key('statsGroupTabCaret');

void main() {
  setUpAll(initializeDateFormatting);

  late ProviderContainer container;

  /// Gerçek kabuğun ilgili iki katmanı: dönem şeridi + gezinme çubuğu.
  /// Şerit de monte edilir, çünkü asıl iddialardan biri "okun şeritte OLMAMASI".
  Future<void> pumpShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    // 🔴 Riverpod 3 auto-dispose tuzağı: dinleyicisiz provider her `read`de
    // yeniden kurulur, `offset` iddiaları hep 0 görünürdü.
    container.listen(statsPeriodProvider, (_, _) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                const StatsPeriodBar(),
                StatsRangeNavigator(clock: () => _now),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> setPeriod(WidgetTester tester, StatsPeriod period) async {
    container.read(statsPeriodProvider.notifier).setPeriod(period);
    await tester.pumpAndSettle();
  }

  String title(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(_kTitle)).data!;

  int offset() => container.read(statsPeriodProvider).offset;

  IconButton nextButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(_kNext));

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(_kPickerButton));
    await tester.pumpAndSettle();
  }

  // ===========================================================================
  // 1) Okların YERİ değişti
  // ===========================================================================

  group('WP-743 (1) gezinme şeritten çıktı, kendi çubuğuna taşındı', () {
    testWidgets('ok ve başlık ŞERİDİN İÇİNDE değil, ÇUBUĞUN içinde', (
      tester,
    ) async {
      await pumpShell(tester);

      for (final key in [_kPrev, _kNext, _kTitle]) {
        expect(
          find.descendant(
            of: find.byType(StatsPeriodBar),
            matching: find.byKey(key),
          ),
          findsNothing,
          reason:
              '$key hâlâ dönem şeridinin içinde; şerit yalnız tür seçicidir.',
        );
        expect(
          find.descendant(
            of: find.byType(StatsRangeNavigator),
            matching: find.byKey(key),
          ),
          findsOneWidget,
          reason: '$key gezinme çubuğunda çizilmedi.',
        );
      }
    });

    testWidgets('şerit chip\'i gezinildiğinde bile DÜZ dönem adını yazar', (
      tester,
    ) async {
      await pumpShell(tester);
      // Varsayılan dönem hafta; iki dönem geriye git.
      await tester.tap(find.byKey(_kPrev));
      await tester.tap(find.byKey(_kPrev));
      await tester.pumpAndSettle();

      expect(offset(), -2);
      // WP-554'te seçili chip "Geçen hafta"/tarih aralığı yazıyordu.
      expect(
        find.descendant(
          of: find.byType(StatsPeriodBar),
          matching: find.text('Hafta'),
        ),
        findsOneWidget,
      );
      // Konum bilgisi artık YALNIZ çubukta (17 Ağu haftasından iki geri).
      expect(title(tester), '3 Ağu – 9 Ağu');
    });
  });

  // ===========================================================================
  // 2) Gün gezinmesi (WP-742 modelinin ekran karşılığı)
  // ===========================================================================

  group('WP-743 (2) gün başlığı', () {
    testWidgets('Bugün → Dün → takvim biçimi', (tester) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.day);

      expect(title(tester), 'Bugün');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('statsPeriodNavSubtitle')))
            .data,
        'Cumartesi',
        reason: 'Alt satır gün için hafta günü adını yazar.',
      );

      await tester.tap(find.byKey(_kPrev));
      await tester.pumpAndSettle();
      expect(offset(), -1);
      expect(title(tester), 'Dün');

      await tester.tap(find.byKey(_kPrev));
      await tester.pumpAndSettle();
      expect(offset(), -2);
      // "Bugün/Dün" dışına çıkınca yerelin CLDR takvim biçimi (ek çeviri yok).
      expect(title(tester), '20 Ağustos 2026');
    });

    testWidgets('bugündeyken ileri ok DEVRE DIŞI, geçmişte açık', (
      tester,
    ) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.day);

      // Gizlenmiyor — kullanıcı sınırda olduğunu görmeli.
      expect(find.byKey(_kNext), findsOneWidget);
      expect(nextButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(_kPrev));
      await tester.pumpAndSettle();
      expect(nextButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(_kNext));
      await tester.pumpAndSettle();
      expect(offset(), 0);
      expect(nextButton(tester).onPressed, isNull, reason: 'sınıra döndük');
    });
  });

  // ===========================================================================
  // 3) Çubuğun hangi dönemde ne çizdiği
  // ===========================================================================

  group('WP-743 (3) çubuk dönemi tanıyor', () {
    testWidgets('Tümü: çubuk HİÇ çizilmiyor', (tester) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.all);

      expect(find.byKey(_kPrev), findsNothing);
      expect(find.byKey(_kNext), findsNothing);
      expect(
        find.byKey(_kPickerButton),
        findsNothing,
        reason:
            '"Tümü" başlangıçtan bugüne tek aralıktır; seçilecek bir dönem yok.',
      );
      expect(tester.getSize(find.byType(StatsRangeNavigator)).height, 0);
    });

    testWidgets('Özel: ok YOK, yalnız aralık düğmesi var', (tester) async {
      // `DraggableDateRangePickerDialog` 800x600'lük varsayılan test
      // yüzeyine sığmıyor (ayrı bulgu, bu WP'nin kapsamı dışında); iddia
      // taşmayı değil düğmenin ne AÇTIĞINI ölçüyor.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.custom);

      expect(find.byKey(_kPickerButton), findsOneWidget);
      expect(
        find.byKey(_kPrev),
        findsNothing,
        reason: '"Önceki özel aralık" diye bir şey yok.',
      );
      expect(find.byKey(_kNext), findsNothing);

      // Düğme ÖLÜ değil: mevcut sürükle-bırak aralık seçicisini açar.
      await openPicker(tester);
      expect(find.byType(DraggableDateRangePickerDialog), findsOneWidget);
    });

    testWidgets('"Özel" chip\'i de aynı aralık seçicisini açar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpShell(tester);

      // 🔴 Chip yalnız `setPeriod(custom)` yapsaydı kullanıcı hiç aralık
      // seçmeden "Özel"e düşer ve sessizce SADECE BUGÜNÜ görürdü.
      await tester.tap(find.text('Özel'));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableDateRangePickerDialog), findsOneWidget);
    });
  });

  // ===========================================================================
  // 4) Başlık düğmesi DÖNEME UYGUN seçiciyi açar
  // ===========================================================================

  group('WP-743 (4) dört dönem, dört ayrı seçici', () {
    const expected = <StatsPeriod, Key>{
      StatsPeriod.day: Key('statsDayPicker'),
      StatsPeriod.week: Key('statsWeekPicker'),
      StatsPeriod.month: Key('statsMonthPicker'),
      StatsPeriod.year: Key('statsYearPicker'),
    };

    for (final entry in expected.entries) {
      testWidgets('${entry.key.name} → ${entry.value}', (tester) async {
        await pumpShell(tester);
        await setPeriod(tester, entry.key);
        await openPicker(tester);

        expect(find.byKey(entry.value), findsOneWidget);
        // Yanlış seçici açılmadı.
        for (final other in expected.values.where((k) => k != entry.value)) {
          expect(find.byKey(other), findsNothing, reason: '$other da açıldı');
        }
      });
    }

    testWidgets('YIL seçilince TAKVİM açılmaz — yalnız yıl listesi', (
      tester,
    ) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.year);
      await openPicker(tester);

      expect(
        find.byType(CalendarDatePicker),
        findsNothing,
        reason:
            'Sahip yıl için takvim istemedi: "2024" demek için gün seçtirmek '
            'iki fazladan karar demektir.',
      );
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2021'), findsOneWidget);
      expect(
        find.text('2020'),
        findsNothing,
        reason: 'Pencere $kStatsNavYearsBack yıl geriye açık.',
      );
    });

    testWidgets('AY seçicisinde bu yılın GELECEK ayları seçilemez', (
      tester,
    ) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.month);
      await openPicker(tester);

      // Ağustos'tayız: Eylül (9) devre dışı, Temmuz (7) açık.
      InkWell cell(int m) => tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(Key('statsMonthPickerCell_$m')),
          matching: find.byType(InkWell),
        ),
      );
      expect(cell(7).onTap, isNotNull);
      expect(
        cell(8).onTap,
        isNotNull,
        reason: 'içinde bulunulan ay seçilebilir',
      );
      expect(cell(9).onTap, isNull, reason: 'gelecek ay seçilemez');

      // İleri yıl oku da sınırda kapalı.
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('statsMonthPickerYearNext')),
            )
            .onPressed,
        isNull,
      );
    });
  });

  // ===========================================================================
  // 5) UÇTAN UCA: seçiciden seçmek gerçekten dönemi taşıyor
  // ===========================================================================

  group('WP-743 (5) seçici → statsPeriodProvider.offset', () {
    testWidgets('hafta listesinden üçüncü satır → offset -2', (tester) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.week);
      await openPicker(tester);

      // Satır 0 = bu hafta (17–23 Ağu), satır 2 = 3–9 Ağustos.
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('statsWeekPickerRow_2')))
            .title
            .toString(),
        contains('3 Ağu'),
      );
      await tester.tap(find.byKey(const Key('statsWeekPickerRow_2')));
      await tester.pumpAndSettle();

      expect(offset(), -2);
      expect(container.read(statsPeriodProvider).period, StatsPeriod.week);
      expect(title(tester), '3 Ağu – 9 Ağu');
    });

    testWidgets('ay ızgarasından Haziran → offset -2', (tester) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.month);
      await openPicker(tester);

      await tester.tap(find.byKey(const Key('statsMonthPickerCell_6')));
      await tester.pumpAndSettle();

      expect(offset(), -2);
      expect(title(tester), 'Haziran 2026');
    });

    testWidgets('yıl listesinden 2024 → offset -2', (tester) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.year);
      await openPicker(tester);

      await tester.tap(find.byKey(const Key('statsYearPickerRow_2024')));
      await tester.pumpAndSettle();

      expect(offset(), -2);
      expect(title(tester), '2024');
    });

    testWidgets('gün takviminden 20 Ağustos → offset -2', (tester) async {
      await pumpShell(tester);
      await setPeriod(tester, StatsPeriod.day);
      await openPicker(tester);

      expect(find.text('Tarih seç'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('statsDayPicker')),
          matching: find.text('20'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();

      expect(offset(), -2);
      expect(title(tester), '20 Ağustos 2026');
    });
  });

  // ===========================================================================
  // 6) Erişilebilirlik — 48dp
  // ===========================================================================

  testWidgets('WP-743 (6) dokunma hedefleri en az 48dp', (tester) async {
    await pumpShell(tester);
    for (final key in [_kPrev, _kNext, _kPickerButton]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.height, greaterThanOrEqualTo(48.0), reason: '$key');
    }
    for (final key in [_kPrev, _kNext]) {
      expect(tester.getSize(find.byKey(key)).width, greaterThanOrEqualTo(48.0));
    }
  });

  // ===========================================================================
  // 7) "Grup" sekmesi = grup değiştirici
  // ===========================================================================

  group('WP-743 (7) grup sekmesindeki ok grup değiştiriciyi açar', () {
    final groups = <StudyGroup>[
      StudyGroup(
        id: 'g-1',
        name: 'Alfa Grubu',
        inviteCode: 'AAA111',
        createdBy: 'me',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      StudyGroup(
        id: 'g-2',
        name: 'Beta Grubu',
        inviteCode: 'BBB222',
        createdBy: 'me',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    ];

    Future<void> pumpScreen(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
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
      );
      addTearDown(container.dispose);
      container.listen(activeGroupIdProvider, (_, _) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const StatsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Yalnız açılan menünün içindeki satır (ekran gövdesindeki grup adı değil).
    Finder menuItem(String name) => find.descendant(
      of: find.byType(PopupMenuItem<void>),
      matching: find.text(name),
    );

    testWidgets('oka dokununca katılınan gruplar listelenir', (tester) async {
      await pumpScreen(tester);

      // 🔴 Çıplak `find.text('Alfa Grubu')` menüyü ÖLÇMEZ: grup sekmesinin
      // gövdesi de aktif grubun adını yazar. Menü, kendi başlığından
      // ("Gruplarım") ve `PopupMenuItem` kabından tanınır.
      expect(find.text('Gruplarım'), findsNothing);
      await tester.tap(find.byKey(_kCaret));
      await tester.pumpAndSettle();

      expect(find.text('Gruplarım'), findsOneWidget);
      expect(menuItem('Alfa Grubu'), findsOneWidget);
      expect(menuItem('Beta Grubu'), findsOneWidget);
      // `switchOnly`: oluştur/katıl/keşfet girdileri BU menüde yok.
      expect(find.text('Grup oluştur'), findsNothing);
    });

    testWidgets('menüden seçmek activeGroupIdProvider\'ı değiştirir', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(container.read(activeGroupIdProvider), isNull);

      await tester.tap(find.byKey(_kCaret));
      await tester.pumpAndSettle();
      await tester.tap(menuItem('Beta Grubu'));
      await tester.pumpAndSettle();

      expect(
        container.read(activeGroupIdProvider),
        'g-2',
        reason:
            'Menü açılıyor ama seçim hiçbir yere yazılmıyorsa ölü anahtardır; '
            'Sınıflar sekmesi ile aynı grubu göstermesi buna bağlı.',
      );
      expect(container.read(userGroupProvider).value?.name, 'Beta Grubu');
    });

    testWidgets('ok dokunma hedefi 48dp', (tester) async {
      await pumpScreen(tester);
      final size = tester.getSize(find.byKey(_kCaret));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('sekme seçili DEĞİLKEN metne dokunmak sekme geçişidir', (
      tester,
    ) async {
      await pumpScreen(tester);
      // Açılışta Kişisel sekmesi seçili.
      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();

      expect(
        find.text('Gruplarım'),
        findsNothing,
        reason: 'Seçili olmayan sekmeye dokunmak menü açmamalı, geçiş yapmalı.',
      );
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBar))).index,
        kStatsGroupTabIndex,
      );

      // Zaten seçiliyken ikinci dokunuş menüyü açar.
      await tester.tap(find.text('Grup'));
      await tester.pumpAndSettle();
      expect(find.text('Gruplarım'), findsOneWidget);
    });
  });
}
