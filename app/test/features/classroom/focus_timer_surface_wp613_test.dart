// WP-613 — tam ekran odak ekranının kaçırdığı İKİ düzeltme.
//
// 🔴 RİSK-1 (WP-561'in uygulanmamış yarısı): gece yarısını aşan koşuda "Bugün"
// odak ekranında şişiyordu. Kırpma tam olarak `liveStartedAt` + `nowInstant`
// argümanlarına bağlıdır; kart onları geçiyor, odak ekranı geçmiyordu. 23:00'da
// başlayan koşuda kart "1 sa 30 dk" derken odak "2 sa 30 dk" diyor, Durdur'da
// ise sayı çöküyordu (oturum `dayOf(start)` ile DÜNE yazılır).
//
// 🔴 RİSK-2: odak ekranında ayna koşusunu durdurmak çıkmaz sokaktı. Düğme ham
// tear-off'tu (`onPressed: notifier.stop`); `stopMirroredRun()` fırlattığında
// `VoidCallback` bağlamında hata hiçbir yere ulaşmıyordu — ne onay, ne mesaj,
// ne de çıkış yolu. Kart aynı kuralı doğru uyguluyordu.
//
// 🔴 Ölçmeyen kapı: WP-561 testleri yalnız SAF fonksiyonu ölçüyordu; hiçbir
// iddia "yüzey argümanı geçiyor mu" diye sormuyordu. Bu dosya yüzeyi çizer.
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
import 'package:online_study_room/features/classroom/widgets/focus_timer_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../support/istanbul_fixture.dart';

const _kMirrorBody = 'Bu, diğer cihazdaki sayacı da durduracak.';
const _kMirrorFailed =
    'Sayaç diğer cihazlarda durdurulamadı. Bağlantını kontrol edip tekrar dene.';

/// Gerçek notifier'ın (kanal/dinleyici kuran) `build()`'ini atlayan sahte:
/// state'i test sürer, ölçülen şey EKRANIN hesabı ve kablosudur.
class _FakeTimerNotifier extends StudyTimerNotifier {
  _FakeTimerNotifier(this._initial, {this.mirrorStopError});

  final StudyTimerState _initial;
  final Object? mirrorStopError;

  var mirrorStopCalls = 0;
  var plainStopCalls = 0;

  @override
  StudyTimerState build() => _initial;

  @override
  Future<void> stop({DateTime? at, String trigger = 'user_button'}) async {
    plainStopCalls++;
    state = const StudyTimerState();
  }

  @override
  Future<void> stopMirroredRun() async {
    mirrorStopCalls++;
    final error = mirrorStopError;
    if (error != null) throw error;
    state = const StudyTimerState();
  }
}

Future<void> _pumpFocus(
  WidgetTester tester,
  _FakeTimerNotifier notifier,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'timer_background_hint_seen': true,
  });
  final prefs = await SharedPreferences.getInstance();
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
        userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
        studyTimerProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(width: 380, height: 900, child: FocusTimerScreen()),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Ekrandaki "Bugün …" satırını döndürür.
String _todayLine(WidgetTester tester) {
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data;
    if (data != null && data.startsWith('Bugün ')) return data;
  }
  fail('"Bugün …" satırı ekranda yok');
}

/// `[atLeast, atMost]` aralığındaki her saniye için ekranda görünecek satır.
///
/// Metni elle ayrıştırmak yerine ekranın kullandığı biçimlendiricinin kendisi
/// kullanılır: `formatHumanSeconds` aktif dile göre "sa/dk/sn" ya da "h/m/s"
/// yazar, elle yazılmış bir regex testi sessizce etkisizleştirirdi.
List<String> _todayLines(int atLeast, int atMost) => <String>[
  for (var s = atLeast < 0 ? 0 : atLeast; s <= atMost; s++)
    'Bugün ${formatHumanSeconds(s)}',
];

/// Kurulum ile çizim arasında geçen gerçek zaman payı. Yakalanan hata saatler
/// mertebesinde; bu pay onun binde biri. ⚠️ Düşen testi yeşile almak için
/// yükseltilmez.
const int _driftSlackSeconds = 30;

void main() {
  testWidgets(
    'RİSK-1: gece yarısını aşan koşuda "Bugün" ŞİŞMEZ (kırpma uygulanır)',
    (tester) async {
      // Koşu 50 saat önce başladı: kırpma olmadan ekran "Bugün 50sa …" der.
      // Kırpma varsa yalnız BUGÜNE düşen kısım sayılır → her zaman < 24 sa.
      final startedAt = DateTime.now().subtract(const Duration(hours: 50));
      final notifier = _FakeTimerNotifier(
        StudyTimerState(
          isRunning: true,
          startedAt: startedAt,
          phase: TimerPhase.work,
        ),
      );

      await _pumpFocus(tester, notifier);
      final line = _todayLine(tester);

      const unclippedSeconds = 50 * 3600;
      expect(
        _todayLines(unclippedSeconds, unclippedSeconds + _driftSlackSeconds),
        isNot(contains(line)),
        reason:
            'ASIL BUG: odak ekranı canlı süreyi kırpmadan ekliyordu → '
            'ekranda "$line"; kart aynı anda bugüne düşen kısmı gösteriyordu',
      );

      // Doğrusu: yalnız BUGÜNE düşen kısım, yani İstanbul gün başından beri
      // geçen süre.
      final clipped = sinceIstanbulMidnight(DateTime.now()).inSeconds;
      expect(
        _todayLines(clipped - _driftSlackSeconds, clipped),
        contains(line),
        reason:
            'kırpma "her şeyi sıfırla" değil: bugüne düşen kısım sayılmalı; '
            'ekranda "$line"',
      );
    },
  );

  testWidgets(
    'KARŞI İDDİA: bugün başlayan koşuda canlı süre AYNEN sayılır',
    (tester) async {
      // Kırpmayı "her şeyi sıfırla" diye uygulamak da bir bug olurdu: bu iddia
      // olmadan `liveWorkSeconds: 0` sabotajı sessizce yeşil geçerdi.
      final liveWindow = backWithinIstanbulToday(const Duration(minutes: 20));
      final startedAt = DateTime.now().subtract(liveWindow);
      final notifier = _FakeTimerNotifier(
        StudyTimerState(
          isRunning: true,
          startedAt: startedAt,
          phase: TimerPhase.work,
        ),
      );

      await _pumpFocus(tester, notifier);
      final line = _todayLine(tester);

      // Kurulum ile çizim arasında birkaç saniye geçebilir; iddia mutlak sayı
      // değil, "canlı süre görünüyor mu".
      expect(
        _todayLines(
          liveWindow.inSeconds,
          liveWindow.inSeconds + _driftSlackSeconds,
        ),
        contains(line),
        reason: 'bugün başlayan koşunun süresi kırpılmamalı; ekranda "$line"',
      );
    },
  );

  testWidgets('RİSK-2: odakta ayna Durdur ÖNCE onay sorar', (tester) async {
    final notifier = _FakeTimerNotifier(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        isGlobalTimerMirror: true,
        globalTimerRunId: 'run-613',
        globalTimerRunRevision: 1,
      ),
    );

    await _pumpFocus(tester, notifier);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    expect(
      find.text(_kMirrorBody),
      findsOneWidget,
      reason:
          'ASIL BUG: odak ekranı başka cihazdaki sayacı onaysız kapatıyordu',
    );

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(notifier.mirrorStopCalls, 0);
    expect(notifier.state.isRunning, isTrue);

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();
    expect(notifier.mirrorStopCalls, 1);
    expect(notifier.state.isRunning, isFalse);
  });

  testWidgets('RİSK-2: ayna durdurma HATA verirse kullanıcıya söylenir', (
    tester,
  ) async {
    // Çıkmaz sokağın ta kendisi: sunucu reddi / ağ kopması. Eski kodda
    // `VoidCallback` bağlamında fırlayan hata hiçbir yere ulaşmıyordu.
    final notifier = _FakeTimerNotifier(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        isGlobalTimerMirror: true,
        globalTimerRunId: 'run-613',
        globalTimerRunRevision: 1,
      ),
      mirrorStopError: StateError('global_timer_mirror_identity_required'),
    );

    await _pumpFocus(tester, notifier);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Durdur'));
    await tester.pumpAndSettle();

    expect(notifier.mirrorStopCalls, 1);
    expect(
      find.text(_kMirrorFailed),
      findsOneWidget,
      reason:
          'kullanıcı Durdur\'a bastı, sayaç akmaya devam ediyor ve hiçbir şey '
          'söylenmiyordu — çıkmaz sokak',
    );
    expect(
      notifier.state.isRunning,
      isTrue,
      reason: 'başarısız durdurma aynayı sahte biçimde boşta göstermemeli',
    );
  });

  testWidgets('KARŞI İDDİA: kendi koşumuzda onay SORULMAZ', (tester) async {
    // Aksi hâlde düzeltme her Durdur'a bir diyalog ekleyen bir gerilemeye
    // dönüşürdü.
    final notifier = _FakeTimerNotifier(
      StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        phase: TimerPhase.work,
      ),
    );

    await _pumpFocus(tester, notifier);
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    expect(find.text(_kMirrorBody), findsNothing);
    expect(notifier.plainStopCalls, 1);
    expect(notifier.state.isRunning, isFalse);
  });
}
