import 'dart:async';

import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/nudge_error_text.dart';
import '../../../core/stats/achievement_ledger_engine.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/validation/name_limits.dart';
import '../../../core/time_engine/group_time_zone_label.dart';
import '../../../core/time_engine/world_clock_math.dart';
import '../../../core/widgets/number_stepper.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/presence.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/report_target.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/nudge_providers.dart';
import '../../../data/providers/presence_providers.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/nudge_repository.dart';
import '../../profile/widgets/social_profile_dialog.dart';
import '../../safety/report_sheet.dart';
import 'group_avatar.dart';
import 'nudge_action.dart';

/// Bir sınıfın bilgi + ayarları (§3.8). Üst kısım bilgiler (davet kodu, üyeler);
/// alt kısım ayarlar (sınıftan çık) ve admin işlemleri (ad değiştir, kod yenile,
/// üye çıkar, sınıfı sil). Admin = sınıfı oluşturan (`group.createdBy`).
class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({super.key, required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(authStateProvider).value?.id;
    final isAdmin = userId != null && group.createdBy == userId;
    final repo = ref.read(groupRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).classroomGrup),
        actions: [
          IconButton(
            key: const ValueKey('report-group-action'),
            tooltip: AppLocalizations.of(context).safetyReport,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => showReportSheet(
              context,
              ref,
              target: ReportTarget.group(
                groupId: group.id,
                hint: 'group:${group.name}',
              ),
            ),
          ),
          if (isAdmin)
            IconButton(
              tooltip: AppLocalizations.of(context).classroomAdiDegistir,
              icon: const Icon(Icons.edit),
              onPressed: () => _renameDialog(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Başlık / ad ---
          Row(
            children: [
              _GroupAvatarEditor(group: group, isAdmin: isAdmin),
              const SizedBox(width: 16),
              Expanded(
                child: Text(group.name, style: theme.textTheme.headlineSmall),
              ),
              IconButton(
                key: const ValueKey('report-group-name-action'),
                tooltip: AppLocalizations.of(context).safetyReport,
                icon: const Icon(Icons.flag_outlined),
                // WP-439 / 0104: grup adı ayrı hedef türüdür ve sunucuda
                // grubun kendisinden ayrı bir vaka açar. İpucu makine
                // etiketidir, kullanıcıya gösterilmez: çevrilmez.
                onPressed: () => showReportSheet(
                  context,
                  ref,
                  target: ReportTarget.groupName(
                    groupId: group.id,
                    hint: 'group_name:${group.name}',
                  ),
                ),
              ),
              if (isAdmin)
                // 🔴 WP-498 yan bulgusu (kart kapsamında değil, aynı dosyada
                // ölçüldü): bu rozetin genişliği yazı ölçeğiyle sınırsız
                // büyüyordu. 320 dp ekranda ölçek 1.6'da satır **8.8 px
                // taşıyordu** (sarı-siyah şerit). Eski kodda da vardı; komşu
                // test bunu göremezdi çünkü `MediaQuery(size:)` gerçek
                // pencereyi daraltmıyor, iddia 800 dp'de sınanıyordu.
                //
                // Üst sınır bilerek **ölçekle büyümüyor**: taşmanın nedeni tam
                // olarak ölçekle büyüyen bir sabitti. Sığmayan metin kırpılır.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      AppLocalizations.of(context).classroomYonetici,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Bilgiler ---
          Text(
            AppLocalizations.of(context).classroomBilgiler,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: Text(AppLocalizations.of(context).classroomDavetKodu),
                  subtitle: SelectableText(
                    group.inviteCode,
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: 2,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: AppLocalizations.of(context).classroomKopyala,
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: group.inviteCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).classroomDavetKoduKopyalandi,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).classroomKoduYenile,
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () => _regenerateCode(context, ref, repo),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(
                    AppLocalizations.of(context).classroomGunlukGrupHedefi,
                  ),
                  subtitle: Text(
                    '${formatHuman(group.dailyGoalMinutes * 60)} · '
                    '${AppLocalizations.of(context).classroomBugunkuToplam}',
                  ),
                  trailing: isAdmin
                      ? IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).classroomHedefiDegistir,
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editGoalDialog(context, ref),
                        )
                      : null,
                  onTap: isAdmin ? () => _editGoalDialog(context, ref) : null,
                ),
                ListTile(
                  leading: Icon(
                    group.visibility == GroupVisibility.public
                        ? Icons.public
                        : Icons.lock_outline,
                  ),
                  title: Text(
                    AppLocalizations.of(context).groupDiscoveryPrivacyTitle,
                  ),
                  subtitle: Text(
                    group.visibility == GroupVisibility.public
                        ? AppLocalizations.of(
                            context,
                          ).groupDiscoveryPublicDescription
                        : AppLocalizations.of(
                            context,
                          ).groupDiscoveryPrivateDescription,
                  ),
                  trailing: isAdmin
                      ? IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).groupDiscoveryChangePrivacy,
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editAccessDialog(context, ref),
                        )
                      : null,
                  onTap: isAdmin ? () => _editAccessDialog(context, ref) : null,
                ),
                ListTile(
                  leading: const Icon(Icons.public_outlined),
                  title: Text(AppLocalizations.of(context).groupTimeZone),
                  subtitle: _TimeZoneSubtitle(timeZone: group.timeZone),
                  trailing: isAdmin
                      ? IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).groupTimeZoneChoose,
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editTimeZoneDialog(context, ref),
                        )
                      : null,
                  onTap: () => showGroupTimeZoneInfoDialog(
                    context,
                    groupTimeZone: group.timeZone,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    AppLocalizations.of(context).classroomOlusturulma,
                  ),
                  subtitle: Text(
                    DateFormat.yMd(
                      AppLocalizations.of(context).localeName,
                    ).format(group.createdAt),
                  ),
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text(
                      AppLocalizations.of(context).safetyBlockedUsersTitle,
                    ),
                    onTap: () => _showBannedMembers(context, repo),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Üyeler ---
          Text(
            AppLocalizations.of(context).classroomUyeler,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _MembersCard(group: group, isAdmin: isAdmin, currentUserId: userId),
          const SizedBox(height: 16),

          // --- Ayarlar / tehlikeli işlemler ---
          Text(
            AppLocalizations.of(context).classroomAyarlar,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!isAdmin && userId != null)
            _LeaveGroupTile(group: group, userId: userId),
          if (isAdmin)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  AppLocalizations.of(context).classroomGrubuSil,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: Text(
                  AppLocalizations.of(context).classroomTumUyelerIcinKalici,
                ),
                onTap: () => _deleteGroup(context, ref, repo),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).classroomGrupAdiniDegistir),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          // WP-517: sunucu karşılığı `0122_name_length_limits.sql`.
          maxLength: kGroupNameMaxLength,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).classroomGrupAdi,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).classroomVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(AppLocalizations.of(context).classroomKaydet),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || name.trim() == group.name) {
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(groupRepositoryProvider).updateGroupName(group.id, name);
      // groups tablosu realtime publication'da degil ve watchUserGroups yalniz
      // group_members akisiyla tetiklenir; ad degisince akis tetiklenmez. Bu yuzden
      // gruplari elle tazele ki liste/ekranlar yeni adi aninda gostersin.
      ref.invalidate(userGroupsProvider);
      navigator.pop();
    } on GroupException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.message == 'public_name_not_allowed'
                ? l10n.moderationPublicNameRejected
                : genericError,
          ),
        ),
      );
    }
  }

  Future<void> _editGoalDialog(BuildContext context, WidgetRef ref) async {
    var hours = group.dailyGoalMinutes ~/ 60;
    var minutes = group.dailyGoalMinutes % 60;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context).classroomGunlukGrupHedefi),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppLocalizations.of(context).classroomGrubunBirGundeToplamda} '
                '${AppLocalizations.of(context).classroomOGunkuGrupToplami}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NumberStepper(
                      label: AppLocalizations.of(context).classroomSaat,
                      value: hours,
                      min: 0,
                      max: 24,
                      onChanged: (v) => setState(() => hours = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: NumberStepper(
                      label: AppLocalizations.of(context).classroomDakika,
                      value: minutes,
                      min: 0,
                      max: 59,
                      onChanged: (v) => setState(() => minutes = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).classroomVazgec),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (hours * 60 + minutes)),
              child: Text(AppLocalizations.of(context).classroomKaydet),
            ),
          ],
        ),
      ),
    );
    if (picked == null || picked < 1 || picked == group.dailyGoalMinutes) {
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final navigator = Navigator.of(context);
    try {
      await ref.read(groupRepositoryProvider).updateGroupGoal(group.id, picked);
      // Ad degisimiyle ayni tazeleme gerekcesi (bkz. _renameDialog).
      ref.invalidate(userGroupsProvider);
      navigator.pop();
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _editAccessDialog(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<GroupVisibility>(
      context: context,
      builder: (ctx) {
        var visibility = group.visibility;
        final l10n = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(l10n.groupDiscoveryPrivacyTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<GroupVisibility>(
                  groupValue: visibility,
                  onChanged: (value) => setState(() => visibility = value!),
                  child: Column(
                    children: [
                      RadioListTile<GroupVisibility>(
                        contentPadding: EdgeInsets.zero,
                        value: GroupVisibility.private,
                        title: Text(l10n.groupDiscoveryPrivate),
                        subtitle: Text(l10n.groupDiscoveryPrivateDescription),
                      ),
                      RadioListTile<GroupVisibility>(
                        contentPadding: EdgeInsets.zero,
                        value: GroupVisibility.public,
                        title: Text(l10n.groupDiscoveryPublic),
                        subtitle: Text(l10n.groupDiscoveryPublicDescription),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.classroomVazgec),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, visibility),
                child: Text(l10n.classroomKaydet),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == group.visibility || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(groupRepositoryProvider)
          .updateGroupAccess(
            group.id,
            visibility: picked,
            memberLimit: group.memberLimit,
          );
      ref.invalidate(userGroupsProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupDiscoveryPrivacyUpdated)),
      );
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _editTimeZoneDialog(BuildContext context, WidgetRef ref) async {
    final choices = <String>{...kGroupTimeZoneChoices, group.timeZone}.toList();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var timeZone = group.timeZone;
        final l10n = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(l10n.groupTimeZoneChoose),
            content: DropdownButtonFormField<String>(
              initialValue: timeZone,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.groupTimeZone),
              items: choices
                  .map(
                    (zone) => DropdownMenuItem(
                      value: zone,
                      child: Text(
                        localizedWorldCityLabel(zone, l10n, fallback: zone),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => timeZone = value!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.classroomVazgec),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, timeZone),
                child: Text(l10n.classroomKaydet),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == group.timeZone || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(groupRepositoryProvider)
          .updateGroupTimeZone(group.id, picked);
      ref.invalidate(userGroupsProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.groupTimeZoneUpdated)),
      );
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _regenerateCode(
    BuildContext context,
    WidgetRef ref,
    GroupRepository repo,
  ) async {
    final ok = await _confirm(
      context,
      title: AppLocalizations.of(context).classroomKoduYenile,
      message: AppLocalizations.of(context).classroomYeniBirDavetKodu,
      action: AppLocalizations.of(context).classroomYenile,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      final code = await repo.regenerateInviteCode(group.id);
      // Yeni davet kodu da groups tablosunda; akis tetiklenmez (bkz. _renameDialog).
      ref.invalidate(userGroupsProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.classroomYeniKodCode(code))),
      );
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _deleteGroup(
    BuildContext context,
    WidgetRef ref,
    GroupRepository repo,
  ) async {
    final ok = await _confirm(
      context,
      title: AppLocalizations.of(context).classroomGrubuSil,
      message:
          '"${group.name}" · '
          '${AppLocalizations.of(context).classroomTumUyelerIcinKalici}. '
          '${AppLocalizations.of(context).classroomBuIslemGeriAlinamaz}',
      action: AppLocalizations.of(context).classroomSil,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final navigator = Navigator.of(context);
    try {
      await repo.deleteGroup(group.id);
      ref.read(activeGroupIdProvider.notifier).select(null);
      navigator.pop();
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _showBannedMembers(
    BuildContext context,
    GroupRepository repo,
  ) async {
    var membersFuture = repo.listBannedMembers(group.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            AppLocalizations.of(dialogContext).safetyBlockedUsersTitle,
          ),
          content: FutureBuilder<List<Profile>>(
            future: membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final members = snapshot.data;
              if (snapshot.hasError || members == null) {
                return Text(
                  AppLocalizations.of(context).authBeklenmeyenBirHataOlustu,
                );
              }
              if (members.isEmpty) {
                return Text(AppLocalizations.of(context).safetyNoBlockedUsers);
              }
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member.displayName),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            await repo.unbanMember(group.id, member.id);
                            setDialogState(
                              () => membersFuture = repo.listBannedMembers(
                                group.id,
                              ),
                            );
                          } on GroupException {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    AppLocalizations.of(
                                      dialogContext,
                                    ).authBeklenmeyenBirHataOlustu,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(AppLocalizations.of(context).safetyUnblock),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(dialogContext).classroomVazgec),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeZoneSubtitle extends StatelessWidget {
  const _TimeZoneSubtitle({required this.timeZone});

  final String timeZone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final relative = groupTimeZoneRelativeLabel(
      groupTimeZone: timeZone,
      l10n: l10n,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizedWorldCityLabel(timeZone, l10n, fallback: timeZone)),
        if (relative != null) Text(relative),
      ],
    );
  }
}

/// Sınıf üyeleri listesi (canlı). Admin başkasını çıkarabilir (kendisi/üye hariç).
class _GroupAvatarEditor extends ConsumerStatefulWidget {
  const _GroupAvatarEditor({required this.group, required this.isAdmin});

  final StudyGroup group;
  final bool isAdmin;

  @override
  ConsumerState<_GroupAvatarEditor> createState() => _GroupAvatarEditorState();
}

class _GroupAvatarEditorState extends ConsumerState<_GroupAvatarEditor> {
  late StudyGroup _group = widget.group;
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    final extension = file.name.contains('.')
        ? file.name.split('.').last
        : 'jpg';
    setState(() => _uploading = true);
    try {
      final updated = await ref
          .read(groupRepositoryProvider)
          .uploadGroupAvatar(
            groupId: _group.id,
            bytes: await file.readAsBytes(),
            extension: extension,
          );
      if (!mounted) return;
      setState(() => _group = updated);
      ref.invalidate(userGroupsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).profileProfilFotografiGuncellendi,
          ),
        ),
      );
    } on GroupException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(genericError)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = GroupAvatar(
      name: _group.name,
      avatarPath: _group.avatarPath,
      avatarUpdatedAt: _group.avatarUpdatedAt,
      radius: 34,
    );
    if (!widget.isAdmin) return avatar;
    return SizedBox.square(
      dimension: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: Center(child: avatar)),
          PositionedDirectional(
            end: -4,
            bottom: -4,
            child: IconButton.filled(
              tooltip: AppLocalizations.of(
                context,
              ).classroomGrupFotografiniDegistir,
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Üye satırının kararlı kancası (test + golden).
///
/// Satır artık `ListTile` değil (WP-498); testler satırı tipe göre bulamaz.
/// Ada/ünvana göre aramak da kırılgan: uzun ad kırpılınca `find.text` tutmaz.
Key memberRowKey(String memberId) => ValueKey('member-row-$memberId');

class _MembersCard extends ConsumerWidget {
  const _MembersCard({
    required this.group,
    required this.isAdmin,
    required this.currentUserId,
  });

  final StudyGroup group;
  final bool isAdmin;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(groupRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final titleNames = {
      for (final achievement in kAchievementDictV3(l10n))
        achievement.id: achievement.name,
    };
    final studyingIds = {
      for (final presence
          in ref.watch(groupPresenceProvider).value ?? const <Presence>[])
        if (presence.status == PresenceStatus.studying) presence.userId,
    };
    // WP-483: yalnız **kendi** susturma tercihim. Karşı taraf bunu okuyamaz.
    final mutedIds =
        ref.watch(mutedNudgeSenderIdsProvider).value ?? const <String>{};
    // 🔴 WP-494: akış artık her `build()`de kurulmuyor; provider aynı grup için
    // tek abonelik tutar ve yenilemede son listeyi korur (spinner yalnız ilk
    // yüklemede). Bkz. `groupMembersByIdProvider`.
    final membersAsync = ref.watch(groupMembersByIdProvider(group.id));
    final members = membersAsync.value;
    if (members == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            // Akış ilk veriden önce hata verirse eskiden sonsuz spinner
            // dönüyordu; hata artık görünür.
            child: membersAsync.hasError
                ? Text(l10n.authBeklenmeyenBirHataOlustu)
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (final m in members)
            _memberRow(
              context,
              member: m,
              repo: repo,
              titleName: titleNames[m.titleAchievementId],
              isStudying: studyingIds.contains(m.id),
              isMuted: mutedIds.contains(m.id),
            ),
        ],
      ),
    );
  }

  /// Tek üye satırı.
  ///
  /// 🔴 WP-498 (V58-N04): burada `ListTile` vardı ve `trailing`e **dört**
  /// `IconButton` diziliyordu. `ListTile` önce `trailing`e istediği genişliği
  /// verir, `title`a **kalanı** bırakır: dört yuva 192 dp yiyor, 320 dp ekranda
  /// ada ~40 dp kalıyordu — ad "B...", "S..." diye tek harfe düşüyordu.
  /// Şikâyetin kanıtı ekrandaki tek istisnaydı: eylem simgesi **olmayan** satır
  /// (yöneticinin kendi satırı) adı tam gösteriyordu. Bu, WP-487'nin (dikey
  /// şişme) yan etkisidir — sorun dikeyden yataya taşınmıştı.
  ///
  /// Çözüm iki parçalı, ikisi de gerekli:
  ///   1. yerleşim `ListTile`dan alındı; ad `Expanded` ile **öncelikli** alanı
  ///      alır, eylemler sabit genişlikte artık ne kalırsa onu değil;
  ///   2. ikincil yönetici eylemleri (çıkar/yasakla) tek taşma menüsüne indi.
  ///      Dürtme ve susturma **satırda kalır** — ikisi de birincil eylem.
  ///
  /// Satır yüksekliği ad/ünvan uzunluğundan bağımsızdır (WP-487 kazanımı):
  /// `ListTile`ın iki satırlık 72 dp taban yüksekliği burada `minHeight` olarak
  /// açıkça duruyor, aksi hâlde eylemi olan satır olmayandan yüksek olurdu.
  Widget _memberRow(
    BuildContext context, {
    required Profile member,
    required GroupRepository repo,
    required String? titleName,
    required bool isStudying,
    required bool isMuted,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final showActions = member.isActive && member.id != currentUserId;
    final canModerate = isAdmin && member.id != group.createdBy;
    return InkWell(
      key: memberRowKey(member.id),
      onTap: () => SocialProfileDialog.show(context, member),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          // Sağda dolgu yok: eylem yuvasındaki `IconButton` zaten 8 dp iç
          // dolgu taşıyor, ikinci bir kenar boşluğu doğrudan addan çalınıyordu.
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
          child: Row(
            children: [
              LiveCrownedAvatar(
                userId: member.id,
                displayName: member.displayName,
                avatarUrl: member.avatarUrl,
                radius: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // WP-487: ad tek satır. Sarmalanan ad + sarmalanan ünvan +
                    // ayrı "Yönetici" satırı aynı üyeyi 5 satıra çıkarabiliyordu.
                    Text(
                      !member.isActive
                          ? l10n.classroomEskiGrupUyesi
                          : (member.displayName.isEmpty
                                ? l10n.classroomIsimsiz
                                : member.displayName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    _memberSubtitle(
                      context,
                      isOwner: member.id == group.createdBy,
                      title: titleName,
                    ),
                  ],
                ),
              ),
              if (showActions) ...[
                _MemberActionSlot(
                  // WP-511: mantık artık ortak (`nudge_action.dart`); kamp ateşi
                  // üye sayfası da aynı bileşeni kullanır.
                  child: NudgeAction(
                    key: ValueKey('nudge-${member.id}'),
                    groupId: group.id,
                    recipient: member,
                    isRecipientStudying: isStudying,
                  ),
                ),
                _MemberActionSlot(
                  child: _MuteNudgeButton(
                    key: ValueKey('mute-${member.id}'),
                    memberId: member.id,
                    isMuted: isMuted,
                  ),
                ),
                // 🔴 WP-446: bu iki eylem aynı görünüyordu ama sonuçları
                // farklı. Çıkarma geri dönülebilir (üye davet koduyla tekrar
                // katılır), yasak değil. Yasak düğmesi üstelik `safetyBlock`
                // ("Kişiyi engelle") metnini kullanıyordu — o ise hesap-kapsamlı
                // KİŞİSEL bir tercihtir, yönetici işlemi değil. Yönetici
                // "engelliyorum" sanıp kalıcı grup yasağı koyabiliyordu.
                // WP-498: ikisi de menüye indi ama **koşulu ve adları aynen**.
                if (canModerate)
                  _MemberActionSlot(
                    child: _MemberModerationMenu(
                      key: ValueKey('moderate-${member.id}'),
                      onRemove: () => _removeMember(context, repo, member),
                      onBan: () => _banMember(context, repo, member),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// WP-487: üye satırının **tek** alt satırı.
  ///
  /// Eskiden ünvan ve "Yönetici" `Column` içinde iki ayrı sarmalanabilir `Text`
  /// idi; uzun ad 2, uzun ünvan 2 satıra çıkınca aynı üye 4–5 satır kaplıyordu
  /// ve liste satırları farklı yüksekliklerde oluyordu (V57-N11).
  ///
  /// Gösterilecek bir şey olmadığında da **boş bir alt satır döndürülür**:
  /// `ListTile` yüksekliğini `subtitle`ın varlığına göre seçtiği için, `null`
  /// dönmek ünvansız üyeleri kısa satır yapar ve düzensizlik geri gelir.
  /// Ünvanı tamamen okumak isteyen satıra dokununca profil kartını açar.
  Widget _memberSubtitle(
    BuildContext context, {
    required bool isOwner,
    required String? title,
  }) {
    if (!isOwner && title == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      children: [
        if (title != null)
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (title != null && isOwner) const SizedBox(width: 6),
        if (isOwner)
          // Yönetici işareti sabit genişlikte: `Flexible` olmayan bir çocuk
          // satır genişliğini aşarsa `Row` taşar, bu yüzden üst sınırı var
          // (yazı tipi ölçeğiyle birlikte büyür).
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.textScalerOf(context).scale(88),
            ),
            child: Text(
              AppLocalizations.of(context).classroomYonetici,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    GroupRepository repo,
    Profile member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirm(
      context,
      title: l10n.classroomUyeyiCikar,
      // WP-446: onay metni artık eylemin KAPSAMINI da söylüyor. Eskiden
      // çıkarma ve yasak birebir aynı cümleyi gösteriyordu.
      message:
          '${l10n.classroomMemberdisplaynameGruptanCikarilsinMi(member.displayName)}'
          '\n\n${l10n.classroomUyeyiCikarKapsam}',
      action: l10n.classroomCikar,
    );
    if (!ok) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    try {
      await repo.removeMember(group.id, member.id);
    } on GroupException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  Future<void> _banMember(
    BuildContext context,
    GroupRepository repo,
    Profile member,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirm(
      context,
      title: l10n.classroomUyeyiYasakla,
      message:
          '${l10n.classroomMemberdisplaynameGruptanYasaklansinMi(member.displayName)}'
          '\n\n${l10n.classroomUyeyiYasaklaKapsam}',
      action: l10n.classroomYasakla,
    );
    if (!ok || !context.mounted) return;
    try {
      await repo.banMember(group.id, member.id);
    } on GroupException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
        );
      }
    }
  }

}

/// WP-483: grup üye satırındaki "dürtmesini sustur" eylemi.
///
/// `muteNudgesFrom` WP-444'te arayüze, iki repository'ye, RLS'e ve testlere
/// yazıldı ama `app/lib` içinden **hiçbir yerden çağrılmıyordu**: kullanıcının
/// birini susturmasının yolu yoktu ve ayarlardaki liste tanımı gereği hep
/// boştu. Testler InMemory katmanını sürdüğü için boşluk yeşil göründü.
///
/// 🔴 Yan kanal kuralı (WP-444): susturma yalnız **susturan kişinin kendi**
/// ekranında görünür. Susturulmuş alıcıya gönderim başarılı görünmeye devam
/// eder ve gönderen tercihi okuyamaz.
class _MuteNudgeButton extends ConsumerStatefulWidget {
  const _MuteNudgeButton({
    super.key,
    required this.memberId,
    required this.isMuted,
  });

  final String memberId;
  final bool isMuted;

  @override
  ConsumerState<_MuteNudgeButton> createState() => _MuteNudgeButtonState();
}

class _MuteNudgeButtonState extends ConsumerState<_MuteNudgeButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(nudgeRepositoryProvider);
    final wasMuted = widget.isMuted;
    setState(() => _busy = true);
    try {
      if (wasMuted) {
        await repo.unmuteNudgesFrom(widget.memberId);
      } else {
        await repo.muteNudgesFrom(widget.memberId);
      }
      // Ayarlardaki liste aynı tercihten besleniyor; iki sağlayıcı da tazelenir.
      ref.invalidate(mutedNudgeSenderIdsProvider);
      ref.invalidate(nudgeMutesProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            wasMuted ? l10n.safetyNudgesUnmuted : l10n.safetyNudgesMuted,
          ),
        ),
      );
    } on NudgeException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.localize(l10n))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return IconButton(
      tooltip: widget.isMuted ? l10n.safetyUnmuteNudges : l10n.safetyMuteNudges,
      // Susturulmuş üyenin satırdaki görünür işareti: dolu simge + vurgu rengi.
      // Sahip "grupta mute işaretini bulamadım" derken göstergeyi de kastetti.
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              widget.isMuted
                  ? Icons.notifications_off
                  : Icons.notifications_off_outlined,
              color: widget.isMuted ? theme.colorScheme.error : null,
            ),
      onPressed: _busy ? null : _toggle,
    );
  }
}

/// Üye satırındaki tek eylem yuvası.
///
/// 🔴 WP-498: `IconButton` varsayılan olarak **48 dp genişliğinde** bir kutu
/// ister. 320 dp ekranda kartın iç genişliği ~280 dp; ada 12 karakterlik
/// (~96 dp) alan bırakmak isteyen bir satırda üç yuvaya toplam 144 dp değil
/// **120 dp** düşer. Bu yüzden yuva yatayda 40 dp'ye çekildi.
///
/// Dokunma hedefinin **dikey** boyutu 48 dp olarak korunur (`IconButton`ın
/// kendi alt sınırı, satır zaten en az 72 dp) ve satırın tamamı ayrıca
/// tıklanabilir (profil kartı). Daralan yalnız yatay ayak izidir; alternatif,
/// adın okunamaz kalmaya devam etmesiydi.
class _MemberActionSlot extends StatelessWidget {
  const _MemberActionSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: _kMemberActionSlotWidth, child: child);
}

const double _kMemberActionSlotWidth = 40;

/// WP-498: yönetici eylemlerinin taşma menüsü.
///
/// Çıkarma ve yasaklama satırdan **kaldırılmadı**, tek yuvaya indirildi: ikisi
/// de nadir, geri dönüşü zor ve zaten onay diyaloğu ister. Dürtme ve susturma
/// menüye girmez — onlar birincil eylemlerdir (kart tuzağı).
///
/// Menü yalnız `isAdmin && m.id != group.createdBy` iken çizilir; koşul
/// sağlanmıyorsa **düğmenin kendisi yoktur**, boş menü açılmaz.
class _MemberModerationMenu extends StatelessWidget {
  const _MemberModerationMenu({
    super.key,
    required this.onRemove,
    required this.onBan,
  });

  final VoidCallback onRemove;
  final VoidCallback onBan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_vert),
      // Yuva 40 dp; `IconButton`ın 8 dp iç dolgusu bu kutuda taşma yapar.
      padding: EdgeInsets.zero,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem<VoidCallback>(
          value: onRemove,
          child: _menuRow(Icons.person_remove_outlined, l10n.classroomUyeyiCikar),
        ),
        PopupMenuItem<VoidCallback>(
          value: onBan,
          child: _menuRow(Icons.gavel_outlined, l10n.classroomUyeyiYasakla),
        ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon),
      const SizedBox(width: 12),
      // Menü genişliği içeriğe göre; uzun çeviride sarmalanır, kırpılmaz.
      Flexible(child: Text(label)),
    ],
  );
}

/// Basit onay diyaloğu (tehlikeli işlemler için).
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(AppLocalizations.of(context).classroomVazgec),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// WP-445: Gruptan çıkış — tek hareket, tek komut.
///
/// Eski hâl durumsuz bir `ListTile`'dı: her tap yeni bir mutasyon başlatıyordu
/// ve zaman aşımında kullanıcı "çıktım mı" sorusuyla baş başa kalıyordu.
///
/// Burada tek kullanıcı hareketi için **tek** `commandId` üretilir ve retry'da
/// aynısı gönderilir; sunucu (`0108`) aynı anahtarı yeniden işlemez. Böylece 20
/// hızlı tap da, zaman aşımı sonrası retry de tek çıkışa indirgenir.
///
/// Liste iyimser biçimde önden silinmez: kart "başarısızlıkta sahte çıkmış
/// görünmez" diyor, bu yüzden görünür geri bildirim (≤1 sn) meşgul göstergesiyle
/// verilir ve satır ancak sunucu onayından sonra kaybolur.
class _LeaveGroupTile extends ConsumerStatefulWidget {
  const _LeaveGroupTile({required this.group, required this.userId});

  final StudyGroup group;
  final String userId;

  @override
  ConsumerState<_LeaveGroupTile> createState() => _LeaveGroupTileState();
}

class _LeaveGroupTileState extends ConsumerState<_LeaveGroupTile> {
  bool _busy = false;

  /// Hareket başına tek anahtar; retry aynısını kullanır.
  String? _commandId;

  Future<void> _confirmAndLeave() async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirm(
      context,
      title: l10n.classroomGruptanCik,
      message:
          '"${widget.group.name}" · '
          '${l10n.classroomGruptanCik}. '
          '${l10n.classroomBuIslemGeriAlinamaz}',
      action: l10n.classroomCik,
    );
    if (!ok || !mounted) return;
    _commandId = const Uuid().v4();
    await _send();
  }

  Future<void> _send() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(groupRepositoryProvider);

    setState(() => _busy = true);
    try {
      // Askıda kalan istek retry'ı gizlemesin.
      await repo
          .leaveGroup(widget.group.id, widget.userId, commandId: _commandId!)
          .timeout(const Duration(seconds: 10));
      // `left` ve `alreadyLeft` aynı kullanıcı gerçeğidir: artık üye değil.
      ref.read(activeGroupIdProvider.notifier).select(null);
      ref.invalidate(userGroupsProvider);
      if (!mounted) return;
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.classroomGruptanCikilamadi),
          action: SnackBarAction(
            label: l10n.classroomRetry,
            // Aynı anahtar: sunucu işi tekrar yapmaz.
            onPressed: _send,
          ),
        ),
      );
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: ListTile(
        key: const ValueKey('leave-group-action'),
        leading: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.logout, color: theme.colorScheme.error),
        title: Text(
          l10n.classroomGruptanCik,
          style: TextStyle(color: theme.colorScheme.error),
        ),
        enabled: !_busy,
        onTap: _busy ? null : _confirmAndLeave,
      ),
    );
  }
}
