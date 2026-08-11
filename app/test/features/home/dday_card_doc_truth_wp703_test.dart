// WP-703/2 — `dday_card.dart` bas yorumu artik yalan soyluyordu.
//
// ## ONCE OLCULDU (2026-08-11, bu dosyanin ilk kosumu)
//
// `app/lib/features/home/widgets/dday_card.dart:12` soyle diyordu:
//
//   /// Veri tamamen cihaz icindedir (`examListProvider`), yeni izin/veri yoktur.
//
// WP-694 bu cumleyi gecersiz kildi: `dday_prefs.dart` artik
// `ExamCountdownRepository` ile sunucuya yaziyor ve acilista sunucudan okuyor
// (`ExamListNotifier._pull`). Kart, kullanicinin **baska cihazinda** girilmis
// bir sinavi ciziyor; veri cihazi terk ediyor.
//
// ## Iddia neden iki parcali
// Yalniz metin arayan bir iddia "kelime polisi" olurdu; yalniz davranis olcen
// bir iddia zaten yesildi (senkron calisiyor) ve yorumu duzeltmezdi. Bu yuzden:
//   1. **Davranis** — kart, yerelde HIC kaydi olmayan bir cihazda sunucudaki
//      sinavi cizer. Bu, "veri tamamen cihaz icindedir" cumlesini olcerek
//      yalanlar.
//   2. **Belge** — (1) dogruysa dosyanin bas yorumu bunu yazmali ve eski
//      yalan cumleyi tasimamali.
//
// 🔴 Bu depoda yalan yorumun bedeli olculdu: "reflow yok" diyen yesil bir test
// proje sahibinin reddettigi davranisi kilitlemisti. Yorum, bir sonraki ajanin
// okudugu tek sozlesmedir.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/exam_countdown.dart';
import 'package:online_study_room/data/providers/exam_countdown_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_exam_countdown_repository.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/features/home/widgets/dday_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = 'user-1';
final _examDay = DateTime(2026, 8, 20);
final _now = DateTime.utc(2026, 8, 10, 9);

/// Kaynak dosyanin `class DDayCard` oncesindeki bas yorumu.
String _leadingDoc() {
  final source = File(
    'lib/features/home/widgets/dday_card.dart',
  ).readAsStringSync();
  final classAt = source.indexOf('class DDayCard');
  expect(
    classAt,
    greaterThan(0),
    reason: 'DDayCard sinifi bulunamadi; dosya tasinmis olabilir.',
  );
  return source.substring(0, classAt);
}

void main() {
  group('WP-703/2 — kartin bas yorumu gercegi anlatir', () {
    testWidgets('kart, yerelde HIC kaydi olmayan cihazda sunucudaki sinavi cizer', (
      tester,
    ) async {
      // Sunucu: baska cihazda girilmis tek sinav.
      final server = InMemoryExamCountdownRepository();
      await server.upsert(
        userKey: _user,
        entry: ExamCountdown(
          id: 'exam-1',
          name: 'YKS',
          day: _examDay,
          sortOrder: 0,
          isPriority: true,
          updatedAt: DateTime.utc(2026, 8, 1),
        ),
      );

      // Bu cihaz: bos yerel depo.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kExamListKey), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            examCountdownRepositoryProvider.overrideWithValue(server),
            examCountdownUserIdProvider.overrideWithValue(_user),
            ddayClockProvider.overrideWithValue(() => _now),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 340,
                  height: 260,
                  child: DDayCard(size: DashboardCardSize.medium),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('YKS'),
        findsOneWidget,
        reason:
            'Kart, cihazda hic kaydi olmayan bir sinavi cizmedi. Bu iddia '
            'duserse senkron kopmus demektir (yorum yine yanlis olur).',
      );
      expect(
        server.loads,
        greaterThan(0),
        reason: 'Sunucu hic okunmadi; olculen sey yerel kopya olurdu.',
      );
    });

    test('bas yorum "yalniz cihaz ici" iddiasini tasimaz', () {
      final doc = _leadingDoc();
      // 🔴 Cumlenin kendisi aranir; WP-694 oncesi metin buydu.
      expect(
        doc.contains('Veri tamamen cihaz'),
        isFalse,
        reason:
            'dday_card.dart bas yorumu hala "Veri tamamen cihaz icindedir '
            '(examListProvider), yeni izin/veri yoktur" diyor. WP-694 bu '
            'cumleyi gecersiz kildi: kayitlar ExamCountdownRepository ile '
            'sunucuya yaziliyor.',
      );
      expect(
        doc.contains('yeni izin/veri yoktur'),
        isFalse,
        reason:
            'Geri sayim artik hesaba bagli sunucu satiri uretiyor; "yeni veri '
            'yoktur" cumlesi yanlis.',
      );
    });

    test('bas yorum WP-694 senkronunu adiyla anar', () {
      final doc = _leadingDoc();
      expect(
        doc.contains('WP-694'),
        isTrue,
        reason:
            'Yorum, davranisi degistiren WP\'yi anmali; okuyan ajan zinciri '
            'takip edebilsin.',
      );
      expect(
        doc.contains('sunucu'),
        isTrue,
        reason: 'Yorum, verinin cihazi terk ettigini soylemeli.',
      );
    });
  });
}
