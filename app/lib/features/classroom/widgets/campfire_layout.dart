import 'dart:math' as math;

/// Dikey eksene göre aynalanan bir sol-sağ çiftin normalize konumu.
class CampfirePairPlacement {
  const CampfirePairPlacement({
    required this.horizontalFactor,
    required this.verticalFactor,
  });

  final double horizontalFactor;
  final double verticalFactor;

  CampfirePairPlacement copyWith({
    double? horizontalFactor,
    double? verticalFactor,
  }) {
    return CampfirePairPlacement(
      horizontalFactor: horizontalFactor ?? this.horizontalFactor,
      verticalFactor: verticalFactor ?? this.verticalFactor,
    );
  }
}

/// Tek sayılı profilde bağımsız ayarlanabilen bir hayvan konumu.
class CampfireSinglePlacement {
  const CampfireSinglePlacement({
    required this.horizontalFactor,
    required this.verticalFactor,
  });

  final double horizontalFactor;
  final double verticalFactor;

  CampfireSinglePlacement copyWith({
    double? horizontalFactor,
    double? verticalFactor,
  }) {
    return CampfireSinglePlacement(
      horizontalFactor: horizontalFactor ?? this.horizontalFactor,
      verticalFactor: verticalFactor ?? this.verticalFactor,
    );
  }
}

/// Belirli bir çift kişi sayısına ait bağımsız yerleşim profili.
class CampfireCountLayout {
  const CampfireCountLayout({
    required this.memberCount,
    required this.ringWidthFactor,
    required this.pairs,
    this.singles = const [],
    required this.groundYFactor,
    required this.fireScale,
    required this.stickReachFactor,
    required this.roastCycleMinutes,
  });

  factory CampfireCountLayout.oddDraft(int memberCount) {
    if (memberCount < 1 || memberCount > 7 || memberCount.isEven) {
      throw ArgumentError.value(
        memberCount,
        'memberCount',
        '1, 3, 5 veya 7 olmalı.',
      );
    }
    final singles =
        [
          for (var index = 0; index < memberCount; index++)
            CampfireSinglePlacement(
              horizontalFactor: math.cos(index * math.pi * 2 / memberCount),
              verticalFactor: math.sin(index * math.pi * 2 / memberCount),
            ),
        ]..sort((a, b) {
          final vertical = a.verticalFactor.compareTo(b.verticalFactor);
          return vertical != 0
              ? vertical
              : a.horizontalFactor.compareTo(b.horizontalFactor);
        });
    final neighbor = CampfireCountLayout.saved(
      memberCount == 1 ? 2 : memberCount + 1,
    );
    return CampfireCountLayout(
      memberCount: memberCount,
      ringWidthFactor: neighbor.ringWidthFactor,
      pairs: const [],
      singles: singles,
      groundYFactor: neighbor.groundYFactor,
      fireScale: neighbor.fireScale,
      stickReachFactor: neighbor.stickReachFactor,
      roastCycleMinutes: neighbor.roastCycleMinutes,
    );
  }

  factory CampfireCountLayout.saved(int memberCount) {
    return switch (memberCount) {
      1 => const CampfireCountLayout(
        memberCount: 1,
        ringWidthFactor: 0.24,
        pairs: [],
        singles: [
          CampfireSinglePlacement(horizontalFactor: 1.00, verticalFactor: 0.00),
        ],
        groundYFactor: 0.66,
        fireScale: 0.80,
        stickReachFactor: 0.78,
        roastCycleMinutes: 12,
      ),
      2 => const CampfireCountLayout(
        memberCount: 2,
        ringWidthFactor: 0.34,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.67, verticalFactor: 0.02),
        ],
        groundYFactor: 0.66,
        fireScale: 0.98,
        stickReachFactor: 0.71,
        roastCycleMinutes: 12,
      ),
      3 => const CampfireCountLayout(
        memberCount: 3,
        ringWidthFactor: 0.31,
        pairs: [],
        singles: [
          CampfireSinglePlacement(
            horizontalFactor: -0.57,
            verticalFactor: -0.40,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.70, verticalFactor: 0.00),
          CampfireSinglePlacement(
            horizontalFactor: -0.54,
            verticalFactor: 0.86,
          ),
        ],
        groundYFactor: 0.66,
        fireScale: 0.80,
        stickReachFactor: 0.73,
        roastCycleMinutes: 12,
      ),
      4 => const CampfireCountLayout(
        memberCount: 4,
        ringWidthFactor: 0.31,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.58, verticalFactor: -0.40),
          CampfirePairPlacement(horizontalFactor: 0.64, verticalFactor: 0.66),
        ],
        groundYFactor: 0.66,
        fireScale: 0.80,
        stickReachFactor: 0.73,
        roastCycleMinutes: 12,
      ),
      5 => const CampfireCountLayout(
        memberCount: 5,
        ringWidthFactor: 0.26,
        pairs: [],
        singles: [
          CampfireSinglePlacement(
            horizontalFactor: 0.61,
            verticalFactor: -0.57,
          ),
          CampfireSinglePlacement(
            horizontalFactor: -0.63,
            verticalFactor: -0.44,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.91, verticalFactor: 0.17),
          CampfireSinglePlacement(
            horizontalFactor: -0.70,
            verticalFactor: 0.70,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.47, verticalFactor: 0.95),
        ],
        groundYFactor: 0.66,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      6 => const CampfireCountLayout(
        memberCount: 6,
        ringWidthFactor: 0.35,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.40, verticalFactor: -0.68),
          CampfirePairPlacement(horizontalFactor: 0.63, verticalFactor: 0.09),
          CampfirePairPlacement(horizontalFactor: 0.44, verticalFactor: 0.87),
        ],
        groundYFactor: 0.66,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      7 => const CampfireCountLayout(
        memberCount: 7,
        ringWidthFactor: 0.23,
        pairs: [],
        singles: [
          CampfireSinglePlacement(
            horizontalFactor: -0.52,
            verticalFactor: -0.67,
          ),
          CampfireSinglePlacement(
            horizontalFactor: 0.57,
            verticalFactor: -0.68,
          ),
          CampfireSinglePlacement(
            horizontalFactor: -0.92,
            verticalFactor: -0.21,
          ),
          CampfireSinglePlacement(
            horizontalFactor: 0.90,
            verticalFactor: -0.08,
          ),
          CampfireSinglePlacement(
            horizontalFactor: -0.88,
            verticalFactor: 0.60,
          ),
          CampfireSinglePlacement(horizontalFactor: 0.62, verticalFactor: 0.78),
          CampfireSinglePlacement(
            horizontalFactor: -0.44,
            verticalFactor: 0.98,
          ),
        ],
        groundYFactor: 0.66,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      8 => const CampfireCountLayout(
        memberCount: 8,
        ringWidthFactor: 0.34,
        pairs: [
          CampfirePairPlacement(horizontalFactor: 0.34, verticalFactor: -0.85),
          CampfirePairPlacement(horizontalFactor: 0.62, verticalFactor: -0.33),
          CampfirePairPlacement(horizontalFactor: 0.61, verticalFactor: 0.45),
          CampfirePairPlacement(horizontalFactor: 0.31, verticalFactor: 0.92),
        ],
        groundYFactor: 0.66,
        fireScale: 0.80,
        stickReachFactor: 0.76,
        roastCycleMinutes: 12,
      ),
      _ => throw ArgumentError.value(
        memberCount,
        'memberCount',
        '1 ile 8 arasında olmalı.',
      ),
    };
  }

  factory CampfireCountLayout.regular(int memberCount) {
    if (memberCount < 2 || memberCount > 8 || memberCount.isOdd) {
      throw ArgumentError.value(
        memberCount,
        'memberCount',
        '2, 4, 6 veya 8 olmalı.',
      );
    }
    final pairCount = memberCount ~/ 2;
    return CampfireCountLayout(
      memberCount: memberCount,
      ringWidthFactor: 0.34,
      pairs: [
        for (var row = 0; row < pairCount; row++)
          CampfirePairPlacement(
            horizontalFactor: math.cos(
              -math.pi / 2 +
                  math.pi / memberCount +
                  row * math.pi * 2 / memberCount,
            ),
            verticalFactor: math.sin(
              -math.pi / 2 +
                  math.pi / memberCount +
                  row * math.pi * 2 / memberCount,
            ),
          ),
      ],
      groundYFactor: 0.56,
      fireScale: 1,
      stickReachFactor: 0.58,
      roastCycleMinutes: 10,
    );
  }

  final int memberCount;
  final double ringWidthFactor;
  final List<CampfirePairPlacement> pairs;
  final List<CampfireSinglePlacement> singles;
  final double groundYFactor;
  final double fireScale;
  final double stickReachFactor;
  final double roastCycleMinutes;

  CampfireCountLayout copyWith({
    double? ringWidthFactor,
    List<CampfirePairPlacement>? pairs,
    List<CampfireSinglePlacement>? singles,
    double? groundYFactor,
    double? fireScale,
    double? stickReachFactor,
    double? roastCycleMinutes,
  }) {
    return CampfireCountLayout(
      memberCount: memberCount,
      ringWidthFactor: ringWidthFactor ?? this.ringWidthFactor,
      pairs: pairs ?? this.pairs,
      singles: singles ?? this.singles,
      groundYFactor: groundYFactor ?? this.groundYFactor,
      fireScale: fireScale ?? this.fireScale,
      stickReachFactor: stickReachFactor ?? this.stickReachFactor,
      roastCycleMinutes: roastCycleMinutes ?? this.roastCycleMinutes,
    );
  }
}

class CampfireSeat {
  const CampfireSeat({required this.x, required this.y, required this.index});

  final double x;
  final double y;
  final int index;

  double get depth => (y + 1) / 2;
}

List<CampfireSeat> campfireSeats(CampfireCountLayout layout) {
  if (layout.memberCount != layout.pairs.length * 2 + layout.singles.length) {
    throw ArgumentError.value(
      '${layout.pairs.length}/${layout.singles.length}',
      'pairs/singles',
      'Çift ve tek konum sayısı üye sayısıyla uyuşmalı.',
    );
  }

  final seats = <CampfireSeat>[];
  for (final pair in layout.pairs) {
    if (pair.horizontalFactor <= 0 ||
        pair.horizontalFactor > 1.2 ||
        pair.verticalFactor < -1 ||
        pair.verticalFactor > 1) {
      throw ArgumentError.value(pair, 'pairs', 'Çift konumu geçersiz.');
    }
    seats.add(
      CampfireSeat(
        x: pair.horizontalFactor,
        y: pair.verticalFactor,
        index: seats.length,
      ),
    );
    seats.add(
      CampfireSeat(
        x: -pair.horizontalFactor,
        y: pair.verticalFactor,
        index: seats.length,
      ),
    );
  }
  for (final single in layout.singles) {
    if (single.horizontalFactor < -1.2 ||
        single.horizontalFactor > 1.2 ||
        single.verticalFactor < -1 ||
        single.verticalFactor > 1) {
      throw ArgumentError.value(single, 'singles', 'Tek konumu geçersiz.');
    }
    seats.add(
      CampfireSeat(
        x: single.horizontalFactor,
        y: single.verticalFactor,
        index: seats.length,
      ),
    );
  }
  return seats;
}
