import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/stats/achievement_ledger_engine.dart';
import '../../../core/stats/progression_visuals.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/achievement_ledger.dart';
import '../../../data/models/gamification_profile.dart';

export '../../../core/stats/progression_visuals.dart'
    show crownColorFor, crownLabel, xpBarMetrics, tierColorFor;

IconData achievementIconData(String iconKey) {
  switch (iconKey) {
    case 'timer':
      return Icons.timer;
    case 'self_improvement':
      return Icons.self_improvement;
    case 'directions_run':
      return Icons.directions_run;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'weekend':
      return Icons.weekend;
    case 'star':
      return Icons.star;
    case 'emoji_events':
      return Icons.emoji_events;
    case 'groups':
      return Icons.groups;
    case 'whatshot':
      return Icons.whatshot;
    case 'campaign':
      return Icons.campaign;
    case 'train':
      return Icons.train;
    case 'dark_mode':
      return Icons.dark_mode;
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'error_outline':
      return Icons.error_outline;
    case 'functions':
      return Icons.functions;
    case 'block':
      return Icons.block;
    case 'hourglass_bottom':
      return Icons.hourglass_bottom;
    case 'sports_esports':
      return Icons.sports_esports;
    case 'trending_up':
      return Icons.trending_up;
    case 'memory':
      return Icons.memory;
    case 'celebration':
      return Icons.celebration;
    default:
      return Icons.emoji_events_outlined;
  }
}

String _crownLabel(AppLocalizations l10n, String rank) {
  return switch (normalizeCrownRank(rank)) {
    'diamond_owl' => l10n.coreElmasTac,
    'platinum_scholar' => l10n.corePlatinTac,
    'gold_achiever' => l10n.coreAltinTac,
    'silver_learner' => l10n.coreGumusTac,
    _ => l10n.coreBronzTac,
  };
}

String _tierLabel(AppLocalizations l10n, int tier) {
  return switch (tier.clamp(1, 5)) {
    1 => l10n.coreBronz,
    2 => l10n.coreGumus,
    3 => l10n.coreAltin,
    4 => l10n.corePlatin,
    _ => l10n.coreElmas,
  };
}

String categoryLabelTr(AppLocalizations l10n, String category) {
  switch (category) {
    case 'study':
      return l10n.profileCalisma;
    case 'streak':
      return l10n.profileSeriVeDuzen;
    case 'group':
      return l10n.profileGrup;
    case 'social':
      return l10n.profileSosyal;
    case 'secret':
      return l10n.profileGizli;
    default:
      return category;
  }
}

/// Bir başarım kademesinin kullanıcıya gösterilen, doğal dildeki şartı.
/// Sözlük/RPC'deki teknik `unit` değeri asla doğrudan kullanıcıya gösterilmez.
String achievementTierConditionTr(
  AppLocalizations l10n,
  AchievementDictEntry achievement,
  AchievementTierDef tier,
) {
  final value = tier.threshold;
  switch (achievement.id) {
    case 'marathon_total':
      return l10n.profileBasarimToplamSaatKosulu(value);
    case 'steel_will':
      return l10n.profileBasarimTekOturumKosulu(value);
    case 'day_hero':
      return l10n.profileBasarimGunlukSaatKosulu(value);
    case 'fire_streak':
      return l10n.profileBasarimSeriKosulu(value);
    case 'weekend_goal_days':
      return l10n.profileBasarimHaftaSonuKosulu(value);
    case 'perfect_month':
      return l10n.profileBasarimKusursuzAyKosulu(value);
    case 'alpha_wolf':
      return l10n.profileBasarimGrupBirinciligiKosulu(value);
    case 'team_player':
      return l10n.profileBasarimGrupHedefKosulu(value);
    case 'campfire_hours':
      return l10n.profileBasarimKampAtesiKosulu(value);
    case 'inspiration':
      return l10n.profileBasarimDurtmeKosulu(value);
    case 'locomotive':
      return l10n.profileBasarimLokomotifKosulu(value);
  }
  switch (tier.unit) {
    case 'hours':
      return l10n.commonHourCount(value);
    case 'minutes':
      return l10n.commonMinuteCount(value);
    case 'day_hours':
      return l10n.commonHourCount(value);
    case 'streak_days':
      return '$value · ${l10n.profileSeriVeDuzen}';
    case 'weekend_goal_days':
      return '$value · ${l10n.profileGunlukHedef}';
    case 'perfect_months':
      return '$value · ${l10n.profileGunlukHedef}';
    case 'group_day_first':
      return '$value · ${l10n.profileGrup}';
    case 'group_goal_contrib':
      return '$value · ${l10n.profileGrup}';
    case 'campfire_hours':
      return '${l10n.commonHourCount(value)} · ${l10n.profileGrup}';
    case 'nudge_starts':
      return '$value · ${l10n.profileCalisma}';
    case 'locomotive_events':
      return '$value · ${l10n.profileGrup}';
    case 'secret_night_owl':
      return l10n.profileGizliBirBasarimAcmak;
    case 'secret_dawn':
      return l10n.profileGizliBirBasarimAcmak;
    case 'secret_404':
      return l10n.profileTam404DakikaSuren;
    case 'secret_pi':
      return l10n.profileTam194DakikaSuren;
    case 'secret_last_second':
      return l10n.profileGizliBirBasarimAcmak;
    case 'secret_1337':
      return l10n.profileGizliBirBasarimAcmak;
    case 'secret_no_limits':
      return l10n.profileBirGundeGunlukHedefinin;
    case 'secret_matrix':
      return l10n.profileGizliBirBasarimAcmak;
    case 'secret_nye':
      return l10n.profileGizliBirBasarimAcmak;
    case 'secret_break_enemy':
      return l10n.profileBuGizliBasariminKosulu;
    default:
      return '$value';
  }
}

String achievementDetailDescription(
  AppLocalizations l10n,
  AchievementDictEntry achievement,
  bool unlocked,
) {
  if (!achievement.isSecret) {
    return l10n.profileBasarimKademeleriniTamamla;
  }
  if (!unlocked) return l10n.profileGizliBirBasarimAcmak;
  return switch (achievement.id) {
    'secret_night_owl' => l10n.profileBasarimGeceKusuAciklama,
    'secret_dawn' => l10n.profileBasarimGunDogumuAciklama,
    'secret_404' => l10n.profileBasarim404Aciklama,
    'secret_pi' => l10n.profileBasarimPiAciklama,
    'secret_last_second' => l10n.profileBasarimSonSaniyeAciklama,
    'secret_1337' => l10n.profileBasarim1337Aciklama,
    'secret_no_limits' => l10n.profileBasarimSinirTanimazAciklama,
    'secret_matrix' => l10n.profileBasarimMatrixAciklama,
    'secret_nye' => l10n.profileBasarimYilbasiAciklama,
    'secret_break_enemy' => l10n.profileBuGizliBasariminKosulu,
    _ => achievement.description,
  };
}

/// Oyunlaştırılmış vitrin: XP barı, taç, vitrin rozetleri, katalog + confetti.
///
/// WP-57. Gizli başarımlar kilitliyken `?????` / siyah siluet.
class AchievementShowcase extends StatefulWidget {
  const AchievementShowcase({
    super.key,
    required this.gamification,
    required this.userAchievements,
    this.displayName,
    this.isSelf = false,
    this.compact = false,
    this.showCatalog = true,
    this.onToggleShowcaseBadge,
    this.forceConfettiAwards = const [],
    this.dictionary,
  });

  final GamificationProfile gamification;
  final List<UserAchievement> userAchievements;
  final String? displayName;
  final bool isSelf;
  final bool compact;
  final bool showCatalog;
  final ValueChanged<String>? onToggleShowcaseBadge;

  /// Dışarıdan bilinen yeni ödüller (confetti tetikler).
  final List<AchievementAward> forceConfettiAwards;

  final List<AchievementDictEntry>? dictionary;

  @override
  State<AchievementShowcase> createState() => AchievementShowcaseState();
}

/// Test / dışarıdan confetti tetiklemek için state tipi public.
class AchievementShowcaseState extends State<AchievementShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  Set<String> _seenUnlockKeys = {};
  var _confettiArmed = false;
  DateTime? _confettiStartedAt;

  List<AchievementDictEntry> get _dict =>
      widget.dictionary ?? kAchievementDictV3(AppLocalizations.of(context));

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1400),
    );
    _seenUnlockKeys = _unlockKeys(widget.userAchievements);
    if (widget.forceConfettiAwards.isNotEmpty) {
      _scheduleConfetti();
    }
  }

  @override
  void didUpdateWidget(covariant AchievementShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _unlockKeys(widget.userAchievements);
    final gained = next.difference(_seenUnlockKeys);
    if (gained.isNotEmpty ||
        widget.forceConfettiAwards.length >
            oldWidget.forceConfettiAwards.length) {
      _scheduleConfetti();
    }
    _seenUnlockKeys = next;
  }

  Set<String> _unlockKeys(List<UserAchievement> list) {
    return {
      for (final a in list)
        if (a.isUnlocked) '${a.achievementId}|${a.tier}',
    };
  }

  /// Kabul: animasyon ≤ 250 ms içinde render (ilk frame).
  void _scheduleConfetti() {
    if (_confettiArmed) return;
    _confettiArmed = true;
    _confettiStartedAt = DateTime.now();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _confettiController.forward(from: 0).whenComplete(() {
        if (mounted) {
          setState(() => _confettiArmed = false);
        } else {
          _confettiArmed = false;
        }
      });
      // İlk çizim bu frame'de — testlerde elapsed ≤ 250 ms doğrulanır.
      setState(() {});
    });
  }

  /// Test yardımcısı: confetti görünür mü?
  @visibleForTesting
  bool get confettiVisible => _confettiArmed || _confettiController.isAnimating;

  @visibleForTesting
  DateTime? get confettiStartedAt => _confettiStartedAt;

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  UserAchievement? _userAch(String id) {
    for (final a in widget.userAchievements) {
      if (a.achievementId == id) return a;
    }
    return null;
  }

  bool _isUnlocked(AchievementDictEntry def) {
    final u = _userAch(def.id);
    return u?.isUnlocked == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xp = widget.gamification.xp;
    final rank = widget.gamification.crownRank;
    final bar = xpBarMetrics(xp);
    final rankColor = crownColorFor(rank, theme.colorScheme);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (widget.displayName != null) ...[
          Text(
            widget.displayName!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
        ],
        _CrownHeader(rank: rank, rankColor: rankColor, xp: xp),
        SizedBox(height: 12),
        _XpBar(
          progress: bar.progress,
          xp: xp,
          next: bar.next,
          floor: bar.floor,
          color: rankColor,
        ),
        SizedBox(height: 16),
        _VitrinRow(
          selectedIds: widget.gamification.selectedBadges,
          dictionary: _dict,
          userAchievements: widget.userAchievements,
          isSelf: widget.isSelf,
          onToggle: widget.onToggleShowcaseBadge,
        ),
        if (widget.showCatalog && !widget.compact) ...[
          SizedBox(height: 20),
          Text(
            AppLocalizations.of(context).profileBasariKatalogu,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ..._buildCatalog(theme),
        ],
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        if (confettiVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confettiController.value,
                      seed: xp + rank.hashCode,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildCatalog(ThemeData theme) {
    final byCat = <String, List<AchievementDictEntry>>{};
    for (final d in _dict) {
      // Saat XP vb. sistem satırları rozet kataloğunda yok.
      if (d.category == 'system' || d.id == kStudyHourAchievementId) continue;
      byCat.putIfAbsent(d.category, () => []).add(d);
    }
    const order = ['study', 'streak', 'group', 'social', 'secret'];
    final widgets = <Widget>[];
    for (final cat in order) {
      final items = byCat[cat];
      if (items == null || items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            categoryLabelTr(AppLocalizations.of(context), cat),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final def in items) {
        widgets.add(
          _CatalogTile(
            def: def,
            userAch: _userAch(def.id),
            unlocked: _isUnlocked(def),
            isSelected: widget.gamification.selectedBadges.contains(def.id),
            isSelf: widget.isSelf,
            onToggle: widget.onToggleShowcaseBadge,
          ),
        );
      }
    }
    return widgets;
  }
}

class _CrownHeader extends StatelessWidget {
  const _CrownHeader({
    required this.rank,
    required this.rankColor,
    required this.xp,
  });

  final String rank;
  final Color rankColor;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: rankColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium, color: rankColor, size: 22),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              _crownLabel(AppLocalizations.of(context), rank),
              style: theme.textTheme.titleSmall?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$xp XP',
              style: theme.textTheme.labelLarge?.copyWith(
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

class _XpBar extends StatelessWidget {
  const _XpBar({
    required this.progress,
    required this.xp,
    required this.next,
    required this.floor,
    required this.color,
  });

  final double progress;
  final int xp;
  final int next;
  final int floor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atCap = xp >= kCrownXpThresholds.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: atCap ? 1 : progress,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        SizedBox(height: 6),
        Text(
          atCap
              ? AppLocalizations.of(context).profileTamamland
              : '$xp / $next XP (${(progress * 100).round()}%)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 5; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: tierColorFor(i).withValues(
                            alpha: crownTierNumber(crownRankForXp(xp)) >= i
                                ? 1
                                : 0.25,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _tierLabel(AppLocalizations.of(context), i),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: tierColorFor(i),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VitrinRow extends StatelessWidget {
  const _VitrinRow({
    required this.selectedIds,
    required this.dictionary,
    required this.userAchievements,
    required this.isSelf,
    this.onToggle,
  });

  final List<String> selectedIds;
  final List<AchievementDictEntry> dictionary;
  final List<UserAchievement> userAchievements;
  final bool isSelf;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            isSelf
                ? '${AppLocalizations.of(context).profileVitrin} · 3'
                : AppLocalizations.of(context).profileVitrin,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              if (i >= selectedIds.length) {
                return _EmptySlot(
                  hint: isSelf ? AppLocalizations.of(context).profileEkle : '—',
                );
              }
              final id = selectedIds[i];
              AchievementDictEntry? found;
              for (final d in dictionary) {
                if (d.id == id) {
                  found = d;
                  break;
                }
              }
              final def =
                  found ??
                  AchievementDictEntry(
                    id: id,
                    category: 'study',
                    name: id,
                    description: '',
                    maxTier: 1,
                    iconKey: 'emoji_events',
                    isSecret: false,
                    tiers: [],
                  );
              UserAchievement? ua;
              for (final a in userAchievements) {
                if (a.achievementId == id) {
                  ua = a;
                  break;
                }
              }
              return _BadgeCircle(
                def: def,
                tier: ua?.tier ?? 1,
                unlocked: ua?.isUnlocked == true,
                userAch: ua,
                onLongPress: isSelf && onToggle != null
                    ? () => onToggle!(id)
                    : null,
                onTap: () => showAchievementDetail(
                  context,
                  def: def,
                  userAch: ua,
                  unlocked: ua?.isUnlocked == true,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Profil vitrininde veya katalogda rozete basınca açıklama.
Future<void> showAchievementDetail(
  BuildContext context, {
  required AchievementDictEntry def,
  UserAchievement? userAch,
  required bool unlocked,
}) {
  final secretLocked = def.isSecret && !unlocked;
  final tier = unlocked ? (userAch?.tier ?? 1) : 0;
  final theme = Theme.of(context);
  final color = badgeVisualColor(
    tier: tier < 1 ? 1 : tier,
    unlocked: unlocked,
    isSecret: def.isSecret,
    secretLocked: secretLocked,
    scheme: theme.colorScheme,
  );

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  secretLocked
                      ? Icons.help_outline
                      : achievementIconData(def.iconKey),
                  size: 48,
                  color: color,
                ),
                SizedBox(height: 12),
                Text(
                  secretLocked ? '?????' : def.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                if (secretLocked)
                  Text(
                    AppLocalizations.of(context).profileGizliBirBasarimAcmak,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  )
                else ...[
                  Text(
                    achievementDetailDescription(
                      AppLocalizations.of(context),
                      def,
                      unlocked,
                    ),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (def.isSecret) ...[
                    SizedBox(height: 8),
                    Chip(
                      avatar: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: kSecretAchievementColor,
                      ),
                      label: Text(
                        AppLocalizations.of(context).profileGizliBasarim,
                      ),
                      backgroundColor: kSecretAchievementColor.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        unlocked
                            ? '${AppLocalizations.of(context).profileTamamland}: $tier/${def.maxTier} · ${_tierLabel(AppLocalizations.of(context), tier)}'
                            : '${AppLocalizations.of(context).profileKilitli} · ${def.maxTier}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (def.tiers.isNotEmpty) ...[
                      SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context).profileTumKademeler,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 6),
                      for (final tierDef in def.tiers)
                        _AchievementTierDetailRow(
                          tier: tierDef,
                          complete: unlocked && tier >= tierDef.tier,
                          condition: achievementTierConditionTr(
                            AppLocalizations.of(context),
                            def,
                            tierDef,
                          ),
                        ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AchievementTierDetailRow extends StatelessWidget {
  const _AchievementTierDetailRow({
    required this.tier,
    required this.complete,
    required this.condition,
  });

  final AchievementTierDef tier;
  final bool complete;
  final String condition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = complete
        ? tierColorFor(tier.tier)
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              complete ? Icons.check_circle : Icons.lock_outline,
              size: 18,
              color: color,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppLocalizations.of(context).profileKademe} ${tier.tier} · $condition',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '+${tier.xp} XP · ${complete ? AppLocalizations.of(context).profileTamamland : AppLocalizations.of(context).profileKilitli}',
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        hint,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  const _BadgeCircle({
    required this.def,
    required this.tier,
    required this.unlocked,
    this.userAch,
    this.onLongPress,
    this.onTap,
    this.secretLocked = false,
  });

  final AchievementDictEntry def;
  final int tier;
  final bool unlocked;
  final UserAchievement? userAch;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final bool secretLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = badgeVisualColor(
      tier: tier < 1 ? 1 : tier,
      unlocked: unlocked,
      isSecret: def.isSecret,
      secretLocked: secretLocked,
      scheme: theme.colorScheme,
    );

    final title = secretLocked ? '?????' : def.name;
    final subtitle = secretLocked
        ? AppLocalizations.of(context).profileGizliBasarim
        : unlocked
        ? '${_tierLabel(AppLocalizations.of(context), tier)} · $tier'
        : AppLocalizations.of(context).profileKilitli;

    return Tooltip(
      message: '$title\n$subtitle',
      child: GestureDetector(
        // onTap yoksa üst widget (katalog kartı) sheet açar; çift sheet olmaz.
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secretLocked
                    ? kSecretLockedColor
                    : color.withValues(alpha: 0.15),
                border: Border.all(color: color, width: 2.5),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: secretLocked
                    ? Text(
                        '?',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: kSecretAchievementColor.withValues(
                            alpha: 0.85,
                          ),
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : Icon(
                        achievementIconData(def.iconKey),
                        color: color,
                        size: 30,
                      ),
              ),
            ),
            if (unlocked && !def.isSecret)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$tier',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.def,
    required this.userAch,
    required this.unlocked,
    required this.isSelected,
    required this.isSelf,
    this.onToggle,
  });

  final AchievementDictEntry def;
  final UserAchievement? userAch;
  final bool unlocked;
  final bool isSelected;
  final bool isSelf;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secretLocked = def.isSecret && !unlocked;
    final tier = unlocked ? (userAch?.tier ?? 1) : 1;
    final nextTier = unlocked ? (tier < def.maxTier ? tier + 1 : tier) : 1;
    final tierDef = def.tiers.isEmpty
        ? null
        : def.tiers.firstWhere(
            (t) => t.tier == (unlocked && tier < def.maxTier ? nextTier : tier),
            orElse: () => def.tiers.first,
          );
    final progress = userAch?.progress ?? 0;
    final need = tierDef?.threshold ?? 1;
    final pct = unlocked && tier >= def.maxTier
        ? 1.0
        : (progress / need).clamp(0.0, 1.0);

    final tierColor = badgeVisualColor(
      tier: tier,
      unlocked: unlocked,
      isSecret: def.isSecret,
      secretLocked: secretLocked,
      scheme: theme.colorScheme,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAchievementDetail(
          context,
          def: def,
          userAch: userAch,
          unlocked: unlocked,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BadgeCircle(
                def: def,
                tier: tier,
                unlocked: unlocked,
                userAch: userAch,
                secretLocked: secretLocked,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            secretLocked ? '?????' : def.name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isSelf && unlocked && onToggle != null)
                          IconButton(
                            tooltip: isSelected
                                ? AppLocalizations.of(
                                    context,
                                  ).profileVitrindenKaldir
                                : AppLocalizations.of(
                                    context,
                                  ).profileVitrineEkle,
                            icon: Icon(
                              isSelected
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            onPressed: () => onToggle!(def.id),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      secretLocked
                          ? AppLocalizations.of(
                              context,
                            ).profileBuGizliBasariminKosulu
                          : def.description,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (!secretLocked) ...[
                      SizedBox(height: 8),
                      // 5 kademe renk şeridi
                      if (!def.isSecret)
                        Row(
                          children: [
                            for (var i = 1; i <= def.maxTier.clamp(1, 5); i++)
                              Expanded(
                                child: Container(
                                  height: 5,
                                  margin: const EdgeInsets.only(right: 3),
                                  decoration: BoxDecoration(
                                    color: tierColorFor(i).withValues(
                                      alpha: unlocked && tier >= i ? 1 : 0.22,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (def.isSecret && unlocked)
                        Text(
                          '${AppLocalizations.of(context).profileGizli} · ${AppLocalizations.of(context).profileTamamland}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: kSecretAchievementColor,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (unlocked && tier >= def.maxTier)
                        Text(
                          '${AppLocalizations.of(context).profileTamamland} · ${_tierLabel(AppLocalizations.of(context), tier)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else ...[
                        SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: pct,
                          color: tierColor,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                        SizedBox(height: 4),
                        Text(
                          unlocked
                              ? '$tier/${def.maxTier} (${_tierLabel(AppLocalizations.of(context), tier)}) · $need'
                              : '$progress / $need',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: unlocked ? tierColor : null,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hafif confetti — ek paket yok (pubspec sıcak dosya).
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.seed});

  final double progress;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rng = math.Random(seed);
    final paint = Paint();
    const count = 48;
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y0 = -20.0 - rng.nextDouble() * 40;
      final y =
          y0 + (size.height + 80) * progress * (0.6 + rng.nextDouble() * 0.4);
      final w = 4.0 + rng.nextDouble() * 5;
      final h = 6.0 + rng.nextDouble() * 8;
      paint.color = HSVColor.fromAHSV(
        (1 - progress).clamp(0.0, 1.0),
        rng.nextDouble() * 360,
        0.85,
        0.95,
      ).toColor();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 * (i.isEven ? 1 : -1));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.seed != seed;
}
