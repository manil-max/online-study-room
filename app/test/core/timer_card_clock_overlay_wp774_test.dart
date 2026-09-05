import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP-774 (sahip, cihazda, v77) — uc istek, uc kablo:
///  1. Live Update karti "bos bildirim gibi": govde satirina canli `MM:SS`.
///  2. Yuzen serit cip gibi gorunsun; durunca KAYBOLMASIN, yeniden
///     baslatilabilsin.
///  3. Baslat her yerde son secili dersle (serit widget'in yolunu kullanir).
///
/// Bu deponun tekrar eden kusuru "bitmis arka uc, baglanmamis on uc";
/// asagidaki iddialar kablolari olcer, sonucu degil (o cihaz kaniti).
void main() {
  const root = 'android/app/src/main/';
  String code(String path) => File('$root$path')
      .readAsStringSync()
      .split('\n')
      .where((line) {
        final s = line.trimLeft();
        return !s.startsWith('//') && !s.startsWith('*') && !s.startsWith('/*');
      })
      .join('\n');

  final service = code(
    'kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt',
  );
  final overlay = code(
    'kotlin/com/manilmax/online_study_room/overlay/TimerOverlay.kt',
  );
  final layout = File(
    '${root}res/layout/timer_overlay_pill.xml',
  ).readAsStringSync();

  test('terfi eden kartin govdesi canli saat tasir ve saniyede bir yenilenir',
      () {
    // WP-775: saat BASLIK (Samsung Saat gibi), durum satiri altinda; cip
    // metni de ayni saat. Kronometre yok (cift saat kusuru).
    final promoted = service.substring(service.indexOf('promotedCardStatusLine('));
    expect(promoted, contains('.setContentTitle(clock)'));
    expect(promoted, contains('.setShortCriticalText(clock)'));
    expect(promoted, contains('.setUsesChronometer(false)'));
    expect(service, contains('scheduleCardTick(startedAtMs)'));
    expect(service, contains('CARD_TICK_TOKEN'));
    // Ekran kapaliyken bildirim gonderilmez; yalniz durum yoklanir.
    expect(service, contains('isInteractive'));
    // Her durdurma yolu sayaci iptal eder; yoksa durmus sayac icin saniyede
    // bir kart gonderilirdi.
    expect(
      RegExp(r'removeCallbacksAndMessages\(CARD_TICK_TOKEN\)')
          .allMatches(service)
          .length,
      greaterThanOrEqualTo(3),
    );
  });

  test('serit durunca kaybolmaz: kosma sarti kalkti, bosta Baslat cizilir', () {
    expect(
      overlay,
      contains('fun shouldShow(enabled: Boolean, permitted: Boolean): Boolean'),
    );
    expect(overlay, isNot(contains('running: Boolean): Boolean')));
    // WP-775: dugme metinli hap -- kosarken beyaz "Durdur", bosta sari "Baslat".
    expect(overlay, contains('R.string.action_start'));
    expect(overlay, contains('R.string.action_stop'));
    expect(overlay, contains('R.drawable.timer_overlay_action_idle_bg'));
    expect(overlay, contains('R.drawable.timer_overlay_action_bg'));
    // Bosta yasayabilmesi icin servis on planda kalir (yalniz serit acikken).
    expect(service, contains('keepAliveForOverlay()'));
    // Tek dugme, tek komut: bosta Baslat = widget'in yolu (son secili ders +
    // secili mod), kosarken Durdur.
    expect(service, contains('sendCommand(this, ACTION_TOGGLE)'));
  });

  test('serit cip gibi: logo + sayac + kucuk tek dugme', () {
    expect(layout, contains('@drawable/ic_stat_focus_camp'));
    expect(layout, contains('android:id="@+id/overlay_timer_action"'));
    expect(layout, isNot(contains('overlay_timer_stop')));
    // WP-775 (sahibin cizimi): 52dp serit, 26dp logo, 22sp saat, metinli dugme.
    expect(layout, contains('android:minHeight="52dp"'));
    expect(layout, contains('android:textSize="22sp"'));
    expect(layout, contains('<TextView'));
    expect(layout, isNot(contains('ic_overlay_stop')));
  });
}
