import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/onboarding/onboarding_prefs.dart';
import 'package:online_study_room/main.dart';

/// WP-516 — Android **calisma zamani** sayac smoke kapisi.
///
/// 🔴 Bu dosyanin varlik sebebi olculdu: v58'de geri sayim ve pomodoro
/// aciliste cokuyordu (Dart `prefs.setInt` Android'e `putLong` yazar; native
/// taraf ayni anahtari `getInt` ile okuyunca `ClassCastException` firlatir ve
/// receiver/servis icinde bu **surecin tamamini** oldurur). O turda 18 kapinin
/// hicbiri kirmizi donmedi: `integration` kapisi `-d windows` ile kosuyor,
/// `android-unit` JVM'de sahte prefs kullaniyor, `androidTest/` bostu. Yani
/// hicbir kapi gercek bir Android surecinde sayaci calistirmiyordu.
///
/// Bu test o bosluga tam olarak oturur ve **iki katmanda** olcer:
///
/// 1. **Yazici sozlesmesi (yaris yok).** `start()` doner donmez, native yazim
///    daha diske dusmeden, Dart'in kendi prefs onbelleginde her sayisal sayac
///    anahtari `int` mi diye bakilir. `setInt` -> `setDouble`/`setString`
///    tipinde bir kayma burada **kesin** yakalanir: native `TimerStateStore`
///    ayni anahtarlari `putLong` ile geri yazdigi icin, yalniz diskteki son
///    degere bakan bir olcum kaymayi maskeleyebilirdi.
/// 2. **Cihaz round-trip.** `prefs.reload()` ile degerler gercek Android
///    `SharedPreferences` deposundan yeniden okunur; boylece plugin koprusunun
///    tamsayiyi tamsayi olarak dondurdugu ve native yazimin Dart yazimiyla
///    ayni tipte bulustugu **cihazda** dogrulanir.
///
/// Ayrica her adimdan sonra surecin ayakta ve sayac ekraninin cizili oldugu
/// dogrulanir; surec olurse `flutter test` zaten "Lost connection to device"
/// ile kirmizi doner, kalan kanit CI'daki `logcat -b crash` taramasidir.
///
/// Not: prefs **mock'lanmaz**. `SharedPreferences.setMockInitialValues` Dart
/// tarafinda kalir ve tam da olcmek istedigimiz Dart <-> native koprusunu hic
/// kurmaz.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sayac ucu modda da Android surecinde baslar ve durur', (
    tester,
  ) async {
    expect(
      defaultTargetPlatform,
      TargetPlatform.android,
      reason:
          'Bu smoke yalniz Android kapisi icindir (ci.yml `android-emulator`, '
          'scripts/test_all.py `android-smoke`). Baska bir hostta kosuyorsa '
          'kapi yanlis baglanmistir.',
    );

    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();

    final auth = InMemoryAuthRepository();
    final profile = await auth.signUp(
      email: 'android-smoke@ornek.com',
      password: '123456',
      displayName: 'Android Smoke',
    );
    await preferences.setBool(onboardingCompletedKeyFor(profile.id), true);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authRepositoryProvider.overrideWithValue(auth),
        groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OnlineStudyRoomApp(),
      ),
    );

    // `pumpAndSettle` bilerek kullanilmiyor: sayac karti bosta bile periyodik
    // tick uretir, kuyruk hicbir zaman bosalmaz ve kapi zaman asimina duserdi.
    await _pumpUntil(
      tester,
      () => find.byType(StudyTimerCard).evaluate().isNotEmpty,
      describe: 'Acilista sayac karti cizilmesi',
    );

    final timer = container.read(studyTimerProvider.notifier);

    // Sira kart ile ayni: once hedefli modlar (v58'de cokenler), sonra
    // kronometre (hedef anahtari silindigi icin v58'de ayakta kalan mod).
    for (final mode in const [
      TimerMode.countdown,
      TimerMode.pomodoro,
      TimerMode.stopwatch,
    ]) {
      final label = mode.name;
      timer.setMode(mode);
      // En kisa hedef: 3 saniyelik olcum penceresinde faz gecisi olmaz, ama
      // hedef anahtari yine de yazilir (cokusun tetikleyicisi buydu).
      timer.setCountdownMinutes(kMinTimerMinutes);
      timer.setPomodoro(
        workMinutes: kMinTimerMinutes,
        breakMinutes: kMinTimerMinutes,
        cycles: kMinPomodoroCycles,
      );
      await tester.pump();

      timer.start();
      // Katman 1 — native geri yazim yarisa girmeden, Dart'in yazdigi tip.
      _expectTimerPrefsAreInts(
        preferences,
        mode: mode,
        stage: '$label baslat (Dart yazimi)',
      );

      await _pumpUntil(
        tester,
        () => container.read(studyTimerProvider).isRunning,
        describe: '$label modunda sayacin calisir duruma gecmesi',
      );
      // Native foreground service + widget tazeleme bu pencerede kosar; v58'de
      // surec tam burada oluyordu.
      await _pumpFor(tester, const Duration(seconds: 3));
      await _expectAliveAndDrawn(tester, preferences, stage: '$label calisiyor');
      // Katman 2 — az onceki `reload()` degerleri cihaz deposundan tazeledi.
      // Burada YALNIZ tip pinlenir, varlik pinlenmez: ayni prefs dosyasina Dart
      // ve native birlikte yazar, `TimerStateStore.writeRunning(...).commit()`
      // butun haritayi bir kerede diske yazar ve Dart'in az once yazdigi
      // yalniz-Dart anahtarlari (accumulated/command_seq) o anda dosyada
      // olmayabilir. Olculdu: `started_at_ms`/`cycle` (native de yazar) vardi,
      // `accumulated_seconds` yoktu. Varlik sozlesmesi katman 1'de yarissiz
      // pinlendigi icin burada tip yeterlidir.
      _expectTimerPrefsAreInts(
        preferences,
        mode: mode,
        stage: '$label calisiyor (cihaz prefs round-trip)',
        requirePresence: false,
      );

      await timer.stop();
      await _pumpUntil(
        tester,
        () => !container.read(studyTimerProvider).isRunning,
        describe: '$label modunda sayacin durmasi',
      );
      await _expectAliveAndDrawn(tester, preferences, stage: '$label durduruldu');
    }
  });
}

/// Dart'in tamsayi olarak yazdigi, native tarafin tamsayi olarak okudugu aktif
/// kosu anahtarlari. Karsiliklari: `TimerStateStore.KEY_*` ve
/// `widgets/StudyWidgetProviders.kt` (`flutter.` on eki native tarafta eklenir).
///
/// Kume bilerek **yalniz `_persistActiveTimer`'in yazdigi** anahtarlardan olusur:
/// o yazim `start()` icinde senkron kostugu icin olcum ile yazim arasina hicbir
/// async adim girmez. Ayar anahtarlari (`timer_countdown_min`, `timer_work_min`,
/// `timer_break_min`, `timer_cycles`) bilerek DISARIDA: (1) native taraf onlari
/// hic okumaz, yani tip sozlesmesinin parcasi degiller; (2) `setInt`in platform
/// yazimi diske dusmeden `_reconcileBackgroundTimerImpl`
/// (`study_providers.dart:1375`) `prefs.reload()` cagirirsa onbellek diskle
/// degistirilir ve deger anlik kaybolur — olculdu, kapiyi yanlis yerden
/// kirmiziya dusuruyordu.
const List<String> _kIntTimerKeys = [
  'timer_active_started_at_ms',
  'timer_active_cycle',
  'timer_active_accumulated_seconds',
  'timer_active_command_seq',
];

/// Hedef suresi: geri sayim/pomodoroda yazilir, kronometrede **silinir**.
/// v58'de kronometrenin ayakta kalmasinin sebebi tam olarak bu silmeydi.
const String _kTargetSecondsKey = 'timer_active_target_seconds';

void _expectTimerPrefsAreInts(
  SharedPreferences preferences, {
  required TimerMode mode,
  required String stage,
  bool requirePresence = true,
}) {
  for (final key in _kIntTimerKeys) {
    final value = preferences.get(key);
    if (requirePresence) {
      expect(
        value,
        isNotNull,
        reason:
            '$stage: `$key` hic yazilmamis. Sayac durumu native tarafa eksik '
            'gidiyor demektir.',
      );
    } else if (value == null) {
      continue;
    }
    expect(
      value,
      isA<int>(),
      reason:
          '$stage: `$key` ${value.runtimeType} olarak yazilmis. Native taraf '
          'bu anahtari tamsayi bekler (TimerStateStore); tip kaymasi v58 '
          "geri sayim/pomodoro cokmesinin ta kendisidir.",
    );
  }

  final target = preferences.get(_kTargetSecondsKey);
  if (mode == TimerMode.stopwatch) {
    if (requirePresence) {
      expect(
        target,
        isNull,
        reason:
            '$stage: kronometrede `$_kTargetSecondsKey` silinmeli; kalirsa '
            'widget bitmeyen bir geri sayim cizer.',
      );
    }
  } else if (requirePresence || target != null) {
    expect(
      target,
      isA<int>(),
      reason:
          '$stage: `$_kTargetSecondsKey` ${target.runtimeType} olarak '
          'yazilmis. Widget ve servis bu anahtari tamsayi okur.',
    );
  }
}

/// Surec ayakta mi + sayac ekrani hala cizili mi?
///
/// `reload()` gercek bir platform kanali turudur: surec olmusse koşum zaten
/// "Lost connection to device" ile biter, ayakta ise degerler cihaz
/// deposundan tazelenmis olur (katman 2 olcumunun girdisi).
Future<void> _expectAliveAndDrawn(
  WidgetTester tester,
  SharedPreferences preferences, {
  required String stage,
}) async {
  await preferences.reload();
  expect(
    find.byType(StudyTimerCard),
    findsWidgets,
    reason: '$stage: sayac ekrani cizili degil.',
  );
  expect(
    tester.takeException(),
    isNull,
    reason: '$stage: yakalanmamis Flutter istisnasi var.',
  );
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  final deadline = DateTime.now().add(total);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() ready, {
  required String describe,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('$describe: $timeout icinde gerceklesmedi.');
}
