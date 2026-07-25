import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/progression_visuals.dart';
import 'package:online_study_room/core/widgets/avatar_aura.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';

/// WP-292 taç görselinin golden baseline'ı.
///
/// Amaç: taç geometrisi bir daha elle değiştirildiğinde (uç sayısı, kavis,
/// bant kalınlığı) değişikliğin gözden kaçmaması. Geometri sayıları
/// `crowned_avatar_test.dart`'ta ayrıca sabitlenmiştir; buradaki görüntü
/// **çizimin** kaymadığını gösterir.
Widget _probe(List<Widget> children) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: Scaffold(
      backgroundColor: const Color(0xFF14101E),
      body: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: children,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('taç golden · 6 kademe · r44', (tester) async {
    await tester.binding.setSurfaceSize(const Size(780, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _probe(<Widget>[
        for (final rank in kCrownRanks)
          CrownedAvatar(displayName: 'A', radius: 44, crownRank: rank),
      ]),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/crown_tiers_r44.png'),
    );
  });

  testWidgets('taç golden · boyut merdiveni', (tester) async {
    // Üründe kullanılan gerçek yarıçaplar. 12–16 tok varyantı, 18+ standart.
    await tester.binding.setSurfaceSize(const Size(620, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _probe(<Widget>[
        for (final r in const <double>[12, 14, 16, 18, 20, 28, 44, 48])
          CrownedAvatar(
            displayName: 'A',
            radius: r,
            crownRank: 'gold_achiever',
          ),
      ]),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/crown_sizes.png'),
    );
  });

  testWidgets('aura golden · 6 kademe · durağan faz', (tester) async {
    // WP-298: aura altın kademede başlar; bronz/gümüş bilerek auralı görünmez.
    // `disableAnimations: true` hem tickerı durdurup golden'ı belirlenir kılar
    // hem de "hareketi azalt" görünümünü belgeler.
    await tester.binding.setSurfaceSize(const Size(900, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _probe(<Widget>[
          for (final rank in kCrownRanks)
            CrownedAvatar(
              displayName: 'A',
              radius: 44,
              crownRank: rank,
              showAura: true,
            ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/crown_aura_tiers.png'),
    );
  });

  testWidgets('aura golden · immortal · dört faz', (tester) async {
    // Fazlar farklı görünmezse dönen kuşaklar tek halka gibi kilitlenmiş olur.
    await tester.binding.setSurfaceSize(const Size(760, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _probe(<Widget>[
        for (final t in const <double>[0.0, 0.25, 0.5, 0.75])
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: AvatarAuraPainter(
                color: tierColorFor(6),
                intensity: 1.0,
                base: 48,
                center: const Offset(80, 90),
                t: t,
              ),
            ),
          ),
      ]),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/crown_aura_phases.png'),
    );
  });
}
