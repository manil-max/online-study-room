import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../core/animals/camp_animal.dart';
import '../../../core/theme/container_roles.dart';

/// Kamp ateşi hayvanını seçtiren alt sayfa (§2G). Seçilen hayvanın kimliğini
/// döndürür (iptal → null). Kaydetme işini çağıran yapar.
Future<String?> showCampAnimalPicker(
  BuildContext context, {
  required String? currentId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _CampAnimalPicker(currentId: currentId),
  );
}

class _CampAnimalPicker extends StatelessWidget {
  const _CampAnimalPicker({required this.currentId});

  final String? currentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).profileKampHayvanin,
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).profileKampAtesiEkranindaSeni,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final a in kCampAnimals)
                  _AnimalTile(
                    animal: a,
                    selected: a.id == currentId,
                    onTap: () => Navigator.of(context).pop(a.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({
    required this.animal,
    required this.selected,
    required this.onTap,
  });

  final CampAnimal animal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 🔴 WP-627: seçili döşemenin zemini ile yazısı **aynı rolü**
    // paylaşmalı. Eskiden zemin `primaryContainer` (fallback yüzünden tam
    // doygun `primary`) idi, yazı ise temadan gelen genel etiket rengi:
    // ikisinin birbiriyle ilgisi yoktu ve ölçüldüğünde 15 temann 9'unda
    // kontrast 4.5 altına, en kötüde 2.24'e düşüyordu.
    //
    // Saydamlık da kaldırıldı: zemin artık zaten düşük doygunluklu bir
    // katman: alfa ile ikinci kez seyreltmek rengi ölçülemez hale getirip
    // kapının ölçtüğü çiftle ekranda çizilen çifti ayırırdı.
    final background = selected
        ? scheme.primaryContainer
        : Color.alphaBlend(
            scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            scheme.surface,
          );
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: background,
          border: Border.all(
            color: selected
                ? accentOn(background, preferred: scheme.primary)
                : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(animal.emoji, style: TextStyle(fontSize: 30)),
            SizedBox(height: 4),
            Text(
              animal.label(AppLocalizations.of(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
