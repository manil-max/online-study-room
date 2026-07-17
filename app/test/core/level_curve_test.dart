import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/level_curve.dart';

void main() {
  test('level curve sqrt formula', () {
    expect(levelForXp(0), 1);
    expect(levelForXp(49), 1);
    expect(levelForXp(50), 2);
    expect(levelForXp(200), 3);
    expect(xpForLevel(1), 0);
    expect(xpForLevel(2), 50);
    expect(xpForLevel(3), 200);
  });

  test('level progress monotonic', () {
    final a = levelProgress(0);
    final b = levelProgress(25);
    final c = levelProgress(50);
    expect(a.level, 1);
    expect(b.progress, greaterThan(0));
    expect(c.level, 2);
  });

  test('quests from study totals (no XP write)', () {
    final empty = buildQuestStatuses(todaySeconds: 0, weekSeconds: 0);
    expect(empty.every((q) => !q.done), isTrue);
    final done = buildQuestStatuses(todaySeconds: 60, weekSeconds: 5 * 3600);
    expect(done.every((q) => q.done), isTrue);
  });

  test('cosmetic frame unlock free at level 3', () {
    expect(isFrameUnlocked(xp: 0, requiredLevel: 3), isFalse);
    expect(isFrameUnlocked(xp: 200, requiredLevel: 3), isTrue);
  });
}
