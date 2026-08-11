// WP-695: sinav geri sayimi ana ekran widget'i.
//
// Bu dosya bes kabul olcutunu olcer. Kritik nokta: widget'in ciziminin
// **Kotlin** tarafinda olmasi, Dart testinin "kaynakta cagri var" demeye
// kacmasini kolaylastirir. Bu depoda tam o kacis defalarca yesil yanan bos
// ozellik uretti (`bitmis-backend-baglanmamis-ui`). Bu yuzden burada olculen
// sey **iki dilin ortak sozlesmesidir**:
//
//   1. Uygulamanin GERCEKTEN prefs'e yazdigi JSON metni uretilir (sahte
//      SharedPreferences uzerinde `ExamListNotifier.add` kosturularak),
//   2. o metnin kimlik alani sabitlenip **Kotlin JVM testindeki fixture** ile
//      birebir karsilastirilir,
//   3. native tarafin okudugu anahtarin `flutter.` onekli hali `kExamListKey`
//      ile karsilastirilir.
//
// Boylece Dart yazar / Kotlin okur zinciri ayrisirsa kirmizi duser; JSON
// bicimi degisirse (WP-694 sunucu tasimasi) fixture bayatlar ve kapi bagirir.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kProviderClass = 'CountdownWidgetProvider';

String _read(String relativePath) =>
    File(relativePath).readAsStringSync().replaceAll('\r\n', '\n');

String _receiverHeader(String className) {
  final manifest = _read('android/app/src/main/AndroidManifest.xml');
  final start = manifest.indexOf('android:name=".widgets.$className"');
  expect(start, greaterThan(-1), reason: '$className manifest\'e kaydedilmemis');
  final blockStart = manifest.lastIndexOf('<receiver', start);
  final blockEnd = manifest.indexOf('>', start);
  return manifest.substring(blockStart, blockEnd);
}

void main() {
  group('1) katalog yayin bayragi', () {
    test('countdown katalogda var ve yayinda', () {
      expect(
        HomeWidgetProvider.values.map((p) => p.name),
        contains('countdown'),
        reason: 'geri sayim saglayicisi katalog enum\'unda yok',
      );
      final entry = kHomeWidgetCatalog.firstWhere(
        (e) => e.provider.androidClassName == _kProviderClass,
        orElse: () => throw StateError('katalogda $_kProviderClass girdisi yok'),
      );
      expect(entry.published, isTrue, reason: 'geri sayim yayinda degil');
      expect(
        publishedHomeWidgets.map((p) => p.androidClassName),
        contains(_kProviderClass),
        reason: 'sozlesme testinin okudugu yayin listesi geri sayimi tasimiyor',
      );
    });

    test('katalog ile boru hatti enum\'u ayrismiyor', () {
      final pipeline = StudyHomeWidget.values.where(
        (w) => w.androidName == _kProviderClass,
      );
      expect(
        pipeline,
        isNotEmpty,
        reason: 'yayin boru hatti geri sayim saglayicisini tanimiyor',
      );
      for (final widget in StudyHomeWidget.values) {
        expect(widget.androidName, widget.catalogProvider.androidClassName);
        expect(widget.isPublished, isHomeWidgetPublished(widget.catalogProvider));
      }
    });

    test('geri sayim widgetData tuketmez (17 anahtarlik firtina geri gelmesin)',
        () {
      final countdown = StudyHomeWidget.values.firstWhere(
        (w) => w.androidName == _kProviderClass,
        orElse: () => throw StateError('boru hattinda geri sayim yok'),
      );
      expect(
        countdown.consumesWidgetData,
        isFalse,
        reason: 'geri sayim prefs\'ten okur; widgetData tuketicisi ilan '
            'edilirse WP-558\'in kapattigi 17 kanal turu geri acilir',
      );
      // WP-708: bu satir eskiden `anyPublishedConsumesWidgetData` genel
      // bayragini `false` bekliyordu. WP-707 dort widget'i yayina alinca
      // bayrak `true` oldu ve iddia bayatladi. Genel bayragi gevsetmek
      // yerine iddia ASIL korudugu seye baglandi: geri sayimin kendi
      // anahtarlari yazilmaz, yani 17 anahtarlik firtina geri gelmez.
      expect(countdown.readKeys, isEmpty);
      expect(
        StudyHomeWidget.writableKeys.intersection(countdown.readKeys),
        isEmpty,
      );
    });
  });

  group('2) native kayit', () {
    test('manifest receiver\'i etkin ve exported', () {
      final header = _receiverHeader(_kProviderClass);
      expect(
        header.contains('android:enabled="false"'),
        isFalse,
        reason: 'yayindaki widget picker\'da gorunmez',
      );
      expect(header.contains('android:exported="true"'), isTrue);
      expect(header.contains('android:permission='), isFalse);

      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final metaIndex = manifest.indexOf(
        '@xml/odak_countdown_widget_info',
        manifest.indexOf('android:name=".widgets.$_kProviderClass"'),
      );
      expect(metaIndex, greaterThan(-1),
          reason: 'receiver kendi appwidget-provider tanimini gostermiyor');
    });

    test('*_info.xml boyut ve guncelleme araligi tasiyor', () {
      final info = _read('android/app/src/main/res/xml/odak_countdown_widget_info.xml');
      for (final attr in const [
        'android:minWidth=',
        'android:minHeight=',
        'android:updatePeriodMillis=',
        'android:initialLayout="@layout/odak_countdown_widget"',
        'android:previewLayout=',
        'android:resizeMode=',
      ]) {
        expect(info.contains(attr), isTrue, reason: '$attr eksik');
      }
    });

    test('saglayici sinifi ve duzeni dosyada var', () {
      expect(
        File('android/app/src/main/res/layout/odak_countdown_widget.xml').existsSync(),
        isTrue,
      );
      expect(
        Directory('android/app/src/main/kotlin')
            .listSync(recursive: true)
            .whereType<File>()
            .any((f) =>
                f.path.endsWith('.kt') &&
                f.readAsStringSync().contains('class $_kProviderClass')),
        isTrue,
        reason: '$_kProviderClass sinifi yok',
      );
    });
  });

  group('3) bos durum ekranda bir sey cizer', () {
    test('duzen bos-durum metnini varsayilan olarak tasiyor', () {
      final layout = _read('android/app/src/main/res/layout/odak_countdown_widget.xml');
      expect(
        layout.contains('@string/widget_countdown_empty'),
        isTrue,
        reason: 'veri yokken widget bos bir dikdortgen cizer',
      );
      // Gomulu metin yasak: kullaniciya donen her metin string kaynagindan.
      expect(
        RegExp(r'android:text="(?!@string/)').hasMatch(layout),
        isFalse,
        reason: 'duzende gomulu metin var (l10n_android_audit kirmizi verir)',
      );
    });

    test('EN/TR string anahtarlari esit', () {
      final en = _read('android/app/src/main/res/values/strings.xml');
      final tr = _read('android/app/src/main/res/values-tr/strings.xml');
      for (final key in const [
        'widget_countdown_empty',
        'widget_countdown_today',
        'widget_countdown_passed',
        'widget_countdown_days_left',
        'widget_countdown_default_name',
        'widget_countdown_title',
        'widget_label_countdown',
        'cd_countdown_widget',
      ]) {
        expect(en.contains('name="$key"'), isTrue, reason: 'EN $key yok');
        expect(tr.contains('name="$key"'), isTrue, reason: 'TR $key yok');
      }
    });
  });

  group('4) gun matematigi', () {
    test('gecmis tarih negatif, bugun sifir (Dart tarafi referans)', () {
      final now = DateTime.utc(2026, 8, 11, 12);
      expect(
        daysUntilExam(examDay: DateTime(2026, 8, 11), now: now),
        0,
      );
      expect(
        daysUntilExam(examDay: DateTime(2026, 8, 10), now: now),
        lessThan(0),
      );
    });

    test('Kotlin tarafi ayni gun matematigini negatif YAZMADAN cizer', () {
      final kt = _read(
        'android/app/src/test/kotlin/com/manilmax/online_study_room/'
        'widgets/CountdownWidgetModelWp695Test.kt',
      );
      // JVM testi olcumu yapar; burada testin var oldugu ve gecmis/bugun/bos
      // dallarini gercekten sinadigi dogrulanir (bayat kapi tuzagi).
      for (final marker in const [
        'CountdownState.PAST',
        'CountdownState.TODAY',
        'CountdownState.EMPTY',
        'CountdownState.FUTURE',
      ]) {
        expect(kt.contains(marker), isTrue, reason: '$marker sinanmamis');
      }
    });
  });

  group('5) Dart yazar / Kotlin okur zinciri', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(const {});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() => container.dispose());

    test('uygulamanin prefs\'e YAZDIGI metin Kotlin fixture\'i ile ayni', () async {
      await container
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 9, 1));

      final raw = prefs.getString(kExamListKey);
      expect(raw, isNotNull, reason: 'sinav prefs\'e hic yazilmadi');

      // Kimlik ve senkron damgasi her kosumda degisir; fixture sabitlerini
      // tasir. Geri kalan HER SEY pinlidir: alan adlari, sira, ic ice yapi.
      final normalized = raw!
          .replaceAll(RegExp(r'"id":"[^"]*"'), '"id":"fixture"')
          .replaceAll(RegExp(r'"updatedAt":"[^"]*"'), '"updatedAt":"STAMP"');
      expect(
        normalized,
        '{"entries":[{"id":"fixture","name":"YKS","day":"2026-09-01",'
        '"updatedAt":"STAMP"}],"priority":null,"synced":[],"deleted":[]}',
        reason: 'prefs bicimi degisti; native ayristirici bayatladi',
      );

      final kt = _read(
        'android/app/src/test/kotlin/com/manilmax/online_study_room/'
        'widgets/CountdownWidgetModelWp695Test.kt',
      );
      expect(
        kt.contains(normalized),
        isTrue,
        reason: 'Kotlin fixture uygulamanin urettigi metin DEGIL',
      );
    });

    test('native okunan anahtar kExamListKey ile ayni', () {
      final source = Directory('android/app/src/main/kotlin')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(
        source.contains('"flutter.$kExamListKey"'),
        isTrue,
        reason: 'native taraf baska bir anahtardan okuyor',
      );
    });

    test('yayin turunda geri sayim saglayicisina updateWidget gider', () async {
      const channel = MethodChannel('home_widget');
      final updated = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'updateWidget') {
          final args = call.arguments as Map<Object?, Object?>;
          updated.add(args['android'] as String? ?? '?');
        }
        return true;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await const AndroidWidgetService().refresh();
      expect(updated, contains(_kProviderClass));
    });
  });
}
