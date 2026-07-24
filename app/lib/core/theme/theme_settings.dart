import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/app_prefs.dart';
import 'app_theme.dart';
import 'custom_theme.dart';

/// Tema rengi nereden uygulanıyor?
/// - [family]: Tema Stüdyosu atmosfer ailesi (tam UI havası)
/// - [palette]: Görünüm > Hazır/Özel palet (renk; aileye zorlanmaz)
enum ThemeColorSource { family, palette }

enum ThemeSaveResult { saved, failed, rejected }

/// Tema tercihleri: sanat ailesi (preset) + eski palet + açık/koyu/sistem.
class ThemeSettings {
  const ThemeSettings({
    required this.familyId,
    required this.paletteId,
    required this.mode,
    this.colorSource = ThemeColorSource.family,
    this.customPalettes = const [],
    this.customThemes = const [],
    this.activeCustomThemeId,
  });

  /// WP-54: ThemePreset id (campfire_night, deep_amoled, …).
  final String familyId;
  final String paletteId;
  final ThemeMode mode;

  /// WP-71: lacivert palet seçince kamp ateşi turuncuya düşmesin.
  final ThemeColorSource colorSource;
  final List<AppPalette> customPalettes;
  final List<CustomTheme> customThemes;
  final String? activeCustomThemeId;

  CustomTheme? get activeCustomTheme {
    for (final theme in customThemes) {
      if (theme.id == activeCustomThemeId && theme.isDefined) return theme;
    }
    return null;
  }

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
    List<CustomTheme>? customThemes,
    String? activeCustomThemeId,
    bool clearActiveCustomTheme = false,
  }) => ThemeSettings(
    familyId: familyId ?? this.familyId,
    paletteId: paletteId ?? this.paletteId,
    mode: mode ?? this.mode,
    colorSource: colorSource ?? this.colorSource,
    customPalettes: customPalettes ?? this.customPalettes,
    customThemes: customThemes ?? this.customThemes,
    activeCustomThemeId: clearActiveCustomTheme
        ? null
        : activeCustomThemeId ?? this.activeCustomThemeId,
  );
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _kFamily = 'theme_family';
  static const _kPalette = 'theme_palette';
  static const _kMode = 'theme_mode';
  static const _kColorSource = 'theme_color_source';
  static const _kCustomPalettes = 'custom_palettes';
  static const _kCustomThemes = 'custom_themes_v2';
  static const _kActiveCustomTheme = 'active_custom_theme_id';
  static const _kCustomThemesMigrated = 'custom_themes_migrated_v1';

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
    final legacyPalettes = List<AppPalette>.from(customPalettes);
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

    var customThemes = _readCustomThemes(prefs);
    if (prefs.getBool(_kCustomThemesMigrated) != true) {
      customThemes = _migrateLegacyPalettes(legacyPalettes);
      unawaited(_persistMigration(prefs, customThemes));
    }
    while (customThemes.length < 3) {
      customThemes.add(_emptyCustomTheme(customThemes.length + 1));
    }
    final activeCustomThemeId =
        prefs.getString(_kActiveCustomTheme) ??
        (paletteId.startsWith('custom_') &&
                customThemes.any(
                  (theme) => theme.id == paletteId && theme.isDefined,
                )
            ? paletteId
            : null);
    return ThemeSettings(
      familyId: familyId,
      paletteId: paletteId,
      mode: mode,
      colorSource: colorSource,
      customPalettes: customPalettes,
      customThemes: customThemes,
      activeCustomThemeId: activeCustomThemeId,
    );
  }

  List<CustomTheme> _readCustomThemes(SharedPreferences prefs) {
    final stored = prefs.getStringList(_kCustomThemes);
    if (stored == null) return [];
    return stored
        .map((json) {
          try {
            return CustomTheme.tryParse(
              Map<String, dynamic>.from(jsonDecode(json)),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<CustomTheme>()
        .toList();
  }

  List<CustomTheme> _migrateLegacyPalettes(List<AppPalette> palettes) {
    final themes = <CustomTheme>[];
    for (var index = 0; index < 3; index++) {
      if (index >= palettes.length) {
        themes.add(_emptyCustomTheme(index + 1));
        continue;
      }
      final palette = palettes[index];
      final light = AppTheme.light(palette);
      final dark = AppTheme.dark(palette);
      themes.add(
        CustomTheme(
          id: 'custom_${index + 1}',
          name: palette.name,
          isDefined: true,
          updatedAt: DateTime.now(),
          lightColors: light.extension<AppColors>()!,
          darkColors: dark.extension<AppColors>()!,
          typography: light.extension<AppTypography>()!,
          shapes: light.extension<AppShapes>()!,
          atmosphere: light.extension<AppAtmosphere>()!,
          feel: light.extension<AppFeel>()!,
        ),
      );
    }
    return themes;
  }

  CustomTheme _emptyCustomTheme(int slot) {
    final base = AppTheme.light(kAppPalettes.first);
    return CustomTheme(
      id: 'custom_$slot',
      name: 'Özel Tema $slot',
      isDefined: false,
      updatedAt: null,
      lightColors: base.extension<AppColors>()!,
      darkColors: AppTheme.dark(kAppPalettes.first).extension<AppColors>()!,
      typography: base.extension<AppTypography>()!,
      shapes: base.extension<AppShapes>()!,
      atmosphere: base.extension<AppAtmosphere>()!,
      feel: base.extension<AppFeel>()!,
    );
  }

  Future<void> _persistMigration(
    SharedPreferences prefs,
    List<CustomTheme> themes,
  ) async {
    final encoded = themes.map((theme) => jsonEncode(theme.toMap())).toList();
    if (await prefs.setStringList(_kCustomThemes, encoded)) {
      await prefs.setBool(_kCustomThemesMigrated, true);
    }
  }

  Future<ThemeSaveResult> saveCustomTheme(CustomTheme theme) async {
    final index = int.tryParse(theme.id.split('_').last);
    if (index == null || index < 1 || index > 3 || theme.isReadOnly) {
      return ThemeSaveResult.rejected;
    }
    final next = List<CustomTheme>.from(state.customThemes);
    while (next.length < 3) {
      next.add(_emptyCustomTheme(next.length + 1));
    }
    next[index - 1] = theme.copyWith(
      isDefined: true,
      updatedAt: DateTime.now(),
    );
    final prefs = ref.read(sharedPreferencesProvider);
    if (!await prefs.setStringList(
      _kCustomThemes,
      next.map((t) => jsonEncode(t.toMap())).toList(),
    )) {
      return ThemeSaveResult.failed;
    }
    state = state.copyWith(customThemes: next);
    return ThemeSaveResult.saved;
  }

  Future<ThemeSaveResult> deleteCustomTheme(String id) async {
    final index = int.tryParse(id.split('_').last);
    if (index == null || index < 1 || index > 3) {
      return ThemeSaveResult.rejected;
    }
    final next = List<CustomTheme>.from(state.customThemes);
    while (next.length < 3) {
      next.add(_emptyCustomTheme(next.length + 1));
    }
    if (next[index - 1].isReadOnly) return ThemeSaveResult.rejected;
    next[index - 1] = _emptyCustomTheme(index);
    final prefs = ref.read(sharedPreferencesProvider);
    if (!await prefs.setStringList(
      _kCustomThemes,
      next.map((t) => jsonEncode(t.toMap())).toList(),
    )) {
      return ThemeSaveResult.failed;
    }
    final active = state.activeCustomThemeId == id
        ? null
        : state.activeCustomThemeId;
    if (active == null) {
      await prefs.remove(_kActiveCustomTheme);
    }
    state = state.copyWith(
      customThemes: next,
      activeCustomThemeId: active,
      clearActiveCustomTheme: active == null,
    );
    return ThemeSaveResult.saved;
  }

  Future<ThemeSaveResult> setActiveCustomTheme(String? id) async {
    if (id != null &&
        !state.customThemes.any((t) => t.id == id && t.isDefined)) {
      return ThemeSaveResult.rejected;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    final ok = id == null
        ? await prefs.remove(_kActiveCustomTheme)
        : await prefs.setString(_kActiveCustomTheme, id);
    if (!ok) {
      return ThemeSaveResult.failed;
    }
    state = state.copyWith(
      activeCustomThemeId: id,
      clearActiveCustomTheme: id == null,
    );
    return ThemeSaveResult.saved;
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
