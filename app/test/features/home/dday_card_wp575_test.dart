// WP-575: Sınav geri sayımı (D-Day) kartı.
//
// 🔴 Bu dosya KOŞUM MAKİNESİNDEN ve GÜNÜN SAATİNDEN BAĞIMSIZDIR. Saat kaynağı
// `ddayClockProvider` üzerinden enjekte edilir; anlar `DateTime.utc(...)` ve
// `tz.TZDateTime(...)` ile kurulur, yani `.year/.month/.day` alanları koşum
// makinesinin bölgesine göre değişmez. Bu depoda gece yarısına bağlı flake iki
// kez sürüm koşumunu kırdı (WP-565), o yüzden hiçbir iddia `DateTime.now()`a
// dayanmaz.
//
// Ölçülen asıl sözleşme: kalan gün, cihazın ham yerel tarihinden değil ürünün
// tek gün sınırından (`istanbulDay`) sayılır. Kurulum iki yönlüdür:
//   * UTC cihaz, İstanbul 00:30   → ham tarih bir gün GERİDE  → yanlış kod 11 der
//   * UTC+4 cihaz, İstanbul 23:30 → ham tarih bir gün İLERİDE → yanlış kod 10 der
// Doğru cevaplar sırasıyla 10 ve 11'dir; yani `istanbulDay` yerine ham fark
// yazılırsa iki test birden düşer (biri fazla, biri eksik gün ile).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dashboard_providers.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/features/home/widgets/card_picker.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Sınav günü: iki senaryoda da aynı takvim tarihi.
final _examDay = DateTime(2026, 8, 20);

Future<SharedPreferences> _prefs({String? examDate}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (examDate != null) await prefs.setString(kExamDateKey, examDate);
  return prefs;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required DateTime now,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ddayClockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              // Kartı doğrudan kurmak yerine pano fabrikasından geçir: tür
              // fabrikaya bağlanmadıysa kart üründe hiç doğmaz.
              child: dashboardCardFor(
                DashboardCardType.dday,
                DashboardCardSize.medium,
                height: 260,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tz_data.initializeTimeZones();
  // UTC+4, yaz saati uygulamayan sabit bölge.
  final dubai = tz.getLocation('Asia/Dubai');

  // UTC cihaz (CI koşucusu): İstanbul 2026-08-10 00:30. Ham UTC tarihi 9 Ağustos.
  final utcDeviceAfterIstanbulMidnight = DateTime.utc(2026, 8, 9, 21, 30);
  // UTC+4 cihaz: kendi takviminde 10 Ağustos 00:30 ama İstanbul 9 Ağustos 23:30.
  final plus4DeviceBeforeIstanbulMidnight = tz.TZDateTime(
    dubai,
    2026,
    8,
    10,
    0,
    30,
  );

  group('gün sınırı istanbulDay ile çizilir', () {
    test('kurulum gerçekten hatanın penceresinde', () {
      // Test kendi senaryosunu doğrular; yoksa yarın "yeşil ama anlamsız" olur.
      expect(
        istanbulDay(utcDeviceAfterIstanbulMidnight),
        DateTime(2026, 8, 10),
        reason: 'Kurulum bozuk: an İstanbul 10 Ağustos gününe düşmüyor.',
      );
      expect(
        utcDeviceAfterIstanbulMidnight.day,
        9,
        reason: 'Kurulum bozuk: ham UTC tarihi İstanbul tarihiyle aynı.',
      );
      expect(
        istanbulDay(plus4DeviceBeforeIstanbulMidnight),
        DateTime(2026, 8, 9),
        reason: 'Kurulum bozuk: an İstanbul 9 Ağustos gününe düşmüyor.',
      );
      expect(
        plus4DeviceBeforeIstanbulMidnight.day,
        10,
        reason: 'Kurulum bozuk: UTC+4 tarihi İstanbul tarihiyle aynı.',
      );
    });

    test('UTC cihaz İstanbul gece yarısını geçmişken 10 gün kalır', () {
      // Ham tarih (9 Ağustos) kullanılsaydı 11 çıkardı.
      expect(
        daysUntilExam(examDay: _examDay, now: utcDeviceAfterIstanbulMidnight),
        10,
      );
    });

    test('UTC+4 cihaz kendi gününe geçmişken hâlâ 11 gün kalır', () {
      // Ham tarih (10 Ağustos) kullanılsaydı 10 çıkardı.
      expect(
        daysUntilExam(
          examDay: _examDay,
          now: plus4DeviceBeforeIstanbulMidnight,
        ),
        11,
      );
    });

    test('gün ortasında da doğru: sınav günü 0, bir gün öncesi 1', () {
      // 09:00Z = İstanbul 12:00; kolay durumun bozulmaması regresyonun sessiz
      // hâlini yakalar.
      expect(
        daysUntilExam(examDay: _examDay, now: DateTime.utc(2026, 8, 20, 9)),
        0,
      );
      expect(
        daysUntilExam(examDay: _examDay, now: DateTime.utc(2026, 8, 19, 9)),
        1,
      );
    });

    test('geçmiş tarihte hesap negatif döner (kart bunu göstermez)', () {
      expect(
        daysUntilExam(examDay: _examDay, now: DateTime.utc(2026, 8, 23, 9)),
        -3,
      );
    });
  });

  group('kart', () {
    testWidgets('tarih seçilmemişken boş kutu değil, "tarih seç" der', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(),
        now: utcDeviceAfterIstanbulMidnight,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      // `cardDataGate` sözleşmesi: başlık korunur + gövde ne olduğunu söyler.
      expect(find.text(l10n.homeSinavGeriSayimi), findsOneWidget);
      expect(find.text(l10n.homeSinavTarihiSecilmedi), findsOneWidget);
      // Çıkmaz sokak yok: nereden ayarlanacağı söylenir (WP-560 dersi).
      expect(find.text(l10n.homeSinavTarihiniAyarlardanSec), findsOneWidget);
    });

    testWidgets('tarih seçilince kalan gün İstanbul gününden yazılır', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(examDate: encodeExamDay(_examDay)),
        now: utcDeviceAfterIstanbulMidnight,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      expect(find.text(l10n.homeSinavaKalanGun(10)), findsOneWidget);
      // Ham cihaz tarihiyle sayılsaydı ekranda bu dururdu.
      expect(find.text(l10n.homeSinavaKalanGun(11)), findsNothing);
      expect(find.text(l10n.homeSinavTarihiSecilmedi), findsNothing);
    });

    testWidgets('UTC+4 cihazda aynı tarih için 11 gün yazılır', (tester) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(examDate: encodeExamDay(_examDay)),
        now: plus4DeviceBeforeIstanbulMidnight,
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      expect(find.text(l10n.homeSinavaKalanGun(11)), findsOneWidget);
      expect(find.text(l10n.homeSinavaKalanGun(10)), findsNothing);
    });

    testWidgets('geçmiş tarihte "geçti" der ve negatif sayı göstermez', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(examDate: encodeExamDay(_examDay)),
        now: DateTime.utc(2026, 8, 23, 9),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      expect(find.text(l10n.homeSinavGecti), findsOneWidget);
      expect(find.text(l10n.homeSinavaKalanGun(-3)), findsNothing);
      // Biçim değişse bile eksili gün sayısı hiçbir yerde görünmemeli.
      expect(find.textContaining(RegExp(r'-\d')), findsNothing);
    });

    testWidgets('sınav günü "0 gün kaldı" değil "bugün" der', (tester) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(examDate: encodeExamDay(_examDay)),
        now: DateTime.utc(2026, 8, 20, 9),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

      expect(find.text(l10n.homeSinavBugun), findsOneWidget);
      expect(find.text(l10n.homeSinavaKalanGun(0)), findsNothing);
    });

    testWidgets('metin katalogdan gelir: İngilizce arayüzde İngilizce yazar', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        prefs: await _prefs(examDate: encodeExamDay(_examDay)),
        now: utcDeviceAfterIstanbulMidnight,
        locale: const Locale('en'),
      );
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));

      expect(find.text(en.homeSinavGeriSayimi), findsOneWidget);
      expect(find.text(en.homeSinavaKalanGun(10)), findsOneWidget);
      // Gömülü Türkçe metin olsaydı İngilizce arayüzde de görünürdü (WP-504).
      expect(find.text(tr.homeSinavaKalanGun(10)), findsNothing);
    });
  });

  group('kart seçici', () {
    testWidgets('seçicide çıkar ve dokununca panoya eklenir', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCardPicker(context),
                  child: const Text('picker'),
                ),
              ),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
        listen: false,
      );
      // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur ve
      // eklenen kart sessizce kaybolur.
      final sub = container.listen(dashboardLayoutProvider, (_, next) {});
      addTearDown(sub.close);

      await tester.tap(find.text('picker'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        find.text(l10n.homeSinavGeriSayimi),
        findsOneWidget,
        reason:
            'Kart seçicide görünmüyor — kategorisi seçicinin sıra listesinde '
            'olmayan bir başlığa düşmüş olabilir; o zaman kart sessizce '
            'eklenemez olur.',
      );

      await tester.tap(find.text(l10n.homeSinavGeriSayimi));
      await tester.pumpAndSettle();

      expect(
        container.read(dashboardLayoutProvider).map((c) => c.type),
        contains(DashboardCardType.dday),
      );
    });

    test('panodan çıkarılabilir', () async {
      final prefs = await _prefs();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(dashboardLayoutProvider, (_, next) {});
      addTearDown(sub.close);

      final notifier = container.read(dashboardLayoutProvider.notifier);
      notifier.addCard(DashboardCardType.dday);
      expect(
        container.read(dashboardLayoutProvider).map((c) => c.type),
        contains(DashboardCardType.dday),
      );

      notifier.removeCard(DashboardCardType.dday);
      expect(
        container.read(dashboardLayoutProvider).map((c) => c.type),
        isNot(contains(DashboardCardType.dday)),
      );
    });
  });

  group('tarih ayarı', () {
    test('seçilen tarih takvim günü olarak saklanır ve silinebilir', () async {
      final prefs = await _prefs();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(examDateProvider, (_, next) {});
      addTearDown(sub.close);

      // Saat bilgisi taşınmaz: kalıcı değer bir **an** değil takvim günüdür.
      await container
          .read(examDateProvider.notifier)
          .set(DateTime(2026, 6, 20, 13, 45));
      expect(prefs.getString(kExamDateKey), '2026-06-20');
      expect(container.read(examDateProvider), DateTime(2026, 6, 20));

      await container.read(examDateProvider.notifier).clear();
      expect(prefs.getString(kExamDateKey), isNull);
      expect(container.read(examDateProvider), isNull);
    });

    test('bozuk kalıcı değer çökmez, "seçilmedi"ye düşer', () {
      expect(decodeExamDay('bozuk-veri'), isNull);
      expect(decodeExamDay(null), isNull);
    });
  });
}
