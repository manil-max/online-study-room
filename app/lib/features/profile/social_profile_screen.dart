import 'dart:async';

import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/achievement_ledger.dart';
import '../../data/models/achievement_metric_progress.dart';
import '../../data/models/achievement_reward.dart';
import '../../data/models/gamification_profile.dart';
import '../../data/models/profile.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/achievement_provider.dart';
import '../../data/providers/achievement_reward_provider.dart';
import '../../data/providers/gamification_providers.dart';
import '../../data/repositories/achievement_reward_repository.dart';
import '../safety/block_user_action.dart';
import '../safety/report_sheet.dart';
import 'widgets/achievement_showcase.dart';

/// Sosyal profil vitrini (Başarım 3.0 R2 / WP-57).
///
/// Ortak grup üyesinin XP/taç/rozetlerini salt-okunur gösterir (RLS:
/// `can_see_user_sessions`). Kendi profilinde vitrin rozeti seçilebilir.
class SocialProfileScreen extends ConsumerStatefulWidget {
  const SocialProfileScreen({
    super.key,
    required this.profile,
    this.newlyAwarded = const [],
  });

  final Profile profile;
  final List<AchievementAward> newlyAwarded;

  static Future<void> open(
    BuildContext context,
    Profile profile, {
    List<AchievementAward> newlyAwarded = const [],
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            SocialProfileScreen(profile: profile, newlyAwarded: newlyAwarded),
      ),
    );
  }

  @override
  ConsumerState<SocialProfileScreen> createState() =>
      _SocialProfileScreenState();
}

class _SocialProfileScreenState extends ConsumerState<SocialProfileScreen> {
  final Set<String> _claimingRewardIds = {};
  final List<AchievementAward> _claimedAwards = [];
  var _claimingAll = false;
  var _capabilityRecorded = false;

  @override
  Widget build(BuildContext context) {
    final selfId = ref.watch(authStateProvider).value?.id;
    final isSelf = selfId != null && selfId == widget.profile.id;

    if (isSelf) {
      ref.watch(gamificationProgressSyncProvider);
      _recordRewardCapability();
    }

    final gamificationAsync = ref.watch(
      gamificationProfileProvider(widget.profile.id),
    );
    final achievementsAsync = ref.watch(
      userAchievementsProvider(widget.profile.id),
    );
    final List<AchievementMetricProgress> metricProgress = isSelf
        ? ref.watch(achievementMetricProgressProvider).asData?.value ?? const []
        : const [];
    final rewardPageAsync = isSelf
        ? ref.watch(pendingAchievementRewardsProvider(null))
        : null;
    final rewardSummaryAsync = isSelf
        ? ref.watch(pendingAchievementRewardSummaryProvider)
        : null;
    final pendingRewards = rewardPageAsync?.asData?.value.rewards ?? const [];
    final pendingCount =
        rewardSummaryAsync?.asData?.value.pendingCount ?? pendingRewards.length;
    final pendingXp =
        rewardSummaryAsync?.asData?.value.pendingXp ??
        pendingRewards.fold<int>(0, (sum, reward) => sum + reward.xpAmount);
    final liveAwards = isSelf
        ? ref.watch(lastAchievementAwardsProvider)
        : const <AchievementAward>[];
    final confettiAwards = <AchievementAward>[
      ...(widget.newlyAwarded.isNotEmpty ? widget.newlyAwarded : liveAwards),
      ..._claimedAwards,
    ];
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelf
              ? AppLocalizations.of(context).profileBasarYolculugum
              : AppLocalizations.of(context).profileSosyalProfil,
        ),
        actions: [
          if (!isSelf)
            PopupMenuButton<String>(
              tooltip: l10n.safetyReport,
              onSelected: (value) async {
                if (value == 'report') {
                  await showReportSheet(
                    context,
                    ref,
                    targetType: 'user',
                    targetId: widget.profile.id,
                    snapshot: widget.profile.displayName,
                  );
                } else if (value == 'block') {
                  await confirmAndBlockUser(
                    context,
                    ref,
                    userId: widget.profile.id,
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'report', child: Text(l10n.safetyReport)),
                PopupMenuItem(value: 'block', child: Text(l10n.safetyBlock)),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: getSafeVerticalPadding(context, horizontal: 20, vertical: 16),
        children: [
          gamificationAsync.when(
            loading: () => Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.profileBeklenmeyenBirHataOlustu,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
            data: (gamification) {
              return achievementsAsync.when(
                loading: () => Column(
                  children: [
                    CrownedAvatar(
                      displayName: widget.profile.displayName,
                      avatarUrl: widget.profile.avatarUrl,
                      radius: 44,
                      crownRank: gamification.crownRank,
                    ),
                    SizedBox(height: 24),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (err, _) => Text(
                  l10n.profileBasarimlarYuklenemedi,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                data: (achs) {
                  return Column(
                    children: [
                      CrownedAvatar(
                        displayName: widget.profile.displayName,
                        avatarUrl: widget.profile.avatarUrl,
                        radius: 44,
                        crownRank: gamification.crownRank,
                      ),
                      SizedBox(height: 16),
                      AchievementShowcase(
                        gamification: gamification,
                        userAchievements: achs,
                        displayName: widget.profile.displayName,
                        isSelf: isSelf,
                        compact: false,
                        showCatalog: true,
                        forceConfettiAwards: confettiAwards,
                        metricProgress: metricProgress,
                        pendingRewards: pendingRewards,
                        pendingRewardCount: pendingCount,
                        pendingRewardXp: pendingXp,
                        rewardsLoading:
                            rewardPageAsync?.isLoading == true ||
                            rewardSummaryAsync?.isLoading == true,
                        rewardError:
                            rewardPageAsync?.hasError == true ||
                            rewardSummaryAsync?.hasError == true,
                        claimingRewardIds: _claimingRewardIds,
                        claimingAllRewards: _claimingAll,
                        onClaimReward: isSelf
                            ? (reward) => _claimReward(reward)
                            : null,
                        onClaimAllRewards: isSelf && pendingRewards.isNotEmpty
                            ? () => unawaited(_claimAll(pendingRewards))
                            : null,
                        onRetryRewards: isSelf ? _retryRewards : null,
                        onToggleShowcaseBadge: isSelf
                            ? (badgeId) => _toggleBadge(
                                context,
                                ref,
                                gamification,
                                badgeId,
                              )
                            : null,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _recordRewardCapability() {
    if (_capabilityRecorded) return;
    _capabilityRecorded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authStateProvider).value;
      if (user == null || user.id != widget.profile.id) return;
      unawaited(
        ref
            .read(achievementRewardRepositoryProvider)
            .recordCapability(
              userId: user.id,
              capability: kRewardInboxCapability,
            )
            .catchError((_) {}),
      );
    });
  }

  Future<void> _claimReward(AchievementReward reward) async {
    if (_claimingAll || !_claimingRewardIds.add(reward.id)) return;
    setState(() {});
    try {
      final result = await ref.read(claimAchievementRewardProvider)(reward.id);
      if (!mounted) return;
      if (result.changed) {
        _claimedAwards.add(
          AchievementAward(
            achievementId: reward.achievementId,
            tier: reward.tier,
            xp: result.xpGranted,
          ),
        );
        _refreshClaimedState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).profileRewardClaimed(result.xpGranted),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileRewardAlreadyClaimed,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) _showClaimError();
    } finally {
      if (mounted) {
        setState(() => _claimingRewardIds.remove(reward.id));
      }
    }
  }

  Future<void> _claimAll(List<AchievementReward> visibleRewards) async {
    if (_claimingAll || _claimingRewardIds.isNotEmpty) return;
    setState(() => _claimingAll = true);
    try {
      final result = await ref.read(claimAllAchievementRewardsProvider)();
      if (!mounted) return;
      final claimedIds = result.claimedRewardIds.toSet();
      if (result.changed) {
        for (final reward in visibleRewards) {
          if (claimedIds.contains(reward.id)) {
            _claimedAwards.add(
              AchievementAward(
                achievementId: reward.achievementId,
                tier: reward.tier,
                xp: reward.xpAmount,
              ),
            );
          }
        }
        _refreshClaimedState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).profileRewardClaimed(result.xpGranted),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileRewardAlreadyClaimed,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) _showClaimError();
    } finally {
      if (mounted) setState(() => _claimingAll = false);
    }
  }

  void _refreshClaimedState() {
    ref.invalidate(gamificationProfileProvider(widget.profile.id));
    ref.invalidate(userAchievementsProvider(widget.profile.id));
    ref.invalidate(pendingAchievementRewardSummaryProvider);
    ref.invalidate(pendingAchievementRewardsProvider);
    setState(() {});
  }

  void _retryRewards() {
    ref.invalidate(pendingAchievementRewardSummaryProvider);
    ref.invalidate(pendingAchievementRewardsProvider);
  }

  void _showClaimError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).profileRewardClaimFailed),
      ),
    );
  }

  void _toggleBadge(
    BuildContext context,
    WidgetRef ref,
    GamificationProfile gamification,
    String badgeId,
  ) {
    final selected = List<String>.from(gamification.selectedBadges);
    final isSelected = selected.contains(badgeId);
    if (isSelected) {
      selected.remove(badgeId);
    } else {
      if (selected.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).profileVitrineEnFazla3),
          ),
        );
        return;
      }
      selected.add(badgeId);
    }
    ref
        .read(gamificationRepositoryProvider)
        .updateProfile(gamification.copyWith(selectedBadges: selected));
  }
}
