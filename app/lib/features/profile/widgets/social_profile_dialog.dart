import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/achievement_engine.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/gamification_providers.dart';

class SocialProfileDialog extends ConsumerWidget {
  const SocialProfileDialog({
    super.key,
    required this.profile,
  });

  final Profile profile;

  static void show(BuildContext context, Profile profile) {
    showDialog(
      context: context,
      builder: (context) => SocialProfileDialog(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamificationAsync = ref.watch(gamificationProfileProvider(profile.id));
    final achievementsAsync = ref.watch(userAchievementsProvider(profile.id));
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst Bölüm (Avatar ve İsim)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: theme.colorScheme.surface,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        profile.displayName.substring(0, 1).toUpperCase(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            
            // Kullanıcı Adı
            Text(
              profile.displayName,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            
            // Gamification Verileri
            gamificationAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Profil yüklenemedi: $err'),
              ),
              data: (gamification) {
                return Column(
                  children: [
                    _CrownBadge(rank: gamification.crownRank, xp: gamification.xp),
                    const SizedBox(height: 16),
                    
                    // Rozet Vitrini
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Vitrin',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            achievementsAsync.when(
                              loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
                              error: (_, _) => const SizedBox(height: 40, child: Center(child: Text('Hata'))),
                              data: (achievements) => _BadgeShowcase(
                                selectedBadgeIds: gamification.selectedBadges,
                                allAchievements: achievements,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownBadge extends StatelessWidget {
  const _CrownBadge({required this.rank, required this.xp});
  final String rank;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Rank'a göre renk ve ikon belirleme
    Color rankColor;
    String rankLabel;
    
    switch (rank) {
      case 'diamond_owl':
        rankColor = Colors.cyanAccent;
        rankLabel = 'Elmas Baykuş';
        break;
      case 'ruby_master':
        rankColor = Colors.redAccent;
        rankLabel = 'Yakut Üstat';
        break;
      case 'platinum_scholar':
        rankColor = Colors.blueGrey.shade300;
        rankLabel = 'Platin Bilgin';
        break;
      case 'gold_achiever':
        rankColor = Colors.amber;
        rankLabel = 'Altın Başaran';
        break;
      case 'silver_learner':
        rankColor = Colors.grey.shade400;
        rankLabel = 'Gümüş Öğrenci';
        break;
      case 'bronze_beginner':
        rankColor = Colors.brown.shade400;
        rankLabel = 'Bronz Başlangıç';
        break;
      default:
        rankColor = Colors.brown.shade800;
        rankLabel = 'Ahşap Çaylak';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: rankColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, color: rankColor, size: 20),
          const SizedBox(width: 8),
          Text(
            rankLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: rankColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$xp XP',
              style: theme.textTheme.bodySmall?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeShowcase extends StatelessWidget {
  const _BadgeShowcase({
    required this.selectedBadgeIds,
    required this.allAchievements,
  });

  final List<String> selectedBadgeIds;
  final List<UserAchievement> allAchievements;

  @override
  Widget build(BuildContext context) {
    if (selectedBadgeIds.isEmpty) {
      return const Center(
        child: Text('Henüz vitrine rozet eklenmedi.'),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        if (index >= selectedBadgeIds.length) {
          return const _EmptyBadgeSlot();
        }
        
        final badgeId = selectedBadgeIds[index];
        final achDef = kAllAchievements.firstWhere(
          (d) => d.id == badgeId,
          orElse: () => kAllAchievements.first,
        );
        final userAch = allAchievements.firstWhere(
          (a) => a.achievementId == badgeId,
          orElse: () => UserAchievement(
            id: '',
            userId: '',
            achievementId: badgeId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        return _BadgeItem(def: achDef, userAch: userAch);
      }),
    );
  }
}

class _EmptyBadgeSlot extends StatelessWidget {
  const _EmptyBadgeSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  const _BadgeItem({required this.def, required this.userAch});

  final AchievementDef def;
  final UserAchievement userAch;

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'timer': return Icons.timer;
      case 'event_available': return Icons.event_available;
      case 'self_improvement': return Icons.self_improvement;
      case 'weekend': return Icons.weekend;
      case 'dark_mode': return Icons.dark_mode;
      case 'wb_sunny': return Icons.wb_sunny;
      case 'directions_run': return Icons.directions_run;
      case 'groups': return Icons.groups;
      case 'local_fire_department': return Icons.local_fire_department;
      case 'star': return Icons.star;
      default: return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tier rengi
    final Color tierColor;
    if (userAch.tier >= 6) {
      tierColor = Colors.cyanAccent;
    } else if (userAch.tier >= 4) {
      tierColor = Colors.amber;
    } else if (userAch.tier >= 2) {
      tierColor = Colors.grey.shade400;
    } else {
      tierColor = Colors.brown.shade400;
    }

    return Tooltip(
      message: '${def.title} (Aşama ${userAch.tier})\n${def.getDescription(def.tierRequirements[userAch.tier - 1])}',
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              tierColor.withValues(alpha: 0.3),
              tierColor.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(color: tierColor, width: 2),
        ),
        child: Center(
          child: Icon(_getIconData(def.icon), color: tierColor, size: 32),
        ),
      ),
    );
  }
}
