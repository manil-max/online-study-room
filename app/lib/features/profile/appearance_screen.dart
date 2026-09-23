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
import 'appearance_preset_preview.dart';
import 'theme_builder/theme_builder_screen.dart';

/// Görünüm: kendi temaların (3 yuva) + hazır temalar + açık/koyu/sistem.
///
/// WP-290 düzeni: en üstte **Kendi Temanı Oluştur**, altında kullanıcının
/// temaları (en yeni en üstte), ince ayraç (başlık metni yok), sonra hazır
/// temalar. Boş yuvalar liste olarak **gösterilmez** (sahip kararı).

/// 🔴 WP-855: ekranda gösterilen hazır tema SIRASI.
///
/// WP-841 karşılama temasını (`kFirstRunFamilyId`, `campfire_day`) listenin
/// SONUNA eklemişti: yeni kullanıcı Görünüm'ü açınca kendi seçili temasını ilk
/// ekranda göremiyordu (mağaza karesinde ölçüldü, 16 temanın 16.'sı).
/// `kThemePresets`in kendisi DEĞİŞMEZ — `themePresetById` bilinmeyen kimlikte
/// `kThemePresets.first`e düşer; o sırayı oynatmak eski kurulumların yedek
/// temasını sessizce değiştirirdi. Yalnız görünüm sırası değişir.
final List<ThemePreset> kAppearancePresetOrder = [
  for (final p in kThemePresets)
    if (p.id == kFirstRunFamilyId) p,
  for (final p in kThemePresets)
    if (p.id != kFirstRunFamilyId) p,
];

/// WP-921: bir bölümün temaları — [kAppearancePresetOrder] sırasıyla, yalnız
/// verilen parlaklıktakiler. İki bölüm birlikte her temayı tam bir kez içerir.
List<ThemePreset> appearancePresetsFor(Brightness brightness) => [
  for (final p in kAppearancePresetOrder)
    if (p.brightness == brightness) p,
];

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
                    // WP-921: mod ile hazır tema ilişkisi görünmüyordu — tema
                    // seçmek modu sessizce Koyu/Açık'a çeviriyordu
                    // (`ThemeSettingsNotifier.setFamily`), karşı modda ise
                    // tema `AppTheme.fromFamily` ile uyarlanıyordu. Tek satır
                    // bu davranışı söyler; davranışın kendisi değişmez.
                    const SizedBox(height: 8),
                    Text(
                      l10n.profileTemaModuAciklama,
                      key: const ValueKey('appearance-mode-help'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.profileHazirTemalar,
                      style: theme.textTheme.titleMedium,
                    ),
                    // WP-921: açık ve koyu temalar ayrı bölümlerde; her
                    // bölümde `kAppearancePresetOrder` sırası korunur (WP-855
                    // karşılama teması açık bölümün başında kalır).
                    for (final section in [
                      (
                        Brightness.light,
                        l10n.profileAcikTemalar,
                        Icons.light_mode_outlined,
                      ),
                      (
                        Brightness.dark,
                        l10n.profileKoyuTemalar,
                        Icons.dark_mode_outlined,
                      ),
                    ]) ...[
                      const SizedBox(height: 12),
                      _SectionLabel(
                        key: ValueKey('appearance-section-${section.$1.name}'),
                        icon: section.$3,
                        label: section.$2,
                      ),
                      const SizedBox(height: 8),
                      _PresetGrid(
                        key: ValueKey('appearance-grid-${section.$1.name}'),
                        presets: appearancePresetsFor(section.$1),
                        columns: cols,
                        isSelected: (preset) =>
                            settings.activeCustomThemeId == null &&
                            !settings.usePaletteColors &&
                            preset.id == settings.familyId,
                        onSelect: (preset) async {
                          // Özel tema aktifken hazır tema seçimi ölü kalır —
                          // `main.dart` sırası: özel tema > palet > aile.
                          await notifier.setActiveCustomTheme(null);
                          notifier.setFamily(preset.id);
                        },
                      ),
                    ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({
    super.key,
    required this.presets,
    required this.columns,
    required this.isSelected,
    required this.onSelect,
  });

  final List<ThemePreset> presets;
  final int columns;
  final bool Function(ThemePreset preset) isSelected;
  final void Function(ThemePreset preset) onSelect;

  /// Minyatürün sabit yüksekliği; yazı ölçeğinden bağımsızdır (resimdir).
  static const double previewHeight = 84;

  @override
  Widget build(BuildContext context) {
    // Kart yüksekliği = minyatür + ölçeklenmiş tek satır ad. En-boy oranı
    // yerine sabit uzunluk: dar telefonda kart ezilmez, geniş masaüstü
    // bandında boşuna uzamaz; 1.5 yazı ölçeğinde ad satırı taşmaz.
    final nameStyle = Theme.of(context).textTheme.bodyMedium;
    final nameLine =
        MediaQuery.textScalerOf(context).scale(nameStyle?.fontSize ?? 14) *
        (nameStyle?.height ?? 1.43);
    final extent = 8 + previewHeight + 6 + nameLine + 8 + 4 + 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: extent,
      ),
      itemCount: presets.length,
      itemBuilder: (context, i) {
        final preset = presets[i];
        return _PresetCard(
          key: ValueKey('appearance-preset-${preset.id}'),
          preset: preset,
          selected: isSelected(preset),
          onTap: () => onSelect(preset),
        );
      },
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    super.key,
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
    final name = preset.localizedName(AppLocalizations.of(context));
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: selected
                ? preset.colors.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? preset.colors.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _PresetGrid.previewHeight,
                child: AppearancePresetPreview(preset: preset),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
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
                      key: const ValueKey('appearance-preset-selected'),
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
