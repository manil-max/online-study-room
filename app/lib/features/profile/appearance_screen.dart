import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_presets.dart';
import '../../core/theme/theme_settings.dart';
import 'theme_studio_screen.dart';
import 'widgets/custom_palette_editor.dart';

/// Görünüm: atmosfer temaları (tam UI havası) + eski palet + açık/koyu/sistem.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);
    final family = settings.family;

    return Scaffold(
      appBar: AppBar(title: const Text('Görünüm ve atmosfer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
              title: const Text('Tema Stüdyosu'),
              subtitle: Text(
                '${family.name} · buzul, ateş, neon, yumuşak… '
                '${kThemePresets.length} atmosfer, canlı önizleme',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ThemeStudioScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text('Tema modu', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Koyu')),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Açık')),
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Sistem')),
            ],
            selected: {settings.mode},
            onSelectionChanged: (s) => notifier.setMode(s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 24),
          Text('Hazır Paletler', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: kAppPalettes.length,
            itemBuilder: (context, i) {
              final p = kAppPalettes[i];
              return _PaletteCard(
                palette: p,
                selected: p.id == settings.paletteId,
                onTap: () => notifier.setPalette(p.id),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Özel Paletler', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (int i = 0; i < settings.customPalettes.length; i++)
            _CustomPaletteTile(
              palette: settings.customPalettes[i],
              selected: settings.paletteId == settings.customPalettes[i].id,
              onTap: () => notifier.setPalette(settings.customPalettes[i].id),
              onEdit: () async {
                final result = await showDialog<AppPalette>(
                  context: context,
                  builder: (ctx) => CustomPaletteEditor(
                    title: 'Özel Palet ${i + 1} Düzenle',
                    initialPalette: settings.customPalettes[i],
                  ),
                );
                if (result != null) {
                  notifier.saveCustomPalette(i, result);
                  if (settings.paletteId != result.id) {
                    notifier.setPalette(result.id);
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Swatch(color: palette.primary),
                const SizedBox(width: 4),
                _Swatch(color: palette.accent),
                const Spacer(),
                if (selected) Icon(Icons.check_circle, color: palette.primary, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              palette.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomPaletteTile extends StatelessWidget {
  const _CustomPaletteTile({
    required this.palette,
    required this.selected,
    required this.onTap,
    required this.onEdit,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? palette.primary : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Swatch(color: palette.primary),
            const SizedBox(width: 4),
            _Swatch(color: palette.accent),
          ],
        ),
        title: Text(palette.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: 'Düzenle',
            ),
            if (selected) Icon(Icons.check_circle, color: palette.primary),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.24)),
      ),
    );
  }
}
