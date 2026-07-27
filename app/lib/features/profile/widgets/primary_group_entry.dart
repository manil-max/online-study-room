import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/warning_tokens.dart';
import '../../../data/providers/group_providers.dart';
import '../../../l10n/app_localizations.dart';
import 'primary_group_selector_card.dart';

/// WP-376: Sağ üstteki seçim girişi. Dokunma hedefi [IconButton] varsayılanıyla
/// 48 dp; rozet [primaryGroupSelectionMissingProvider]'dan gelir.
class PrimaryGroupAppBarAction extends ConsumerWidget {
  const PrimaryGroupAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(primaryGroupSelectionMissingProvider);
    final l10n = AppLocalizations.of(context);
    // WP-358: uyarı rengi tema paletinden değil, üstünde durduğu yüzeyden.
    final warning = warningColorsOn(Theme.of(context).colorScheme.surface);
    final button = IconButton(
      key: const Key('primary-group-appbar-action'),
      tooltip: l10n.primaryGroupTitle,
      icon: const Icon(Icons.groups_outlined),
      onPressed: () => showPrimaryGroupSelector(context),
    );
    if (!missing) return button;
    return Badge(
      key: const Key('primary-group-appbar-badge'),
      backgroundColor: warning.container,
      smallSize: 10,
      child: button,
    );
  }
}

/// WP-376: Kaybın ekranın kendisinde de göründüğü şerit. Kocaman kartın
/// yerini alır; seçim yapılmışsa **hiç** yer kaplamaz.
class PrimaryGroupMissingBanner extends ConsumerWidget {
  const PrimaryGroupMissingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(primaryGroupSelectionMissingProvider)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        key: const Key('primary-group-missing-banner'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => showPrimaryGroupSelector(context),
        child: const PrimaryGroupMissingWarning(),
      ),
    );
  }
}
