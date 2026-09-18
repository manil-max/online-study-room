// WP-860 — AYNI CİHAZDA HESAP DEĞİŞİNCE TEMA BAŞKA HESABA SIZMAZ.
//
// Avcı bulgusu (v86–v87 turu, WP-838 uzlaşması): yerel tema damgası
// (`theme_prefs_updated_at`) hangi hesaba ait olduğunu bilmiyordu ve çıkışta
// silinmiyordu. Aynı cihazda A çıkıp B girince uzlaşma A'nın damgasını B'nin
// sunucu kopyasıyla yarıştırıyordu:
//   * A'nın yerel değişikliği B'nin kaydından yeniyse A'nın teması B'nin
//     HESABINA yazılıyordu (B'nin kendi seçimi sunucudan siliniyordu).
//   * B'nin teması cihaza inip damgayı ilerletince, A geri girdiğinde B'nin
//     teması A'nın hesabına yazılıyordu.
//
// Sözleşme: yerel damga başka bir hesaba aitse "damga yok" sayılır — o
// hesabın sunucu kopyası (varsa) kazanır ve yukarı hiçbir şey itilmez.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/core/theme/theme_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hesap başına ayrı sunucu satırı tutan kapı (RLS'in istemciden görünüşü).
class _AccountsGateway extends ThemePrefsGateway {
  _AccountsGateway(this.rows);

  final Map<String, Map<String, dynamic>> rows;
  String? currentUser;
  final List<({String user, Map<String, dynamic> prefs})> pushed = [];
  final StreamController<void> _signIns = StreamController<void>.broadcast();

  @override
  bool get isSignedIn => currentUser != null;

  @override
  String? get userId => currentUser;

  @override
  Stream<void> get signIns => _signIns.stream;

  @override
  Future<Map<String, dynamic>?> fetch() async =>
      currentUser == null ? null : rows[currentUser];

  @override
  Future<void> push(Map<String, dynamic> prefs) async {
    final user = currentUser;
    if (user == null) return;
    pushed.add((user: user, prefs: prefs));
    rows[user] = prefs;
  }

  void signOut() => currentUser = null;

  void signIn(String user) {
    currentUser = user;
    _signIns.add(null);
  }

  Future<void> dispose() => _signIns.close();
}

Map<String, dynamic> _row(String family, DateTime at) => ThemeSettings(
  familyId: family,
  paletteId: 'navy',
  mode: ThemeMode.dark,
).toRemoteMap(at);

Future<void> _drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'A çıkıp B girince A\'nın yerel teması B\'nin hesabına YAZILMAZ',
    () async {
      final gateway = _AccountsGateway({
        // B temasını uzun zaman önce kendi cihazında seçmiş.
        'user-b': _row('forest_study', DateTime.utc(2026, 1, 1)),
      })..currentUser = 'user-a';
      addTearDown(gateway.dispose);
      SharedPreferences.setMockInitialValues({
        'theme_family': 'nordic_snow',
        'theme_palette': 'navy',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          themePrefsGatewayProvider.overrideWithValue(gateway),
        ],
      );
      addTearDown(container.dispose);

      // A bu cihazda temasını değiştirir (damga: şimdi) ve çıkar.
      container.read(themeSettingsProvider);
      await _drain();
      container.read(themeSettingsProvider.notifier).setFamily('deep_amoled');
      await Future<void>.delayed(
        ThemeSettingsNotifier.pushDebounce + const Duration(milliseconds: 80),
      );
      await _drain();
      gateway.signOut();

      gateway.signIn('user-b');
      await _drain();

      expect(
        gateway.pushed
            .where((p) => p.user == 'user-b')
            .map((p) => p.prefs['family']),
        isEmpty,
        reason: 'A\'nın teması B\'nin hesabına itildi',
      );
      expect(gateway.rows['user-b']!['family'], 'forest_study');
      expect(container.read(themeSettingsProvider).familyId, 'forest_study');
    },
  );

  test(
    'B\'nin teması cihaza indikten sonra A geri girince A\'nın hesabı EZİLMEZ',
    () async {
      final gateway = _AccountsGateway({
        'user-a': _row('nordic_snow', DateTime.utc(2026, 3, 1)),
        'user-b': _row('forest_study', DateTime.utc(2026, 4, 1)),
      })..currentUser = 'user-a';
      addTearDown(gateway.dispose);
      // Cihaz A'nın hesabıyla uzlaşmış halde (damga A'nın kaydıyla aynı).
      SharedPreferences.setMockInitialValues({
        'theme_family': 'nordic_snow',
        'theme_palette': 'navy',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
        'theme_prefs_updated_at': DateTime.utc(2026, 3, 1).toIso8601String(),
      });
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
      gateway.pushed.clear();

      gateway.signOut();
      gateway.signIn('user-b');
      await _drain();
      expect(container.read(themeSettingsProvider).familyId, 'forest_study');

      gateway.signOut();
      gateway.signIn('user-a');
      await _drain();

      expect(
        gateway.pushed
            .where((p) => p.user == 'user-a')
            .map((p) => p.prefs['family']),
        isEmpty,
        reason: 'B\'nin teması A\'nın hesabına itildi',
      );
      expect(gateway.rows['user-a']!['family'], 'nordic_snow');
      expect(container.read(themeSettingsProvider).familyId, 'nordic_snow');
    },
  );

  test('çıkışken seçilen tema ilk girişte hesaba yine İTİLİR', () async {
    // Mevcut tasarım korunur: oturumsuz seçim cihazındır, sahipsizdir.
    final gateway = _AccountsGateway({
      'user-a': _row('nordic_snow', DateTime.utc(2026, 1, 1)),
    });
    addTearDown(gateway.dispose);
    SharedPreferences.setMockInitialValues({
      'theme_family': 'nordic_snow',
      'theme_palette': 'navy',
      'theme_color_source': 'family',
      'theme_mode': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        themePrefsGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    container.read(themeSettingsProvider);
    container.read(themeSettingsProvider.notifier).setFamily('deep_amoled');
    await _drain();

    gateway.signIn('user-a');
    await _drain();

    expect(gateway.rows['user-a']!['family'], 'deep_amoled');
  });
}
