import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'admin_group_members.dart';
import 'admin_search_field.dart';

/// WP-D (`docs/design/ADMIN-PANEL-PLAN.md` §2.3 / §5 WP-D kabul 2) — grup
/// dosyasinin uye tarafi.
///
/// 🔴 Duzeltilen kusur: "Uye At" yoneticiyi **elle UUID yazdiran bir metin
/// kutusuna** sokuyordu (`admin_groups_tab.dart:68-77`,
/// `adminHedefKullaniciIdZorunlu`) ve grubun uyelerini gosteren hicbir ekran
/// yoktu. Panoya kopyalanmis bir UUID'yi elle dogru yazmak bir is akisi
/// degildir; yanlis yazilan bir karakter sessizce **baska birini** atardi.
///
/// Artik hedef **secilir**. Iki kaynak birlestirilir:
///   1. `groupMembersByIdProvider` — grubun gercek uye listesi.
///   2. `adminUsersProvider` — yonetici kullanici dizini (e-postalar buradan
///      gelir; uye akisi e-posta tasimaz).
///
/// 🔴 SUNUCU SINIRI (WP-D'nin olctugu) ve WP-F'nin kapattigi delik:
/// `group_member_directory` (`0115_profile_titles.sql:103`) cagirani
/// `is_group_member` ile suzer ve uye olmayan bir yoneticiye `42501` doner;
/// `group_members` uzerinde yonetici SELECT politikasi da yoktur
/// (`0001_initial_schema.sql:156`). Yani uyesi olmadigin bir grubun listesi bu
/// akistan **uretimde okunamazdi** — yonetici uye ATABILIYOR ama kimin uye
/// oldugunu GOREMIYORDU.
///
/// WP-F ucuncu bir kaynak ekledi: [adminGroupMembersProvider] →
/// `admin-operations` edge fonksiyonunun `list_group_members` eylemi (service
/// role, yonetici kapisinin arkasinda). Iki kaynagin **birlesimi** cizilir
/// ([adminGroupMemberUnion]); kayip metni yalniz IKISI DE duserse yazilir.
/// Satir etiketi: ad bos ise kimlik yazilir.
///
/// 🔴 `0115` engellenen uyenin adini BOSALTIR (satiri silmez). O kural kamp
/// atesi icindir ve degistirilmedi. Ama bos bir baslik, tiklanabilir ama
/// okunamaz bir satir demektir; yonetici kimi attigini gormeli.
String adminMemberLabel(Profile member) =>
    member.displayName.trim().isEmpty ? member.id : member.displayName;

/// Yonetici yolunu ve uye akisini birlikte tazeler.
void refreshAdminGroupMembers(WidgetRef ref, String groupId) {
  ref.invalidate(adminGroupMembersProvider(groupId));
  ref.invalidate(groupMembersByIdProvider(groupId));
}

@immutable
class AdminDirectoryEntry {
  const AdminDirectoryEntry({
    required this.id,
    this.displayName,
    this.email,
    this.isMember = false,
  });

  final String id;
  final String? displayName;
  final String? email;

  /// Bu kisi grubun uye listesinde **gorundu** mu?
  final bool isMember;

  /// Satirda okunan birincil metin: e-posta varsa o, yoksa ad, o da yoksa
  /// kimlik. Hicbir zaman bos degildir.
  String get primaryLabel => email ?? displayName ?? id;

  /// Ikincil metin — birincil ile ayni seyi tekrarlamaz.
  String get secondaryLabel => email != null ? (displayName ?? id) : id;

  AdminDirectoryEntry merge(AdminDirectoryEntry other) => AdminDirectoryEntry(
    id: id,
    displayName: displayName ?? other.displayName,
    email: email ?? other.email,
    isMember: isMember || other.isMember,
  );
}

/// Uye akisi + kullanici dizini → tek satir listesi (kimlik basina bir satir).
///
/// Uyeler basa gelir: yoneticinin aradigi kisi neredeyse her zaman gruptadir.
List<AdminDirectoryEntry> adminMergeDirectory({
  required List<Profile> members,
  required List<AdminUserDto> users,
}) {
  final merged = <String, AdminDirectoryEntry>{};
  final order = <String>[];

  void put(AdminDirectoryEntry entry) {
    final existing = merged[entry.id];
    if (existing == null) {
      merged[entry.id] = entry;
      order.add(entry.id);
    } else {
      merged[entry.id] = existing.merge(entry);
    }
  }

  for (final member in members) {
    put(
      AdminDirectoryEntry(
        id: member.id,
        displayName: member.displayName,
        // 🔴 WP-771: `is_active` sunucudan geliyordu ama okunmuyordu — gruptan
        // AYRILMIS kisi secicide "Grup uyesi" olarak isaretleniyordu. Satir
        // kalir (kisi dizinde vardir), yalniz uyelik iddiasi kalkar.
        isMember: member.isActive,
      ),
    );
  }
  for (final user in users) {
    put(AdminDirectoryEntry(id: user.id, email: user.email));
  }

  return [for (final id in order) merged[id]!];
}

/// Grup dosyasindaki uye listesi (kart icine gomulu).
class AdminGroupMemberList extends ConsumerWidget {
  const AdminGroupMemberList({
    required this.groupId,
    required this.onRemove,
    super.key,
  });

  final String groupId;
  final void Function(AdminDirectoryEntry entry) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final view = adminGroupMemberUnion(
      adminList: ref.watch(adminGroupMembersProvider(groupId)),
      memberStream: ref.watch(groupMembersByIdProvider(groupId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.adminUyeler, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (view.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        // 🔴 Sessiz bos liste YOK: okunamayan bir liste ile bos bir grup
        // ayni sey degildir; yonetici hangisi oldugunu bilmeli.
        else if (view.unavailable)
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.adminUyeListesiOkunamadi)),
              IconButton(
                tooltip: l10n.adminUyeListesiniYenile,
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => refreshAdminGroupMembers(ref, groupId),
              ),
            ],
          )
        else if (view.members.isEmpty)
          Text(l10n.adminUyeYok)
        else
          Column(
            children: [
              for (final member in view.members)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline, size: 20),
                  title: Text(adminMemberLabel(member)),
                  subtitle: Text(
                    l10n.adminIdGroupid(member.id),
                    style: theme.textTheme.bodySmall,
                  ),
                  // 🔴 WP-771: ayrilmis uye aktif uye gibi ciziliyor ve
                  // yanina "Uyeyi at" dugmesi konuyordu. Olmayan bir uyeligi
                  // bitiren dugme yalan soyler; satir etiketle kalir.
                  trailing: member.isActive
                      ? IconButton(
                          tooltip: l10n.adminUyeyiAt,
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            size: 20,
                          ),
                          onPressed: () => onRemove(
                            AdminDirectoryEntry(
                              id: member.id,
                              displayName: adminMemberLabel(member),
                              isMember: true,
                            ),
                          ),
                        )
                      : Chip(
                          label: Text(l10n.adminEskiUye),
                          visualDensity: VisualDensity.compact,
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Hedefi **secerek** belirleyen dialog. UUID kutusunun yerini alir.
Future<AdminDirectoryEntry?> showAdminMemberPicker({
  required BuildContext context,
  required StudyGroup group,
}) {
  return showDialog<AdminDirectoryEntry>(
    context: context,
    builder: (_) => _AdminMemberPickerDialog(group: group),
  );
}

class _AdminMemberPickerDialog extends ConsumerStatefulWidget {
  const _AdminMemberPickerDialog({required this.group});

  final StudyGroup group;

  @override
  ConsumerState<_AdminMemberPickerDialog> createState() =>
      _AdminMemberPickerDialogState();
}

class _AdminMemberPickerDialogState
    extends ConsumerState<_AdminMemberPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final view = adminGroupMemberUnion(
      adminList: ref.watch(adminGroupMembersProvider(widget.group.id)),
      memberStream: ref.watch(groupMembersByIdProvider(widget.group.id)),
    );
    final users = ref.watch(adminUsersProvider);

    final entries = adminMergeDirectory(
      members: view.members,
      users: users.value ?? const [],
    );
    final visible = entries
        .where(
          (entry) =>
              adminMatchesQuery(_query, [entry.email, entry.displayName, entry.id]),
        )
        .toList(growable: false);

    return AlertDialog(
      title: Text(l10n.adminUyeSecBaslik),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSearchField(
              label: l10n.adminKisiAra,
              value: _query,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            if (view.unavailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.adminUyeListesiOkunamadi,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: AdminEmptyResult(
                        message: entries.isEmpty
                            ? l10n.adminKullaniciBulunamadi
                            : l10n.adminSonucYok,
                        onClearFilter: _query.isEmpty
                            ? null
                            : () => setState(() => _query = ''),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final entry in visible)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              entry.isMember
                                  ? Icons.person_outline
                                  : Icons.person_search_outlined,
                              size: 20,
                            ),
                            title: Text(entry.primaryLabel),
                            subtitle: Text(
                              entry.isMember
                                  ? '${l10n.commonGrupUyesi} · ${entry.secondaryLabel}'
                                  : entry.secondaryLabel,
                              style: theme.textTheme.bodySmall,
                            ),
                            onTap: () => Navigator.of(context).pop(entry),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminIptal),
        ),
      ],
    );
  }
}
