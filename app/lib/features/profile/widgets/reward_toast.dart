import 'dart:async';

import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Shell-level pending reward banner. Reward state is **event-driven** (beta-v41
/// WP-G): the banner reacts to [pendingCount]/[pendingXp] which the shell watches
/// from the self-only reward provider; that provider is invalidated when a session
/// completes and after claim — no periodic polling. All data access and
/// authorization remain in the reward provider. Dismissing the banner never clears
/// the navigation badge.
class RewardToast extends StatefulWidget {
  const RewardToast({
    super.key,
    required this.pendingCount,
    required this.pendingXp,
    required this.onOpenProfile,
    this.crownRank,
  });

  final int pendingCount;
  final int pendingXp;
  final String? crownRank;
  final VoidCallback onOpenProfile;

  @override
  State<RewardToast> createState() => _RewardToastState();
}

class _RewardToastState extends State<RewardToast> {
  static const _debounceDuration = Duration(milliseconds: 250);

  Timer? _debounceTimer;
  Timer? _celebrationTimer;
  late int _visibleCount;
  late int _visibleXp;
  String? _dismissedSignature;
  String? _lastRank;
  String? _celebratingRank;

  String get _signature => '$_visibleCount|$_visibleXp';

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pendingCount;
    _visibleXp = widget.pendingXp;
    _lastRank = widget.crownRank;
  }

  @override
  void didUpdateWidget(covariant RewardToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingCount != oldWidget.pendingCount ||
        widget.pendingXp != oldWidget.pendingXp) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceDuration, () {
        if (!mounted) return;
        setState(() {
          _visibleCount = widget.pendingCount;
          _visibleXp = widget.pendingXp;
          if (_dismissedSignature != _signature) {
            _dismissedSignature = null;
          }
        });
      });
    }

    final nextRank = widget.crownRank;
    if (_lastRank != null && nextRank != null && nextRank != _lastRank) {
      _celebrationTimer?.cancel();
      setState(() => _celebratingRank = nextRank);
      _celebrationTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _celebratingRank = null);
      });
    }
    _lastRank = nextRank;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _celebrationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final showReward = _visibleCount > 0 && _dismissedSignature != _signature;
    final showCrown = _celebratingRank != null;
    final duration = reduceMotion ? Duration.zero : _debounceDuration;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AnimatedSwitcher(
            duration: duration,
            child: showCrown
                ? _CrownCelebration(
                    key: ValueKey(_celebratingRank),
                    rank: _celebratingRank!,
                    reduceMotion: reduceMotion,
                  )
                : showReward
                ? _RewardBanner(
                    key: ValueKey(_signature),
                    pendingCount: _visibleCount,
                    pendingXp: _visibleXp,
                    onOpenProfile: widget.onOpenProfile,
                    onDismiss: () {
                      setState(() => _dismissedSignature = _signature);
                    },
                  )
                : const SizedBox.shrink(key: ValueKey('reward-toast-empty')),
          ),
        ),
      ),
    );
  }
}

class _RewardBanner extends StatelessWidget {
  const _RewardBanner({
    super.key,
    required this.pendingCount,
    required this.pendingXp,
    required this.onOpenProfile,
    required this.onDismiss,
  });

  final int pendingCount;
  final int pendingXp;
  final VoidCallback onOpenProfile;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.redeem, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(
                  context,
                ).profileRewardReady(pendingCount, pendingXp),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenProfile,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(AppLocalizations.of(context).profileRewardClaim),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: AppLocalizations.of(context).homeKapat,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownCelebration extends StatelessWidget {
  const _CrownCelebration({
    super.key,
    required this.rank,
    required this.reduceMotion,
  });

  final String rank;
  final bool reduceMotion;

  String _label(AppLocalizations l10n) {
    return switch (rank) {
      'diamond_owl' => l10n.coreElmasTac,
      'platinum_scholar' => l10n.corePlatinTac,
      'gold_achiever' => l10n.coreAltinTac,
      'silver_learner' => l10n.coreGumusTac,
      _ => l10n.coreBronzTac,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Material(
      elevation: 6,
      color: theme.colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              _label(AppLocalizations.of(context)),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (_, scale, content) =>
          Transform.scale(scale: scale, child: content),
      child: child,
    );
  }
}
