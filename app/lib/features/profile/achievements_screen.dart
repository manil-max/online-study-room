import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/achievement_engine.dart';
import '../../data/models/achievement.dart';
import '../../data/models/gamification_profile.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/gamification_providers.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).value?.id;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Giriş yapmalısınız.')));
    }

    // WP-56: ekran açılınca process_achievement_event (idempotent).
    ref.watch(gamificationProgressSyncProvider);

    final profileAsync = ref.watch(gamificationProfileProvider(userId));
    final achievementsAsync = ref.watch(userAchievementsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Başarı Yolculuğu 🏆'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Hata: $err')),
        data: (profile) {
          return achievementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Hata: $err')),
            data: (userAchvs) {
              return _AchievementsContent(
                profile: profile,
                userAchievements: userAchvs,
              );
            },
          );
        },
      ),
    );
  }
}

class _AchievementsContent extends ConsumerWidget {
  const _AchievementsContent({
    required this.profile,
    required this.userAchievements,
  });

  final GamificationProfile profile;
  final List<UserAchievement> userAchievements;

  void _toggleBadge(BuildContext context, WidgetRef ref, String badgeId) {
    final isSelected = profile.selectedBadges.contains(badgeId);
    List<String> newBadges = List.from(profile.selectedBadges);

    if (isSelected) {
      newBadges.remove(badgeId);
    } else {
      if (newBadges.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vitrine en fazla 3 rozet ekleyebilirsiniz.')),
        );
        return;
      }
      newBadges.add(badgeId);
    }

    final repo = ref.read(gamificationRepositoryProvider);
    repo.updateProfile(profile.copyWith(selectedBadges: newBadges));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kategoriye göre grupla
    final grouped = <AchievementCategory, List<AchievementDef>>{};
    for (final def in kAllAchievements) {
      grouped.putIfAbsent(def.category, () => []).add(def);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryHeader(context),
        const SizedBox(height: 24),
        ...grouped.entries.map((e) => _buildCategorySection(context, ref, e.key, e.value)),
      ],
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'Toplam XP',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${profile.xp}',
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(
              'Rütbe: ${profile.crownRank.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: theme.colorScheme.primaryContainer,
          ),
          const SizedBox(height: 16),
          Text(
            'Vitrine seçili rozetler: ${profile.selectedBadges.length}/3',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary),
          )
        ],
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, WidgetRef ref, AchievementCategory category, List<AchievementDef> items) {
    final theme = Theme.of(context);
    String catName;
    switch (category) {
      case AchievementCategory.study: catName = 'Çalışma'; break;
      case AchievementCategory.focus: catName = 'Odaklanma'; break;
      case AchievementCategory.social: catName = 'Sosyal'; break;
      case AchievementCategory.fun: catName = 'Eğlenceli'; break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            catName,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...items.map((def) {
          final userAch = userAchievements.where((a) => a.achievementId == def.id).firstOrNull;
          final isUnlocked = userAch?.isUnlocked == true;
          final isSelected = profile.selectedBadges.contains(def.id);
          
          final currentTier = isUnlocked ? userAch!.tier : 1;
          final currentReq = def.tierRequirements[currentTier - 1];
          final progress = userAch?.progress ?? 0;
          final progressPercent = (progress / currentReq).clamp(0.0, 1.0);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: Opacity(
              opacity: isUnlocked ? 1.0 : 0.6,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: _buildIcon(context, def.icon, currentTier, isUnlocked),
                title: Row(
                  children: [
                    Expanded(child: Text(def.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (isUnlocked)
                      IconButton(
                        icon: Icon(
                          isSelected ? Icons.push_pin : Icons.push_pin_outlined,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                        onPressed: () => _toggleBadge(context, ref, def.id),
                        tooltip: isSelected ? 'Vitrinden Kaldır' : 'Vitrine Ekle',
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(def.getDescription(currentReq)),
                    const SizedBox(height: 8),
                    if (!isUnlocked || currentTier < def.maxTier) ...[
                      LinearProgressIndicator(value: progressPercent),
                      const SizedBox(height: 4),
                      Text('$progress / $currentReq', style: theme.textTheme.bodySmall),
                    ] else ...[
                      Text('Maksimum seviyeye ulaşıldı!', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
                    ]
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildIcon(BuildContext context, String iconName, int tier, bool isUnlocked) {
    IconData iconData;
    switch (iconName) {
      case 'timer': iconData = Icons.timer; break;
      case 'event_available': iconData = Icons.event_available; break;
      case 'self_improvement': iconData = Icons.self_improvement; break;
      case 'weekend': iconData = Icons.weekend; break;
      case 'dark_mode': iconData = Icons.dark_mode; break;
      case 'wb_sunny': iconData = Icons.wb_sunny; break;
      case 'directions_run': iconData = Icons.directions_run; break;
      case 'groups': iconData = Icons.groups; break;
      case 'local_fire_department': iconData = Icons.local_fire_department; break;
      case 'star': iconData = Icons.star; break;
      default: iconData = Icons.emoji_events;
    }

    Color color = isUnlocked ? Theme.of(context).colorScheme.primary : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 32),
    );
  }
}
