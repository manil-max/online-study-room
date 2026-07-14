import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';
import 'app_theme.dart';

/// Tema rengi nereden uygulanıyor?
/// - [family]: Tema Stüdyosu atmosfer ailesi (tam UI havası)
/// - [palette]: Görünüm > Hazır/Özel palet (renk; aileye zorlanmaz)
enum ThemeColorSource { family, palette }

/// Tema tercihleri: sanat ailesi (preset) + eski palet + açık/koyu/sistem.
class ThemeSettings {
  const ThemeSettings({
    required this.familyId,
    required this.paletteId,
    required this.mode,
    this.colorSource = ThemeColorSource.family,
    this.customPalettes = const [],
  });

  /// WP-54: ThemePreset id (campfire_night, deep_amoled, …).
  final String familyId;
  final String paletteId;
  final ThemeMode mode;

  /// WP-71: lacivert palet seçince kamp ateşi turuncuya düşmesin.
  final ThemeColorSource colorSource;
  final List<AppPalette> customPalettes;

  ThemePreset get family => themePresetById(familyId);

  AppPalette get palette {
    if (paletteId.startsWith('custom_')) {
      final index = int.tryParse(paletteId.split('_').last) ?? 1;
      if (index >= 1 && index <= customPalettes.length) {
        return customPalettes[index - 1];
      }
    }
    return paletteById(paletteId);
  }

  /// true → AppTheme.light/dark(palette); false → fromFamily.
  bool get usePaletteColors =>
      colorSource == ThemeColorSource.palette ||
      paletteId.startsWith('custom_');

  ThemeSettings copyWith({
    String? familyId,
    String? paletteId,
    ThemeMode? mode,
    ThemeColorSource? colorSource,
    List<AppPalette>? customPalettes,
  }) => ThemeSettings(
    familyId: familyId ?? this.familyId,
    paletteId: paletteId ?? this.paletteId,
    mode: mode ?? this.mode,
    colorSource: colorSource ?? this.colorSource,
    customPalettes: customPalettes ?? this.customPalettes,
  );
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _kFamily = 'theme_family';
  static const _kPalette = 'theme_palette';
  static const _kMode = 'theme_mode';
  static const _kColorSource = 'theme_color_source';
  static const _kCustomPalettes = 'custom_palettes';

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final paletteId = prefs.getString(_kPalette) ?? kAppPalettes.first.id;
    final storedFamily = prefs.getString(_kFamily);
    final familyId = storedFamily ?? migratePaletteIdToPreset(paletteId);

    final mode = switch (prefs.getString(_kMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

    final storedSource = prefs.getString(_kColorSource);
    final colorSource = switch (storedSource) {
      'palette' => ThemeColorSource.palette,
      'family' => ThemeColorSource.family,
      // Eski kurulum: family yoksa veya yalnızca palet kaydı varsa palet renkleri.
      _ =>
        storedFamily == null
            ? ThemeColorSource.palette
            : ThemeColorSource.family,
    };

    List<AppPalette> customPalettes = [];
    final customList = prefs.getStringList(_kCustomPalettes);
    if (customList != null) {
      for (final item in customList) {
        try {
          customPalettes.add(AppPalette.fromMap(jsonDecode(item)));
        } catch (_) {}
      }
    }
    while (customPalettes.length < 3) {
      final idx = customPalettes.length + 1;
      customPalettes.add(
        AppPalette(
          id: 'custom_$idx',
          name: 'Custom $idx',
          primary: const Color(0xFF8B5CF6),
          onPrimary: const Color(0xFFFFFFFF),
          accent: const Color(0xFF12C281),
          onAccent: const Color(0xFFFFFFFF),
        ),
      );
    }

    return ThemeSettings(
      familyId: familyId,
      paletteId: paletteId,
      mode: mode,
      colorSource: colorSource,
      customPalettes: customPalettes,
    );
  }

  void saveCustomPalette(int index, AppPalette palette) {
    if (index < 0 || index >= state.customPalettes.length) return;

    final updatedList = List<AppPalette>.from(state.customPalettes);
    updatedList[index] = AppPalette(
      id: 'custom_${index + 1}',
      name: palette.name,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      accent: palette.accent,
      onAccent: palette.onAccent,
    );

    state = state.copyWith(customPalettes: updatedList);

    final prefs = ref.read(sharedPreferencesProvider);
    final jsonList = updatedList.map((p) => jsonEncode(p.toMap())).toList();
    prefs.setStringList(_kCustomPalettes, jsonList);
  }

  void setFamily(String id) {
    // Aile seçilince mood'u ailenin parlaklığına hizala — seçim hemen görünsün.
    final preset = themePresetById(id);
    final mode = preset.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    state = state.copyWith(
      familyId: id,
      mode: mode,
      colorSource: ThemeColorSource.family,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kFamily, id);
    prefs.setString(_kMode, mode.name);
    prefs.setString(_kColorSource, 'family');
  }

  void setPalette(String id) {
    // Hazır/özel palet: renk kaynağı palet. Aileyi turuncu kamp ateşine ZORLAMA
    // (eski migratePaletteIdToPreset('navy')→campfire_night bug'ı).
    state = state.copyWith(
      paletteId: id,
      colorSource: ThemeColorSource.palette,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kPalette, id);
    prefs.setString(_kColorSource, 'palette');
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    ref.read(sharedPreferencesProvider).setString(_kMode, mode.name);
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
      ThemeSettingsNotifier.new,
    );
