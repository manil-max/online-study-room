import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/stats/achievement_ledger_engine.dart';
import '../../../core/stats/progression_visuals.dart';
import '../../../data/models/achievement.dart';
import '../../../data/models/achievement_ledger.dart';
import '../../../data/models/gamification_profile.dart';

export '../../../core/stats/progression_visuals.dart'
    show crownColorFor, crownLabelTr, xpBarMetrics, tierColorFor, tierLabelTr;

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

String categoryLabelTr(String category) {
  switch (category) {
    case 'study':
      return 'Çalışma';
    case 'streak':
      return 'Seri ve Düzen';
    case 'group':
      return 'Grup';
    case 'social':
      return 'Sosyal';
    case 'secret':
      return 'Gizli';
    default:
      return category;
  }
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
      widget.dictionary ?? kAchievementDictV3();

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
  bool get confettiVisible =>
      _confettiArmed || _confettiController.isAnimating;

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
          const SizedBox(height: 8),
        ],
        _CrownHeader(
          rank: rank,
          rankColor: rankColor,
          xp: xp,
        ),
        const SizedBox(height: 12),
        _XpBar(
          progress: bar.progress,
          xp: xp,
          next: bar.next,
          floor: bar.floor,
          color: rankColor,
        ),
        const SizedBox(height: 16),
        _VitrinRow(
          selectedIds: widget.gamification.selectedBadges,
          dictionary: _dict,
          userAchievements: widget.userAchievements,
          isSelf: widget.isSelf,
          onToggle: widget.onToggleShowcaseBadge,
        ),
        if (widget.showCatalog && !widget.compact) ...[
          const SizedBox(height: 20),
          Text(
            'Başarı kataloğu',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
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
            categoryLabelTr(cat),
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
            isSelected:
                widget.gamification.selectedBadges.contains(def.id),
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              crownLabelTr(rank),
              style: theme.textTheme.titleSmall?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
        const SizedBox(height: 6),
        Text(
          atCap
              ? 'Maksimum taç seviyesine ulaşıldı (Elmas)'
              : 'Sonraki taç: $next XP (${(progress * 100).round()}%)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
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
                            alpha: crownTierNumber(
                                      crownRankForXp(xp),
                                    ) >=
                                    i
                                ? 1
                                : 0.25,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tierLabelTr(i),
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
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            isSelf ? 'Vitrin (en fazla 3)' : 'Vitrin',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              if (i >= selectedIds.length) {
                return _EmptySlot(hint: isSelf ? 'Ekle' : '—');
              }
              final id = selectedIds[i];
              AchievementDictEntry? found;
              for (final d in dictionary) {
                if (d.id == id) {
                  found = d;
                  break;
                }
              }
              final def = found ??
                  AchievementDictEntry(
                    id: id,
                    category: 'study',
                    name: id,
                    description: '',
                    maxTier: 1,
                    iconKey: 'emoji_events',
                    isSecret: false,
                    tiers: const [],
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
                onLongPress:
                    isSelf && onToggle != null ? () => onToggle!(id) : null,
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
    builder: (ctx) {
      return SafeArea(
        child: Padding(
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
              const SizedBox(height: 12),
              Text(
                secretLocked ? '?????' : def.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (secretLocked)
                Text(
                  'Gizli bir başarım. Açmak için şanslı veya çok dikkatli olmalısın.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                )
              else ...[
                Text(
                  def.description,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (def.isSecret) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(Icons.auto_awesome,
                        size: 16, color: kSecretAchievementColor),
                    label: const Text('Gizli başarım'),
                    backgroundColor:
                        kSecretAchievementColor.withValues(alpha: 0.15),
                  ),
                ] else if (unlocked) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      'Kademe $tier/${def.maxTier} · ${tierLabelTr(tier)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Henüz açılmadı · en fazla ${def.maxTier} kademe',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
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
        ? 'Gizli başarım'
        : unlocked
            ? '${tierLabelTr(tier)} · Kademe $tier'
            : 'Kilitli';

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
                          color: kSecretAchievementColor.withValues(alpha: 0.85),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
    final nextTier = unlocked
        ? (tier < def.maxTier ? tier + 1 : tier)
        : 1;
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            secretLocked ? '?????' : def.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isSelf && unlocked && onToggle != null)
                          IconButton(
                            tooltip:
                                isSelected ? 'Vitrinden kaldır' : 'Vitrine ekle',
                            icon: Icon(
                              isSelected
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              color:
                                  isSelected ? theme.colorScheme.primary : null,
                            ),
                            onPressed: () => onToggle!(def.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secretLocked
                          ? 'Gizli bir başarım — şartı gizli tutulur'
                          : def.description,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (!secretLocked) ...[
                      const SizedBox(height: 8),
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
                          'Gizli · açıldı',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: kSecretAchievementColor,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (unlocked && tier >= def.maxTier)
                        Text(
                          'Maksimum kademe · ${tierLabelTr(tier)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tierColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: pct,
                          color: tierColor,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unlocked
                              ? 'Kademe $tier/${def.maxTier} (${tierLabelTr(tier)}) · sonraki $need'
                              : 'İlerleme: $progress / $need',
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
      final y = y0 + (size.height + 80) * progress * (0.6 + rng.nextDouble() * 0.4);
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
