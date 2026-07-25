import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/progression_visuals.dart';
import 'package:online_study_room/core/widgets/avatar_aura.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';

/// Aurası açık bir avatarı pump eder.
///
/// ⚠️ `pumpAndSettle()` **kullanılamaz**: aura `repeat()` ile sonsuz animasyon
/// çalıştırır, settle asla dönmez. `reduceMotion: true` verilen durumda ticker
/// durduğu için settle güvenli olur — bu da testin kendisi.
Future<void> _pump(
  WidgetTester tester, {
  required String rank,
  bool reduceMotion = false,
  double radius = 44,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: CrownedAvatar(
              displayName: 'Ada',
              radius: radius,
              crownRank: rank,
              showAura: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
}

AvatarAuraPainter? _auraPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<AvatarAuraPainter>()
    .firstOrNull;

void main() {
  test('WP-298 sahip kararı: aura altın kademede başlar, kademeli artar', () {
    // Bronz ve gümüşte efekt yok; altından itibaren monoton artıyor.
    expect(auraIntensityForTier(1), 0);
    expect(auraIntensityForTier(2), 0);
    expect(auraIntensityForTier(3), greaterThan(0));

    for (var tier = 3; tier < 6; tier++) {
      expect(
        auraIntensityForTier(tier + 1),
        greaterThan(auraIntensityForTier(tier)),
        reason: 'kademe ${tier + 1} kendinden öncekinden güçlü olmalı',
      );
    }
    expect(auraIntensityForTier(6), 1.0);
    // Sınır dışı değer çökmez (sunucudan beklenmeyen kademe gelebilir).
    expect(auraIntensityForTier(0), 0);
    expect(auraIntensityForTier(99), 1.0);
  });

  test('WP-298: aura dikeyde tacın içinde kalır, yalnız yanlara taşar', () {
    // 🔴 Bu kısıt gerçek: iki ekranda da avatar bir `ListView` içinde ve
    // `ListView` dikeyde kırpar. Aura tacın tepesini aşarsa listenin üstünde
    // kesik görünür.
    const geometry = CrownGeometry.standard;
    expect(
      kAuraOuterRadius,
      lessThan(geometry.tipRadius + geometry.pearlRadius),
      reason: 'aura tacın tepesini aştı → ListView tepesinde kesilir',
    );
    // Yanlara taşması ise bilinçli — aksi hâlde efekt görünmez.
    expect(kAuraOuterRadius, greaterThan(geometry.halfWidth(1.0)));
  });

  testWidgets('WP-298: aura yalnız showAura açıkken çizilir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CrownedAvatar(
              displayName: 'Ada',
              radius: 44,
              crownRank: 'immortal_legend',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _auraPainter(tester),
      isNull,
      reason: 'varsayılan kapalı olmalı — listeler bu yüzden güvenli',
    );
  });

  testWidgets('WP-298: altın altındaki kademelerde katman hiç kurulmaz', (
    tester,
  ) async {
    for (final rank in const ['bronze_beginner', 'silver_learner']) {
      await _pump(tester, rank: rank, reduceMotion: true);
      expect(
        _auraPainter(tester),
        isNull,
        reason: '$rank auraya sahip olmamalı',
      );
    }
    for (final rank in const [
      'gold_achiever',
      'diamond_owl',
      'emerald_sage',
      'immortal_legend',
    ]) {
      await _pump(tester, rank: rank, reduceMotion: true);
      final painter = _auraPainter(tester);
      expect(painter, isNotNull, reason: '$rank aura almalı');
      expect(painter!.intensity, auraIntensityForTier(crownTierNumber(rank)));
      // Aura rengi kademe rengiyle aynı — sahip böyle istedi.
      expect(painter.color, crownColorFor(rank));
    }
  });

  testWidgets('WP-298 kabul: "hareketi azalt" açıkken animasyon durur', (
    tester,
  ) async {
    await _pump(tester, rank: 'immortal_legend', reduceMotion: true);
    final first = _auraPainter(tester)!.t;
    // Ticker duruyorsa `pumpAndSettle` dönebilir; dönmezse test zaman aşımına
    // uğrar ve bu da geçerli bir başarısızlıktır.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(
      _auraPainter(tester)!.t,
      first,
      reason: 'hareketi azalt açıkken faz ilerledi',
    );
    // Durağan hâlde de aura görünür kalır (yoğunluk sıfırlanmaz).
    expect(_auraPainter(tester)!.intensity, 1.0);
  });

  testWidgets('WP-298: hareket açıkken faz gerçekten ilerliyor', (
    tester,
  ) async {
    await _pump(tester, rank: 'immortal_legend');
    final first = _auraPainter(tester)!.t;
    await tester.pump(const Duration(seconds: 2));
    expect(
      _auraPainter(tester)!.t,
      isNot(first),
      reason: 'animasyon başlamamış — aura ölü katman',
    );
    // Sonsuz animasyonu bırakmadan bitir (pending timer uyarısı olmasın).
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
