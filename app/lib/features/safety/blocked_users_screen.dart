import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/moderation_appeal.dart';
import '../../data/models/moderation_sanction.dart';
import '../../data/models/profile.dart';
import '../../data/providers/moderation_providers.dart';
import '../../data/repositories/moderation_repository.dart';

/// WP-683 — güvenlik listelerinin (engellenenler · dürtmesi susturulanlar)
/// masaüstü genişlik tavanı.
///
/// 🔴 Türetildi, seçilmedi. Bu iki ekran SPEC §3 **A1 "yoğun liste"**dir ve
/// her satırı bir etiket–değer satırıdır: solda kişinin adı, sağda "Engeli
/// kaldır" / "Susturmayı kaldır" eylemi. SPEC KURAL 2.2 o mesafeyi **600
/// px**'te sert tavanlar (80 karakter × 7.5 px, WCAG 2.1 SC 1.4.8). Satır bir
/// `Card > ListTile` içindedir, yatay iç dolgu 2 × 16 = 32 px → kart tavanı
/// **632 px**. 632, 4'ün katıdır (WinUI, SPEC §1.2).
///
/// 🔴 ÖLÇÜLEN KUSUR (WP-683 öncesi, `desktop_wp683_screens_test.dart`,
/// etiketin SOL kenarı → değerin SAĞ kenarı):
///
/// | ekran | 1008 | 1200 | 1920 | 2560 | panel (920) |
/// |---|---:|---:|---:|---:|---:|
/// | engellenenler ("Engellenen Bora" → "Engeli kaldır") | 864 | 1056 | **1776** | **2416** | 776 |
/// | susturulanlar ("Susturulan Deniz" → "Susturmayı kaldır") | 864 | 1056 | **1776** | **2416** | 776 |
///
/// Panel bandında bile (776 px) tavan aşılıyordu: kusur yalnız "pencereyle
/// büyüme" değil, **tavansızlık**tı.
const double kSafetyBlockMaxWidth = DesktopBreakpoints.maxLabelValueWidth + 32;

/// Masaüstünde içeriği [kSafetyBlockMaxWidth] ile tavanlar ve yatayda ortalar;
/// **mobilde çocuğu olduğu gibi geçirir** (SPEC §7).
///
/// 🔴 Tavan `MediaQuery`den DEĞİL kaptan kurulur: bu ekranlar Ayarlar'dan
/// `showDesktopPanel` ile açıldığında 920 px'lik bir `SizedBox` içinde çizilir
/// ama `MediaQuery.sizeOf` orada hâlâ tüm pencereyi verir.
class SafetyDesktopBand extends StatelessWidget {
  const SafetyDesktopBand({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kSafetyBlockMaxWidth),
        child: child,
      ),
    );
  }
}

/// WP-129: Ayarlar → Engellenen kullanıcılar (unblock UI).
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(blockedProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyBlockedUsersTitle)),
      // WP-442: Hesabındaki kısıtlar ve itiraz yolu burada; kullanıcı
      // cezasının nedenini ve süresini görmeden itiraz edemez.
      body: SafetyDesktopBand(
        child: ListView(
          padding: getSafeVerticalPadding(
            context,
            horizontal: 12,
            vertical: 12,
          ),
          children: [
            const MyRestrictionsSection(),
            const Divider(height: 32),
            Text(
              l10n.safetyBlockedUsersTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // 🔴 WP-591: bkz. muted_nudges_screen -- `safetyActionFailed`
              // yukleme hatasini anlatmiyor ve cikis vermiyordu.
              error: (_, _) => Center(
                child: ErrorRetryView(
                  message: l10n.homeVerilerYuklenemedi,
                  onRetry: () => ref.invalidate(blockedProfilesProvider),
                ),
              ),
              data: (profiles) {
                if (profiles.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.safetyNoBlockedUsers,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final p in profiles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _BlockedUserTile(profile: p),
                      ),
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

class _BlockedUserTile extends ConsumerStatefulWidget {
  const _BlockedUserTile({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_BlockedUserTile> createState() => _BlockedUserTileState();
}

class _BlockedUserTileState extends ConsumerState<_BlockedUserTile> {
  bool _busy = false;

  Future<void> _unblock() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(moderationRepositoryProvider)
          .unblockUser(widget.profile.id);
      ref.invalidate(blockedUserIdsProvider);
      ref.invalidate(blockedProfilesProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.safetyUnblocked)));
    } on ModerationException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.safetyActionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = widget.profile;
    final name = p.displayName.trim().isEmpty
        ? l10n.safetyBlockedUserFallbackName
        : p.displayName;

    return Card(
      child: ListTile(
        leading: Semantics(
          label: name,
          child: LiveCrownedAvatar(
            userId: p.id,
            displayName: name,
            avatarUrl: p.avatarUrl,
            radius: 20,
          ),
        ),
        title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _busy ? null : _unblock,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.safetyUnblock, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// WP-442: Kullanıcının kendi hakkındaki yaptırımları ve itiraz yolu.
///
/// Kim şikâyet etti bilgisi burada **hiç** yoktur; kullanıcı yalnız kararı,
/// gerekçesini ve süresini görür.
class MyRestrictionsSection extends ConsumerWidget {
  const MyRestrictionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sanctions = ref.watch(mySanctionsProvider);
    final appeals = ref.watch(myAppealsProvider);

    return Column(
      key: const Key('my-restrictions-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.safetyMyRestrictions, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        sanctions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // 🔴 WP-591: kendi yaptirimlarini goremeyen kullanici itiraz da
          // edemez; bu dalin cikissiz kalmasi en pahalisiydi.
          error: (_, _) => ErrorRetryView(
            dense: true,
            message: l10n.homeVerilerYuklenemedi,
            onRetry: () => ref.invalidate(mySanctionsProvider),
          ),
          data: (items) {
            final visible = [
              for (final sanction in items)
                if (sanction.state == ModerationSanctionState.applied) sanction,
            ];
            if (visible.isEmpty) {
              return Text(
                l10n.safetyRestrictionNone,
                style: theme.textTheme.bodyMedium,
              );
            }
            return Column(
              children: [
                for (final sanction in visible)
                  _RestrictionTile(
                    sanction: sanction,
                    appeal: appeals.value
                        ?.where((a) => a.sanctionId == sanction.id)
                        .firstOrNull,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RestrictionTile extends ConsumerWidget {
  const _RestrictionTile({required this.sanction, this.appeal});

  final ModerationSanction sanction;
  final ModerationAppeal? appeal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final expiresAt = sanction.expiresAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _actionLabel(l10n, sanction.action),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(sanction.reason, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              expiresAt == null
                  ? l10n.safetyRestrictionPermanent
                  : l10n.safetyRestrictionUntil(
                      expiresAt.toLocal().toString().substring(0, 16),
                    ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (appeal != null)
              Text(switch (appeal!.status) {
                ModerationAppealStatus.open => l10n.safetyAppealPending,
                ModerationAppealStatus.upheld => l10n.safetyAppealUpheld,
                ModerationAppealStatus.overturned =>
                  l10n.safetyAppealOverturned,
              }, style: theme.textTheme.bodySmall)
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: Key('appeal-action-${sanction.id}'),
                  onPressed: () => _openAppealSheet(context, ref),
                  child: Text(l10n.safetyAppealAction),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppealSheet(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final statement = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AppealSheet(),
    );
    if (statement == null) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .submitAppeal(sanctionId: sanction.id, statement: statement);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(myAppealsProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.safetyAppealSubmitted)));
  }

  static String _actionLabel(AppLocalizations l10n, ModerationAction action) =>
      switch (action) {
        ModerationAction.noAction => l10n.adminModerationSanctionNoAction,
        ModerationAction.warn => l10n.adminModerationSanctionWarn,
        ModerationAction.nameReset => l10n.adminModerationSanctionNameReset,
        ModerationAction.mute24h => l10n.adminModerationSanctionMute24h,
        ModerationAction.suspend24h => l10n.adminModerationSanctionSuspend24h,
        ModerationAction.suspend7d => l10n.adminModerationSanctionSuspend7d,
        ModerationAction.suspend14d => l10n.adminModerationSanctionSuspend14d,
        ModerationAction.suspend30d => l10n.adminModerationSanctionSuspend30d,
        ModerationAction.banPermanent => l10n.adminModerationSanctionBan,
      };
}

/// İtiraz metni sayfası. Sunucudaki 10 karakter alt sınırı burada da geçerli:
/// kullanıcı boş gönderip ham SQL hatası görmez.
class _AppealSheet extends StatefulWidget {
  const _AppealSheet();

  @override
  State<_AppealSheet> createState() => _AppealSheetState();
}

class _AppealSheetState extends State<_AppealSheet> {
  final TextEditingController _statement = TextEditingController();

  @override
  void dispose() {
    _statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tooShort = _statement.text.trim().length < kAppealMinLength;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('appeal-statement-field'),
              controller: _statement,
              maxLines: 4,
              maxLength: kAppealMaxLength,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.safetyAppealStatement,
                errorText: tooShort && _statement.text.isNotEmpty
                    ? l10n.safetyAppealTooShort
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('appeal-submit'),
              onPressed: tooShort
                  ? null
                  : () => Navigator.of(context).pop(_statement.text.trim()),
              child: Text(l10n.safetyAppealAction),
            ),
          ],
        ),
      ),
    );
  }
}
