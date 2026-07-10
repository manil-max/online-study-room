import 'package:flutter/material.dart';

import '../../../core/animals/camp_animal.dart';

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
            Text('Kamp hayvanın', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Kamp ateşi ekranında seni bu hayvan temsil eder.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.6)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(animal.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Text(
              animal.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
