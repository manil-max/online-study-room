// WP-838 — TEMA TERCİHİ VE ÖZEL TEMALAR HESAPTA SAKLANIR.
//
// Sahip geri bildirimi: "yeni cihazda açınca tema ayarım gitmiş" ve
// "özelleştirilmiş temaları hesapta saklama ihtimalimiz var mı".
//
// Eski davranış (ölçüldü, `core/theme/theme_settings.dart`): tercihlerin
// TAMAMI yalnız `SharedPreferences`e yazılıyordu. Sunucuya hiçbir şey
// gitmediği için yeni cihaz ilk kurulum karşılamasıyla (`campfire_day`)
// açılıyordu.
//
// Bu dosyanın ölçtüğü sözleşme:
//   1. Uzlaşma **son-yazan-kazanır**: sunucu yeniyse yerel değişir, yerel
//      yeniyse (ya da sunucu boşsa) yerel yukarı itilir. Alan alan birleştirme
//      YOK.
//   2. Çevrimdışı çalışmayı bozmaz: ağ hatasında yerel kayıt olduğu gibi
//      kalır, istisna dışarı sızmaz ve yazma bir sonraki değişiklikte
//      kendiliğinden yeniden denenir.
//   3. Oturumu olmayan kullanıcı ağa hiç çıkmaz.
//   4. Kaydırıcı her oynadığında değil, değişikliğin sonunda tek itiş.
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

/// Ağ yerine sayaç tutan kapı: kaç kez okundu, kaç kez yazıldı, ne yazıldı.
class _FakeGateway extends ThemePrefsGateway {
  _FakeGateway({this.signedIn = true, this.remote});

  bool signedIn;
  Map<String, dynamic>? remote;
  bool failFetch = false;
  bool failPush = false;
  int fetchCount = 0;
  int pushCount = 0;
  final List<Map<String, dynamic>> pushed = <Map<String, dynamic>>[];
  final StreamController<void> _signIns = StreamController<void>.broadcast();

  @override
  bool get isSignedIn => signedIn;

  @override
  Stream<void> get signIns => _signIns.stream;

  @override
  Future<Map<String, dynamic>?> fetch() async {
    fetchCount++;
    if (failFetch) throw Exception('ağ yok');
    return remote;
  }

  @override
  Future<void> push(Map<String, dynamic> prefs) async {
    pushCount++;
    if (failPush) throw Exception('ağ yok');
    pushed.add(prefs);
    remote = prefs;
  }

  void emitSignIn() => _signIns.add(null);
  Future<void> dispose() => _signIns.close();
}

typedef _Install = ({ProviderContainer container, SharedPreferences prefs});

Future<_Install> _install(
  Map<String, Object> seed,
  _FakeGateway gateway,
) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return (
    container: ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        themePrefsGatewayProvider.overrideWithValue(gateway),
      ],
    ),
    prefs: prefs,
  );
}

/// `build()` ve uzlaşma içindeki yazmalar `unawaited`/async; kuyruğu boşalt.
Future<void> _drain() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Gecikmeli itişin ateşlenmesini bekler.
Future<void> _awaitPush() async {
  await Future<void>.delayed(
    ThemeSettingsNotifier.pushDebounce + const Duration(milliseconds: 80),
  );
  await _drain();
}

CustomTheme _customTheme(String name) => ThemeDraft.fromPreset(
  slotId: 'custom_1',
  name: name,
  preset: themePresetById('neon_focus'),
).toCustomTheme().copyWith(isDefined: true, updatedAt: DateTime(2026, 7, 1));

Map<String, dynamic> _remotePayload({
  required String family,
  required DateTime at,
  String palette = 'navy',
  ThemeMode mode = ThemeMode.dark,
  ThemeColorSource source = ThemeColorSource.family,
  List<CustomTheme> themes = const [],
  String? activeCustomThemeId,
}) => ThemeSettings(
  familyId: family,
  paletteId: palette,
  mode: mode,
  colorSource: source,
  customThemes: themes,
  activeCustomThemeId: activeCustomThemeId,
).toRemoteMap(at);

void main() {
  group('uzlaşma — son yazan kazanır', () {
    test('sunucu kopyası yeniyse yerel tema DEĞİŞİR ve diske yazılır', () async {
      final gateway = _FakeGateway(
        remote: _remotePayload(
          family: 'forest_study',
          palette: 'emerald',
          mode: ThemeMode.light,
          at: DateTime.utc(2026, 2, 1),
        ),
      );
      addTearDown(gateway.dispose);
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_palette': 'navy',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
        'theme_prefs_updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      }, gateway);
      addTearDown(install.container.dispose);

      expect(
        install.container.read(themeSettingsProvider).familyId,
        'nordic_snow',
      );
      await _drain();

      final settings = install.container.read(themeSettingsProvider);
      expect(settings.familyId, 'forest_study');
      expect(settings.paletteId, 'emerald');
      expect(settings.mode, ThemeMode.light);
      // Diske de yazılmalı: yazılmazsa sonraki açılış yine eskisini okurdu.
      expect(install.prefs.getString('theme_family'), 'forest_study');
      expect(install.prefs.getString('theme_palette'), 'emerald');
      expect(install.prefs.getString('theme_mode'), 'light');
      expect(
        install.prefs.getString('theme_prefs_updated_at'),
        DateTime.utc(2026, 2, 1).toIso8601String(),
      );
      // Sunucu kazandığında yerel kopya geri itilmez (ping-pong olmaz).
      expect(gateway.pushCount, 0);
    });

    test('yerel kopya yeniyse sunucuya İTİLİR, yerel değişmez', () async {
      final gateway = _FakeGateway(
        remote: _remotePayload(
          family: 'forest_study',
          at: DateTime.utc(2026, 2, 1),
        ),
      );
      addTearDown(gateway.dispose);
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_palette': 'navy',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
        'theme_prefs_updated_at': DateTime.utc(2026, 3, 1).toIso8601String(),
      }, gateway);
      addTearDown(install.container.dispose);

      install.container.read(themeSettingsProvider);
      await _drain();

      expect(
        install.container.read(themeSettingsProvider).familyId,
        'nordic_snow',
      );
      expect(gateway.pushCount, 1);
      expect(gateway.pushed.single['family'], 'nordic_snow');
      // Damga yerelden gelir; sunucudaki eski damga kullanılmaz.
      expect(
        gateway.pushed.single['updatedAt'],
        DateTime.utc(2026, 3, 1).toIso8601String(),
      );
    });

    test('sunucuda kayıt yoksa yerel kopya İTİLİR', () async {
      final gateway = _FakeGateway();
      addTearDown(gateway.dispose);
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_palette': 'navy',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
        'theme_prefs_updated_at': DateTime.utc(2026, 3, 1).toIso8601String(),
      }, gateway);
      addTearDown(install.container.dispose);

      install.container.read(themeSettingsProvider);
      await _drain();

      expect(gateway.fetchCount, 1);
      expect(gateway.pushCount, 1);
      expect(gateway.pushed.single['family'], 'nordic_snow');
    });

    test(
      'yeni cihaz: damgasız temiz kurulum hesaptaki tercihi EZMEZ',
      () async {
        // Sahibin şikâyetinin ta kendisi. Temiz kurulumda yerel damga yoktur;
        // damgasız kurulum her zaman "eski" sayılır, yani karşılama teması
        // hesaptaki gerçek tercihi ezemez.
        final gateway = _FakeGateway(
          remote: _remotePayload(
            family: 'forest_study',
            palette: 'emerald',
            mode: ThemeMode.light,
            at: DateTime.utc(2026, 2, 1),
          ),
        );
        addTearDown(gateway.dispose);
        final install = await _install({}, gateway);
        addTearDown(install.container.dispose);

        // İlk okuma karşılama temasını verir (henüz uzlaşma olmadı).
        expect(
          install.container.read(themeSettingsProvider).familyId,
          kFirstRunFamilyId,
        );
        await _drain();

        expect(
          install.container.read(themeSettingsProvider).familyId,
          'forest_study',
        );
        expect(install.prefs.getString('theme_family'), 'forest_study');
        expect(gateway.pushCount, 0);
      },
    );

    test('özel temalar da hesapta saklanır ve geri gelir', () async {
      final gateway = _FakeGateway(
        remote: _remotePayload(
          family: 'nordic_snow',
          palette: 'custom_1',
          source: ThemeColorSource.palette,
          at: DateTime.utc(2026, 2, 1),
          themes: [_customTheme('Gece Lambası')],
          activeCustomThemeId: 'custom_1',
        ),
      );
      addTearDown(gateway.dispose);
      final install = await _install({}, gateway);
      addTearDown(install.container.dispose);

      install.container.read(themeSettingsProvider);
      await _drain();

      final settings = install.container.read(themeSettingsProvider);
      expect(settings.activeCustomThemeId, 'custom_1');
      expect(settings.activeCustomTheme?.name, 'Gece Lambası');
      expect(settings.colorSource, ThemeColorSource.palette);
      expect(install.prefs.getString('active_custom_theme_id'), 'custom_1');
      expect(install.prefs.getStringList('custom_themes_v2'), isNotNull);
      // Sunucudan gelen küme zaten göçmüştür; göçler yeniden koşmamalı.
      expect(install.prefs.getBool('custom_themes_migrated_v1'), isTrue);
    });

    test('bozuk sunucu kaydı yerel temayı bozmaz', () async {
      final gateway = _FakeGateway(
        remote: {'family': 42, 'updatedAt': DateTime.utc(2026, 5, 1).toIso8601String()},
      );
      addTearDown(gateway.dispose);
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_prefs_updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      }, gateway);
      addTearDown(install.container.dispose);

      install.container.read(themeSettingsProvider);
      await _drain();

      expect(
        install.container.read(themeSettingsProvider).familyId,
        'nordic_snow',
      );
      expect(install.prefs.getString('theme_family'), 'nordic_snow');
    });
  });

  group('çevrimdışı dayanıklılık', () {
    test(
      'okuma hatası: yerel değişmez, istisna sızmaz, sonraki değişiklikte '
      'yeniden denenir',
      () async {
        final gateway = _FakeGateway(
          remote: _remotePayload(
            family: 'forest_study',
            at: DateTime.utc(2026, 9, 1),
          ),
        )..failFetch = true;
        addTearDown(gateway.dispose);
        final install = await _install({
          'theme_family': 'nordic_snow',
          'theme_color_source': 'family',
          'theme_mode': 'dark',
        }, gateway);
        addTearDown(install.container.dispose);

        final notifier = install.container.read(themeSettingsProvider.notifier);
        // İstisna çağırana/widget ağacına sızmaz.
        await expectLater(notifier.syncWithServer(), completes);
        await _drain();

        expect(
          install.container.read(themeSettingsProvider).familyId,
          'nordic_snow',
        );
        expect(gateway.pushCount, 0);

        // Ağ geri geldi: bir sonraki tema değişikliği yazmayı kendiliğinden
        // yeniden dener (her itiş TAM kümeyi gönderir).
        gateway.failFetch = false;
        notifier.setFamily('deep_amoled');
        await _awaitPush();

        expect(gateway.pushCount, 1);
        expect(gateway.pushed.single['family'], 'deep_amoled');
      },
    );

    test(
      'yazma hatası: yerel değişmez ve sonraki değişiklikte yeniden denenir',
      () async {
        final gateway = _FakeGateway()..failPush = true;
        addTearDown(gateway.dispose);
        final install = await _install({
          'theme_family': 'nordic_snow',
          'theme_color_source': 'family',
          'theme_mode': 'dark',
          'theme_prefs_updated_at': DateTime.utc(2026, 3, 1).toIso8601String(),
        }, gateway);
        addTearDown(install.container.dispose);

        final notifier = install.container.read(themeSettingsProvider.notifier);
        await _drain();

        expect(gateway.pushCount, 1); // denendi
        expect(gateway.pushed, isEmpty); // ama sunucuya ulaşmadı
        expect(
          install.container.read(themeSettingsProvider).familyId,
          'nordic_snow',
        );

        gateway.failPush = false;
        notifier.setFamily('deep_amoled');
        await _awaitPush();

        expect(gateway.pushCount, 2);
        expect(gateway.pushed.single['family'], 'deep_amoled');
      },
    );
  });

  group('oturum ve trafik', () {
    test('oturumu olmayan kullanıcı ağa HİÇ çıkmaz', () async {
      final gateway = _FakeGateway(signedIn: false);
      addTearDown(gateway.dispose);
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
      }, gateway);
      addTearDown(install.container.dispose);

      final notifier = install.container.read(themeSettingsProvider.notifier);
      await _drain();
      notifier.setFamily('deep_amoled');
      notifier.setMode(ThemeMode.light);
      await _awaitPush();
      await notifier.syncWithServer();
      await _drain();

      expect(gateway.fetchCount, 0);
      expect(gateway.pushCount, 0);
      // Yerel taraf normal çalışmaya devam eder.
      expect(
        install.container.read(themeSettingsProvider).familyId,
        'deep_amoled',
      );
      expect(install.prefs.getString('theme_family'), 'deep_amoled');
    });

    test('oturum açılınca uzlaşma kendiliğinden tetiklenir', () async {
      final gateway = _FakeGateway(
        signedIn: false,
        remote: _remotePayload(
          family: 'forest_study',
          at: DateTime.utc(2026, 2, 1),
        ),
      );
      addTearDown(gateway.dispose);
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
      }, gateway);
      addTearDown(install.container.dispose);

      install.container.read(themeSettingsProvider);
      await _drain();
      expect(gateway.fetchCount, 0);

      gateway.signedIn = true;
      gateway.emitSignIn();
      await _drain();

      expect(gateway.fetchCount, 1);
      expect(
        install.container.read(themeSettingsProvider).familyId,
        'forest_study',
      );
    });

    test('art arda değişiklikler TEK itişle gider (kaydırıcı koruması)', () async {
      final gateway = _FakeGateway();
      addTearDown(gateway.dispose);
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_color_source': 'family',
        'theme_mode': 'dark',
      }, gateway);
      addTearDown(install.container.dispose);

      final notifier = install.container.read(themeSettingsProvider.notifier);
      await _drain();
      final baseline = gateway.pushCount;

      notifier.setFamily('deep_amoled');
      notifier.setFamily('forest_study');
      notifier.setFamily('neon_focus');
      notifier.setMode(ThemeMode.light);
      // Gecikme dolmadan hiçbir şey gitmemeli.
      await _drain();
      expect(gateway.pushCount, baseline);

      await _awaitPush();
      expect(gateway.pushCount, baseline + 1);
      expect(gateway.pushed.last['family'], 'neon_focus');
      expect(gateway.pushed.last['mode'], 'light');
    });
  });
}
