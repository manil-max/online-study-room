// WP-819 — sayaç kartındaki HEDEF ÇUBUĞU da artık "0" iddia etmiyor.
//
// 🔴 WP-817 kartın üst satırındaki "Bugün" değerini dürüst yaptı ama aynı
// yalan `_GoalProgress` bloğunda sürüyordu: `%0`, `0sn / 4sa` ve dolu bir
// ilerleme çubuğu — üstelik oturumlar HENÜZ YÜKLENMEMİŞKEN.
//
// Neden gözden kaçtı ve neden önemli: blok yalnız `showSecondary`
// (hücre yüksekliği >= `kTimerFullMinHeight` = 400) iken çizilir. Dar
// telefonda hiç görünmez; **masaüstünde ve geniş kartta görünür**. WP-817'nin
// testleri 260 px'te koşuyordu, yani bu blok o ölçümlerin hiçbirine girmedi.
// Düzeltmenin buraya uğramaması, kusurun tam olarak sahibin kullandığı
// yüzeyde açık kalması demekti.
//
// 🔴 Bu dosyanın ilk iddiası bloğun GERÇEKTEN ÇİZİLDİĞİdir. O olmadan bütün
// `findsNothing` iddiaları boşa geçerdi — bugün bu depoda tam olarak öyle bir
// zayıf test yakalandı (veri ilgili dalı hiç uyarmıyordu).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/utils/duration_format.dart';

import '../../support/istanbul_fixture.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Blok yalnız yükseklik >= [kTimerFullMinHeight] iken çizilir.
const double _tallEnough = kTimerFullMinHeight + 240;

/// Bugüne düşen, İstanbul gününde kalan bir oturum.
///
/// 🔴 WP-821/2: ilk hâli `DateTime(now.year, now.month, now.day, 12)` idi —
/// yani YEREL öğlen. Kendi makinemde (UTC+3) doğruydu, CI'da (UTC) yanlış:
/// 21:34 UTC'de yerel gün 7 Eylül, İstanbul günü ise 8 Eylül. Oturum düne
/// düştü ve `%25` iddiası kırmızı oldu. Gece yarısı tuzağının **aynadaki
/// hâli**: bu kez saat değil SAAT DİLİMİ kaydırdı.
StudySession _todaySession(int seconds) {
  final safe = agoWithinIstanbulToday(const Duration(hours: 1));
  return StudySession(
    id: 's1',
    userId: 'u1',
    start: safe,
    end: safe.add(Duration(seconds: seconds)),
    durationSeconds: seconds,
    source: StudySource.live,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Stream<List<StudySession>> sessions,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(520, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userSessionsProvider.overrideWith((ref) => sessions),
        userSubjectsProvider.overrideWith(
          (ref) => Stream.value(const <Subject>[]),
        ),
        // 4 saat = 240 dk. "%25" ve "1sa / 4sa" bu ayardan turer.
        dailyGoalMinutesProvider.overrideWithValue(240),
        userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(width: 480, height: _tallEnough, child: StudyTimerCard()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// Hedef cubugunun `value`si. `null` = BELIRSIZ ("bilmiyorum").
double? _barValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator).first,
    )
    .value;

void main() {
  late String goalLabel;

  setUpAll(() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    goalLabel = l10n.classroomGunlukHedef;
  });

  // --- 0. NOBETCI: blok gercekten ciziliyor mu -----------------------------
  testWidgets('🔴 NOBETCI: hedef cubugu bu olcude GERCEKTEN cizilir', (
    tester,
  ) async {
    await _pump(tester, sessions: Stream.value([_todaySession(3600)]));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text(goalLabel),
      findsOneWidget,
      reason:
          'Blok cizilmiyorsa asagidaki butun "yok" iddialari BOSA gecer. Bu '
          'satir olmadan dosya hicbir sey kanitlamaz.',
    );
  });

  // --- 1. YUKLENIRKEN hicbir sayi iddia edilmez ----------------------------
  testWidgets('yuklenirken %0 ve 0sn YAZMAZ, isarete duser', (tester) async {
    // Hic emisyon yapmayan akis: cihazda ag turunun beklendigi kare.
    await _pump(tester, sessions: StreamController<List<StudySession>>().stream);

    expect(find.text(goalLabel), findsOneWidget, reason: 'Blok cizilmedi.');
    expect(
      find.text('%0'),
      findsNothing,
      reason:
          'Yuzde 0 "bugun hic calismadin" demektir; oysa henuz olculmedi.',
    );
    expect(
      find.text('${formatHumanSeconds(0)} / ${formatHumanSeconds(240 * 60)}'),
      findsNothing,
      reason:
          'Sifir sure / hedef satiri ayni yanlis iddianin sure halidir: '
          '"bugun hic calismadin".',
    );
    expect(
      find.text(kUnknownMetric),
      findsWidgets,
      reason: 'Bilinmeyen sayinin yerinde isaret durmali.',
    );
    expect(
      _barValue(tester),
      isNull,
      reason:
          'Dolu bir cubuk da bir SAYI iddiasidir. `0` cizmek "bugun hic '
          'calismadin" demektir; bilinmiyorken cubuk BELIRSIZ olmali.',
    );
    // Bicim testte SABIT YAZILMAZ: uretimdeki bicimlendiriciden turetilir,
    // yoksa bicim degisince test kusuru degil kendini olcer.
    final goalText = formatHumanSeconds(240 * 60);
    expect(
      find.text('$kUnknownMetric / $goalText'),
      findsOneWidget,
      reason:
          'Hedef BILINIR (kullanicinin kendi ayari); yalniz bugunku sure '
          'isarete duser. Hedefi de gizlemek bilgi kaybi olurdu.',
    );
  });

  // --- 2. HATA halinde da sifir iddia edilmez ------------------------------
  testWidgets('hata halinde de %0 yazmaz', (tester) async {
    await _pump(
      tester,
      sessions: Stream<List<StudySession>>.error(StateError('ag yok')),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(goalLabel), findsOneWidget, reason: 'Blok cizilmedi.');
    expect(
      find.text('%0'),
      findsNothing,
      reason:
          'Hata halinde "0" iddiasi KALICIDIR: kullanici gununu kaybettigini '
          'sanir ve bunu duzeltecek hicbir sey olmaz.',
    );
    expect(find.text(kUnknownMetric), findsWidgets);
    expect(_barValue(tester), isNull);
  });

  // --- 3. VERI GELINCE gercek sayi cizilir (duzeltme ozelligi oldurmedi) ---
  testWidgets('veri gelince GERCEK yuzde ve sure cizilir', (tester) async {
    await _pump(tester, sessions: Stream.value([_todaySession(3600)]));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('%25'),
      findsOneWidget,
      reason: '3600 sn / 14400 sn = %25. Duzeltme gercek sayiyi de gizlerse '
          'care hastaliktan kotu olurdu.',
    );
    expect(
      find.text('${formatHumanSeconds(3600)} / ${formatHumanSeconds(240 * 60)}'),
      findsOneWidget,
    );
    expect(
      find.text(kUnknownMetric),
      findsNothing,
      reason: 'Veri varken bilinmiyor isareti kalmamali.',
    );
    expect(
      _barValue(tester),
      closeTo(0.25, 0.001),
      reason: 'Veri gelince cubuk gercek orani cizmeli, belirsiz kalmamali.',
    );
  });
}
