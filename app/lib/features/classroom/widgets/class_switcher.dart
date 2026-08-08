import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/group_error_text.dart';
import '../../../core/validation/name_limits.dart';
import '../../../core/time_engine/device_timezone.dart';
import '../../../core/time_engine/world_clock_math.dart';
import '../../../core/widgets/anchored_menu.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import 'class_detail_screen.dart';
import 'group_avatar.dart';
import 'group_discovery_screen.dart';

/// Sınıf değiştirici (Instagram hesap değiştirme mantığı, §3.8): katılınan
/// sınıflar listelenir, dokununca aktif sınıf değişir; ayrıca "Sınıf oluştur" /
/// "Sınıfa katıl". Alttan açılan pencere yerine **basılan yerde** açılır (§3.12).
///
/// Sağ üstteki ↔ ikonundan tetiklenirse [context] o ikonun context'idir (menü
/// ona göre konumlanır); sekmeye basılı tutunca [at] basış konumudur.
/// [switchOnly] true ise yalnızca grup değiştirme (oluştur/katıl/⋮ gizli) —
/// İstatistik gibi yerlerde sadece geçiş için.
Future<void> showClassSwitcher(
  BuildContext context,
  WidgetRef ref, {
  Offset? at,
  bool switchOnly = false,
}) {
  final theme = Theme.of(context);
  final groups = ref.read(userGroupsProvider).value ?? const <StudyGroup>[];
  final activeId = ref.read(userGroupProvider).value?.id;

  final items = <PopupMenuEntry<void>>[
    PopupMenuItem<void>(
      enabled: false,
      height: 32,
      child: Text(
        AppLocalizations.of(context).classroomGruplarim,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    if (groups.isEmpty)
      PopupMenuItem<void>(
        enabled: false,
        child: Text(
          AppLocalizations.of(context).classroomHenuzGrupYok,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    for (final g in groups)
      PopupMenuItem<void>(
        onTap: () => ref.read(activeGroupIdProvider.notifier).select(g.id),
        child: Row(
          children: [
            GroupAvatar(
              name: g.name,
              avatarPath: g.avatarPath,
              avatarUpdatedAt: g.avatarUpdatedAt,
              radius: 13,
              backgroundColor: g.id == activeId
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: g.id == activeId
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(g.name, overflow: TextOverflow.ellipsis)),
            if (g.id == activeId)
              Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
            if (!switchOnly) _ClassDetailButton(group: g),
          ],
        ),
      ),
    if (!switchOnly) ...[
      const PopupMenuDivider(),
      PopupMenuItem<void>(
        onTap: () => createGroupFlow(context, ref),
        child: Row(
          children: [
            Icon(Icons.add, size: 20),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context).classroomGrupOlustur),
          ],
        ),
      ),
      PopupMenuItem<void>(
        onTap: () => joinGroupFlow(context, ref),
        child: Row(
          children: [
            Icon(Icons.login, size: 20),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context).classroomGrubaKatil),
          ],
        ),
      ),
      PopupMenuItem<void>(
        onTap: () => Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const GroupDiscoveryScreen())),
        child: Row(
          children: [
            const Icon(Icons.travel_explore, size: 20),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context).groupDiscoveryAction),
          ],
        ),
      ),
    ],
  ];

  return at != null
      ? showMenuAtPosition<void>(
          context: context,
          globalPosition: at,
          items: items,
        )
      : showAnchoredMenu<void>(context: context, items: items);
}

/// Sınıf satırındaki ⋮ — menüyü kapatıp sınıf detay/ayar ekranını açar.
/// Satırın "aktif yap" eylemini tetiklemez (iç buton dokunuşu kazanır).
class _ClassDetailButton extends StatelessWidget {
  const _ClassDetailButton({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).classroomGrupBilgileriVeAyarlari,
      icon: const Icon(Icons.more_vert, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final nav = Navigator.of(context, rootNavigator: true);
        Navigator.of(context).pop(); // menüyü kapat
        nav.push(
          MaterialPageRoute(builder: (_) => ClassDetailScreen(group: group)),
        );
      },
    );
  }
}

/// Sınıf oluşturma akışı: ad sorar, oluşturur, yeni sınıfı aktif yapar.
/// Başarılıysa true döner.
///
/// 🔴 WP-530: `createGroup` sunucu turu sahada 5-6 sn sürüyor. Eskiden
/// "Oluştur" **diyaloğu anında kapatıyordu** ve istek boyunca ekranda hiçbir
/// gösterge kalmıyordu; sahip "olmadı" sanıp ikinci kez denedi. Ölçüldü
/// (WP-530 probu): ikinci deneme ikinci `createGroup` çağrısını gerçekten
/// gönderiyordu → **iki grup**. Bu yüzden istek artık diyaloğun **içinde**
/// koşar: buton devre dışı + "Kuruluyor…", bitince sonuç.
/// 🔴 WP-535: oturum burada OKUNMAZ. WP-530'da `authStateProvider` diyalogdan
/// ONCE okunuyordu; akis bir `Stream` oldugu icin ilk karelerde deger henuz
/// `null` olur ve "Grup olustur" **hicbir sey yapmadan** doner. Sessiz
/// hicbir sey, WP-530'un kapatmaya calistigi hatanin ta kendisi. Kullanici
/// bilgisi artik gonderim aninda okunur; yoksa diyalogda yazili hata cikar.
Future<bool> createGroupFlow(BuildContext context, WidgetRef ref) async {
  final group = await _promptCreateGroup(context, ref);
  if (group == null) return false;

  ref.read(activeGroupIdProvider.notifier).select(group.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).classroomGrupOlusturuldu),
      ),
    );
  }
  return true;
}

/// Ad/gizlilik/saat dilimi sorar **ve grubu kurar**. Oluşan grubu döner;
/// vazgeçilirse veya ad boşsa null.
Future<StudyGroup?> _promptCreateGroup(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  return showDialog<StudyGroup>(
    context: context,
    // WP-530: istek uçarken bariyere dokunmak kullanıcıyı yine göstergesiz
    // ekranda bırakırdı. Vazgeçmenin açık düğmesi var.
    barrierDismissible: false,
    builder: (ctx) {
      var visibility = GroupVisibility.private;
      var timeZone = DeviceTimezone.lastId ?? kDefaultGroupTimeZone;
      if (!kGroupTimeZoneChoices.contains(timeZone)) {
        timeZone = kDefaultGroupTimeZone;
      }
      var submitting = false;
      String? error;
      final l10n = AppLocalizations.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) {
          final currentError = error;

          Future<void> submit() async {
            // İkinci basış: düğme zaten devre dışı; bu ikinci kapı aynı
            // sözleşmeyi klavye/erişilebilirlik yollarına karşı da tutar.
            if (submitting) return;
            // 🔴 WP-540: burada `Navigator.pop(ctx)` vardı — boş girişte
            // diyalog **hiçbir şey söylemeden** kapanıyordu. Kullanıcı için
            // bu, sessizce başarısız olmuş bir eylemden ayırt edilemez.
            if (controller.text.trim().isEmpty) {
              setState(() => error = l10n.commonGrupAdiBosOlamaz);
              return;
            }
            final creator = ref.read(authStateProvider).value;
            if (creator == null) {
              setState(() => error = l10n.profileOturumBulunamadiGirisYap);
              return;
            }
            setState(() {
              submitting = true;
              error = null;
            });
            try {
              final group = await ref
                  .read(groupRepositoryProvider)
                  .createGroup(
                    name: controller.text,
                    creator: creator,
                    visibility: visibility,
                    timeZone: timeZone,
                  );
              if (ctx.mounted) Navigator.pop(ctx, group);
            } catch (failure) {
              // WP-540: sebep artık kaybolmuyor. Yasaklı grup adı
              // (`public_name_not_allowed`, `0094`) tek "Beklenmeyen bir hata
              // oluştu." cümlesine iniyordu — oysa ad DEĞİŞTİRMEDE doğru mesaj
              // zaten vardı. Ağ hatası da ilk kez yakalanıyor: `GroupException`
              // olmayan hata eskiden buradan kaçıyor, gösterge sonsuza dek
              // dönüyor ve `PopScope` yüzünden diyalog da kapanmıyordu.
              if (!ctx.mounted) return;
              setState(() {
                submitting = false;
                error = groupActionErrorText(failure, l10n);
              });
            }
          }

          return PopScope(
            canPop: !submitting,
            child: AlertDialog(
              title: Text(l10n.classroomGrupOlustur),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      // WP-540: `_promptJoinGroup`da vardı, burada yoktu —
                      // istek uçarken ad hâlâ düzenlenebiliyordu.
                      enabled: !submitting,
                      textCapitalization: TextCapitalization.words,
                      // WP-517: sunucu karşılığı `0122_name_length_limits.sql`.
                      // `_promptJoinGroup` (davet kodu) bilerek sınırsız — o ad
                      // değil.
                      maxLength: kGroupNameMaxLength,
                      decoration: InputDecoration(
                        labelText: l10n.classroomGrupAdi,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.groupDiscoveryPrivacyTitle,
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                    ),
                    RadioGroup<GroupVisibility>(
                      groupValue: visibility,
                      onChanged: (value) => setState(() => visibility = value!),
                      child: Column(
                        children: [
                          RadioListTile<GroupVisibility>(
                            contentPadding: EdgeInsets.zero,
                            value: GroupVisibility.private,
                            title: Text(l10n.groupDiscoveryPrivate),
                            subtitle: Text(
                              l10n.groupDiscoveryPrivateDescription,
                            ),
                          ),
                          RadioListTile<GroupVisibility>(
                            contentPadding: EdgeInsets.zero,
                            value: GroupVisibility.public,
                            title: Text(l10n.groupDiscoveryPublic),
                            subtitle: Text(
                              l10n.groupDiscoveryPublicDescription,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: timeZone,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.groupTimeZone,
                      ),
                      items: kGroupTimeZoneChoices
                          .map(
                            (zone) => DropdownMenuItem(
                              value: zone,
                              child: Text(
                                localizedWorldCityLabel(
                                  zone,
                                  l10n,
                                  fallback: zone,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) => setState(() => timeZone = value!),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.groupTimeZoneDescription,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    if (currentError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        currentError,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: Text(l10n.classroomVazgec),
                ),
                FilledButton(
                  key: const Key('create-group-submit'),
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.classroomGrupKuruluyor),
                          ],
                        )
                      : Text(l10n.classroomOlustur),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Sınıfa katılma akışı: davet kodu sorar, katar, o sınıfı aktif yapar.
/// Başarılıysa true döner.
///
/// 🔴 WP-532: grup kurmanın (WP-530) ikizi kusur burada da ölçüldü. Eski akış
/// "Katıl"a basınca diyaloğu **anında kapatıyordu**, `joinGroup` isteği
/// göstergesiz uçuyordu ve başarıda hiçbir onay yoktu. Prob çıktısı:
/// "1. basıştan sonra diyalog açık mı? false", "ilerleme göstergesi var mı?
/// false", "bitişte başarı göstergesi (SnackBar) var mı? false". Kullanıcı
/// "olmadı" sanıp akışı yeniden açınca **ikinci `joinGroup` çağrısı** gidiyordu
/// (prob: "TOPLAM joinGroup çağrısı = 2"). Sunucu tarafı bunu yutuyor —
/// `join_group` RPC'si (`0093_group_bans.sql`) zaten üyeyse grubu aynen döner —
/// yani kurmadaki gibi çift kayıt oluşmuyor; ama kullanıcı yine boş ekrana
/// bakıyor ve gereksiz ikinci tur atılıyor. İstek artık diyaloğun **içinde**
/// koşar.
/// 🔴 WP-540: oturum burada OKUNMAZ — `createGroupFlow`daki WP-535 dersinin
/// ikizi. `authStateProvider` bir `Stream`; ilk karelerde `.value` null olur ve
/// "Gruba katıl" **hiçbir şey yapmadan** dönerdi. Kullanıcı bilgisi artık
/// gönderim anında okunur; yoksa diyalogda yazılı hata çıkar.
Future<bool> joinGroupFlow(BuildContext context, WidgetRef ref) async {
  final group = await _promptJoinGroup(context, ref);
  if (group == null) return false;

  ref.read(activeGroupIdProvider.notifier).select(group.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).classroomGrubaKatildin),
      ),
    );
  }
  return true;
}

/// Davet kodu sorar **ve gruba katılır**. Katılınan grubu döner; vazgeçilirse
/// veya kod boşsa null.
Future<StudyGroup?> _promptJoinGroup(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  return showDialog<StudyGroup>(
    context: context,
    // WP-532: istek uçarken bariyere dokunmak kullanıcıyı yine göstergesiz
    // ekranda bırakırdı. Vazgeçmenin açık düğmesi var.
    barrierDismissible: false,
    builder: (ctx) {
      var submitting = false;
      String? error;
      final l10n = AppLocalizations.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) {
          final currentError = error;

          Future<void> submit() async {
            // İkinci basış: düğme zaten devre dışı; bu ikinci kapı aynı
            // sözleşmeyi klavye/erişilebilirlik yollarına karşı da tutar.
            if (submitting) return;
            // WP-540: boş kodda diyalog sessizce kapanıyordu (bkz.
            // `_promptCreateGroup`daki aynı kusur).
            if (controller.text.trim().isEmpty) {
              setState(() => error = l10n.classroomDavetKodunuGir);
              return;
            }
            final member = ref.read(authStateProvider).value;
            if (member == null) {
              setState(() => error = l10n.profileOturumBulunamadiGirisYap);
              return;
            }
            setState(() {
              submitting = true;
              error = null;
            });
            try {
              final group = await ref
                  .read(groupRepositoryProvider)
                  .joinGroup(inviteCode: controller.text, member: member);
              if (ctx.mounted) Navigator.pop(ctx, group);
            } catch (failure) {
              // 🔴 WP-540: burada BEŞ ayrı sebep tek cümleye iniyordu — kod
              // yanlış · yasaklısın (`group_banned`) · grup dolu · oturum yok ·
              // ağ. Kullanıcı hangisini düzelteceğini bilemiyordu.
              // `groupActionErrorText` (core/l10n/group_error_text.dart)
              // sebebi koddan okur; desen `core/l10n/nudge_error_text.dart`.
              if (!ctx.mounted) return;
              setState(() {
                submitting = false;
                error = groupActionErrorText(failure, l10n);
              });
            }
          }

          return PopScope(
            canPop: !submitting,
            child: AlertDialog(
              title: Text(l10n.classroomGrubaKatil),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      enabled: !submitting,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: l10n.classroomDavetKodu,
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    if (currentError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        currentError,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: Text(l10n.classroomVazgec),
                ),
                FilledButton(
                  key: const Key('join-group-submit'),
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            // Diyalog dar telefonda 280dp ile sınırlı; uzun
                            // çeviri taşmasın diye esnek.
                            Flexible(
                              child: Text(
                                l10n.classroomGrubaKatiliniyor,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(l10n.classroomKatil),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
