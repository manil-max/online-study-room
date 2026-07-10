import 'study_stats.dart';

class FreezeAwareStreak {
  const FreezeAwareStreak({
    required this.streak,
    required this.freezesUsed,
    required this.protectedDays,
  });

  final int streak;
  final int freezesUsed;
  final List<DateTime> protectedDays;
}

FreezeAwareStreak currentStreakWithFreezes({
  required Map<DateTime, int> totals,
  required int goalSeconds,
  required int availableFreezes,
  DateTime? today,
}) {
  if (goalSeconds <= 0) {
    return const FreezeAwareStreak(
      streak: 0,
      freezesUsed: 0,
      protectedDays: [],
    );
  }

  final start = dayOf(today ?? DateTime.now());
  bool met(DateTime day) => (totals[day] ?? 0) >= goalSeconds;

  var cursor = met(start) ? start : start.subtract(const Duration(days: 1));
  var streak = 0;
  var freezesUsed = 0;
  final protectedDays = <DateTime>[];

  while (true) {
    if (met(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
      continue;
    }
    if (freezesUsed < availableFreezes) {
      freezesUsed++;
      protectedDays.add(cursor);
      cursor = cursor.subtract(const Duration(days: 1));
      continue;
    }
    break;
  }

  return FreezeAwareStreak(
    streak: streak,
    freezesUsed: freezesUsed,
    protectedDays: List.unmodifiable(protectedDays),
  );
}

enum CrownTier { none, bronze, silver, gold }

extension CrownTierLabel on CrownTier {
  String get label => switch (this) {
    CrownTier.none => 'Taç yok',
    CrownTier.bronze => 'Bronz taç',
    CrownTier.silver => 'Gümüş taç',
    CrownTier.gold => 'Altın taç',
  };
}

enum AchievementId {
  firstSession,
  oneHourTotal,
  sevenDayStreak,
  thirtyHourTotal,
}

class AchievementStatus {
  const AchievementStatus({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  final AchievementId id;
  final String title;
  final String description;
  final bool unlocked;
}

List<AchievementStatus> achievementsFor({
  required int sessionCount,
  required int totalSeconds,
  required int streak,
}) {
  return [
    AchievementStatus(
      id: AchievementId.firstSession,
      title: 'İlk kamp',
      description: 'İlk çalışma oturumunu kaydet',
      unlocked: sessionCount >= 1,
    ),
    AchievementStatus(
      id: AchievementId.oneHourTotal,
      title: 'Isınma turu',
      description: 'Toplam 1 saat çalış',
      unlocked: totalSeconds >= 3600,
    ),
    AchievementStatus(
      id: AchievementId.sevenDayStreak,
      title: 'Seri ateşi',
      description: '7 günlük hedef serisine ulaş',
      unlocked: streak >= 7,
    ),
    AchievementStatus(
      id: AchievementId.thirtyHourTotal,
      title: 'Kamp ustası',
      description: 'Toplam 30 saat çalış',
      unlocked: totalSeconds >= 30 * 3600,
    ),
  ];
}

CrownTier crownTierFor(Iterable<AchievementStatus> achievements) {
  final unlocked = achievements.where((a) => a.unlocked).length;
  if (unlocked >= 4) return CrownTier.gold;
  if (unlocked >= 3) return CrownTier.silver;
  if (unlocked >= 2) return CrownTier.bronze;
  return CrownTier.none;
}
