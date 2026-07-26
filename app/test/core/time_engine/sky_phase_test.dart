import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/time_engine/sky_phase.dart';

void main() {
  group('skyPhase', () {
    test('dört sivil çıpada fazı deterministik değiştirir', () {
      expect(_at(5, 29).phase, SkyPhase.night);
      expect(_at(5, 30).phase, SkyPhase.dawn);
      expect(_at(6, 30).phase, SkyPhase.day);
      expect(_at(18, 30).phase, SkyPhase.dusk);
      expect(_at(19, 30).phase, SkyPhase.night);
    });

    test('24 saatin her tam saatinde beklenen fazı üretir', () {
      final phases = [for (var hour = 0; hour < 24; hour++) _at(hour, 0).phase];

      expect(phases.take(6), everyElement(SkyPhase.night));
      expect(phases[6], SkyPhase.dawn);
      expect(phases.sublist(7, 19), everyElement(SkyPhase.day));
      expect(phases[19], SkyPhase.dusk);
      expect(phases.sublist(20), everyElement(SkyPhase.night));
    });

    test('şafak ve akşam geçişleri ani değil smoothstep ile yumuşaktır', () {
      final dawnStart = _at(5, 30);
      final dawnMid = _at(6, 0);
      final dawnEnd = _at(6, 29, second: 59);
      final duskStart = _at(18, 30);
      final duskMid = _at(19, 0);
      final duskEnd = _at(19, 29, second: 59);

      expect(dawnStart.value, 0);
      expect(dawnMid.value, closeTo(0.5, 0.0001));
      expect(dawnEnd.value, closeTo(1, 0.001));
      expect(duskStart.value, 1);
      expect(duskMid.value, closeTo(0.5, 0.0001));
      expect(duskEnd.value, closeTo(0, 0.001));
      expect(dawnMid.warmth, closeTo(1, 0.0001));
      expect(duskMid.warmth, closeTo(1, 0.0001));
    });

    test('23:59 → 00:01 gece yarısı sarmasında gece kalır', () {
      final before = skyPhase(
        DateTime(2026, 7, 26, 23, 59),
        kDefaultSkyAnchors,
      );
      final after = skyPhase(DateTime(2026, 7, 27, 0, 1), kDefaultSkyAnchors);

      expect(before.phase, SkyPhase.night);
      expect(after.phase, SkyPhase.night);
      expect(before.value, 0);
      expect(after.value, 0);
    });

    test('güneş yayı gündoğumu ile günbatımı arasında 0..1 ilerler', () {
      expect(_at(6, 30).sunProgress, 0);
      expect(_at(12, 30).sunProgress, closeTo(0.5, 0.0001));
      expect(_at(18, 29).sunProgress, closeTo(1, 0.002));
    });

    test('tarih değişse de aynı sivil saat aynı sonucu verir', () {
      final first = skyPhase(DateTime(2026, 1, 5, 6), kDefaultSkyAnchors);
      final second = skyPhase(DateTime(2031, 11, 20, 6), kDefaultSkyAnchors);

      expect(second.phase, first.phase);
      expect(second.value, first.value);
      expect(second.phaseProgress, first.phaseProgress);
    });

    test('sırası bozuk çıpaları fail-closed reddeder', () {
      const invalid = SkyAnchors(
        dawnMinute: 400,
        sunriseMinute: 300,
        sunsetMinute: 1100,
        duskMinute: 1200,
      );

      expect(
        () => skyPhase(DateTime(2026, 7, 26, 12), invalid),
        throwsArgumentError,
      );
    });
  });
}

SkyPhaseResult _at(int hour, int minute, {int second = 0}) =>
    skyPhase(DateTime(2026, 7, 26, hour, minute, second), kDefaultSkyAnchors);
