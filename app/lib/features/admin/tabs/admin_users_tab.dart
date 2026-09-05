import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../directory/admin_search_field.dart';
import '../sanctions/admin_person_dossier.dart';
import '../sanctions/admin_sanction_actions.dart';
import '../sanctions/admin_sanction_dialogs.dart';
import '../sanctions/sanction_ladder.dart';

/// Kullanıcılar sekmesinden uygulanabilen askı basamakları.
///
/// 🔴 WP-625: burada **süresiz** bir seçenek yoktur. Eski "Askıya Al" düğmesi
/// tek dokunuşta ≈100 yıllık, `moderation_sanctions`'a hiç yazılmayan bir ban
/// kuruyordu: Moderasyon sekmesinde görünmüyor, geri alınamıyor, kendiliğinden
/// dolmuyordu. Artık yönetici basamağı **seçer**, sunucu kaydı yazar. Kalıcı
/// yasak listede duruyor ama adı kalıcı olduğunu söylüyor.
///
/// 🔴 WP-C: liste artık burada **sayılmaz**, tek kanonik kaynaktan
/// (`sanctions/sanction_ladder.dart`) türetilir. Elle yazıldığı sürece UGC
/// sekmesindeki dokuz basamaklı listeyle ayrı yaşıyordu; sahibin "banlama
/// farklı yere gidiyorum herhalde" şikâyetinin kökü buydu.
final List<ModerationAction> kAdminSuspensionLadder =
    kAdminAccountRestrictionLadder;

/// 🔴 WP-771: kisi dizininde **arama yoktu**. Grup dizini ve uye secici
/// WP-D'de arama kazandi, kullanici listesi duz bir `ListView` olarak kaldi:
/// bir vakadan gelen e-postayi/kimligi yonetici listede gozle ariyordu. Yeni
/// desen icat edilmedi — ayni ucu (`AdminSearchField` + [adminMatchesQuery] +
/// `AdminEmptyResult`) burada da kullanilir.
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AdminSearchField(
            label: l10n.adminKullaniciAramaIpucu,
            value: _query,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminUsersProvider);
              await ref.read(adminUsersProvider.future);
            },
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
              data: (items) {
                final visible = items
                    .where(
                      (user) =>
                          adminMatchesQuery(_query, [user.email, user.id]),
                    )
                    .toList(growable: false);

                if (visible.isEmpty) {
                  // Kaydirilabilir kalir ki "asagi cek-yenile" bos ekranda da
                  // calissin.
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    children: [
                      AdminEmptyResult(
                        message: items.isEmpty
                            ? l10n.adminKullaniciBulunamadi
                            : l10n.adminSonucYok,
                        onClearFilter: _query.isEmpty
                            ? null
                            : () => setState(() => _query = ''),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _UserCard(user: visible[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final AdminUserDto user;

  Future<void> _performAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String promptTitle,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final raw = await askAdminReason(context, promptTitle);
    if (raw == null) return;
    final reason = raw.trim();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminGerekceBelirtilmelidir)),
      );
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
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminIslemBasarili)));
    } on AdminException catch (e) {
      // 🔴 WP-771: sunucunun gercek cevabi ("Forbidden", "reason is required")
      // burada atiliyordu; yonetici neden reddedildigini goremiyordu.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

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
                  // 🔴 WP-C: kisinin dosyasina goturen gorunur yol. Aktif
                  // kisit, ceza gecmisi ve **kisit kaldirma** orada durur;
                  // geri alinamaz eylemler (hesap silme) de yalniz orada.
                  OutlinedButton.icon(
                    key: const Key('admin-user-open-dossier'),
                    onPressed: () => openAdminPersonDossier(
                      context,
                      targetUserId: user.id,
                      targetEmail: user.email,
                    ),
                    icon: const Icon(Icons.badge_outlined, size: 20),
                    label: Text(l10n.adminSanctionOpenDossier),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _performAction(
                      context,
                      ref,
                      'send_password_reset',
                      l10n.adminSifreSifirlamaEpostasiGonder,
                    ),
                    icon: const Icon(Icons.lock_reset, size: 20),
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
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                      label: Text(l10n.adminAskiKaldir),
                    )
                  else
                    OutlinedButton.icon(
                      key: const Key('admin-user-suspend-menu'),
                      // Ayni akis, ayni basamaklar, ayni kurallar: kisi
                      // dosyasindaki yaptirim yolunun kendisi cagriliyor.
                      onPressed: () => AdminSanctionActions.chooseAndApply(
                        context,
                        ref,
                        targetUserId: user.id,
                        confirmationPhrase: user.email,
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 20),
                      label: Text(l10n.adminAskiyaAl),
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
