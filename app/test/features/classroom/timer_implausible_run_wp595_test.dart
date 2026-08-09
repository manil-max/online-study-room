// WP-595: sayac 6 saati gectiginde kullaniciya SOYLENIR.
//
// Olay (gercek kullanici, 2026-08-08 gecesi): sayac 22:40'ta basladi, sabah
// 10:02'de durduruldu, 11 sa 22 dk "calisma" kaydedildi, XP + basarim verildi.
// Kullanici calisma kaydini sildi; XP ve basarim GITMEDI (sunucuda `xp_ledger`
// append-only, `gamification_profiles.xp` biriken sayac). Yani Durdur'a basmak
// geri alinamaz bir islemdi ve hicbir yerde oyle yazmiyordu.
//
// 🔴 `TimerVerificationNotice` bu WP'den once `SizedBox.shrink()` idi: iki
// sayac yuzeyinde de ciziliyor ama hicbir sey soylemiyordu. Duzeltmeyi geri
// alip (govdeyi `SizedBox.shrink()` yapip) bu dosyanin KIRMIZI dondugu
// dogrulandi.
//
// 🔴 Iki yonlu iddia zorunlu: uyari hem esigin USTUNDE ciktigi hem esigin
// ALTINDA cikmadigi olculur. Tek yonlu olsa "her zaman uyar" diyen bozuk bir
// surum de yesil gecerdi.
//
// 🔴 Zaman ENJEKTE edilir (`now:`), duvar saatinden okunmaz — gece yarisi
// flake'i bu repoda iki kez surum kosumunu kirdi. Riverpod tuzagi da yok:
// widget dogrudan pump edilir, autoDispose provider'a bagli sayac iddiasi
// kurulmaz.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/implausible_run_guard.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/timer_mode_controls.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Olayin gercek baslangic ani (gunlukten: run 6191a3982963).
final _startedAt = DateTime.utc(2026, 8, 8, 19, 40, 28);

Future<void> _pumpNotice(
  WidgetTester tester, {
  required StudyTimerState timer,
  required DateTime now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: TimerVerificationNotice(timer: timer, now: now),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('11 sa 22 dk suren kosuda uyari CIKAR ve sureyi yazar', (
    tester,
  ) async {
    await _pumpNotice(
      tester,
      timer: StudyTimerState(isRunning: true, startedAt: _startedAt),
      // Gunlukten: stop_requested elapsed_seconds = 40938.
      now: _startedAt.add(const Duration(seconds: 40938)),
    );

    expect(find.byKey(kImplausibleRunNoticeKey), findsOneWidget);

    // Sure kullaniciya gorunur olmali: "kac saattir aciksin" sorusunun cevabi
    // uyarinin kendisidir. Locale test icinde `tr` sabitlendi.
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(kImplausibleRunNoticeKey),
        matching: find.byType(Text),
      ),
    );
    expect(text.data, contains('11sa 22dk'));

    // Sonucun geri alinamazligi da yazmali — olayin can alici noktasi buydu.
    expect(text.data, contains('XP'));
  });

  testWidgets('esigin TAM UZERINDE (6 sa) uyari CIKAR', (tester) async {
    await _pumpNotice(
      tester,
      timer: StudyTimerState(isRunning: true, startedAt: _startedAt),
      now: _startedAt.add(kImplausibleRunThreshold),
    );
    expect(find.byKey(kImplausibleRunNoticeKey), findsOneWidget);
  });

  testWidgets('esigin ALTINDA (5 sa 59 dk) uyari CIKMAZ', (tester) async {
    await _pumpNotice(
      tester,
      timer: StudyTimerState(isRunning: true, startedAt: _startedAt),
      now: _startedAt.add(const Duration(hours: 5, minutes: 59)),
    );
    expect(find.byKey(kImplausibleRunNoticeKey), findsNothing);
  });

  testWidgets('normal bir kosuda (45 dk) uyari CIKMAZ', (tester) async {
    await _pumpNotice(
      tester,
      timer: StudyTimerState(isRunning: true, startedAt: _startedAt),
      now: _startedAt.add(const Duration(minutes: 45)),
    );
    expect(find.byKey(kImplausibleRunNoticeKey), findsNothing);
  });

  testWidgets('sayac DURUYORSA eski baslangicta bile uyari CIKMAZ', (
    tester,
  ) async {
    await _pumpNotice(
      tester,
      timer: StudyTimerState(isRunning: false, startedAt: _startedAt),
      now: _startedAt.add(const Duration(hours: 20)),
    );
    expect(find.byKey(kImplausibleRunNoticeKey), findsNothing);
  });
}
