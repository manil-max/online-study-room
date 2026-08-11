// WP-558: widget veri boru hattinin DAVRANIS olcumu (kaynak taramasi yok).
//
// Denetim bulgusu: yayinda yalniz 1x1 Baslat/Durdur widget'i varken boru hatti
// kapali uc saglayiciya (`stats` / `groupGoal` / `leaderboard`) her veri
// degisiminde yayin gonderiyor, ustune 17 anahtarlik snapshot'i iki kez
// yaziyordu. Gercek `home_widget` MethodChannel'i sahte bir handler ile
// kesilir ve platform kanali turleri SAYILIR.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// `home_widget` platform kanalinin cagri sayaci.
class _HomeWidgetSpy {
  _HomeWidgetSpy() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handle);
  }

  static const MethodChannel _channel = MethodChannel('home_widget');

  final List<String> updatedAndroidNames = <String>[];
  final List<String> savedKeys = <String>[];

  /// Toplam platform kanali turu (her `invokeMethod` bir tur).
  int turns = 0;

  Future<Object?> _handle(MethodCall call) async {
    turns++;
    final args = call.arguments as Map<Object?, Object?>;
    switch (call.method) {
      case 'updateWidget':
        updatedAndroidNames.add(args['android'] as String? ?? '?');
        return true;
      case 'saveWidgetData':
        savedKeys.add(args['id']! as String);
        return true;
    }
    return null;
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

List<String> get _publishedAndroidNames => StudyHomeWidget.values
    .where((widget) => widget.isPublished)
    .map((widget) => widget.androidName)
    .toList();

const List<StudyHomeWidget> _statsWidgets = <StudyHomeWidget>[
  StudyHomeWidget.stats,
  StudyHomeWidget.groupGoal,
  StudyHomeWidget.leaderboard,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const AndroidWidgetService service = AndroidWidgetService();
  late AppLocalizations l10n;
  late _HomeWidgetSpy spy;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });
  setUp(() => spy = _HomeWidgetSpy());
  tearDown(() => spy.dispose());

  // 🔴 WP-708 — BU BLOK YENIDEN YAZILDI, GEVSETILMEDI.
  //
  // WP-558 yazildiginda yayinda YALNIZ sayac vardi; iddialar bu fixture'a
  // dayaniyordu ("hicbir anahtar yazilmaz", "0 kanal turu"). WP-707 dort
  // widget'i yayina alinca bes iddia birden bayatladi. Sayilari buyutup
  // gecmek kolaydi -- yapilmadi: WP-558'in KORUDUGU sey "sifir tur" degil,
  // *okuyucusu olmayan anahtara tur harcanmamasi*. Iddialar o ozelligi
  // olcecek sekilde yeniden yazildi (bkz. widget_key_ownership_wp708_test).

  test('tuzak teli: boru hattinda yayindan dusuk uye kalmadi', () {
    // WP-558'in negatif fixture'i tukendi: `StudyHomeWidget` uyelerinin hepsi
    // yayinda. Bu iddia allowlist'i olcmez, allowlist testinin ARTIK
    // olcemedigini hatirlatir. Bir uye tekrar yayindan dusurulurse kirmizi
    // duser ve negatif fixture geri eklenmelidir.
    expect(
      StudyHomeWidget.values.where((widget) => !widget.isPublished),
      isEmpty,
      reason: 'bir uye yayindan dustu: allowlist icin negatif fixture ekle',
    );
    // Katalog duzeyinde negatif ornek HALA var: alarm bilerek yayin disi.
    expect(isHomeWidgetPublished(HomeWidgetProvider.alarm), isFalse);
    expect(_publishedAndroidNames, isNotEmpty);
  });

  test('refresh yalniz yayindaki saglayicilara gider', () async {
    await service.refresh();

    expect(spy.updatedAndroidNames, _publishedAndroidNames);
    expect(spy.turns, _publishedAndroidNames.length);
  });

  test('acikca istenen saglayici kumesi disina yayin gitmez', () async {
    await service.refresh(widgets: _statsWidgets);

    expect(
      spy.updatedAndroidNames,
      _statsWidgets.map((widget) => widget.androidName).toList(),
    );
    expect(spy.turns, _statsWidgets.length);
  });

  test('snapshot 17 anahtar tasir, yalniz OKUNAN 10 tanesi yazilir', () async {
    final snapshot = AndroidWidgetSnapshot.placeholder(l10n);
    expect(snapshot.toWidgetData().length, 17);
    expect(StudyHomeWidget.anyPublishedConsumesWidgetData, isTrue);

    await service.saveSnapshot(snapshot);

    // Yazilan kume, saglayicilarin Kotlin'de GERCEKTEN okudugu kumedir.
    expect(spy.savedKeys.toSet(), StudyHomeWidget.writableKeys);
    expect(spy.turns, StudyHomeWidget.writableKeys.length);
    // Okuyucusu olmayan yedi anahtar (dort sayac + uc oksuz istatistik)
    // tek bir kanal turu bile harcamaz -- WP-558'in asil kazanimi budur.
    expect(spy.savedKeys, isNot(contains('timer_elapsed')));
    expect(spy.savedKeys, isNot(contains('stats_today')));
  });

  test('tam istatistik turu: onceden 37 kanal turu, simdi 23', () async {
    // `_syncStatsWidgets` bir turu: 2 x saveSnapshot + 3 x updateWidget.
    // Eskiden 2x17+3 = 37 idi; simdi 2x10+3 = 23.
    await service.saveSnapshot(AndroidWidgetSnapshot.placeholder(l10n));
    await service.saveSnapshot(AndroidWidgetSnapshot.placeholder(l10n));
    await service.refresh(widgets: _statsWidgets);

    expect(spy.turns, 2 * StudyHomeWidget.writableKeys.length + 3);
    expect(spy.turns, 23);
  });

  test('sayac turu: onceden 18 kanal turu, simdi yalniz 1 yeniden cizim',
      () async {
    await service.saveSnapshot(
      AndroidWidgetSnapshot.timer(
        l10n: l10n,
        elapsed: '00:24:59',
        status: 'Calisiyor',
        action: 'Durdur',
      ),
    );
    await service.refresh(widgets: const [StudyHomeWidget.timer]);

    expect(spy.savedKeys, isEmpty, reason: 'sayac widgeti prefs\'ten okur');
    expect(spy.updatedAndroidNames, ['TimerWidgetProvider']);
    expect(spy.turns, 1);
  });

  test('seedPlaceholder yalnizca yayindaki widgeti cizer', () async {
    await service.seedPlaceholder();

    expect(spy.savedKeys.toSet(), StudyHomeWidget.writableKeys);
    expect(spy.updatedAndroidNames, _publishedAndroidNames);
    expect(
      spy.turns,
      _publishedAndroidNames.length + StudyHomeWidget.writableKeys.length,
    );
  });
}
