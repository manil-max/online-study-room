import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-559: uygulamada secilen dil NATIVE yuzeye iletiliyor mu?
///
/// Sahada olculen hata: telefon Turkce, kullanici uygulamada Ingilizce secmis;
/// arayuz Ingilizce ama sayac bildirimi "Odaklaniyorsun / Durdur", widget
/// dugmesi "Durdur", alarm ekrani "Ertele (5 dk)" diyordu. Sebep: native taraf
/// metni `getString(R.string...)` ile cozer, o da `Configuration.locale`e --
/// yani per-app override yoksa CIHAZ diline -- bakar. WP-526 ayni sinifi
/// yalniz Dart tarafinda kapatmisti.
///
/// Bu dosya niyeti degil DAVRANISI olcer: kanala giden gercek cagriyi kaydeder.
const MethodChannel _channel = MethodChannel(
  'com.manilmax.online_study_room/device_integrations',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  List<Object?> tagsOf(MethodCall call) =>
      ((call.arguments as Map)['languageTags'] as List).cast<Object?>();

  void mockNative({Object? Function(MethodCall call)? onCall}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (onCall != null) return onCall(call);
          return true;
        });
  }

  setUp(() {
    calls = <MethodCall>[];
    // Kanal normalde yalniz Android'de acilir; testin host platformuna bagli
    // olarak sessizce hicbir sey olcmemesini engeller.
    debugNativeLocaleChannelEnabled = true;
    mockNative();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    debugNativeLocaleChannelEnabled = false;
  });

  test('manuel dil secimi native tarafa BCP-47 etiketi olarak gider', () async {
    expect(await applyNativeAppLocale(AppLanguage.english), isTrue);
    expect(calls.single.method, 'setApplicationLocales');
    expect(tagsOf(calls.single), ['en']);

    calls.clear();
    expect(await applyNativeAppLocale(AppLanguage.turkish), isTrue);
    expect(tagsOf(calls.single), ['tr']);
  });

  test('"sistem" secilince per-app override TEMIZLENIR (bos liste)', () async {
    // 🔴 Buraya cozulmus cihaz dili ('tr'/'en') gonderilirse override kilitlenir
    // ve kullanici telefon dilini degistirdiginde uygulama eski dilde kalir.
    await applyNativeAppLocale(AppLanguage.system);
    expect(calls.single.method, 'setApplicationLocales');
    expect(tagsOf(calls.single), isEmpty);
  });

  test('etiket haritasi uc tercihi de kapsar', () {
    expect(nativeLanguageTagsFor(AppLanguage.english), ['en']);
    expect(nativeLanguageTagsFor(AppLanguage.turkish), ['tr']);
    expect(nativeLanguageTagsFor(AppLanguage.system), isEmpty);
  });

  test('dil degistirmek native cagriyi tetikler', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(appLanguageProvider);
    await pumpEventQueue();
    calls.clear();

    await container
        .read(appLanguageProvider.notifier)
        .setLanguage(AppLanguage.english);

    expect(
      calls.map((c) => c.method),
      contains('setApplicationLocales'),
      reason: 'Ayarlardan dil degistirmek native yuzeye iletilmiyor',
    );
    expect(tagsOf(calls.last), ['en']);
  });

  test('acilista kayitli tercih bir kez uygulanir', () async {
    // Kullanici dili ONCEKI oturumda secmis olabilir; override yalniz
    // `setLanguage` aninda yazilsaydi bu kullanicida native metinler cihaz
    // dilinde kalirdi.
    SharedPreferences.setMockInitialValues({
      'app_language_preference': 'turkish',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(appLanguageProvider), AppLanguage.turkish);
    await pumpEventQueue();

    expect(
      calls.map((c) => c.method),
      ['setApplicationLocales'],
      reason: 'Acilis tercihi native tarafa hic gitmedi',
    );
    expect(tagsOf(calls.single), ['tr']);
  });

  test('Android disinda kanal hic acilmaz', () async {
    debugNativeLocaleChannelEnabled = false;
    expect(await applyNativeAppLocale(AppLanguage.english), isFalse);
    expect(calls, isEmpty);
  });

  test('native uygulayamazsa cagiran hata almaz', () async {
    // API 33 altinda `LocaleManager` yoktur -> native `false` doner.
    mockNative(onCall: (_) => false);
    expect(await applyNativeAppLocale(AppLanguage.english), isFalse);

    mockNative(
      onCall: (_) => throw PlatformException(code: 'boom'),
    );
    expect(await applyNativeAppLocale(AppLanguage.turkish), isFalse);
  });
}
