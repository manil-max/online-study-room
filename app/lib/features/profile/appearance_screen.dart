import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_settings.dart';

/// Görünüm ayarları: renk paleti seçimi + açık/koyu/sistem modu (kalıcı).
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Görünüm')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          Text('Renk paleti', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final p in kAppPalettes)
            _PaletteTile(
              palette: p,
              selected: p.id == settings.paletteId,
              onTap: () => notifier.setPalette(p.id),
            ),
        ],
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
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
        trailing: selected
            ? Icon(Icons.check_circle, color: palette.primary)
            : const Icon(Icons.circle_outlined),
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
        border: Border.all(color: Colors.white24),
      ),
    );
  }
}
