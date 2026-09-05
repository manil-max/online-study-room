import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../directory/admin_member_picker.dart';
import '../directory/admin_search_field.dart';

/// WP-D (`docs/design/ADMIN-PANEL-PLAN.md` §5 WP-D kabul 1, 2, 4) — grup
/// dizini.
///
/// Neyi degistirdi:
///   1. Listenin ustunde **arama kutusu** var; ad, davet kodu ve kimlik
///      parcasiyla filtreler (eskiden hicbir filtre yoktu, §2.3).
///   2. Her grup karti **uye listesini** cizer; "Uye At" artik hedefi
///      **secmene** izin verir — elle UUID yazdiran kutu kalkti
///      (eski `admin_groups_tab.dart:68-77`).
///   3. Arama sonuc vermezse ekranda **filtreyi temizleyen** kontrol durur
///      (§2.4 "filtre cikmazi").
class AdminGroupsTab extends ConsumerStatefulWidget {
  const AdminGroupsTab({super.key});

  @override
  ConsumerState<AdminGroupsTab> createState() => _AdminGroupsTabState();
}

class _AdminGroupsTabState extends ConsumerState<AdminGroupsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(adminGroupsProvider);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AdminSearchField(
            label: l10n.adminGrupAra,
            value: _query,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminGroupsProvider);
              await ref.read(adminGroupsProvider.future);
            },
            child: groups.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text(l10n.authBeklenmeyenBirHataOlustu)),
              data: (items) {
                final visible = items
                    .where(
                      (group) => adminMatchesQuery(_query, [
                        group.name,
                        group.inviteCode,
                        group.id,
                      ]),
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
                            ? l10n.adminGrupBulunamadi
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
                      _GroupCard(group: visible[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final StudyGroup group;

  /// Hedefi **secilmis** bir uye/kullanici icin gerekce sorar ve eylemi
  /// uygular. Gerekce zorunlulugu korunur (PLAN §3 "Korunacaklar").
  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    AdminDirectoryEntry target,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reason = await _askReason(
      context,
      title: l10n.adminUyeyiAt,
      subtitle: target.primaryLabel,
    );
    if (reason == null) return;
    if (!context.mounted) return;
    await _perform(
      context,
      ref,
      action: 'remove_group_member',
      reason: reason,
      targetUserId: target.id,
    );
  }

  Future<void> _deleteGroup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await _askReason(
      context,
      title: l10n.adminGrubuSil,
      subtitle: group.name,
    );
    if (reason == null) return;
    if (!context.mounted) return;
    await _perform(context, ref, action: 'delete_group', reason: reason);
  }

  /// Gerekce diyalogu.
  ///
  /// 🔴 WP-771: kontrol eskiden BURADA, `showDialog` doner donmez `dispose`
  /// ediliyordu. Diyalogun kapanis animasyonu hala surdugu icin `TextField`
  /// atilmis bir controller ile yeniden ciziliyor ve cerceve
  /// "A TextEditingController was used after being disposed" ile dusuyordu —
  /// yani gerekce yazip "Onayla"ya basan yonetici hata kabugu goruyordu.
  /// Ayni ders `sanctions/admin_sanction_dialogs.dart:34-43` icinde zaten
  /// yaziliydi: kontrolu **diyalogun kendisi** tutar ve serbest birakir.
  Future<String?> _askReason(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) async {
    final l10n = AppLocalizations.of(context);
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => _GroupReasonDialog(title: title, subtitle: subtitle),
    );
    if (raw == null) return null;
    final reason = raw.trim();
    if (reason.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.adminGerekliAlanlarDoldurulmalidir)),
        );
      }
      return null;
    }
    return reason;
  }

  Future<void> _perform(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    required String reason,
    String? targetUserId,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .performGroupAction(
            action: action,
            targetGroupId: group.id,
            targetUserId: targetUserId,
            reason: reason,
          );
      ref.invalidate(adminGroupsProvider);
      // 🔴 WP-771: uye listesi AYRI saglayicidan gelir ve `autoDispose`
      // degildir; yalniz grup listesini tazelemek karti bayat birakiyordu —
      // atilan kisi satirda durmaya devam ediyordu. Tazeleyici WP-F'de
      // yazilmisti ama yalniz hata-yeniden-dene dugmesinden cagriliyordu.
      if (targetUserId != null) {
        refreshAdminGroupMembers(ref, group.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.adminIslemBasarili)));
      }
    } on AdminException catch (e) {
      // 🔴 WP-771: sunucunun gercek mesaji burada yutuluyordu.
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.adminIdGroupid(group.id),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AdminGroupMemberList(
              groupId: group.id,
              onRemove: (entry) => _removeMember(context, ref, entry),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final target = await showAdminMemberPicker(
                      context: context,
                      group: group,
                    );
                    if (target == null) return;
                    if (!context.mounted) return;
                    await _removeMember(context, ref, target);
                  },
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: Text(l10n.adminUyeAt),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteGroup(context, ref),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    l10n.adminGrubuSil,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Gerekce diyalogu — kontrolu diyalogun kendisi tutar (bkz. [_GroupCard._askReason]).
///
/// `null` = iptal; bos dize = onaylandi ama gerekce yazilmadi.
class _GroupReasonDialog extends StatefulWidget {
  const _GroupReasonDialog({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_GroupReasonDialog> createState() => _GroupReasonDialogState();
}

class _GroupReasonDialogState extends State<_GroupReasonDialog> {
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.subtitle),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.adminGerekceZorunlu,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminIptal),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.adminOnayla),
        ),
      ],
    );
  }
}
