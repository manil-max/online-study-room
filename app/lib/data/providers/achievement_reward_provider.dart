import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/achievement_reward.dart';
import '../repositories/achievement_reward_repository.dart';
import '../repositories/in_memory/in_memory_achievement_reward_repository.dart';
import '../repositories/supabase/supabase_achievement_reward_repository.dart';
import 'auth_providers.dart';

final achievementRewardRepositoryProvider =
    Provider<AchievementRewardRepository>((ref) {
      if (SupabaseConfig.isConfigured) {
        return SupabaseAchievementRewardRepository(Supabase.instance.client);
      }
      final repository = InMemoryAchievementRewardRepository();
      ref.onDispose(repository.dispose);
      return repository;
    });

final pendingAchievementRewardSummaryProvider =
    FutureProvider<AchievementRewardSummary>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return AchievementRewardSummary.empty;
      return ref
          .watch(achievementRewardRepositoryProvider)
          .getPendingSummary(userId: user.id);
    });

final pendingAchievementRewardsProvider =
    FutureProvider.family<AchievementRewardPage, AchievementRewardCursor?>((
      ref,
      cursor,
    ) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const AchievementRewardPage(rewards: []);
      return ref
          .watch(achievementRewardRepositoryProvider)
          .listPendingRewards(userId: user.id, cursor: cursor);
    });

final claimAchievementRewardProvider =
    Provider<Future<AchievementRewardClaimResult> Function(String rewardId)>((
      ref,
    ) {
      return (rewardId) async {
        final user = ref.read(authStateProvider).value;
        if (user == null) {
          throw const AchievementRewardException(
            'Ödül toplamak için giriş yapmalısın.',
          );
        }
        final result = await ref
            .read(achievementRewardRepositoryProvider)
            .claimReward(userId: user.id, rewardId: rewardId);
        ref.invalidate(pendingAchievementRewardSummaryProvider);
        ref.invalidate(pendingAchievementRewardsProvider);
        return result;
      };
    });

final claimAllAchievementRewardsProvider =
    Provider<Future<AchievementRewardClaimResult> Function({int limit})>((ref) {
      return ({int limit = kDefaultAchievementRewardPageSize}) async {
        final user = ref.read(authStateProvider).value;
        if (user == null) {
          throw const AchievementRewardException(
            'Ödül toplamak için giriş yapmalısın.',
          );
        }
        final result = await ref
            .read(achievementRewardRepositoryProvider)
            .claimAll(userId: user.id, limit: limit);
        ref.invalidate(pendingAchievementRewardSummaryProvider);
        ref.invalidate(pendingAchievementRewardsProvider);
        return result;
      };
    });
