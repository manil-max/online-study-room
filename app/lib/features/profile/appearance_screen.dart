import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_settings.dart';
import '../desktop/desktop_surface.dart';
import 'theme_studio_screen.dart';
import 'widgets/custom_palette_editor.dart';

/// Görünüm: atmosfer temaları + palet + açık/koyu/sistem.
/// Masaüstünde okuma genişliği + çok sütunlu palet ızgarası.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);
    final family = settings.family;
    final desktop = isDesktopWindow;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).profileGorunumVeAtmosfer),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cols = desktopGridColumns(
            constraints.maxWidth,
            compact: 2,
            medium: 3,
            expanded: 4,
          );
          return ListView(
            padding: EdgeInsets.fromLTRB(
              desktop ? 20 : 16,
              12,
              desktop ? 20 : 16,
              24,
            ),
            children: [
              DesktopReadingBody(
                maxWidth: desktop ? 880 : double.infinity,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.palette_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          AppLocalizations.of(context).profileTemaStudyosu,
                        ),
                        subtitle: Text(
                          '${family.localizedName(l10n)} · ${l10n.profileCanliOnizleme}',
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ThemeStudioScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      l10n.profileTemaModu,
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: desktop ? 420 : double.infinity,
                        ),
                        child: SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text(l10n.profileKoyu),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text(l10n.profileAcik),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text(l10n.profileSistem),
                            ),
                          ],
                          selected: {settings.mode},
                          onSelectionChanged: (s) => notifier.setMode(s.first),
                          showSelectedIcon: false,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).profileHazirPaletler,
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: desktop ? 2.4 : 2.2,
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
                    SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).profileOzelPaletler,
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    for (int i = 0; i < settings.customPalettes.length; i++)
                      _CustomPaletteTile(
                        palette: settings.customPalettes[i],
                        selected:
                            settings.paletteId == settings.customPalettes[i].id,
                        onTap: () =>
                            notifier.setPalette(settings.customPalettes[i].id),
                        onEdit: () async {
                          final result = await showDialog<AppPalette>(
                            context: context,
                            builder: (ctx) => CustomPaletteEditor(
                              title: l10n.profileOzelPaletI1('${i + 1}'),
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
              ),
            ],
          );
        },
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? palette.primary
                : theme.colorScheme.outlineVariant,
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
                SizedBox(width: 4),
                _Swatch(color: palette.accent),
                Spacer(),
                if (selected)
                  Icon(Icons.check_circle, color: palette.primary, size: 18),
              ],
            ),
            SizedBox(height: 8),
            Text(
              palette.localizedName(AppLocalizations.of(context)),
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
        borderRadius: BorderRadius.circular(8),
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
            SizedBox(width: 4),
            _Swatch(color: palette.accent),
          ],
        ),
        title: Text(palette.localizedName(AppLocalizations.of(context))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined),
              onPressed: onEdit,
              tooltip: AppLocalizations.of(context).profileDuzenle,
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
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onPrimary.withValues(alpha: 0.24),
        ),
      ),
    );
  }
}
