import 'dart:async';

import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/achievement_ledger.dart';
import '../../data/models/achievement_metric_progress.dart';
import '../../data/models/achievement_reward.dart';
import '../../data/models/gamification_profile.dart';
import '../../data/models/profile.dart';
import '../../data/models/report_target.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/achievement_provider.dart';
import '../../data/providers/achievement_reward_provider.dart';
import '../../data/providers/gamification_providers.dart';
import '../../data/repositories/achievement_reward_repository.dart';
import '../desktop/desktop_page_scaffold.dart';
import '../safety/block_user_action.dart';
import '../safety/report_sheet.dart';
import 'widgets/achievement_showcase.dart';
import 'widgets/primary_group_entry.dart';
import 'widgets/profile_stats_panel.dart';

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
  late String? _selectedTitleId;
  var _titleUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedTitleId = widget.profile.titleAchievementId;
    // 🔴 WP-421: Sahip "push düştü ama başarımlar ekranında rozet yok, ~2 dk
    // sonra geldi" dedi. Gecikmenin kaynağı push değil **önbellekti**: bu
    // sağlayıcılar yalnız oturum bitişi/ödül toplama gibi olaylarda
    // tazeleniyordu. Ekran her açıldığında sunucudan yeniden okunur; rozet
    // artık push'u beklemez.
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(userAchievementsProvider(widget.profile.id));
      ref.invalidate(gamificationProfileProvider(widget.profile.id));
      ref.invalidate(pendingAchievementRewardSummaryProvider);
      ref.invalidate(pendingAchievementRewardsProvider);
    });
  }

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
          // WP-376: seçim gövdeden çıktı, giriş sağ üstte. Rozet yalnız
          // gerçekten kayıp varken (üyelik var + seçim yok) görünür;
          // yükleme/hata durumunda olmayan bir kayıp ilan edilmez.
          if (isSelf) const PrimaryGroupAppBarAction(),
          if (!isSelf)
            PopupMenuButton<String>(
              tooltip: l10n.safetyReport,
              onSelected: (value) async {
                if (value == 'report') {
                  await showReportSheet(
                    context,
                    ref,
                    // WP-439: tarihsel `user` türü yerine kanonik `profile`.
                    target: ReportTarget.profile(
                      userId: widget.profile.id,
                      hint: widget.profile.displayName,
                    ),
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
        // 🔴 WP-674: yatay pay artık listede DEĞİL, sınırlı içerik sütununun
        // içinde (bkz. [_desktopColumn]). Listede kalsaydı sütun sayfa
        // kenarından 20 px içeride başlar, sağ kenarı 1440 tavanını aşardı.
        padding: isDesktopWindow
            ? getSafeVerticalPadding(
                context,
                horizontal: 20,
                vertical: 16,
              ).copyWith(left: 0, right: 0)
            : getSafeVerticalPadding(context, horizontal: 20, vertical: 16),
        children: [
          _desktopColumn(
            gamificationAsync.when(
              // WP-638: yeniden yükleme sırasında gövde bir spinner'a çökerse
              // ListView içeriği kaybolur ve kaydırma yeri başa döner ("ekran
              // gidip geliyor"). Elde eski veri varsa onu göstermeye devam et;
              // spinner yalnız gerçekten hiç veri yokken çıkar.
              skipLoadingOnReload: true,
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
                  // WP-638: aynı gerekçe — rozet listesi tazelenirken katalog
                  // yok olup yeniden gelmesin.
                  skipLoadingOnReload: true,
                  loading: () => Column(
                    children: [
                      CrownedAvatar(
                        displayName: widget.profile.displayName,
                        avatarUrl: widget.profile.avatarUrl,
                        radius: 44,
                        crownRank: gamification.crownRank,
                        showAura: true,
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
                          // WP-298: aura yalnız bu iki profil yüzeyinde açık.
                          showAura: true,
                        ),
                        SizedBox(height: 16),
                        if (isSelf) const PrimaryGroupMissingBanner(),
                        AchievementShowcase(
                          // WP-660: gunluk seri / aktif gun / rekorlar. Panel
                          // kendi verisini okur; ekran yalnizca yerini verir.
                          // 🔴 WP-674: panel artık KARDEŞ değil, vitrinin SOL
                          // rayında. Kardeş kalsaydı geniş pencerede tek başına
                          // 1440 px'e yayılan bir kart olurdu; SPEC §2.3 kart
                          // tavanı 760 px. Mobilde sıra değişmez.
                          statsPanel: ProfileStatsPanel(
                            userId: widget.profile.id,
                            isSelf: isSelf,
                          ),
                          gamification: gamification,
                          userAchievements: achs,
                          displayName: widget.profile.displayName,
                          titleAchievementId: _selectedTitleId,
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
                          titleUpdating: _titleUpdating,
                          onSelectTitle: isSelf ? _setTitle : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🔴 WP-674 — masaüstünde içerik SPEC §2.3'ün ızgara tavanında (1440 px)
  /// durur ve ortalanır. Ölçüm (düzeltme öncesi, 2560 px pencere): bu ekranın
  /// boyanan içeriği **2512 px** yayılıyordu. Mobil ağaç hiç sarmalanmaz (SPEC §7).
  Widget _desktopColumn(Widget child) {
    if (!isDesktopWindow) return child;
    // 🔴 Hizalama neden ORTALI değil: bu ekran kabuğun üstüne itilen tam
    // pencere bir rotadır. Kapı (`desktop_stretch_probe.dart`) sol gezinme
    // şeridini yalnızca ONSTAGE olduğunda dışlar; tam pencere bir rota
    // şeridi örtünce şerit offstage'e düşer, boyanmaz ama render ağacında
    // KALIR ve glif kutuları ölçüme girer (12..161 px). Ortalanmış bir
    // 1440'lık sütun 2560 px'te 560..2000'e düşerdi; ölçülen aralık
    // 12..2000 = 1988 px olurdu. Başlangıca yaslanmış sütun hem SPEC §2.3'ün
    // 1440 tavanını tutar hem de şerit ile aynı kenardan başlar.
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DesktopBreakpoints.maxContentWidth,
        ),
        // SPEC §6 "BAGLA, ATMA": sınırı masaüstü yüzeyinin kendisi koyar.
        // Dıştaki kutu zaten 1440 verdiği için içerideki ortalama etkisizdir.
        child: DesktopContent(
          maxWidth: DesktopBreakpoints.maxContentWidth,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      ),
    );
  }

  Future<void> _setTitle(String? achievementId) async {
    if (_titleUpdating) return;
    setState(() => _titleUpdating = true);
    try {
      await ref.read(authRepositoryProvider).updateTitle(achievementId);
      if (!mounted) return;
      setState(() => _selectedTitleId = achievementId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profileTitleUpdated),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profileTitleUpdateFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _titleUpdating = false);
    }
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
