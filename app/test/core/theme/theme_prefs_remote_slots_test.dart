// WP-861 — SUNUCU KAYDINDA BOZUK BİR ÖZEL TEMA ÖTEKİLERİN YUVASINI KAYDIRMAZ.
//
// Avcı bulgusu (WP-838 uzlaşması): `_settingsFromRemote` okunamayan özel
// temayı atıp kalanları SIRAYLA listeye diziyor, eksik yeri sona
// `_emptyCustomTheme(n)` ile dolduruyordu. `saveCustomTheme`/`deleteCustomTheme`
// ise yuvayı kimliğin son rakamıyla **liste konumundan** buluyor. Böylece
// custom_1 bozuk gelince liste [custom_2, custom_3, custom_3(boş)] oluyor;
// kullanıcı custom_2'yi kaydettiğinde custom_3 temasının üstüne yazılıyordu.
//
// Sözleşme: sunucudan gelen özel temalar kimliklerinin yuvasına oturur;
// okunamayan yuva boş yuvaya döner, komşu yuvalar yerinden oynamaz.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/custom_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/core/theme/theme_sync.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gateway extends ThemePrefsGateway {
  _Gateway(this.remote);

  Map<String, dynamic>? remote;

  @override
  bool get isSignedIn => true;

  @override
  Stream<void> get signIns => const Stream<void>.empty();

  @override
  Future<Map<String, dynamic>?> fetch() async => remote;

  @override
  Future<void> push(Map<String, dynamic> prefs) async => remote = prefs;
}

CustomTheme _theme(String slot, String name) => ThemeDraft.fromPreset(
  slotId: slot,
  name: name,
  preset: themePresetById('neon_focus'),
).toCustomTheme().copyWith(isDefined: true, updatedAt: DateTime(2026, 7, 1));

Future<void> _drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('bozuk custom_1 kaydı custom_2/custom_3 yuvalarını KAYDIRMAZ', () async {
    final payload = ThemeSettings(
      familyId: 'forest_study',
      paletteId: 'navy',
      mode: ThemeMode.dark,
      customThemes: [
        _theme('custom_1', 'Bir'),
        _theme('custom_2', 'İki'),
        _theme('custom_3', 'Üç'),
      ],
    ).toRemoteMap(DateTime.utc(2026, 8, 1));
    // custom_1 okunamaz hale gelir (ör. yarım yazılmış/elle bozulmuş satır).
    (payload['customThemes'] as List)[0] = {'id': 'custom_1'};

    final gateway = _Gateway(payload);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        themePrefsGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    container.read(themeSettingsProvider);
    await _drain();

    final themes = container.read(themeSettingsProvider).customThemes;
    expect(themes.map((t) => t.id), ['custom_1', 'custom_2', 'custom_3']);
    expect(themes.map((t) => t.isDefined), [false, true, true]);

    // Kullanıcı custom_2'yi düzenler: custom_3 yerinde kalmalı.
    await container
        .read(themeSettingsProvider.notifier)
        .saveCustomTheme(_theme('custom_2', 'İki (yeni)'));
    final after = container.read(themeSettingsProvider).customThemes;
    expect(after.map((t) => t.name), ['', 'İki (yeni)', 'Üç']);
  });
}
