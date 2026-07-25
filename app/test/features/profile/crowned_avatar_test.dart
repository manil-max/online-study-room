import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/progression_visuals.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';

/// Test yardımcısı: taç geometrisindeki kutupsal noktayı üretir.
Offset _polar(Offset center, double base, double angleDeg, double radiusMul) {
  final a = angleDeg * math.pi / 180.0;
  final r = base * radiusMul;
  return Offset(center.dx + r * math.sin(a), center.dy - r * math.cos(a));
}

Future<CrownPainter> _pumpAndReadPainter(
  WidgetTester tester, {
  required String? rank,
  double radius = 32,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: CrownedAvatar(
            displayName: 'Ada',
            radius: radius,
            crownRank: rank,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<CrownPainter>()
      .single;
}

void main() {
  testWidgets('CrownedAvatar taç + halka çizer, workspace_premium değil', (
    tester,
  ) async {
    final painter = await _pumpAndReadPainter(tester, rank: 'gold_achiever');

    expect(find.byType(CrownedAvatar), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium), findsNothing);
    expect(painter.geometry, CrownGeometry.standard);
  });

  testWidgets('taçsız kullanıcıda taç hiç çizilmez', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: CrownedAvatar(displayName: 'Ada', radius: 32)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final crowns = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<CrownPainter>();
    expect(crowns, isEmpty);
  });

  testWidgets('WP-292 kabul: kademe → renk eşlemesi birebir korundu', (
    tester,
  ) async {
    // Görsel yenilendi ama hangi rütbenin hangi rengi aldığı değişmedi.
    for (final rank in kCrownRanks) {
      final painter = await _pumpAndReadPainter(tester, rank: rank);
      expect(painter.color, crownColorFor(rank), reason: '$rank rengi kaydı');
      expect(painter.color, tierColorFor(crownTierNumber(rank)));
    }
    // Sunucudan gelen eski rütbe hâlâ Elmas'a normalize ediliyor.
    final legacy = await _pumpAndReadPainter(tester, rank: 'platinum_scholar');
    expect(legacy.color, tierColorFor(4));
  });

  test('WP-292 kabul: aynı XP → aynı kademe (eşiklere dokunulmadı)', () {
    // 🔴 Bu test WP-292'nin asıl riskini kapatır: kozmetik değişiklik sırasında
    // XP eşiğini kaydırmak kullanıcıların görünen tacını sessizce değiştirir.
    expect(kCrownXpThresholds, <int>[0, 20000, 75000, 200000, 500000, 1000000]);
    expect(crownRankForXp(0), 'bronze_beginner');
    expect(crownRankForXp(19999), 'bronze_beginner');
    expect(crownRankForXp(20000), 'silver_learner');
    expect(crownRankForXp(74999), 'silver_learner');
    expect(crownRankForXp(75000), 'gold_achiever');
    expect(crownRankForXp(199999), 'gold_achiever');
    expect(crownRankForXp(200000), 'diamond_owl');
    expect(crownRankForXp(499999), 'diamond_owl');
    expect(crownRankForXp(500000), 'emerald_sage');
    expect(crownRankForXp(999999), 'emerald_sage');
    expect(crownRankForXp(1000000), 'immortal_legend');
  });

  test('WP-292: bandın alt kenarı avatara teğet — havada duran taç yok', () {
    // Eski tacın kusuru buydu: düz `RRect` bant yalnız tepe noktasına değiyor,
    // uçları dairenin dışında havada kalıyordu. Yeni bandın alt kenarı
    // avatarla eş merkezli bir yay olduğu için hem her açıda değiyor hem de
    // kafanın içine girmiyor.
    const geometry = CrownGeometry.standard;
    const center = Offset(100, 100);
    const base = 50.0;
    final path = geometry.pathFor(center: center, base: base);

    expect(path.contains(center), isFalse, reason: 'taç kafanın içine girdi');
    expect(
      path.contains(_polar(center, base, 0, 0.99)),
      isFalse,
      reason: 'bandın altı halkanın dış kenarını aştı',
    );
    expect(
      path.contains(_polar(center, base, 0, 1.02)),
      isTrue,
      reason: 'bant tepe noktasında değmiyor',
    );
    // Teğetlik yalnız tepede değil, bandın iki ucunda da geçerli olmalı.
    for (final angle in const <double>[-48, -30, 30, 48]) {
      expect(
        path.contains(_polar(center, base, angle, 1.02)),
        isTrue,
        reason: '$angle° açısında bant avatardan ayrıldı',
      );
      expect(
        path.contains(_polar(center, base, angle, 0.97)),
        isFalse,
        reason: '$angle° açısında bant avatarın içine girdi',
      );
    }
  });

  test('WP-292: uçların yüksekliği sahip onayına uyuyor', () {
    const geometry = CrownGeometry.standard;
    const center = Offset(100, 100);
    const base = 50.0;
    final path = geometry.pathFor(center: center, base: base);

    expect(geometry.halfSpanDeg, 50);
    expect(geometry.tipRadius, 1.63);
    expect(geometry.pearlRadius, 0.10);
    expect(geometry.bow, 0.50);
    // Orta uç 1.63'e kadar dolu, ötesi boş.
    expect(path.contains(_polar(center, base, 0, 1.55)), isTrue);
    expect(path.contains(_polar(center, base, 0, 1.70)), isFalse);
    // Uçlar arasındaki vadi 1.20'de: 1.30 boşta kalmalı (5 ayrı uç okunuyor).
    expect(path.contains(_polar(center, base, -25, 1.30)), isFalse);
  });

  test('WP-292: küçük avatarlar tok varyantı alır, uç sayısı değişmez', () {
    // Üründe kullanılan gerçek yarıçaplar.
    expect(CrownGeometry.forRadius(12), CrownGeometry.compact);
    expect(CrownGeometry.forRadius(14), CrownGeometry.compact);
    expect(CrownGeometry.forRadius(16), CrownGeometry.compact);
    expect(CrownGeometry.forRadius(18), CrownGeometry.standard);
    expect(CrownGeometry.forRadius(20), CrownGeometry.standard);
    expect(CrownGeometry.forRadius(48), CrownGeometry.standard);

    // İnci küçük boyutta kapanır (r = 12'de çapı ~2 piksele düşüyordu)…
    expect(
      CrownGeometry.compact.pearlCenters(center: Offset.zero, base: 20),
      isEmpty,
    );
    // …ama siluet aynı kalır: her iki varyantta da 5 uç.
    expect(CrownGeometry.compact.tips(), hasLength(5));
    expect(CrownGeometry.standard.tips(), hasLength(5));
    expect(
      CrownGeometry.standard.pearlCenters(center: Offset.zero, base: 20),
      hasLength(5),
    );
  });

  testWidgets(
    'WP-292: kutu her boyutta daraldı, yükseklik en fazla 4 px arttı',
    (tester) async {
      // Eski kutu `3.04 × yarıçap` kareydi ve avatarın **altında** boş yer
      // bırakıyordu. Yeni kutu tam tacın kapladığı yer kadar. Ölçülen sonuç:
      // genişlik her boyutta daralıyor, yükseklik r ≥ 28'de düşüyor, küçük
      // avatarlarda (tok varyant tacı uzattığı için) ~2–4 px artıyor.
      // Bu sınır bilerek testte: ileride taç uzatılırsa liste satırlarının
      // sessizce şişmesi burada yakalanır.
      for (final radius in const <double>[12, 14, 16, 18, 20, 28, 44, 48]) {
        await _pumpAndReadPainter(
          tester,
          rank: 'gold_achiever',
          radius: radius,
        );
        final size = tester.getSize(find.byType(CrownedAvatar));
        final old = 3.04 * radius;

        expect(
          size.width,
          lessThan(old),
          reason: 'r = $radius kutusu genişledi',
        );
        expect(
          size.height,
          lessThan(old + 4),
          reason: 'r = $radius satır yüksekliği 4 px üstünde arttı',
        );

        final geometry = CrownGeometry.forRadius(radius);
        final base = radius + crownRingWidth(radius);
        final outline = math.max(0.8, radius * 0.045);
        expect(
          size.height,
          closeTo(geometry.topExtent(base) + outline + base + outline, 0.01),
          reason: 'r = $radius yüksekliği geometriden türemiyor',
        );
      }
    },
  );

  test('xpBarMetrics crown thresholds progress', () {
    final m = xpBarMetrics(5000);
    expect(m.currentXp, 5000);
    expect(m.nextThreshold, 20000);
    expect(m.progress, greaterThan(0));
    expect(m.progress, lessThanOrEqualTo(1));
    expect(m.next, greaterThan(m.floor));
  });
}
