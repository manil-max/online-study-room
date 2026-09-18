import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/app_prefs.dart';
import 'app_theme.dart';
import 'custom_theme.dart';
import 'theme_sync.dart';

/// Tema rengi nereden uygulanıyor?
/// - [family]: Tema Stüdyosu atmosfer ailesi (tam UI havası)
/// - [palette]: Görünüm > Hazır/Özel palet (renk; aileye zorlanmaz)
enum ThemeColorSource { family, palette }

enum ThemeSaveResult { saved, failed, rejected }

/// WP-835/WP-841: hiç tema kaydı olmayan ilk kurulumun karşılama ailesi.
///
/// Uygulamanın kendi kimliği ateş: launcher ikonu kamp ateşi, Android widget
/// paleti `widget_ember_flame` (#FF8A3D) / `widget_ember_glow` (#FFC46B).
/// Eski davranış tasarlanmış bir karşılama değildi: tema kaydı yokken palet
/// `navy`'ye düşüyor, `migratePaletteIdToPreset` onu soğuk `ocean_glass`'e
/// çeviriyordu — sahibin "varsayılan tema kötü" geri bildirimi buradan geldi.
///
/// WP-835 karşılamayı koyu `campfire_night`e aldı; sahip üç adayın karesine
/// bakıp **açık** tema istedi ("3. seçenekteki gibi ama logodaki turuncu
/// renkte"). Karşılama artık `campfire_day`: krem kağıt zemin + aynı #F97316
/// turuncusu. Aile açık olduğu için mod da açık başlar (aşağıdaki `build`
/// kuralı `setFamily` ile birebir aynı: mod ailenin parlaklığıdır).
const String kFirstRunFamilyId = 'campfire_day';

/// WP-838: sunucuya yazılan tercih kümesinin biçim sürümü. İleride alan
/// eklenirse eski istemcinin okumayı reddetmesi değil, bilmediği alanı
/// görmezden gelmesi beklenir; bu yüzden sürüm yalnız teşhis içindir.
const int kThemePrefsVersion = 1;

/// Sunucu kopyasının istemci tarafından yazılmış ISO-8601/UTC damgası.
/// Okunamıyorsa `null` döner ve o kopya "eski" sayılır (yerel kazanır).
DateTime? themePrefsUpdatedAt(Map<String, dynamic>? prefs) {
  final raw = prefs?['updatedAt'];
  if (raw is! String) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

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

  /// WP-838: sunucuya giden **tam** tercih kümesi. Alan alan birleştirme yok —
  /// çatışma `updatedAt` ile son-yazan-kazanır olarak çözülür, bu yüzden küme
  /// her zaman bütün halinde gönderilir.
  Map<String, dynamic> toRemoteMap(DateTime updatedAt) => {
    'version': kThemePrefsVersion,
    'family': familyId,
    'palette': paletteId,
    'mode': mode.name,
    'colorSource': colorSource.name,
    'customPalettes': customPalettes.map((p) => p.toMap()).toList(),
    'customThemes': customThemes.map((t) => t.toMap()).toList(),
    'activeCustomTheme': activeCustomThemeId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

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
  static const _kPaletteSourceMigrated = 'palette_source_migrated_v1';

  /// WP-838: son YEREL tema değişikliğinin ISO-8601/UTC damgası. Çatışma
  /// kuralı buna bakar. Bilerek `_kThemeKeys` dışında tutuldu: ilk kurulumun
  /// karşılama teması (`_persistFirstRunTheme`) bir kullanıcı seçimi DEĞİLDİR
  /// ve damgalanmaz — damgalansaydı yeni cihazdaki varsayılan, hesaptaki
  /// gerçek tercihten "daha yeni" sayılıp onu ezerdi (bu WP'nin düzelttiği
  /// şikâyetin ta kendisi). Damgası olmayan kurulum her zaman "eski" sayılır.
  static const _kUpdatedAt = 'theme_prefs_updated_at';

  /// WP-860: damgayı atan hesabın kimliği. Çıkışta damga silinmez; aynı
  /// cihazda başka hesap girince damga ONUN değildir ve "damga yok" sayılır.
  /// Yoksa A'nın yerel seçimi B'nin hesabına itilir, B'nin teması cihaza inip
  /// damgayı ilerletince de A geri girdiğinde B'nin teması A'nın hesabına
  /// yazılırdı. Oturumsuz seçimde sahip yazılmaz (cihazın seçimi, eski
  /// davranış); sahipsiz eski damga da oturumdaki hesabınki sayılır.
  static const _kUpdatedBy = 'theme_prefs_updated_by';

  /// Tema Stüdyosu'nda kaydırıcı oynarken her karede sunucuya yazmamak için:
  /// son değişiklikten sonra bu kadar beklenir, sonra tek bir itiş yapılır.
  @visibleForTesting
  static const Duration pushDebounce = Duration(milliseconds: 800);

  Timer? _pushTimer;
  bool _syncing = false;

  /// WP-835: "hiç tema kaydı yok" ölçütü. Bu anahtarlardan biri bile varsa
  /// kullanıcı ya da eski bir göç tema tarafına dokunmuştur; o kurulumun
  /// görüntüsü değiştirilmez.
  static const _kThemeKeys = <String>[
    _kFamily,
    _kPalette,
    _kMode,
    _kColorSource,
    _kCustomPalettes,
    _kCustomThemes,
    _kActiveCustomTheme,
    _kCustomThemesMigrated,
    _kPaletteSourceMigrated,
  ];

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isFirstRun = !_kThemeKeys.any(prefs.containsKey);
    final paletteId = prefs.getString(_kPalette) ?? kAppPalettes.first.id;
    final storedFamily = prefs.getString(_kFamily);
    final familyId =
        storedFamily ??
        (isFirstRun ? kFirstRunFamilyId : migratePaletteIdToPreset(paletteId));

    final mode = switch (prefs.getString(_kMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      // İlk kurulumda mod ailenin parlaklığıdır (`setFamily` ile aynı kural);
      // yoksa açık bir karşılama ailesi koyu karşılığıyla açılırdı.
      _ =>
        isFirstRun && themePresetById(familyId).brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
    };

    final storedSource = prefs.getString(_kColorSource);
    var colorSource = switch (storedSource) {
      'palette' => ThemeColorSource.palette,
      'family' => ThemeColorSource.family,
      // Eski kurulum: family yoksa veya yalnızca palet kaydı varsa palet renkleri.
      _ =>
        storedFamily == null
            ? ThemeColorSource.palette
            : ThemeColorSource.family,
    };

    // WP-835: ilk kurulum aileyle başlar ve seçim KALICI yazılır. Yazılmazsa
    // ikinci açılışta kayıt "var" sayılır ama `theme_family` boş olduğu için
    // `migratePaletteIdToPreset('navy')` yine soğuk `ocean_glass`'e düşerdi.
    if (isFirstRun) {
      colorSource = ThemeColorSource.family;
      unawaited(_persistFirstRunTheme(prefs, familyId, mode));
    }

    // WP-302: "Hazır Paletler" listesi arayüzden kaldırıldı. Yerleşik bir
    // palete bağlı kalan kurulumlar aileye taşınır; yoksa Görünüm ekranında
    // hiçbir kart seçili görünmez ve kullanıcı seçimini geri alamaz.
    // ⚠️ `custom_*` paletlere DOKUNULMAZ: onlar WP-288 göçüyle özel temaya
    // dönüşür, buradan geçerlerse iki göç birbirini ezer.
    // İlk kurulumda kaynak yukarıda aileye ayarlandığı için bu blok çalışmaz.
    if (colorSource == ThemeColorSource.palette &&
        !paletteId.startsWith('custom_') &&
        prefs.getBool(_kPaletteSourceMigrated) != true) {
      colorSource = ThemeColorSource.family;
      // Aile kaydı varsa kullanıcının kendi seçimi korunur; yoksa yukarıda
      // `migratePaletteIdToPreset` zaten en yakın hazır temayı vermişti.
      unawaited(_persistPaletteSourceMigration(prefs));
    }

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
      customPalettes.add(_defaultCustomPalette(customPalettes.length + 1));
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

    // WP-838: tercihler hesapta da durur. Oturum açılışında (kalıcı oturumun
    // geri yüklenmesi dahil) sunucu kopyasıyla uzlaşılır. Kapı kapalıysa
    // (bellek-içi mod, Supabase kurulmamış) tek satır ağ trafiği olmaz.
    final gateway = ref.watch(themePrefsGatewayProvider);
    final signIns = gateway.signIns.listen((_) => unawaited(syncWithServer()));
    ref.onDispose(signIns.cancel);
    ref.onDispose(() => _pushTimer?.cancel());
    if (gateway.isSignedIn) {
      // Oturum bu sağlayıcı kurulmadan ÖNCE geri yüklenmiş olabilir; o
      // durumda `initialSession` olayı kaçırılır, ilk uzlaşma buradan başlar.
      Future.microtask(syncWithServer);
    }

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

  AppPalette _defaultCustomPalette(int slot) => AppPalette(
    id: 'custom_$slot',
    name: 'Custom $slot',
    primary: const Color(0xFF8B5CF6),
    onPrimary: const Color(0xFFFFFFFF),
    accent: const Color(0xFF12C281),
    onAccent: const Color(0xFFFFFFFF),
  );

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
      // Boş yuvanın adı hiçbir yerde çizilmiyor: `AppearanceScreen` yalnız
      // `isDefined` temaları listeler ve sihirbaz tanımsız yuvada `name: ''`
      // kullanır. Buraya gömülü Türkçe bir ad koymak (eski hâli) yuva bir gün
      // gösterilirse dili kaçıran sessiz bir sızıntıydı (WP-294).
      name: '',
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

  /// WP-835: ilk açılışta hesaplanan karşılama teması diske yazılır; sonraki
  /// açılışlar bu kaydı okur, yeniden türetmeye çalışmaz.
  Future<void> _persistFirstRunTheme(
    SharedPreferences prefs,
    String familyId,
    ThemeMode mode,
  ) async {
    await prefs.setString(_kFamily, familyId);
    await prefs.setString(_kMode, mode.name);
    await prefs.setString(_kColorSource, 'family');
  }

  Future<void> _persistPaletteSourceMigration(SharedPreferences prefs) async {
    await prefs.setString(_kColorSource, 'family');
    await prefs.setBool(_kPaletteSourceMigrated, true);
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

  /// WP-838: yerel kayıt ile hesaptaki kopyayı uzlaştırır.
  ///
  /// Kural **son-yazan-kazanır**, alan alan birleştirme yoktur: sunucudaki
  /// `updatedAt` yereldekinden yeniyse sunucu kopyası uygulanır ve diske
  /// yazılır; aksi halde (yerel daha yeni ya da sunucuda kayıt yok) yerel
  /// kopya yukarı itilir.
  ///
  /// Çevrimdışı çalışmayı bozmaz: çizim her zaman yereldeki kayıttan sürer,
  /// ağ hatası yutulur ve widget ağacına sızmaz. Başarısız bir yazma bir
  /// sonraki tema değişikliğinde kendiliğinden yeniden denenir, çünkü her itiş
  /// tam kümeyi gönderir.
  Future<void> syncWithServer() async {
    final gateway = ref.read(themePrefsGatewayProvider);
    // Oturumu olmayan kullanıcı ağa hiç çıkmaz.
    if (!gateway.isSignedIn || _syncing) return;
    _syncing = true;
    try {
      Map<String, dynamic>? remote;
      try {
        remote = await gateway.fetch();
      } catch (_) {
        // Çevrimdışı/sunucu hatası: yerel kayıt olduğu gibi kalır.
        return;
      }
      final remoteAt = themePrefsUpdatedAt(remote);
      final owner = ref.read(sharedPreferencesProvider).getString(_kUpdatedBy);
      final localAt = owner == null || owner == gateway.userId
          ? _localUpdatedAt()
          : null;
      if (remote != null &&
          remoteAt != null &&
          (localAt == null || remoteAt.isAfter(localAt))) {
        await _applyRemote(remote, remoteAt);
        return;
      }
      // 🔴 WP-864: cihazdaki tercih BAŞKA bir hesaba aitse ve bu hesabın
      // sunucuda kaydı yoksa yukarı hiçbir şey itilmez. Eskiden A'nın teması,
      // kaydı olmayan B'nin hesabına "B'nin ilk teması" diye yazılıyordu. B
      // bir şey seçtiğinde damga B'ye geçer ve normal akış başlar.
      if (owner != null && owner != gateway.userId) return;
      await _pushNow();
    } finally {
      _syncing = false;
    }
  }

  DateTime? _localUpdatedAt() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kUpdatedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Her yerel tema değişikliği damgalanır ve tek bir gecikmeli itiş planlanır.
  /// Damga **hemen** yazılır: uygulama itiş olmadan kapansa bile o cihazın
  /// değişikliği sonraki uzlaşmada doğru tarihle yarışır.
  void _touchAndSchedulePush() {
    // Damga oturumdan bağımsız yazılır: çıkış yapmışken seçilen tema da
    // sonraki uzlaşmada doğru tarihle yarışmalı.
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kUpdatedAt, DateTime.now().toUtc().toIso8601String());
    _stampOwner(prefs, ref.read(themePrefsGatewayProvider).userId);
    // Oturum yoksa itilecek bir şey de yok. Zamanlayıcıyı burada hiç kurmamak
    // ölü bir bekleyişi önler; `flutter_test` sahte saati "hâlâ bekleyen
    // zamanlayıcı" diye haklı olarak hata sayar.
    if (!ref.read(themePrefsGatewayProvider).isSignedIn) return;
    _pushTimer?.cancel();
    // WP-864: bekleyen itiş KURULDUĞU hesaba bağlıdır. Bekleme dolmadan hesap
    // değişirse eski hesabın teması yeni hesaba yazılmaz.
    final scheduledFor = ref.read(themePrefsGatewayProvider).userId;
    _pushTimer = Timer(
      pushDebounce,
      () => unawaited(_pushNow(expectedUserId: scheduledFor)),
    );
  }

  Future<void> _pushNow({String? expectedUserId}) async {
    final gateway = ref.read(themePrefsGatewayProvider);
    if (!gateway.isSignedIn) return;
    if (expectedUserId != null && gateway.userId != expectedUserId) return;
    final updatedAt = _localUpdatedAt() ?? DateTime.now().toUtc();
    try {
      await gateway.push(state.toRemoteMap(updatedAt));
      // Yerel küme artık bu hesabın sunucu kopyasıdır.
      _stampOwner(ref.read(sharedPreferencesProvider), gateway.userId);
    } catch (_) {
      // Ağ hatası kullanıcıya yansımaz; sonraki değişiklik yeniden dener.
    }
  }

  /// Sunucu kopyasını hem duruma hem diske yazar. Diske yazılmazsa sonraki
  /// açılış yine eski temayı okur ve uzlaşma sessizce geri alınmış olurdu.
  Future<void> _applyRemote(
    Map<String, dynamic> remote,
    DateTime remoteAt,
  ) async {
    final settings = _settingsFromRemote(remote);
    // Bozuk/eksik kayıt: kullanıcının yerel teması korunur.
    if (settings == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kFamily, settings.familyId);
    await prefs.setString(_kPalette, settings.paletteId);
    await prefs.setString(_kMode, settings.mode.name);
    await prefs.setString(_kColorSource, settings.colorSource.name);
    await prefs.setStringList(
      _kCustomPalettes,
      settings.customPalettes.map((p) => jsonEncode(p.toMap())).toList(),
    );
    await prefs.setStringList(
      _kCustomThemes,
      settings.customThemes.map((t) => jsonEncode(t.toMap())).toList(),
    );
    final active = settings.activeCustomThemeId;
    if (active == null) {
      await prefs.remove(_kActiveCustomTheme);
    } else {
      await prefs.setString(_kActiveCustomTheme, active);
    }
    // Sunucudan gelen küme zaten göçmüş bir kümedir; WP-288/WP-302 göçleri
    // bunun üstünde bir daha koşmamalı.
    await prefs.setBool(_kCustomThemesMigrated, true);
    await prefs.setBool(_kPaletteSourceMigrated, true);
    await prefs.setString(_kUpdatedAt, remoteAt.toUtc().toIso8601String());
    _stampOwner(prefs, ref.read(themePrefsGatewayProvider).userId);
    state = settings;
  }

  void _stampOwner(SharedPreferences prefs, String? userId) {
    if (userId == null) {
      prefs.remove(_kUpdatedBy);
    } else {
      prefs.setString(_kUpdatedBy, userId);
    }
  }

  /// Sunucu JSON'undan tercih kümesi. Tek bir bozuk alan yüzünden tüm kayıt
  /// atılmaz; aile/palet kimliği okunamıyorsa kayıt kullanılamaz sayılır.
  ThemeSettings? _settingsFromRemote(Map<String, dynamic> remote) {
    final familyId = remote['family'];
    final paletteId = remote['palette'];
    if (familyId is! String || paletteId is! String) return null;

    final mode = switch (remote['mode']) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    final colorSource = remote['colorSource'] == 'palette'
        ? ThemeColorSource.palette
        : ThemeColorSource.family;

    final palettes = <AppPalette>[];
    for (final item in remote['customPalettes'] as List? ?? const []) {
      try {
        palettes.add(
          AppPalette.fromMap(Map<String, dynamic>.from(item as Map)),
        );
      } catch (_) {}
    }
    while (palettes.length < 3) {
      palettes.add(_defaultCustomPalette(palettes.length + 1));
    }

    // WP-861: her tema kimliğinin yuvasına oturur. Sırayla dizilseydi tek bir
    // okunamayan tema komşularını bir yuva kaydırır, `saveCustomTheme` (yuvayı
    // kimlikten değil liste konumundan bulur) başka bir temanın üstüne yazardı.
    final themes = [
      for (var slot = 1; slot <= 3; slot++) _emptyCustomTheme(slot),
    ];
    final filled = <int>{};
    for (final item in remote['customThemes'] as List? ?? const []) {
      try {
        final parsed = CustomTheme.tryParse(
          Map<String, dynamic>.from(item as Map),
        );
        final slot = int.tryParse(parsed?.id.split('_').last ?? '');
        if (parsed == null ||
            parsed.id != 'custom_$slot' ||
            slot == null ||
            slot < 1 ||
            slot > 3 ||
            !filled.add(slot)) {
          continue;
        }
        themes[slot - 1] = parsed;
      } catch (_) {}
    }

    final active = remote['activeCustomTheme'];
    return ThemeSettings(
      familyId: familyId,
      paletteId: paletteId,
      mode: mode,
      colorSource: colorSource,
      customPalettes: palettes,
      customThemes: themes,
      activeCustomThemeId:
          active is String && themes.any((t) => t.id == active && t.isDefined)
          ? active
          : null,
    );
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
    _touchAndSchedulePush();
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
    _touchAndSchedulePush();
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
    _touchAndSchedulePush();
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
    _touchAndSchedulePush();
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
    _touchAndSchedulePush();
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
    _touchAndSchedulePush();
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    ref.read(sharedPreferencesProvider).setString(_kMode, mode.name);
    _touchAndSchedulePush();
  }
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
      ThemeSettingsNotifier.new,
    );
