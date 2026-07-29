import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_layout.dart';

void main() {
  group('CampfireCountLayout', () {
    test('yalnız 2, 4, 6 ve 8 kişilik çift profiller üretir', () {
      for (final count in [2, 4, 6, 8]) {
        final layout = CampfireCountLayout.regular(count);
        expect(layout.memberCount, count);
        expect(layout.pairs, hasLength(count ~/ 2));
      }

      expect(() => CampfireCountLayout.regular(3), throwsArgumentError);
      expect(() => CampfireCountLayout.regular(10), throwsArgumentError);
    });

    test('1, 3, 5 ve 7 kişilik bağımsız tek konum profilleri üretir', () {
      for (final count in [1, 3, 5, 7]) {
        final layout = CampfireCountLayout.oddDraft(count);
        expect(layout.memberCount, count);
        expect(layout.pairs, isEmpty);
        expect(layout.singles, hasLength(count));
        expect(campfireSeats(layout), hasLength(count));
      }

      expect(() => CampfireCountLayout.oddDraft(2), throwsArgumentError);
      expect(() => CampfireCountLayout.oddDraft(9), throwsArgumentError);
    });

    test('üç kişilik başlangıç düzeni çizimdeki üçgeni verir', () {
      final layout = CampfireCountLayout.oddDraft(3);

      expect(layout.singles[0].horizontalFactor, closeTo(-0.5, 0.0001));
      expect(
        layout.singles[0].verticalFactor,
        closeTo(-math.sqrt(3) / 2, 0.0001),
      );
      expect(layout.singles[1].horizontalFactor, closeTo(1, 0.0001));
      expect(layout.singles[1].verticalFactor, closeTo(0, 0.0001));
      expect(layout.singles[2].horizontalFactor, closeTo(-0.5, 0.0001));
      expect(
        layout.singles[2].verticalFactor,
        closeTo(math.sqrt(3) / 2, 0.0001),
      );
    });

    test('tek hayvan konumu diğer hayvanlardan bağımsız değişir', () {
      final baseline = CampfireCountLayout.oddDraft(5);
      final singles = [...baseline.singles];
      singles[2] = singles[2].copyWith(
        horizontalFactor: -0.22,
        verticalFactor: 0.14,
      );
      final changed = baseline.copyWith(singles: singles);

      expect(changed.singles[0], same(baseline.singles[0]));
      expect(changed.singles[1], same(baseline.singles[1]));
      expect(changed.singles[2].horizontalFactor, -0.22);
      expect(changed.singles[2].verticalFactor, 0.14);
      expect(changed.singles[3], same(baseline.singles[3]));
      expect(changed.singles[4], same(baseline.singles[4]));
    });

    test('altı kişilik varsayılan profil düzgün altıgendir', () {
      final seats = campfireSeats(CampfireCountLayout.regular(6));

      expect(seats.map((seat) => seat.x), [
        closeTo(0.5, 0.0001),
        closeTo(-0.5, 0.0001),
        closeTo(1, 0.0001),
        closeTo(-1, 0.0001),
        closeTo(0.5, 0.0001),
        closeTo(-0.5, 0.0001),
      ]);
      expect(seats.map((seat) => seat.y), [
        closeTo(-math.sqrt(3) / 2, 0.0001),
        closeTo(-math.sqrt(3) / 2, 0.0001),
        closeTo(0, 0.0001),
        closeTo(0, 0.0001),
        closeTo(math.sqrt(3) / 2, 0.0001),
        closeTo(math.sqrt(3) / 2, 0.0001),
      ]);
    });

    test('her çift dikey eksene göre tam aynadır', () {
      for (final count in [2, 4, 6, 8]) {
        final seats = campfireSeats(CampfireCountLayout.regular(count));
        for (var index = 0; index < seats.length; index += 2) {
          expect(seats[index].x, closeTo(-seats[index + 1].x, 0.000001));
          expect(seats[index].y, closeTo(seats[index + 1].y, 0.000001));
        }
      }
    });

    test('bir çiftin ince ayarı diğer çiftleri değiştirmez', () {
      final baseline = CampfireCountLayout.regular(8);
      final changedPairs = [...baseline.pairs];
      changedPairs[1] = changedPairs[1].copyWith(
        horizontalFactor: 0.77,
        verticalFactor: -0.22,
      );
      final changed = baseline.copyWith(pairs: changedPairs);

      expect(changed.pairs[0], same(baseline.pairs[0]));
      expect(changed.pairs[1].horizontalFactor, 0.77);
      expect(changed.pairs[1].verticalFactor, -0.22);
      expect(changed.pairs[2], same(baseline.pairs[2]));
      expect(changed.pairs[3], same(baseline.pairs[3]));
    });

    test('kişi sayılarının profilleri birbirinden bağımsızdır', () {
      final layouts = {
        for (final count in [2, 4, 6, 8])
          count: CampfireCountLayout.regular(count),
      };
      final changedSix = layouts[6]!.copyWith(ringWidthFactor: 0.28);
      final updated = {...layouts, 6: changedSix};

      expect(updated[6]!.ringWidthFactor, 0.28);
      expect(updated[2]!.ringWidthFactor, 0.34);
      expect(updated[4]!.ringWidthFactor, 0.34);
      expect(updated[8]!.ringWidthFactor, 0.34);
    });

    test('sahibin seçtiği dört profil birebir kayıtlıdır', () {
      final two = CampfireCountLayout.saved(2);
      expect(two.ringWidthFactor, 0.34);
      expect(two.pairs.single.horizontalFactor, 0.67);
      expect(two.pairs.single.verticalFactor, 0.02);
      expect(two.fireScale, 0.98);
      expect(two.stickReachFactor, 0.71);

      final four = CampfireCountLayout.saved(4);
      expect(four.ringWidthFactor, 0.31);
      expect(four.pairs, isEmpty);
      expect(four.singles.map((seat) => seat.horizontalFactor), [
        -0.72,
        0.72,
        0.74,
        -0.72,
      ]);
      expect(four.singles.map((seat) => seat.verticalFactor), [
        -0.80,
        -0.84,
        0.70,
        0.74,
      ]);
      expect(four.stickReachFactor, 0.73);

      final six = CampfireCountLayout.saved(6);
      expect(six.ringWidthFactor, 0.35);
      expect(six.pairs.map((pair) => pair.horizontalFactor), [
        0.40,
        0.63,
        0.44,
      ]);
      expect(six.pairs.map((pair) => pair.verticalFactor), [-0.68, 0.09, 0.87]);

      final eight = CampfireCountLayout.saved(8);
      expect(eight.pairs, isEmpty);
      expect(eight.singles.map((seat) => seat.horizontalFactor), [
        -0.34,
        0.34,
        -0.72,
        0.72,
        -0.76,
        0.76,
        -0.56,
        0.56,
      ]);
      expect(eight.singles.map((seat) => seat.verticalFactor), [
        -0.94,
        -0.92,
        -0.32,
        -0.26,
        0.20,
        0.22,
        0.78,
        0.82,
      ]);

      for (final layout in [two, four, six, eight]) {
        expect(layout.groundYFactor, kCampfireGroundYFactor);
        expect(layout.roastCycleMinutes, 12);
      }
      for (final layout in [four, six, eight]) {
        expect(layout.fireScale, 0.80);
      }
      for (final layout in [six, eight]) {
        expect(layout.stickReachFactor, 0.76);
      }
    });

    test('sahibin seçtiği dört tek profil birebir kayıtlıdır', () {
      final one = CampfireCountLayout.saved(1);
      expect(one.ringWidthFactor, 0.24);
      expect(one.singles.single.horizontalFactor, 1.00);
      expect(one.singles.single.verticalFactor, 0.00);
      expect(one.stickReachFactor, 0.78);

      final three = CampfireCountLayout.saved(3);
      expect(three.ringWidthFactor, 0.31);
      expect(three.singles.map((seat) => seat.horizontalFactor), [
        -0.57,
        0.70,
        -0.54,
      ]);
      expect(three.singles.map((seat) => seat.verticalFactor), [
        -0.40,
        0.00,
        0.86,
      ]);
      expect(three.stickReachFactor, 0.73);

      final five = CampfireCountLayout.saved(5);
      expect(five.ringWidthFactor, 0.26);
      expect(five.singles.map((seat) => seat.horizontalFactor), [
        0.61,
        -0.63,
        0.91,
        -0.70,
        0.47,
      ]);
      expect(five.singles.map((seat) => seat.verticalFactor), [
        -0.57,
        -0.44,
        0.17,
        0.70,
        0.95,
      ]);

      final seven = CampfireCountLayout.saved(7);
      expect(seven.ringWidthFactor, 0.23);
      expect(seven.singles.map((seat) => seat.horizontalFactor), [
        -0.52,
        0.57,
        -0.92,
        0.90,
        -0.88,
        0.62,
        -0.44,
      ]);
      expect(seven.singles.map((seat) => seat.verticalFactor), [
        -0.67,
        -0.68,
        -0.21,
        -0.08,
        0.60,
        0.78,
        0.98,
      ]);

      for (final layout in [one, three, five, seven]) {
        expect(layout.groundYFactor, kCampfireGroundYFactor);
        expect(layout.fireScale, 0.80);
        expect(layout.roastCycleMinutes, 12);
      }
      for (final layout in [five, seven]) {
        expect(layout.stickReachFactor, 0.76);
      }
    });

    test('profil ile çift sayısı uyuşmazsa reddeder', () {
      final invalid = CampfireCountLayout(
        memberCount: 4,
        ringWidthFactor: 0.34,
        pairs: [CampfireCountLayout.regular(2).pairs.single],
        groundYFactor: kCampfireGroundYFactor,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      );

      expect(() => campfireSeats(invalid), throwsArgumentError);
    });
  });
}
