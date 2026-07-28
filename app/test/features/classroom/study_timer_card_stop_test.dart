import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'package:online_study_room/core/stats/istanbul_calendar.dart';

import '../../support/async_wait.dart';
import '../../support/istanbul_fixture.dart';

/// Gerçek notifier'ın (kanal/dinleyici kurulumu olan) build()'ini atlayan sahte.
/// Testte state'i biz elle sürüyoruz; amaç UI'ın hesabını doğrulamak.
class _FakeTimerNotifier extends StudyTimerNotifier {
  _FakeTimerNotifier(this._initial);

  final StudyTimerState _initial;

  @override
  StudyTimerState build() => _initial;

  void push(StudyTimerState next) => state = next;
}

class _MirrorTimerNotifier extends StudyTimerNotifier {
  _MirrorTimerNotifier(this._initial);

  final StudyTimerState _initial;
  var mirrorStopCalls = 0;

  @override
  StudyTimerState build() => _initial;

  @override
  Future<void> stopMirroredRun() async {
    mirrorStopCalls++;
    state = const StudyTimerState();
  }
}

/// Testin kurulumu ile kartın ilk çizimi arasında geçen gerçek zaman payı.
///
/// Yakalanmak istenen hata `liveSeconds` (≈1 saat) kadarlık bir zıplama, yani
/// bu pay gerçek hatanın **otuzda biri**nden küçük — hassasiyeti düşürmüyor.
/// ⚠️ Düşen bir testi yeşile almak için yükseltilmez.
const int _driftSlackSeconds = 120;

/// Metni ayrıştırmak yerine **aralıktaki her saniyeyi biçimlendirip** ekranda
/// arar. Böylece dil ekleri (`sn`/`s`) ve `activeAppLocale` genel durumu testin
/// derdi olmaktan çıkar — kartla birebir aynı biçimlendirici kullanılır.
int? _findVisibleSecondsInRange(WidgetTester tester, int atLeast, int atMost) {
  final byText = <String, int>{
    for (var s = atLeast; s <= atMost; s++) formatHumanSeconds(s): s,
  };
  int? best;
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final seconds = byText[widget.data];
    if (seconds == null) continue;
    if (best == null || seconds > best) best = seconds;
  }
  return best;
}

List<String> _visibleTexts(WidgetTester tester) => [
  for (final widget in tester.widgetList<Text>(find.byType(Text)))
    if (widget.data != null) widget.data!,
];

/// Ekranda `[atLeast, atMost]` aralığına düşen bir süre metni belirene kadar
/// kareleri ilerletir ve **görülen** değeri döndürür.
///
/// Tam eşleşme beklemek burada kararsızlığın ta kendisiydi: kart canlı süreyi
/// gerçek saatten okuduğu için beklenen sayı, test kurulumu 1 saniyeyi aşar
/// aşmaz kaçırılıyor ve bir daha yakalanamıyordu.
Future<int> waitForTodayTotal(
  WidgetTester tester, {
  required int atLeast,
  required int atMost,
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final found = _findVisibleSecondsInRange(tester, atLeast, atMost);
    if (found != null) return found;
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'waitForTodayTotal zaman aşımına uğradı (${timeout.inSeconds} sn): '
        '[$atLeast, $atMost] aralığında süre yok. '
        'Ekrandaki metinler: ${_visibleTexts(tester)}'
        '${reason == null ? '' : ' — $reason'}',
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('WP-379: ayna Durdur onaysız global koşuya dokunmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final mirror = _MirrorTimerNotifier(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        isGlobalTimerMirror: true,
        globalTimerRunId: 'run-379',
        globalTimerRunRevision: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userSessionsProvider.overrideWith(
            (_) => Stream.value(const <StudySession>[]),
          ),
          userSubjectsProvider.overrideWith(
            (_) => Stream.value(const <Subject>[]),
          ),
          dailyGoalMinutesProvider.overrideWithValue(240),
          userGroupProvider.overrideWithValue(
            const AsyncData<StudyGroup?>(null),
          ),
          studyTimerProvider.overrideWith(() => mirror),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bu, diğer cihazdaki sayacı da durduracak.'),
      findsOneWidget,
    );

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(mirror.mirrorStopCalls, 0);
    expect(mirror.state.isRunning, isTrue);

    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Durdur').last);
    await tester.pumpAndSettle();
    expect(mirror.mirrorStopCalls, 1);
    expect(mirror.state.isRunning, isFalse);
  });

  testWidgets('WP-250: Durdur sırasında "Bugün" toplamı zıplamaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    // WP-296 bu testi bir kez saatten kurtarmaya çalıştı ama gün başlangıcını
    // **yerel** takvimle aldı; ürünün gün sınırı ise `Europe/Istanbul`. UTC
    // koşucuda 21:00 = İstanbul 00:00 olduğu için kayıt düne düşüyor,
    // `dailyTotals` bugüne 0 yazıyor ve toplam 2 saat yerine 1 saat çıkıyordu
    // — v49 sürümünü kıran hata buydu. Artık geriye gidiş **İstanbul günü**
    // içinde tutuluyor: gün başından beri 1 saat geçmemişse pencere kısalır,
    // beklenen toplam da ona göre hesaplanır.
    final liveWindow = backWithinIstanbulToday(const Duration(hours: 1));
    final liveSeconds = liveWindow.inSeconds;
    final startedAt = now.subtract(liveWindow);
    const recordedSeconds = 3600;
    final expectedTotal = recordedSeconds + liveSeconds;

    // Bugün zaten kayıtlı bir saat.
    final recordedSession = StudySession(
      id: 'rec-1',
      userId: 'u1',
      start: startedAt,
      end: startedAt.add(const Duration(seconds: recordedSeconds)),
      durationSeconds: recordedSeconds,
      source: StudySource.live,
    );
    // Durdurulan oturum DB'ye düştüğünde eklenecek satır.
    final stoppedSession = StudySession(
      id: 'rec-2',
      userId: 'u1',
      start: startedAt,
      end: now,
      durationSeconds: liveSeconds,
      source: StudySource.live,
    );

    final sessions = StreamController<List<StudySession>>.broadcast();
    addTearDown(sessions.close);

    final running = StudyTimerState(
      isRunning: true,
      startedAt: startedAt,
      phase: TimerPhase.work,
    );
    final fake = _FakeTimerNotifier(running);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userSessionsProvider.overrideWith((ref) => sessions.stream),
          userSubjectsProvider.overrideWith(
            (ref) => Stream.value(const <Subject>[]),
          ),
          dailyGoalMinutesProvider.overrideWithValue(240),
          userGroupProvider.overrideWithValue(
            const AsyncData<StudyGroup?>(null),
          ),
          studyTimerProvider.overrideWith(() => fake),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
          ),
        ),
      ),
    );

    sessions.add([recordedSession]);
    // Akış olayı + yeniden çizim iki ayrı tura düşebilir; tek `pump()`
    // hızlı makinede yetiyor ama CI koşucusunda yetmiyordu (v49 kırılması).
    //
    // 🔴 WP-322 — kalan kararsızlığın KÖK NEDENİ buradaydı.
    // Kart canlı süreyi HER karede gerçek saatten hesaplar
    // (`study_timer_card.dart:130-132` → `DateTime.now().difference(startedAt)`).
    // Yukarıdaki `now` yakalandıktan sonra `pumpWidget` + prefs kurulumu
    // **1 saniyeden uzun sürerse** ekrandaki toplam `expectedTotal + 1` olur
    // ve saat ileri aktığı için bir daha ASLA `expectedTotal`e dönmez →
    // tam eşleşme bekleyen `pumpUntilFound` 10 sn dönüp düşerdi. Geliştirici
    // makinesinde kurulum < 1 sn olduğu için geçiyor, tam suit yükü altında
    // düşüyordu: "bir koşumda düştü, ikincide geçti" tam olarak buydu.
    //
    // Çözüm süreyi dondurmak değil — testin **iddiası** zaten mutlak sayı
    // değil: yakalamak istediği hata `liveSeconds` (≈3600 sn) kadarlık bir
    // ZIPLAMA. Birkaç saniyelik koşum sapmasına tolerans vermek bu
    // hassasiyeti azaltmaz; aşağıdaki olumsuz iddia payın 30 katı uzakta.
    final observedTotal = await waitForTodayTotal(
      tester,
      atLeast: expectedTotal,
      atMost: expectedTotal + _driftSlackSeconds,
      reason: 'kayıtlı + canlı toplamı ekranda görünmeli',
    );
    expect(
      observedTotal,
      lessThan(expectedTotal + liveSeconds),
      reason: 'canlı süre daha ilk çizimde iki kez sayılmamalı',
    );

    // --- Durdur'a basıldı: notifier ilk await'ten önce bunu yayınlar. ---
    fake.push(
      running.copyWith(
        isStopping: true,
        settlingSeconds: liveSeconds,
        settlingBaseline: recordedSeconds,
        settlingDay: istanbulDay(now),
      ),
    );
    await tester.pump();
    expect(
      find.text(formatHumanSeconds(expectedTotal)),
      findsWidgets,
      // Not: settling* alanlarını test verdiği için buradan sonrası
      // gerçek saatten bağımsız ve **tam belirlenimli**dir.
      reason: 'durdurma anında toplam değişmemeli',
    );

    // --- RTT penceresi: kayıt yerel cache'e düştü, stream emit etti,
    //     ama `_finish()` HENÜZ çalışmadı (isRunning hâlâ true). ---
    sessions.add([recordedSession, stoppedSession]);
    // Olumsuz iddia: sayı **değişmemeli**. Tek `pump()` ile yetinilseydi
    // olay henüz işlenmemiş olabilir ve test hatayı kaçırıp boş yere geçerdi.
    await pumpFrames(tester);
    expect(
      find.text(formatHumanSeconds(expectedTotal)),
      findsWidgets,
      reason: 'ASIL BUG: burada canlı süre iki kez sayılıyordu',
    );
    expect(
      find.text(formatHumanSeconds(expectedTotal + liveSeconds)),
      findsNothing,
    );

    // --- `_finish()` çalıştı. ---
    fake.push(
      const StudyTimerState().copyWith(
        settlingSeconds: liveSeconds,
        settlingBaseline: recordedSeconds,
        settlingDay: istanbulDay(now),
      ),
    );
    await tester.pump();
    expect(find.text(formatHumanSeconds(expectedTotal)), findsWidgets);
  });
}
