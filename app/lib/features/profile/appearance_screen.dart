import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/custom_theme.dart';
import '../../core/theme/theme_settings.dart';
import '../../core/desktop/desktop_layout.dart';
import '../desktop/desktop_surface.dart';
// WP-679: ortak masaustu olculeri (`ProfileDesktopBody`) Ayarlar'da durur.
import 'settings_screen.dart';
import 'theme_builder/theme_builder_screen.dart';

/// Görünüm: kendi temaların (3 yuva) + hazır temalar + açık/koyu/sistem.
///
/// WP-290 düzeni: en üstte **Kendi Temanı Oluştur**, altında kullanıcının
/// temaları (en yeni en üstte), ince ayraç (başlık metni yok), sonra hazır
/// temalar. Boş yuvalar liste olarak **gösterilmez** (sahip kararı).
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  /// En yeni en üstte; `updatedAt` yoksa en sona.
  static List<CustomTheme> visibleThemes(List<CustomTheme> themes) {
    final defined = themes.where((theme) => theme.isDefined).toList()
      ..sort((a, b) {
        final at = a.updatedAt;
        final bt = b.updatedAt;
        if (at == null && bt == null) return a.id.compareTo(b.id);
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    return defined;
  }

  Future<void> _openBuilder(
    BuildContext context,
    WidgetRef ref, {
    CustomTheme? initial,
  }) async {
    final settings = ref.read(themeSettingsProvider);
    final full = settings.customThemes.every((theme) => theme.isDefined);
    if (initial == null && full) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).profileTemaSlotlariDolu),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ThemeBuilderScreen(initial: initial)),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CustomTheme theme,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.profileTemayiSilOnay(theme.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileIptal),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileSil),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(themeSettingsProvider.notifier)
        .deleteCustomTheme(theme.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == ThemeSaveResult.saved
              ? l10n.profileTemaSilindi
              : l10n.profileTemaKaydedilemedi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(themeSettingsProvider);
    final notifier = ref.read(themeSettingsProvider.notifier);
    final desktop = isDesktopWindow;
    final myThemes = visibleThemes(settings.customThemes);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileGorunumVeAtmosfer)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 🔴 WP-679 — sutun sayisi PENCEREDEN hesaplaniyordu ama izgara
          // 880 px'lik bir kutuya cizilıyordu: 1920 px pencerede
          // `desktopGridColumns(1920)` = 4 donuyor ve dort kart 880 px'e
          // sikisiyordu (kart basina ~207 px, en-boy 2.15 → 96 px yukseklik).
          // Karar artik KABIN genisliginden verilir; 880 sihirli sayisi da
          // SPEC §2.3'un form sutunu tavanina (760) indi.
          final band = isDesktopWindow
              ? (constraints.maxWidth < DesktopBreakpoints.maxFormWidth
                    ? constraints.maxWidth
                    : DesktopBreakpoints.maxFormWidth)
              : constraints.maxWidth;
          final cols = desktopGridColumns(
            band,
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
              ProfileDesktopBody.form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.auto_awesome_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(l10n.profileKendiTemaniOlustur),
                        subtitle: Text(l10n.profileKendiTemaniOlusturAlt),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openBuilder(context, ref),
                      ),
                    ),
                    for (final custom in myThemes)
                      _CustomThemeTile(
                        theme: custom,
                        selected: settings.activeCustomThemeId == custom.id,
                        onTap: () => notifier.setActiveCustomTheme(custom.id),
                        onEdit: () =>
                            _openBuilder(context, ref, initial: custom),
                        onDelete: () => _delete(context, ref, custom),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    Text(
                      l10n.profileTemaModu,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
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
                              icon: const Icon(Icons.dark_mode_outlined),
                              label: Text(l10n.profileKoyu),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: const Icon(Icons.light_mode_outlined),
                              label: Text(l10n.profileAcik),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: const Icon(Icons.brightness_auto_outlined),
                              label: Text(l10n.profileSistem),
                            ),
                          ],
                          selected: {settings.mode},
                          onSelectionChanged: (s) => notifier.setMode(s.first),
                          showSelectedIcon: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.profileHazirTemalar,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: desktop ? 2.15 : 1.75,
                      ),
                      itemCount: kThemePresets.length,
                      itemBuilder: (context, i) {
                        final preset = kThemePresets[i];
                        return _PresetCard(
                          preset: preset,
                          selected:
                              settings.activeCustomThemeId == null &&
                              !settings.usePaletteColors &&
                              preset.id == settings.familyId,
                          onTap: () async {
                            // Özel tema aktifken hazır tema seçimi ölü kalır —
                            // `main.dart` sırası: özel tema > palet > aile.
                            await notifier.setActiveCustomTheme(null);
                            notifier.setFamily(preset.id);
                          },
                        );
                      },
                    ),
                    // WP-302: "Hazır Paletler" bölümü kaldırıldı. Palet yalnız
                    // iki rengi (primary/accent) değiştiren eski modeldi;
                    // hazır temalar ise tipografi, biçim, atmosfer ve hisle
                    // birlikte tam bir görünüm veriyor — yani paletin yaptığı
                    // her şeyi zaten kapsıyor. İki liste yan yana durunca
                    // hangisinin ne yaptığı anlaşılmıyordu (sahip raporu).
                    // Palet motoru kodda kalır: eski kurulumların görünümü
                    // `_migrateLegacyPaletteToFamily` ile en yakın hazır
                    // temaya taşınana kadar bozulmasın.
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

class _CustomThemeTile extends StatelessWidget {
  const _CustomThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomTheme theme;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: _ThemeSwatch(colors: theme.darkColors),
        title: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: theme.isReadOnly ? Text(l10n.profileTemaSaltOkunur) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Icon(Icons.check_circle, color: scheme.primary, size: 20),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.profileDuzenle,
              onPressed: theme.isReadOnly ? null : onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.profileSil,
              onPressed: theme.isReadOnly ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Expanded(child: ColoredBox(color: colors.scaffold)),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: ColoredBox(color: colors.primary)),
                  Expanded(child: ColoredBox(color: colors.accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
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
              ? preset.colors.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? preset.colors.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PresetPalettePreview(preset: preset),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.localizedName(AppLocalizations.of(context)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hazır tema kapağı, çalışma anındaki semantik renkleri küçük ölçekte gösterir.
///
/// Büyük alanlar uygulamanın gerçek scaffold ve yüzey hiyerarşisidir; primary ve
/// accent yalnız kontrol/vurgu olarak kalır. Böylece kapak tema kimliğini iki
/// küçük renk noktasına indirgemez.
class _PresetPalettePreview extends StatelessWidget {
  const _PresetPalettePreview({required this.preset});

  final ThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final colors = preset.colors;
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(
        key: ValueKey('theme-preset-preview-${preset.id}'),
        height: 38,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  key: ValueKey('theme-preset-scaffold-${preset.id}'),
                  color: colors.scaffold,
                ),
              ),
              Positioned.fill(
                left: 4,
                top: 4,
                right: 4,
                bottom: 4,
                child: ColoredBox(
                  key: ValueKey('theme-preset-surface-${preset.id}'),
                  color: colors.surface1,
                ),
              ),
              Positioned(
                right: 7,
                bottom: 7,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PreviewAccent(
                      key: ValueKey('theme-preset-primary-${preset.id}'),
                      color: colors.primary,
                    ),
                    const SizedBox(width: 3),
                    _PreviewAccent(
                      key: ValueKey('theme-preset-accent-${preset.id}'),
                      color: colors.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewAccent extends StatelessWidget {
  const _PreviewAccent({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 12, height: 6, child: ColoredBox(color: color));
}
