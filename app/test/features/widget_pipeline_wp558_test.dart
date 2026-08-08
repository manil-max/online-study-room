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

  test('test bos degil: bugun en az bir saglayici yayindan dusuk', () {
    expect(
      StudyHomeWidget.values.where((widget) => !widget.isPublished),
      isNotEmpty,
      reason: 'hepsi yayindaysa asagidaki allowlist testleri hicbir sey '
          'kanitlamaz',
    );
    expect(_publishedAndroidNames, isNotEmpty);
  });

  test('yayinda olmayan saglayiciya updateWidget GONDERILMEZ', () async {
    await service.refresh();

    expect(spy.updatedAndroidNames, _publishedAndroidNames);
    expect(spy.turns, _publishedAndroidNames.length);
  });

  test('acikca istenen kapali saglayici da yayin almaz', () async {
    await service.refresh(widgets: _statsWidgets);

    expect(spy.updatedAndroidNames, isEmpty);
    expect(spy.turns, 0, reason: 'kapali widget icin tek kanal turu bile yok');
  });

  test('snapshot 17 anahtar tasir ama okuyucusu yoksa hicbiri yazilmaz',
      () async {
    final snapshot = AndroidWidgetSnapshot.placeholder(l10n);
    // Olcum: eski davranista tur basina bu kadar ayri `saveWidgetData` vardi.
    expect(snapshot.toWidgetData().length, 17);
    expect(StudyHomeWidget.anyPublishedConsumesWidgetData, isFalse);

    await service.saveSnapshot(snapshot);

    expect(spy.savedKeys, isEmpty);
    expect(spy.turns, 0);
  });

  test('tam istatistik turu: onceden 37 kanal turu, simdi 0', () async {
    // `_syncStatsWidgets` bir turu: 2 x saveSnapshot (17) + 3 x updateWidget.
    await service.saveSnapshot(AndroidWidgetSnapshot.placeholder(l10n));
    await service.saveSnapshot(AndroidWidgetSnapshot.placeholder(l10n));
    await service.refresh(widgets: _statsWidgets);

    expect(spy.turns, 0);
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

    expect(spy.savedKeys, isEmpty);
    expect(spy.updatedAndroidNames, _publishedAndroidNames);
    expect(spy.turns, _publishedAndroidNames.length);
  });
}
