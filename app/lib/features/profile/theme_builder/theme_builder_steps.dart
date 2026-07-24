import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import 'theme_contrast.dart';
import 'theme_draft.dart';
import 'theme_feel_catalog.dart';
import 'theme_builder_widgets.dart';

/// Sihirbaz adımlarının içerikleri. Her adım yalnız taslağı dönüştürür;
/// kalıcı yazma yalnız son adımda (`theme_builder_screen.dart`) yapılır.

typedef DraftChanged = ValueChanged<ThemeDraft>;

/// 1) Zemin — hazır aileden başla.
class BaseStep extends StatelessWidget {
  const BaseStep({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.columns,
  });

  final ThemeDraft draft;
  final DraftChanged onChanged;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileZeminAciklama, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kThemePresets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.2,
          ),
          itemBuilder: (context, index) {
            final preset = kThemePresets[index];
            return _BaseTile(
              preset: preset,
              onTap: () => onChanged(
                ThemeDraft.fromPreset(
                  slotId: draft.slotId,
                  name: draft.name,
                  preset: preset,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BaseTile extends StatelessWidget {
  const _BaseTile({required this.preset, required this.onTap});

  final ThemePreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              _PresetSwatch(colors: preset.colors),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  preset.localizedName(l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  const _PresetSwatch({required this.colors});

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

/// 2) Renkler — düzenlenen varyantın tam renk seti + AA koruması.
class ColorsStep extends StatelessWidget {
  const ColorsStep({
    super.key,
    required this.draft,
    required this.onChanged,
    this.brightness,
    this.counterpartMode = false,
  });

  final ThemeDraft draft;
  final DraftChanged onChanged;

  /// null → `draft.editing`.
  final Brightness? brightness;

  /// true → düzenlemeler karşı varyanta yazılır (6b adımı).
  final bool counterpartMode;

  Brightness get _target => brightness ?? draft.editing;

  void _apply(AppColors colors) {
    onChanged(
      counterpartMode
          ? draft.withCounterpartColors(colors)
          : draft.withEditedColors(colors),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = draft.colorsFor(_target);

    String? warn(Color fg, Color bg, {bool large = false}) {
      if (meetsContrastAa(fg, bg, large: large)) return null;
      return l10n.profileKontrastUyarisi(
        contrastRatio(fg, bg).toStringAsFixed(1),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!counterpartMode) ...[
          Text(l10n.profileDuzenlenenVaryant, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          SegmentedButton<Brightness>(
            segments: [
              ButtonSegment(
                value: Brightness.dark,
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(l10n.profileKoyu),
              ),
              ButtonSegment(
                value: Brightness.light,
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(l10n.profileAcik),
              ),
            ],
            selected: {_target},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                onChanged(draft.copyWith(editing: value.first)),
          ),
          const SizedBox(height: 12),
        ],
        ColorField(
          label: l10n.profileAnaRenk,
          color: colors.primary,
          warning: warn(colors.primary, colors.surface1, large: true),
          onFixWarning: () => _apply(
            colors.copyWith(
              primary: fixForegroundForAa(
                colors.primary,
                colors.surface1,
                large: true,
              ),
              onPrimary: readableOn(
                fixForegroundForAa(
                  colors.primary,
                  colors.surface1,
                  large: true,
                ),
              ),
            ),
          ),
          onChanged: (value) => _apply(
            colors.copyWith(primary: value, onPrimary: readableOn(value)),
          ),
        ),
        ColorField(
          label: l10n.profileVurguRengi,
          color: colors.accent,
          warning: warn(colors.accent, colors.surface1, large: true),
          onFixWarning: () => _apply(
            colors.copyWith(
              accent: fixForegroundForAa(
                colors.accent,
                colors.surface1,
                large: true,
              ),
              onAccent: readableOn(
                fixForegroundForAa(colors.accent, colors.surface1, large: true),
              ),
            ),
          ),
          onChanged: (value) => _apply(
            colors.copyWith(accent: value, onAccent: readableOn(value)),
          ),
        ),
        ColorField(
          label: l10n.profileRenkZemin,
          color: colors.scaffold,
          onChanged: (value) => _apply(colors.copyWith(scaffold: value)),
        ),
        ColorField(
          label: l10n.profileRenkYuzey,
          color: colors.surface1,
          onChanged: (value) => _apply(colors.copyWith(surface1: value)),
        ),
        ColorField(
          label: l10n.profileRenkYuzeyYuksek,
          color: colors.surface2,
          onChanged: (value) => _apply(colors.copyWith(surface2: value)),
        ),
        ColorField(
          label: l10n.profileRenkMetin,
          color: colors.textPrimary,
          warning: warn(colors.textPrimary, colors.surface1),
          onFixWarning: () => _apply(
            colors.copyWith(
              textPrimary: fixForegroundForAa(
                colors.textPrimary,
                colors.surface1,
              ),
            ),
          ),
          onChanged: (value) => _apply(colors.copyWith(textPrimary: value)),
        ),
        ColorField(
          label: l10n.profileRenkIkincilMetin,
          color: colors.textSecondary,
          warning: warn(colors.textSecondary, colors.surface1),
          onFixWarning: () => _apply(
            colors.copyWith(
              textSecondary: fixForegroundForAa(
                colors.textSecondary,
                colors.surface1,
              ),
            ),
          ),
          onChanged: (value) => _apply(colors.copyWith(textSecondary: value)),
        ),
        ColorField(
          label: l10n.profileRenkKenarlik,
          color: colors.border,
          onChanged: (value) => _apply(colors.copyWith(border: value)),
        ),
      ],
    );
  }
}

/// 3) Yazılar.
class TypographyStep extends StatelessWidget {
  const TypographyStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final ThemeDraft draft;
  final DraftChanged onChanged;

  static String _familyLabel(AppLocalizations l10n, String family) =>
      switch (family) {
        kFontFamilySerif => l10n.profileFontTirnakli,
        kFontFamilyMono => l10n.profileFontEsAralikli,
        _ => l10n.profileFontDuz,
      };

  Widget _familyPicker(
    BuildContext context,
    String label,
    String value,
    ValueChanged<String> onPick,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final family in DraftTypography.kFamilies)
                ChoiceChip(
                  label: Text(
                    _familyLabel(l10n, family),
                    style: TextStyle(fontFamily: family),
                  ),
                  selected: value == family,
                  onSelected: (_) => onPick(family),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typography = draft.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _familyPicker(
          context,
          l10n.profileYaziBaslikFontu,
          typography.titleFamily,
          (value) => onChanged(
            draft.copyWith(typography: typography.copyWith(titleFamily: value)),
          ),
        ),
        _familyPicker(
          context,
          l10n.profileYaziGovdeFontu,
          typography.bodyFamily,
          (value) => onChanged(
            draft.copyWith(typography: typography.copyWith(bodyFamily: value)),
          ),
        ),
        _familyPicker(
          context,
          l10n.profileYaziSayacFontu,
          typography.clockFamily,
          (value) => onChanged(
            draft.copyWith(typography: typography.copyWith(clockFamily: value)),
          ),
        ),
        SliderRow(
          label: l10n.profileYaziKalinlik,
          value: typography.weightStep.toDouble(),
          min: -1,
          max: 2,
          divisions: 3,
          valueLabel: '${typography.weightStep + 2}/4',
          onChanged: (value) => onChanged(
            draft.copyWith(
              typography: typography.copyWith(weightStep: value.round()),
            ),
          ),
        ),
        SliderRow(
          label: l10n.profileYaziOlcek,
          value: typography.scale,
          min: kMinTypographyScale,
          max: kMaxTypographyScale,
          divisions: 9,
          valueLabel: '×${typography.scale.toStringAsFixed(2)}',
          onChanged: (value) => onChanged(
            draft.copyWith(typography: typography.copyWith(scale: value)),
          ),
        ),
        SliderRow(
          label: l10n.profileYaziHarfAraligi,
          value: typography.letterSpacing,
          min: -0.5,
          max: 1.5,
          divisions: 8,
          onChanged: (value) => onChanged(
            draft.copyWith(
              typography: typography.copyWith(letterSpacing: value),
            ),
          ),
        ),
      ],
    );
  }
}

/// 4) Biçim.
class ShapeStep extends StatelessWidget {
  const ShapeStep({super.key, required this.draft, required this.onChanged});

  final ThemeDraft draft;
  final DraftChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shapes = draft.shapes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderRow(
          label: l10n.profileBicimKucukYaricap,
          value: shapes.radiusSm,
          min: 0,
          max: 24,
          divisions: 24,
          valueLabel: shapes.radiusSm.toStringAsFixed(0),
          onChanged: (value) =>
              onChanged(draft.copyWith(shapes: shapes.copyWith(radiusSm: value))),
        ),
        SliderRow(
          label: l10n.profileBicimKoseYaricapi,
          value: shapes.radiusMd,
          min: 0,
          max: 40,
          divisions: 40,
          valueLabel: shapes.radiusMd.toStringAsFixed(0),
          onChanged: (value) =>
              onChanged(draft.copyWith(shapes: shapes.copyWith(radiusMd: value))),
        ),
        SliderRow(
          label: l10n.profileBicimBuyukYaricap,
          value: shapes.radiusLg,
          min: 0,
          max: 56,
          divisions: 56,
          valueLabel: shapes.radiusLg.toStringAsFixed(0),
          onChanged: (value) =>
              onChanged(draft.copyWith(shapes: shapes.copyWith(radiusLg: value))),
        ),
        SliderRow(
          label: l10n.profileBicimGolge,
          value: shapes.cardElevation,
          min: 0,
          max: 8,
          divisions: 8,
          valueLabel: shapes.cardElevation.toStringAsFixed(0),
          onChanged: (value) => onChanged(
            draft.copyWith(shapes: shapes.copyWith(cardElevation: value)),
          ),
        ),
        SliderRow(
          label: l10n.profileBicimKenarKalinligi,
          value: shapes.borderWidth,
          min: 0,
          max: 3,
          divisions: 6,
          onChanged: (value) => onChanged(
            draft.copyWith(shapes: shapes.copyWith(borderWidth: value)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.profileBicimKeskin),
          value: shapes.sharp,
          onChanged: (value) =>
              onChanged(draft.copyWith(shapes: shapes.copyWith(sharp: value))),
        ),
      ],
    );
  }
}

/// 5) Atmosfer.
class AtmosphereStep extends StatelessWidget {
  const AtmosphereStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final ThemeDraft draft;
  final DraftChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final atmosphere = draft.atmosphere;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profileAtmosferAciklama,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ColorField(
          label: l10n.profileAtmosferDegradeBasi,
          color: atmosphere.gradientStart,
          onChanged: (value) => onChanged(
            draft.copyWith(atmosphere: atmosphere.copyWith(gradientStart: value)),
          ),
        ),
        ColorField(
          label: l10n.profileAtmosferDegradeSonu,
          color: atmosphere.gradientEnd,
          onChanged: (value) => onChanged(
            draft.copyWith(atmosphere: atmosphere.copyWith(gradientEnd: value)),
          ),
        ),
        ColorField(
          label: l10n.profileAtmosferParilti,
          color: atmosphere.glowColor,
          onChanged: (value) => onChanged(
            draft.copyWith(atmosphere: atmosphere.copyWith(glowColor: value)),
          ),
        ),
        SliderRow(
          label: l10n.profileAtmosferPariltiGucu,
          value: atmosphere.glowStrength,
          min: 0,
          max: 1,
          divisions: 10,
          valueLabel: '%${(atmosphere.glowStrength * 100).round()}',
          onChanged: (value) => onChanged(
            draft.copyWith(atmosphere: atmosphere.copyWith(glowStrength: value)),
          ),
        ),
        SliderRow(
          label: l10n.profileAtmosferPariltiYumusakligi,
          value: atmosphere.blurSigma,
          min: 0,
          max: 24,
          divisions: 12,
          valueLabel: atmosphere.blurSigma.toStringAsFixed(0),
          onChanged: (value) => onChanged(
            draft.copyWith(atmosphere: atmosphere.copyWith(blurSigma: value)),
          ),
        ),
        SliderRow(
          label: l10n.profileAtmosferCamlik,
          value: atmosphere.glassOpacity,
          min: 0,
          max: 1,
          divisions: 10,
          valueLabel: '%${(atmosphere.glassOpacity * 100).round()}',
          onChanged: (value) => onChanged(
            draft.copyWith(atmosphere: atmosphere.copyWith(glassOpacity: value)),
          ),
        ),
      ],
    );
  }
}

/// 6) His.
class FeelStep extends StatelessWidget {
  const FeelStep({super.key, required this.draft, required this.onChanged});

  final ThemeDraft draft;
  final DraftChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileHisAciklama, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final option in kFeelOptions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: draft.feel.feelId == option.id,
            leading: Icon(
              draft.feel.feelId == option.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(option.localizedName(l10n)),
            subtitle: Text(option.localizedCost(l10n)),
            onTap: () => onChanged(draft.withFeel(option.feel)),
          ),
      ],
    );
  }
}

/// 6b) Karşı mod — türetilen varyant düzenlenebilir gösterilir.
class CounterpartStep extends StatelessWidget {
  const CounterpartStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final ThemeDraft draft;
  final DraftChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                draft.counterpart == Brightness.dark
                    ? l10n.profileKarsiModKoyuAciklama
                    : l10n.profileKarsiModAcikAciklama,
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => onChanged(draft.withRederivedCounterpart()),
              child: Text(l10n.profileKarsiModYenidenTuret),
            ),
          ],
        ),
        if (!draft.counterpartEdited)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.profileKarsiModTuretildi,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ColorsStep(
          draft: draft,
          onChanged: onChanged,
          brightness: draft.counterpart,
          counterpartMode: true,
        ),
      ],
    );
  }
}

/// 7) Özet — ad ver, yuva seç, kaydet.
class SummaryStep extends StatelessWidget {
  const SummaryStep({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.nameController,
    required this.slots,
    required this.onSave,
    required this.canSave,
  });

  final ThemeDraft draft;
  final DraftChanged onChanged;
  final TextEditingController nameController;

  /// slotId → dolu mu (dolu yuvaya kaydetmek üzerine yazar).
  final Map<String, bool> slots;
  final VoidCallback onSave;
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameController,
          maxLength: kThemeNameMaxLength,
          decoration: InputDecoration(
            labelText: l10n.profileOzetTemaAdi,
            errorText: nameController.text.trim().isEmpty
                ? l10n.profileTemaAdiBos
                : null,
          ),
          onChanged: (value) => onChanged(draft.copyWith(name: value)),
        ),
        const SizedBox(height: 8),
        Text(l10n.profileOzetYuva, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in slots.entries)
              ChoiceChip(
                label: Text(
                  entry.value
                      ? l10n.profileYuvaDolu(entry.key.split('_').last)
                      : l10n.profileYuvaBos(entry.key.split('_').last),
                ),
                selected: draft.slotId == entry.key,
                onSelected: (_) => onChanged(draft.copyWith(slotId: entry.key)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: canSave ? onSave : null,
          icon: const Icon(Icons.check),
          label: Text(l10n.profileKaydetVeUygula),
        ),
      ],
    );
  }
}
