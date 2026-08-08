import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/study_group.dart';
import 'card_scaffold.dart';

/// Veri gelmeden çizilen yer tutucunun kimliği; testler bu anahtarla ölçer.
const Key kGroupCardSkeletonKey = Key('groupCardSkeleton');

/// Grup gerektiren kartların ortak "veri henüz yok" kapısı (WP-495B).
///
/// `null` dönerse grup gerçekten hazırdır ve kart kendi gövdesini çizer.
/// Aksi hâlde çizilecek yer tutucuyu döndürür:
///
/// - veri geldi ve grup **yok** → [GroupCardShell] (davet),
/// - hata → tek satır hata metni,
/// - henüz veri yok → başlık + iskelet.
///
/// 🔴 Kapının varlık sebebi: `userGroupProvider.value` ilk yüklemede **her
/// zaman** `null` döner. Doğrudan `== null` kontrolü, grubu olan kullanıcıya da
/// açılışta bir kare "Grup Oluştur" daveti gösteriyordu (V58-N02); belirti tek
/// kartta değil, grup gerektiren **her** kartta vardı.
Widget? groupCardGate(
  BuildContext context,
  AsyncValue<StudyGroup?> groupAsync, {
  required String title,
  VoidCallback? onCreateGroup,
  VoidCallback? onJoinGroup,
}) {
  if (groupAsync.hasValue) {
    if (groupAsync.value != null) return null;
    return GroupCardShell(
      title: title,
      onCreateGroup: onCreateGroup,
      onJoinGroup: onJoinGroup,
    );
  }
  return GroupCardStatus(
    title: title,
    child: groupAsync.hasError
        ? groupCardMessage(
            context,
            AppLocalizations.of(context).homeGrupBilgisiYuklenemedi,
          )
        : const GroupCardSkeleton(key: kGroupCardSkeletonKey),
  );
}

/// Grup kartları için "henüz grupta değilsin" yer tutucusu.
class GroupCardShell extends StatelessWidget {
  const GroupCardShell({
    super.key,
    required this.title,
    this.onCreateGroup,
    this.onJoinGroup,
  });

  final String title;
  final VoidCallback? onCreateGroup;
  final VoidCallback? onJoinGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // WP-176: Home sabit hücrede taşmayı önlemek için bounded → iç scroll;
    // Groups ListView (unbounded) → iç scroll yok, dış liste kayar (WP-172).
    // WP-508: bounded dalda da kaydırma yalnız gerçekten taştığında açılır.
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.group_add_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).homeBirGrubaKatilincaBurada,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (onCreateGroup != null || onJoinGroup != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onCreateGroup != null)
                      FilledButton.tonalIcon(
                        onPressed: onCreateGroup,
                        icon: const Icon(Icons.add),
                        label: Text(
                          AppLocalizations.of(context).homeGrupOlustur,
                        ),
                      ),
                    if (onJoinGroup != null)
                      OutlinedButton.icon(
                        onPressed: onJoinGroup,
                        icon: const Icon(Icons.login),
                        label: Text(AppLocalizations.of(context).homeKodaKatil),
                      ),
                  ],
                ),
              ],
            ],
          );

          final unbounded = !constraints.maxHeight.isFinite;
          // WP-508: yalnız taşarsa kayar; sığdığında dış sayfa akar.
          return Padding(
            padding: const EdgeInsets.all(16),
            child: unbounded ? column : cardScrollIfOverflows(child: column),
          );
        },
      ),
    );
  }
}

/// Yükleme/hata gövdesi için kart çerçevesi: yalnız başlık + verilen içerik.
///
/// [GroupCardShell] gibi bounded hücrede iç kaydırma yapar (WP-176), fakat
/// "gruba katıl" davetini **taşımaz** — bu kart veri henüz yokken çizilir.
class GroupCardStatus extends StatelessWidget {
  const GroupCardStatus({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          );
          return Padding(
            padding: const EdgeInsets.all(16),
            child: constraints.maxHeight.isFinite
                ? cardScrollIfOverflows(child: column)
                : column,
          );
        },
      ),
    );
  }
}

/// Veri gelene kadar çizilen yer tutucu satırlar.
///
/// Animasyonsuz: ana ekranda aynı anda birçok kart bulunabilir ve sürekli dönen
/// bir shimmer kare bütçesini yer.
class GroupCardSkeleton extends StatelessWidget {
  const GroupCardSkeleton({super.key, this.rows = 2});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Hata durumu boş durumdan ayrı görünür; aksi hâlde ağ hatası "kimse
/// çalışmıyor" ya da "grubun yok" gibi okunur.
Widget groupCardMessage(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Text(
    text,
    style: theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}
