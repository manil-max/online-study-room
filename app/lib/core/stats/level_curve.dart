/// WP-154: XP → seviye (salt okunur türetilmiş; sunucu XP bozulmaz).
///
/// Formül (ürün kararı varsayılan): `level = floor(sqrt(xp / 50)) + 1`
/// xp=0 → 1; xp=50 → 2; xp=200 → 3; …
int levelForXp(int xp) {
  if (xp <= 0) return 1;
  return (xp / 50).floor().sqrtFloor() + 1;
}

extension on int {
  int sqrtFloor() {
    if (this <= 0) return 0;
    var x = this;
    var y = (x + 1) ~/ 2;
    while (y < x) {
      x = y;
      y = (x + this ~/ x) ~/ 2;
    }
    return x;
  }
}

/// Seviye [level] için gereken minimum XP.
int xpForLevel(int level) {
  if (level <= 1) return 0;
  final n = level - 1;
  return 50 * n * n;
}

/// Mevcut seviyede ilerleme 0..1 (sonraki seviyeye).
({int level, int floorXp, int nextXp, double progress}) levelProgress(int xp) {
  final level = levelForXp(xp);
  final floor = xpForLevel(level);
  final next = xpForLevel(level + 1);
  if (next <= floor) {
    return (level: level, floorXp: floor, nextXp: next, progress: 1.0);
  }
  final p = ((xp - floor) / (next - floor)).clamp(0.0, 1.0);
  return (level: level, floorXp: floor, nextXp: next, progress: p);
}

/// WP-154: basit günlük/haftalık görev durumu (istemci görüntü; XP yazılmaz).
enum QuestId { dailyLogin, weeklyFiveHours }

class QuestStatus {
  const QuestStatus({
    required this.id,
    required this.progress,
    required this.target,
    required this.done,
  });

  final QuestId id;
  final int progress;
  final int target;
  final bool done;
}

/// [todaySeconds] ve [weekSeconds] Istanbul gün/hafta toplamlarından.
List<QuestStatus> buildQuestStatuses({
  required int todaySeconds,
  required int weekSeconds,
}) {
  const weekTarget = 5 * 3600;
  return [
    QuestStatus(
      id: QuestId.dailyLogin,
      progress: todaySeconds > 0 ? 1 : 0,
      target: 1,
      done: todaySeconds > 0,
    ),
    QuestStatus(
      id: QuestId.weeklyFiveHours,
      progress: weekSeconds.clamp(0, weekTarget),
      target: weekTarget,
      done: weekSeconds >= weekTarget,
    ),
  ];
}

/// Kozmetik kilit: ücretsiz unlock (level eşiği).
bool isFrameUnlocked({required int xp, required int requiredLevel}) {
  return levelForXp(xp) >= requiredLevel;
}
