import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';
import 'app_theme.dart';

/// Tema tercihleri: seçili palet + açık/koyu/sistem modu. Cihazda kalıcı.
class ThemeSettings {
  const ThemeSettings({required this.paletteId, required this.mode});

  final String paletteId;
  final ThemeMode mode;

  AppPalette get palette => paletteById(paletteId);

  ThemeSettings copyWith({String? paletteId, ThemeMode? mode}) => ThemeSettings(
        paletteId: paletteId ?? this.paletteId,
        mode: mode ?? this.mode,
      );
}

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  static const _kPalette = 'theme_palette';
  static const _kMode = 'theme_mode';

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final paletteId = prefs.getString(_kPalette) ?? kAppPalettes.first.id;
    final mode = switch (prefs.getString(_kMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark, // varsayılan koyu (kardeşin tasarımı)
    };
    return ThemeSettings(paletteId: paletteId, mode: mode);
  }

  void setPalette(String id) {
    state = state.copyWith(paletteId: id);
    ref.read(sharedPreferencesProvider).setString(_kPalette, id);
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    ref.read(sharedPreferencesProvider).setString(_kMode, mode.name);
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
        ThemeSettingsNotifier.new);
