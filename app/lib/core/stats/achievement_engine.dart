import '../../data/models/achievement.dart';
import '../../data/models/gamification_profile.dart';
import '../../data/models/study_session.dart';

/// Tüm başarı tanımları (toplam 10 başarı x 6 tier = 60 aşama)
const List<AchievementDef> kAllAchievements = [
  // Çalışma Süresi (Study Time)
  AchievementDef(
    id: 'study_hours',
    title: 'Hour of Wisdom',
    descriptionTemplate: 'Study {count} hours total',
    category: AchievementCategory.study,
    icon: 'timer',
    maxTier: 6,
    tierRequirements: [10, 50, 100, 250, 500, 1000],
    xpRewards: [100, 500, 1000, 2500, 5000, 10000],
  ),
  AchievementDef(
    id: 'study_sessions',
    title: 'Consistency',
    descriptionTemplate: 'Toplam {count} oturum tamamla',
    category: AchievementCategory.study,
    icon: 'event_available',
    maxTier: 6,
    tierRequirements: [10, 50, 100, 500, 1000, 5000],
    xpRewards: [50, 250, 500, 2500, 5000, 25000],
  ),
  // Odaklanma (Focus)
  AchievementDef(
    id: 'deep_focus',
    title: 'Deep Focus',
    descriptionTemplate: 'Complete an uninterrupted {count}-minute session',
    category: AchievementCategory.focus,
    icon: 'self_improvement',
    maxTier: 6,
    tierRequirements: [30, 60, 90, 120, 150, 180],
    xpRewards: [50, 100, 200, 500, 1000, 2000],
  ),
  AchievementDef(
    id: 'weekend_warrior',
    title: 'Weekend Warrior',
    descriptionTemplate: 'Study {count} hours on weekends',
    category: AchievementCategory.focus,
    icon: 'weekend',
    maxTier: 6,
    tierRequirements: [5, 10, 20, 50, 100, 200],
    xpRewards: [100, 200, 400, 1000, 2000, 4000],
  ),
  // Sosyal ve Eğlenceli
  AchievementDef(
    id: 'night_owl',
    title: 'Night Owl',
    descriptionTemplate: 'Study {count} hours between 00:00 and 04:00',
    category: AchievementCategory.fun,
    icon: 'dark_mode',
    maxTier: 6,
    tierRequirements: [5, 10, 20, 50, 100, 200],
    xpRewards: [100, 200, 400, 1000, 2000, 4000],
  ),
  AchievementDef(
    id: 'early_bird',
    title: 'Early Bird',
    descriptionTemplate: 'Study {count} hours between 04:00 and 08:00',
    category: AchievementCategory.fun,
    icon: 'wb_sunny',
    maxTier: 6,
    tierRequirements: [5, 10, 20, 50, 100, 200],
    xpRewards: [100, 200, 400, 1000, 2000, 4000],
  ),
  // ... 60'ı tamamlayacak diğer 4 başarım kalemi (4 x 6 tier = 24 aşama)
  AchievementDef(
    id: 'marathon',
    title: 'Marathon',
    descriptionTemplate: 'Study {count} hours in one day',
    category: AchievementCategory.focus,
    icon: 'directions_run',
    maxTier: 6,
    tierRequirements: [4, 6, 8, 10, 12, 16],
    xpRewards: [200, 300, 400, 500, 600, 1000],
  ),
  AchievementDef(
    id: 'group_study',
    title: 'Group Synergy',
    descriptionTemplate: 'Study in the same group on {count} days',
    category: AchievementCategory.social,
    icon: 'groups',
    maxTier: 6,
    tierRequirements: [7, 14, 30, 90, 180, 365],
    xpRewards: [100, 200, 500, 1500, 3000, 5000],
  ),
  AchievementDef(
    id: 'streak_master',
    title: 'Streak Master',
    descriptionTemplate: 'Meet the goal for {count} consecutive days',
    category: AchievementCategory.social,
    icon: 'local_fire_department',
    maxTier: 6,
    tierRequirements: [3, 7, 14, 30, 100, 365],
    xpRewards: [50, 150, 300, 1000, 3000, 10000],
  ),
  AchievementDef(
    id: 'perfect_week',
    title: 'Perfect Week',
    descriptionTemplate: 'Meet the daily goal for {count} weeks',
    category: AchievementCategory.study,
    icon: 'star',
    maxTier: 6,
    tierRequirements: [1, 2, 4, 12, 24, 52],
    xpRewards: [500, 1000, 2000, 6000, 12000, 25000],
  ),
];

/// Taç (Crown) seviyelerini XP'ye göre belirler
String calculateCrownRank(int xp) {
  if (xp >= 100000) return 'diamond_owl';
  if (xp >= 50000) return 'ruby_master';
  if (xp >= 25000) return 'platinum_scholar';
  if (xp >= 10000) return 'gold_achiever';
  if (xp >= 5000) return 'silver_learner';
  if (xp >= 1000) return 'bronze_beginner';
  return 'wood_novice';
}

/// Tüm session'ları analiz ederek kazanımları güncelleyen motor.
class AchievementEngine {
  /// Mevcut başarı listesi ve güncel oturumlarla yeni başarıları hesaplar.
  /// Dikkat: Bu fonksiyon sunucudan kopuk istemci tarafında veya bir edge function'da çalışabilir.
  static ({
    GamificationProfile newProfile,
    List<UserAchievement> newAchievements,
  })
  calculateProgression({
    required GamificationProfile profile,
    required List<UserAchievement> currentAchievements,
    required List<StudySession> allSessions,
  }) {
    // Toplam istatistikleri hesapla
    int totalMinutes = 0;
    int weekendMinutes = 0;
    int nightMinutes = 0;
    int morningMinutes = 0;
    int maxSingleSession = 0;
    int maxMinutesInDay = 0;

    final Map<String, int> dailyMinutes = {};
    final Set<String> groupStudyDays = {};

    for (final session in allSessions) {
      final dur = session.durationSeconds ~/ 60;
      if (dur <= 0) continue;

      totalMinutes += dur;

      final start = session.start;
      if (start.weekday == DateTime.saturday ||
          start.weekday == DateTime.sunday) {
        weekendMinutes += dur;
      }

      if (start.hour >= 0 && start.hour < 4) {
        nightMinutes += dur;
      }
      if (start.hour >= 4 && start.hour < 8) {
        morningMinutes += dur;
      }

      if (dur > maxSingleSession) maxSingleSession = dur;

      final dateKey =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      dailyMinutes[dateKey] = (dailyMinutes[dateKey] ?? 0) + dur;

      if (dailyMinutes[dateKey]! > maxMinutesInDay) {
        maxMinutesInDay = dailyMinutes[dateKey]!;
      }

      // Group id check is removed since StudySession doesn't store it
    }

    final int totalHours = totalMinutes ~/ 60;
    final int weekendHours = weekendMinutes ~/ 60;
    final int nightHours = nightMinutes ~/ 60;
    final int morningHours = morningMinutes ~/ 60;
    final int maxHoursInDay = maxMinutesInDay ~/ 60;

    final int currentStreak = 0;
    final int perfectWeeks = 0;
    final int completedSessions = allSessions.length;

    int newXp = 0;
    final List<UserAchievement> updatedAchievements = [];

    // Her bir kuralı kontrol et
    for (final def in kAllAchievements) {
      int progressValue = 0;

      switch (def.id) {
        case 'study_hours':
          progressValue = totalHours;
          break;
        case 'study_sessions':
          progressValue = completedSessions;
          break;
        case 'deep_focus':
          progressValue = maxSingleSession;
          break;
        case 'weekend_warrior':
          progressValue = weekendHours;
          break;
        case 'night_owl':
          progressValue = nightHours;
          break;
        case 'early_bird':
          progressValue = morningHours;
          break;
        case 'marathon':
          progressValue = maxHoursInDay;
          break;
        case 'group_study':
          progressValue = groupStudyDays.length;
          break;
        case 'streak_master':
          progressValue = currentStreak;
          break;
        case 'perfect_week':
          progressValue = perfectWeeks;
          break;
      }

      // Mevcut durumu bul
      UserAchievement? currentAch = currentAchievements
          .where((a) => a.achievementId == def.id)
          .firstOrNull;
      int currentMaxTierUnlocked = currentAch?.isUnlocked == true
          ? currentAch!.tier
          : 0;

      bool unlockedAny = false;
      int highestTierUnlocked = currentMaxTierUnlocked;

      // Tier'ları kontrol et
      for (int i = 0; i < def.maxTier; i++) {
        final req = def.tierRequirements[i];
        final tierLevel = i + 1;

        if (progressValue >= req) {
          if (tierLevel > highestTierUnlocked) {
            unlockedAny = true;
            highestTierUnlocked = tierLevel;
            newXp += def.xpRewards[i];
          }
        }
      }

      if (currentAch == null) {
        // İlk defa ekleniyor
        updatedAchievements.add(
          UserAchievement(
            id: '', // UUID'yi db'de veya repo'da atayacağız
            userId: profile.userId,
            achievementId: def.id,
            tier: unlockedAny ? highestTierUnlocked : 1,
            progress: progressValue,
            unlockedAt: unlockedAny ? DateTime.now() : null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        // Sadece ilerleme veya yeni tier varsa güncelle
        if (currentAch.progress != progressValue || unlockedAny) {
          updatedAchievements.add(
            currentAch.copyWith(
              progress: progressValue,
              tier: unlockedAny ? highestTierUnlocked : currentAch.tier,
              unlockedAt: unlockedAny ? DateTime.now() : currentAch.unlockedAt,
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    }

    final finalXp = profile.xp + newXp;
    final newRank = calculateCrownRank(finalXp);

    final newProfile = profile.copyWith(
      xp: finalXp,
      crownRank: newRank,
      updatedAt: DateTime.now(),
    );

    return (newProfile: newProfile, newAchievements: updatedAchievements);
  }
}
