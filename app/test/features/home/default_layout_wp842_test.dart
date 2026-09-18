import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dashboard_providers.dart';

/// 🔴 WP-842 — sahip: *"default'ta başka ek widget'lar da olsun"*.
///
/// Önceki varsayılan pano üç karttı (sayaç + Bugün + Grup sıralaması) ve
/// panonun alt yarısı boş kalıyordu. Bu dosya üç şeyi ölçer: hangi kartların
/// geldiğini, boyların tek kaynaktan (WP-836 tablosu) türediğini ve kartların
/// üst üste binmediğini.
void main() {
  const columns = 32;

  test('varsayılan pano altı kart taşır', () {
    final layout = defaultDashboardLayout(columns);
    expect(layout.map((c) => c.type).toList(), [
      DashboardCardType.timer,
      DashboardCardType.today,
      DashboardCardType.leaderboard,
      DashboardCardType.goal,
      DashboardCardType.weekly,
      DashboardCardType.tasks,
    ]);
  });

  test('grup ŞARTI olan kart varsayılanda yok', () {
    final types = defaultDashboardLayout(columns).map((c) => c.type).toSet();
    expect(types.contains(DashboardCardType.groupGoal), isFalse);
    expect(types.contains(DashboardCardType.groupTrend), isFalse);
    expect(types.contains(DashboardCardType.activeMembers), isFalse);
  });

  test('tam genişlikli kartların boyu WP-836 tablosundan gelir', () {
    final layout = defaultDashboardLayout(columns);
    for (final type in [
      DashboardCardType.timer,
      DashboardCardType.goal,
      DashboardCardType.weekly,
      DashboardCardType.tasks,
    ]) {
      final card = layout.firstWhere((c) => c.type == type);
      expect(
        card.h,
        type.defaultCells(columns).h,
        reason: '$type boyu elle yazılmış olmamalı',
      );
      expect(card.w, columns, reason: '$type tam genişlik bekleniyor');
    }
  });

  test('kartlar üst üste binmez ve ızgaradan taşmaz', () {
    final layout = defaultDashboardLayout(columns);
    final occupied = <String>{};
    for (final card in layout) {
      expect(card.x, greaterThanOrEqualTo(0));
      expect(card.x + card.w, lessThanOrEqualTo(columns));
      expect(card.h, greaterThan(0));
      for (var y = card.y; y < card.y + card.h; y++) {
        for (var x = card.x; x < card.x + card.w; x++) {
          expect(
            occupied.add('$x:$y'),
            isTrue,
            reason: '${card.type} ($x,$y) hücresinde başka kartla çakışıyor',
          );
        }
      }
    }
  });

  test('yan yana çift panoyu tam kaplar', () {
    final layout = defaultDashboardLayout(columns);
    final today = layout.firstWhere((c) => c.type == DashboardCardType.today);
    final board = layout.firstWhere(
      (c) => c.type == DashboardCardType.leaderboard,
    );
    expect(today.y, board.y);
    expect(today.w + board.w, columns);
  });
}
