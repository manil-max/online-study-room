import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';
import 'app_theme.dart';

/// Tema tercihleri: sanat ailesi (12 preset) + eski palet + açık/koyu/sistem.
class ThemeSettings {
  const ThemeSettings({
    required this.familyId,
    required this.paletteId,
    required this.mode,
    this.customPalettes = const [],
  });

  /// WP-54: ThemePreset id (campfire_night, deep_amoled, …).
  final String familyId;
  final String paletteId;
  final ThemeMode mode;
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

  ThemeSettings copyWith({
    String? familyId,
    String? paletteId,
    ThemeMode? mode,
    List<AppPalette>? customPalettes,
  }) =>
      ThemeSettings(
        familyId: familyId ?? this.familyId,
        paletteId: paletteId ?? this.paletteId,
        mode: mode ?? this.mode,
        customPalettes: customPalettes ?? this.customPalettes,
      );
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _kFamily = 'theme_family';
  static const _kPalette = 'theme_palette';
  static const _kMode = 'theme_mode';
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
          name: 'Özel $idx',
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
    state = state.copyWith(familyId: id);
    ref.read(sharedPreferencesProvider).setString(_kFamily, id);
  }

  void setPalette(String id) {
    // Eski palet seçimi → family'yi de hizala
    final family = migratePaletteIdToPreset(id);
    state = state.copyWith(paletteId: id, familyId: family);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kPalette, id);
    prefs.setString(_kFamily, family);
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
