// WP-554 — iki bulgu, tek dosya:
//
// (1) **Erişilebilirlik**: uygulamanın iki imza yüzeyi (sayaç + kamp ateşi)
//     ekran okuyucuya görünmezdi. Sayaç `formatHms` ile "01:23:45" basıyordu;
//     TalkBack bunu rakam rakam okur. Kamp ateşindeki dokunulabilir üyeler ise
//     hiçbir etiket taşımıyordu (`CustomPaint` semantik düğüm üretmez).
// (2) **Dönem gezinme**: geçmiş haftaya bakmanın tek yolu Özel → takvim →
//     ay okuyla geri → iki ucu ayrı ayrı sürükle → onayla zinciriydi.
//
// İddialar **davranış** düzeyinde: etiketin İÇERİĞİ ve hesaplanan tarih
// SINIRLARI ölçülür. "Semantics widget'ı var" / "buton var" iddiaları mutasyona
// dayanıklı değildir, burada kasten kullanılmadı.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/features/classroom/widgets/clock_style.dart';
import 'package:online_study_room/features/stats/widgets/stats_period_bar.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Widget _app({required Widget child, String locale = 'tr'}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// Kamp ateşi sahnesi: enjekte saat + sabit `startedAt` → deterministik süre.
final _sceneNow = DateTime(2026, 7, 28, 12);
final _studyStart = DateTime(2026, 7, 28, 11, 30); // → 00:30:00

Widget _campfireHarness() {
  final members = [
    Profile(id: 'u0', displayName: 'Ada', createdAt: DateTime(2026, 1, 1)),
    Profile(id: 'u1', displayName: 'Bora', createdAt: DateTime(2026, 1, 1)),
  ];
  return ProviderScope(
    overrides: [
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupPresenceProvider.overrideWith(
        (ref) => Stream.value([
          Presence(
            userId: 'u0',
            status: PresenceStatus.studying,
            todaySeconds: 0,
            startedAt: _studyStart,
          ),
          Presence(
            userId: 'u1',
            status: PresenceStatus.offline,
            todaySeconds: 0,
          ),
        ]),
      ),
      groupTodaySecondsProvider.overrideWithValue(const {'u0': 0, 'u1': 0}),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: 360,
              child: CampfireScene(clock: () => _sceneNow),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Sayacın ekran okuyucuya okunan etiketi (tek düğüm, `excludeSemantics`).
String _clockLabel(WidgetTester tester) =>
    tester.getSemantics(find.byType(StudyClock)).label;

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('WP-554 (1a) sayaç ekran okuyucuya insan dilinde konuşuyor', () {
    testWidgets('TR: faz + saat/dakika/saniye + durum; ham "01:23:45" YOK', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: const StudyClock(
            seconds: 5025, // 01:23:45
            pctToGoal: 0.4,
            running: true,
            style: ClockStyle.digits,
            fontSize: 40,
          ),
        ),
      );

      final label = _clockLabel(tester);
      expect(label, contains('Çalışma sayacı'));
      expect(label, contains('1 saat'));
      expect(label, contains('23 dakika'));
      expect(label, contains('45 saniye'));
      expect(label, contains('çalışıyor'));

      // Görünen metin değişmedi (kozmetik regresyon yok)…
      expect(find.text('01:23:45'), findsOneWidget);
      // …ama ekran okuyucu artık rakam dizisini duymuyor.
      expect(label, isNot(contains('01:23:45')));
      expect(find.bySemanticsLabel('01:23:45'), findsNothing);

      handle.dispose();
    });

    testWidgets('EN: aynı etiket İngilizce tekil/çoğul biçimle üretilir', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          locale: 'en',
          child: const StudyClock(
            seconds: 3661, // 01:01:01
            pctToGoal: 0.1,
            running: true,
            style: ClockStyle.ring,
            fontSize: 40,
          ),
        ),
      );

      final label = _clockLabel(tester);
      expect(label, contains('Study timer'));
      expect(label, contains('1 hour'));
      expect(label, contains('1 minute'));
      expect(label, contains('1 second'));
      expect(label, contains('running'));
      expect(label, isNot(contains('01:01:01')));
      handle.dispose();
    });

    testWidgets('mola fazı çalışma fazından ayırt ediliyor', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: const StudyClock(
            seconds: 300,
            pctToGoal: 0.9,
            running: true,
            style: ClockStyle.digits,
            fontSize: 40,
            phase: TimerPhase.rest,
          ),
        ),
      );
      final label = _clockLabel(tester);
      expect(label, contains('Mola sayacı'));
      expect(label, isNot(contains('Çalışma sayacı')));
      expect(label, contains('5 dakika'));
      handle.dispose();
    });

    testWidgets(
      'durum üç halde de doğru: çalışıyor / duraklatıldı / durduruldu',
      (tester) async {
        final handle = tester.ensureSemantics();

        Future<String> pump({
          required int seconds,
          required bool running,
        }) async {
          await tester.pumpWidget(
            _app(
              child: StudyClock(
                seconds: seconds,
                pctToGoal: 0.2,
                running: running,
                style: ClockStyle.digits,
                fontSize: 40,
              ),
            ),
          );
          return _clockLabel(tester);
        }

        expect(await pump(seconds: 90, running: true), contains('çalışıyor'));
        expect(
          await pump(seconds: 90, running: false),
          contains('duraklatıldı'),
        );
        expect(await pump(seconds: 0, running: false), contains('durduruldu'));

        handle.dispose();
      },
    );

    test(
      'spokenDuration sıfırda sessiz kalmaz, sıfır parçaları atlar',
      () async {
        final tr = await AppLocalizations.delegate.load(const Locale('tr'));
        expect(spokenDuration(tr, 0), '0 saniye');
        expect(spokenDuration(tr, 3600), '1 saat');
        expect(spokenDuration(tr, 3660), '1 saat 1 dakika');
        expect(spokenDuration(tr, -5), '0 saniye');

        final en = await AppLocalizations.delegate.load(const Locale('en'));
        expect(en.a11yDurationHours(2), '2 hours');
        expect(en.a11yDurationHours(1), '1 hour');
      },
    );
  });

  group('WP-554 (1b) kamp ateşi üyeleri ekran okuyucuya görünüyor', () {
    testWidgets('dokunulabilir üye düğümü ad + durum taşıyor', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_campfireHarness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Çalışan üye ve çevrimdışı üye ayrı ayrı okunabiliyor.
      expect(find.bySemanticsLabel('Ada, Çalışıyor'), findsOneWidget);
      expect(find.bySemanticsLabel('Bora, Çevrimdışı'), findsOneWidget);

      // Etiket yetmez: düğüm ekran okuyucudan ETKİNLEŞTİRİLEBİLİR olmalı,
      // yoksa TalkBack kullanıcısı kampçı kartını hiç açamaz.
      final data = tester
          .getSemantics(find.bySemanticsLabel('Ada, Çalışıyor'))
          .getSemanticsData();
      // `hasFlag` Flutter 3.32'de deprecate edildi; `flagsCollection`
      // ayni bilgiyi tip guvenli alanlarla veriyor.
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);

      handle.dispose();
    });

    testWidgets('dekoratif katman semantik ağaçta yok, ekranda duruyor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_campfireHarness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Görünüm aynı: isim + canlı süre hâlâ çiziliyor.
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('00:30:00'), findsOneWidget);

      // Ama dekoratif etiket katmanı okunmuyor: ham HH:MM:SS ve isim tekrarı
      // semantik ağaçta yok (isim yalnız dokunulabilir düğümün etiketinde).
      expect(find.bySemanticsLabel('00:30:00'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'^\d{2}:\d{2}:\d{2}$')),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Ada'), findsNothing);

      handle.dispose();
    });
  });

  group('WP-554 (2) dönem seridinde ileri/geri gezinme', () {
    late ProviderContainer container;

    Future<void> pumpBar(WidgetTester tester) async {
      container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: StatsPeriodBar()),
          ),
        ),
      );
    }

    IconButton nextButton(WidgetTester tester) =>
        tester.widget<IconButton>(find.byKey(const Key('statsPeriodNav_next')));

    /// Seçili chip metni = dönem başlığı. Gezinildiğinde "Hafta" yerine
    /// "Geçen hafta" yazar; kullanıcı nerede olduğunu buradan bilir.
    String title(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('statsPeriodNavTitle'))).data!;

    testWidgets('geri ok GERÇEKTEN bir önceki haftanın aralığını hesaplar', (
      tester,
    ) async {
      await pumpBar(tester);
      final now = DateTime(2026, 3, 11, 15, 30); // Çarşamba

      expect(container.read(statsPeriodProvider).period, StatsPeriod.week);
      // Bugündeyken seçili chip kendi adını taşır (WP-190 sözleşmesi).
      expect(title(tester), 'Hafta');

      await tester.tap(find.byKey(const Key('statsPeriodNav_prev')));
      await tester.pump();

      final sel = container.read(statsPeriodProvider);
      expect(sel.offset, -1);
      expect(sel.period, StatsPeriod.week, reason: 'chip türü korunmalı');

      final (from, to) = sel.range(now: now);
      final thisWeek = startOfWeek(now);
      // Tarih SINIRI iddiası: bir önceki haftanın Pazartesi 00:00'ı…
      expect(from, thisWeek.subtract(const Duration(days: 7)));
      // …ve o haftanın son GÜNÜ (Pazar) — "şimdi" değil.
      //
      // 🔴 WP-612: burada eskiden `thisWeek - 1ms` (cihazın YEREL 23:59:59.999'u)
      // bekleniyordu ve iddia HAM `to` üzerindeydi. O değer gün anahtarı
      // değildir; `dayOf` onu İstanbul'a çevirir ve UTC+3'ün batısındaki her
      // cihazda (CI dâhil) gün BİR İLERİ kayardı — "geçen hafta" 8 gün olurdu.
      // Bu satır hatayı ölçmüyor, SÖZLEŞMEYE çeviriyordu. Kapanış artık `from`
      // gibi bir gün anahtarıdır; kaç GÜN kapsandığı ve saat dilimi davranışı
      // `stats_bleeding_wp612_test.dart` içinde ölçülür.
      expect(to, DateTime(2026, 3, 8));
      expect(to.isBefore(thisWeek), isTrue);

      expect(title(tester), 'Geçen hafta');
    });

    testWidgets('ileri ok bugündeyken DEVRE DIŞI, geçmişteyken açık', (
      tester,
    ) async {
      await pumpBar(tester);

      // Bugündeyiz: ok görünür ama basılamaz (gizlenmiyor!).
      expect(find.byKey(const Key('statsPeriodNav_next')), findsOneWidget);
      expect(nextButton(tester).onPressed, isNull);
      expect(container.read(statsPeriodProvider).canGoForward, isFalse);

      await tester.tap(find.byKey(const Key('statsPeriodNav_prev')));
      await tester.pump();
      expect(nextButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('statsPeriodNav_next')));
      await tester.pump();
      expect(container.read(statsPeriodProvider).offset, 0);
      expect(nextButton(tester).onPressed, isNull, reason: 'sınıra döndük');
      expect(title(tester), 'Hafta');
    });

    test('geleceğe taşma 0da kırpılır', () {
      const sel = StatsPeriodSelection(period: StatsPeriod.week);
      expect(sel.shifted(1).offset, 0);
      expect(sel.shifted(-2).shifted(5).offset, 0);
      expect(sel.shifted(-2).shifted(1).offset, -1);
    });

    test('ay ve yıl sınırları takvim aritmetiğiyle hesaplanır', () {
      final now = DateTime(2026, 1, 15, 9);
      // Ocak'tan bir geri → Aralık 2025 (yıl taşması).
      final month = const StatsPeriodSelection(
        period: StatsPeriod.month,
      ).shifted(-1);
      final (mFrom, mTo) = month.range(now: now);
      expect(mFrom, DateTime(2025, 12, 1));
      // WP-612: kapanış = dönemin son GÜNÜ (gün anahtarı), son "an"ı değil.
      expect(mTo, DateTime(2025, 12, 31));

      final year = const StatsPeriodSelection(
        period: StatsPeriod.year,
      ).shifted(-2);
      final (yFrom, yTo) = year.range(now: now);
      expect(yFrom, DateTime(2024, 1, 1));
      expect(yTo, DateTime(2024, 12, 31));
    });

    test('gezinme Bugün/Tümü/Özel için kapalı; offset aralığı bozmaz', () {
      final now = DateTime(2026, 3, 11, 15, 30);
      for (final p in [
        StatsPeriod.today,
        StatsPeriod.all,
        StatsPeriod.custom,
      ]) {
        final sel = StatsPeriodSelection(period: p);
        expect(sel.supportsNavigation, isFalse, reason: p.name);
        expect(sel.canGoForward, isFalse, reason: p.name);
        expect(sel.shifted(-3).offset, 0, reason: p.name);
        expect(sel.shifted(-3).range(now: now), sel.range(now: now));
      }
    });

    testWidgets('dönem türü değişince gezinme başa döner', (tester) async {
      await pumpBar(tester);
      await tester.tap(find.byKey(const Key('statsPeriodNav_prev')));
      await tester.pump();
      expect(container.read(statsPeriodProvider).offset, -1);

      container.read(statsPeriodProvider.notifier).setPeriod(StatsPeriod.month);
      await tester.pump();
      expect(container.read(statsPeriodProvider).offset, 0);
      expect(title(tester), 'Ay');
    });

    testWidgets('gezinme okları Bugün/Tümü/Özel modunda çizilmez', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(find.byKey(const Key('statsPeriodNav_prev')), findsOneWidget);

      container.read(statsPeriodProvider.notifier).setPeriod(StatsPeriod.today);
      await tester.pump();
      expect(find.byKey(const Key('statsPeriodNav_prev')), findsNothing);
      expect(find.byKey(const Key('statsPeriodNav_next')), findsNothing);
    });

    testWidgets('dokunma hedefi en az 48dp', (tester) async {
      await pumpBar(tester);
      for (final key in ['statsPeriodNav_prev', 'statsPeriodNav_next']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(48.0), reason: key);
        expect(size.height, greaterThanOrEqualTo(48.0), reason: key);
      }
    });

    testWidgets('iki dönem geride başlık takvim biçimine düşer', (
      tester,
    ) async {
      await pumpBar(tester);
      container.read(statsPeriodProvider.notifier).setPeriod(StatsPeriod.month);
      await tester.pump();
      container.read(statsPeriodProvider.notifier).shift(-1);
      await tester.pump();
      expect(title(tester), 'Geçen ay');

      container.read(statsPeriodProvider.notifier).shift(-1);
      await tester.pump();
      // "Bu ay/Geçen ay" dışına çıkınca ay adı + yıl yazar (yerelin CLDR
      // biçimi); kullanıcı nerede olduğunu bilir.
      final now = DateTime.now();
      final target = DateTime(now.year, now.month - 2, 1);
      expect(title(tester), contains(target.year.toString()));
      expect(title(tester), isNot('Geçen ay'));
    });
  });
}
