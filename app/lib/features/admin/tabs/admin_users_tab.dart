import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Kullanıcılar sekmesinden uygulanabilen askı basamakları.
///
/// 🔴 WP-625: burada **süresiz** bir seçenek yoktur. Eski "Askıya Al" düğmesi
/// tek dokunuşta ≈100 yıllık, `moderation_sanctions`'a hiç yazılmayan bir ban
/// kuruyordu: Moderasyon sekmesinde görünmüyor, geri alınamıyor, kendiliğinden
/// dolmuyordu. Artık yönetici basamağı **seçer**, sunucu kaydı yazar. Kalıcı
/// yasak listede duruyor ama adı kalıcı olduğunu söylüyor.
const List<ModerationAction> kAdminSuspensionLadder = [
  ModerationAction.suspend24h,
  ModerationAction.suspend7d,
  ModerationAction.suspend14d,
  ModerationAction.suspend30d,
  ModerationAction.banPermanent,
];

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminUsersProvider);
        await ref.read(adminUsersProvider.future);
      },
      child: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.adminKullaniciBulunamadi));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _UserCard(user: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final AdminUserDto user;

  /// Gerekçe sorar. `null` = iptal edildi; boş dize = onaylandı ama gerekçe yok.
  ///
  /// Denetleyiciyi diyalogun kendisi tutar: çağıran tarafta `dispose` etmek
  /// kapanış animasyonu sürerken çerçeveyi düşürüyordu.
  Future<String?> _askReason(BuildContext context, String promptTitle) {
    return showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(title: promptTitle),
    );
  }

  Future<void> _performAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String promptTitle,
  ) async {
    final l10n = AppLocalizations.of(context);
    final raw = await _askReason(context, promptTitle);
    if (raw == null) return;
    final reason = raw.trim();
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminGerekceBelirtilmelidir)),
        );
      }
      return;
    }

    try {
      await ref
          .read(adminRepositoryProvider)
          .performUserAction(
            action: action,
            targetUserId: user.id,
            reason: reason,
          );
      ref.invalidate(adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminIslemBasarili)));
      }
    } on AdminException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
        );
      }
    }
  }

  /// WP-625: askı basamağını yönetici seçer.
  ///
  /// Eski akış tek düğmeyle süresiz ban kuruyordu. Basamak seçimi bu yüzden
  /// zorunlu: süre kullanıcıya söylenebilir olmalı ve kayda düşmeli.
  Future<void> _openSuspensionMenu(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<ModerationAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                l10n.adminKullaniciyiAskiyaAl,
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
            ),
            for (final action in kAdminSuspensionLadder)
              ListTile(
                key: Key('admin-suspend-${action.wire}'),
                title: Text(_ladderLabel(l10n, action)),
                onTap: () => Navigator.of(sheetContext).pop(action),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await _applySanction(context, ref, selected);
  }

  /// Yaptırımı **moderasyon hattından** uygular.
  ///
  /// Eski yol (`performUserAction('suspend_user')`) yalnız auth ban kuruyordu;
  /// `moderation_sanctions`'a satır yazılmadığı için askı ne görünüyor ne geri
  /// alınabiliyordu. Idempotency anahtarını istemci üretir: "istek gitti mi"
  /// belirsizliği yalnız burada bilinir, tekrar ikinci yaptırım açmaz.
  Future<void> _applySanction(
    BuildContext context,
    WidgetRef ref,
    ModerationAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final raw = await _askReason(context, _ladderLabel(l10n, action));
    if (raw == null) return;
    final reason = raw.trim();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminGerekceBelirtilmelidir)),
      );
      return;
    }

    final request = ModerationSanctionRequest(
      targetUserId: user.id,
      action: action,
      reason: reason,
      idempotencyKey:
          'admin-users-${user.id}-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await ref.read(adminModerationRepositoryProvider).applySanction(request);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(adminUsersProvider);
    ref.invalidate(moderationSanctionsProvider(user.id));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminModerationSanctionApplied)),
    );
  }

  static String _ladderLabel(AppLocalizations l10n, ModerationAction action) =>
      switch (action) {
        ModerationAction.suspend24h => l10n.adminModerationSanctionSuspend24h,
        ModerationAction.suspend7d => l10n.adminModerationSanctionSuspend7d,
        ModerationAction.suspend14d => l10n.adminModerationSanctionSuspend14d,
        ModerationAction.suspend30d => l10n.adminModerationSanctionSuspend30d,
        ModerationAction.banPermanent => l10n.adminModerationSanctionBan,
        // Kullanıcılar sekmesi yalnız hesabı kapatan basamakları sunar; diğer
        // basamaklar vaka bağlamıyla Moderasyon sekmesinden uygulanır.
        _ => l10n.adminAskiyaAl,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDeleted = user.deleted;
    final isSuspended = user.isSuspended;

    return Card(
      color: isDeleted ? theme.colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.email,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: isDeleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isDeleted)
                  Chip(
                    label: Text(l10n.adminSilinmis),
                    visualDensity: VisualDensity.compact,
                  )
                else if (isSuspended)
                  Chip(
                    label: Text(l10n.adminAskida),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminIdGroupid(user.id),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adminKayitUsercreatedattolocaltostringsubstring016(
                user.createdAt.toLocal().toString().substring(0, 16),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (user.lastSignInAt != null)
              Text(
                l10n.adminSonGirisUserlastsigninattolocaltostringsubstring016(
                  user.lastSignInAt!.toLocal().toString().substring(0, 16),
                ),
                style: theme.textTheme.bodySmall,
              ),
            if (!isDeleted) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _performAction(
                      context,
                      ref,
                      'send_password_reset',
                      l10n.adminSifreSifirlamaEpostasiGonder,
                    ),
                    icon: const Icon(Icons.lock_reset, size: 18),
                    label: Text(l10n.adminSifreSifirla),
                  ),
                  if (isSuspended)
                    OutlinedButton.icon(
                      key: const Key('admin-user-unsuspend'),
                      onPressed: () => _performAction(
                        context,
                        ref,
                        'unsuspend_user',
                        l10n.adminAskiyiKaldir,
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: Text(l10n.adminAskiKaldir),
                    )
                  else
                    OutlinedButton.icon(
                      key: const Key('admin-user-suspend-menu'),
                      onPressed: () => _openSuspensionMenu(context, ref),
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: Text(l10n.adminAskiyaAl),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _performAction(
                      context,
                      ref,
                      'soft_delete_user',
                      l10n.adminKullaniciyiSoftDeleteYap,
                    ),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      l10n.adminSil,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gerekçe soran diyalog.
///
/// `null` döner = iptal; boş dize döner = onaylandı ama gerekçe yazılmadı.
/// Çağıran bu ikisini ayırır: iptalde sessiz kalınır, boş gerekçede uyarılır.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('admin-user-reason-field'),
        controller: _controller,
        decoration: InputDecoration(
          labelText: l10n.adminGerekceZorunlu,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminIptal),
        ),
        FilledButton(
          key: const Key('admin-user-reason-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.adminOnayla),
        ),
      ],
    );
  }
}
