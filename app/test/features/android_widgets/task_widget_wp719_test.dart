// WP-719: widget'lar UYGULAMADA SECILI dili konusur + gorev widget'i
// icerigine gore kucululur.
//
// Sahada olculen iki kusur:
//
//  1. **Iki dil bir ekranda.** Uygulama Turkce iken ana ekranda gorev widget'i
//     "Tasks / No tasks yet", siralama "9 hours 34 minutes" yaziyordu; ayni
//     ekranda geri sayim widget'i "76 gun kaldi" diyordu. Fark KAYNAKTA:
//     geri sayimin metni native `getString` ile gelir (`CountdownWidget.kt:185`
//     -> `values-tr/strings.xml:82`), digerlerinin metni Dart'tan gelir ve Dart
//     tarafi `activeAppLocale` adli **degisken bir global**e bakar
//     (`system_localizations.dart`). O global CIHAZ dilinden tohumlanir ve
//     ancak `MaterialApp` kurulunca kullanicinin tercihine duzeltilir; widget
//     aynasini once yazan her yol (arka plan isolate'i, acilis turu) yanlis
//     dili diske yazar ve orada KALIR.
//
//  2. **Kucullmeyen kutu.** Kart `layout_height="match_parent"` idi: icerik bir
//     satir da olsa, hic de olsa, boyali kart kutunun tamamini kaplardi.
//     Ustelik gorunen satir sayisi kutuya degil kaba bir yukseklik SINIFINA
//     baglanmisti; 110dp'lik kutuda 3 satir + baslik cizilmeye calisiliyordu
//     (24 + 20 + 96 = 140dp) yani icerik kirpiliyordu.
//
// Iddialar bilerek ayrildi:
//  - Dil duzeltmesi geri alinirsa yalniz "dil" grubu duser.
//  - Kucultme geri alinirsa yalniz "olcu" grubu duser.
//  - Ana ekrandan isaretleme (WP-701) ve derin baglanti (WP-706) ayri grupta
//    korunur; ikisi de bu WP'de bozulmamali.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/l10n/system_localizations.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kotlinPath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/TaskWidget.kt';
const String _layoutPath = 'android/app/src/main/res/layout/odak_task_widget.xml';
const String _infoXmlPath =
    'android/app/src/main/res/xml/odak_task_widget_info.xml';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path yok');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

/// Yorumlari atar; `<!-- ... -->` icindeki ornek nitelik olculere karismasin.
String _stripComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// `android:id="@+id/<id>"` tasiyan elemanin acilis etiketi.
String _element(String xml, String id) {
  final clean = _stripComments(xml);
  final marker = clean.indexOf('android:id="@+id/$id"');
  expect(marker, greaterThan(-1), reason: '$id layout\'ta yok');
  final start = clean.lastIndexOf('<', marker);
  final end = clean.indexOf('>', marker);
  return clean.substring(start, end);
}

String? _attr(String element, String name) =>
    RegExp('android:$name="([^"]*)"').firstMatch(element)?.group(1);

int _dpAttr(String element, String name) {
  final raw = _attr(element, name);
  expect(raw, isNotNull, reason: 'android:$name beyan edilmemis');
  expect(raw, endsWith('dp'), reason: 'android:$name dp olmali: $raw');
  return int.parse(raw!.substring(0, raw.length - 2));
}

int _kotlinInt(String source, String name) {
  final match = RegExp(
    '^\\s*(?:internal\\s+)?const val $name\\s*=\\s*(\\d+)\\b',
    multiLine: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: '$name sabiti TaskWidget.kt icinde yok');
  return int.parse(match!.group(1)!);
}

/// Kullanicinin GORDUGU boyali kartin yuksekligi (dp).
///
/// Model layout'un KENDI beyanlarindan kurulur: kart `match_parent` ise cizim
/// kutunun tamami kadardir (icerik ne olursa olsun ayni sayi -> "kuculmuyor"
/// sikayetinin sayisal karsiligi). `wrap_content` ise yukseklik dolgu + baslik
/// + satir yuksekliklerinin toplamidir.
int _cardHeightDp({
  required String layout,
  required int boxHeightDp,
  required int rows,
  required bool titleVisible,
}) {
  final card = _element(layout, 'task_widget_root');
  if (_attr(card, 'layout_height') == 'match_parent') return boxHeightDp;
  final padding = _dpAttr(card, 'padding');
  final rowHeight = _dpAttr(_element(layout, 'task_widget_row_0'), 'minHeight');
  final titleBlock = titleVisible ? 20 : 0;
  final body = rows == 0 ? 20 : rows * rowHeight;
  return 2 * padding + titleBlock + body;
}

UserTask _task(String id, String title) => UserTask(
  id: id,
  title: title,
  completed: false,
  createdAt: DateTime.utc(2026, 8, 11),
  sortOrder: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP-719 · dil: widget uygulamada SECILI dili konusur', () {
    const channel = MethodChannel('home_widget');
    late List<String> refreshed;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      refreshed = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'updateWidget') {
              final args = call.arguments as Map<Object?, Object?>;
              refreshed.add(args['android'] as String? ?? '?');
            }
            return true;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      setActiveAppLocale(const Locale('en'));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    /// Sahadaki durum: kullanici uygulamada **Turkce** secmis, ama widget
    /// aynasini yazan tur `activeAppLocale` daha duzeltilmeden kosuyor
    /// (arka plan isolate'i / acilis turu). Global o an cihaz dilindedir.
    Future<ProviderContainer> boot(String languagePreference) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_language_preference': languagePreference,
      });
      final prefs = await SharedPreferences.getInstance();
      setActiveAppLocale(const Locale('en'));
      final now = DateTime.utc(2026, 8, 11, 12);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(
            InMemoryUserTaskRepository(now: () => now),
          ),
          userTaskClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      await container.read(userTasksProvider.future);
      return container;
    }

    Map<String, dynamic> mirrorOf(ProviderContainer container) =>
        jsonDecode(
              container
                  .read(sharedPreferencesProvider)
                  .getString(TaskWidgetPrefsKeys.mirror)!,
            )
            as Map<String, dynamic>;

    test('🔴 uygulama Turkce ise ayna Turkce yazilir (bos durum)', () async {
      final container = await boot('turkish');
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));

      await container.read(taskWidgetBridgeProvider).syncMirror(const []);

      final mirror = mirrorOf(container);
      expect(
        mirror['title'],
        tr.taskListTitle,
        reason:
            'widget basligi cihaz dilinden geliyor; kullanici uygulamada '
            'Turkce secmisken ana ekranda "Tasks" goruyor',
      );
      expect(
        mirror['empty'],
        tr.taskListEmpty,
        reason: 'bos durum metni de uygulama dilinde olmali',
      );
    });

    test('🔴 uygulama Ingilizce ise ayna Ingilizce yazilir', () async {
      final container = await boot('english');
      setActiveAppLocale(const Locale('tr')); // global TERS yonde bayat
      final en = await AppLocalizations.delegate.load(const Locale('en'));

      await container.read(taskWidgetBridgeProvider).syncMirror([
        _task('a', 'Matematik testi'),
      ]);

      expect(mirrorOf(container)['title'], en.taskListTitle);
      expect(mirrorOf(container)['empty'], en.taskListEmpty);
    });

    test('🔴 ayna yazildiktan sonra ORTAK yukleyici de dogru dili verir', () async {
      // Siralama/hedef widget'larinin metni `loadSystemLocalizations()`
      // uzerinden gider (`study_providers.dart:3009`). Ayni turda etkin dil
      // duzeltilmezse "9 hours 34 minutes" Ingilizce kalir.
      final container = await boot('turkish');

      await container.read(taskWidgetBridgeProvider).syncMirror(const []);

      final l10n = await loadSystemLocalizations();
      expect(l10n.localeName, 'tr');
      expect(activeAppLocale.languageCode, 'tr');
    });

    test('tercih `system` iken cihaz dili kullanilir', () async {
      final container = await boot('system');
      final expected = await AppLocalizations.delegate.load(
        resolvePreferredAppLocale(platformLocale(), AppLanguage.system),
      );

      await container.read(taskWidgetBridgeProvider).syncMirror(const []);

      expect(mirrorOf(container)['title'], expected.taskListTitle);
    });

    test('WP-701 KORUNUYOR: ana ekrandan isaretleme acilista uygulanir', () async {
      final container = await boot('turkish');
      final task = await container
          .read(userTaskActionsProvider)
          .add(rawTitle: 'Matematik testi');
      await container
          .read(sharedPreferencesProvider)
          .setString(
            TaskWidgetPrefsKeys.pending,
            jsonEncode({
              'ops': [
                {'id': 'o1', 'taskId': task!.id, 'done': true, 'at': '1'},
              ],
            }),
          );

      await container.read(taskWidgetBridgeProvider).start();

      expect(
        container.read(userTasksProvider).value!.single.completed,
        isTrue,
        reason: 'WP-701 yolu bozuldu: ana ekrandaki isaret kayboldu',
      );
      expect(refreshed, contains(StudyHomeWidget.task.androidName));
    });
  });

  group('WP-719 · olcu: kart icerigine gore kuculur', () {
    late String layout;
    late String kotlin;

    setUpAll(() {
      layout = _read(_layoutPath);
      kotlin = _read(_kotlinPath);
    });

    test('🔴 boyali kart icerigi kadar yer kaplar (match_parent degil)', () {
      final card = _element(layout, 'task_widget_root');
      expect(
        _attr(card, 'layout_height'),
        'wrap_content',
        reason:
            'kart match_parent ise bir satirlik icerik de kutunun tamamini '
            'boyar; sahibin gordugu "kocaman bos alan" budur',
      );
      // Kart artik kutuyu doldurmadigina gore bir kapsayiciya ihtiyaci var;
      // yoksa RemoteViews kokunun yuksekligi belirsiz kalir.
      final frame = _element(layout, 'task_widget_frame');
      expect(_attr(frame, 'layout_height'), 'match_parent');
      expect(
        _attr(frame, 'gravity'),
        contains('center_vertical'),
        reason: 'kisa kart kutunun icinde ortalanmali, tepeye yapismamali',
      );
      expect(
        _attr(frame, 'background'),
        isNull,
        reason: 'boyayan tek eleman kart olmali; kapsayici seffaf kalir',
      );
    });

    test('🔴 yukseklik tablosu: bos < 1 gorev < 3 gorev < 5 gorev', () {
      const box = 250; // en buyuk kutu; icerik tabloyu belirlesin
      int heightFor(int rows) => _cardHeightDp(
        layout: layout,
        boxHeightDp: box,
        rows: rows,
        titleVisible: true,
      );

      final table = {for (final rows in const [0, 1, 3, 5]) rows: heightFor(rows)};
      expect(
        table[0]!,
        lessThan(table[1]!),
        reason: 'bos durumda kart kuculmuyor: ${table[0]} dp / ${table[1]} dp',
      );
      expect(table[1]!, lessThan(table[3]!));
      expect(table[3]!, lessThan(table[5]!));
      expect(
        table[0]!,
        lessThan(box ~/ 2),
        reason:
            'bos durumda kart kutunun yarisindan kisa olmali (${table[0]} dp)',
      );
    });

    test('🔴 gorunen satir sayisi KUTUYA sigar (sinifa degil)', () {
      // WP-701 satir sayisini kaba yukseklik SINIFINDAN turetiyordu ve
      // modelinde satir yuksekligi ~17dp sayiliyordu; layout'ta satir
      // `minHeight="32dp"`. 110dp kutuda 3 satir + baslik = 140dp -> kirpik.
      expect(
        kotlin,
        contains('fun taskWidgetRowCapacity('),
        reason: 'satir sayisi gercek kutu yuksekliginden turetilmeli',
      );
      final rowHeight = _dpAttr(
        _element(layout, 'task_widget_row_0'),
        'minHeight',
      );
      expect(
        _kotlinInt(kotlin, 'TASK_ROW_HEIGHT_DP'),
        rowHeight,
        reason:
            'Kotlin satir yuksekligi layout ile ayrisirsa kapasite hesabi '
            'kagit uzerinde kalir',
      );

      final padding = _dpAttr(_element(layout, 'task_widget_root'), 'padding');
      final titleBlock = _kotlinInt(kotlin, 'TASK_TITLE_HEIGHT_DP');
      // Her kutu boyunda: cizilen kart kutuya sigmali.
      for (final box in const [56, 80, 110, 180, 250]) {
        final capacity =
            ((box - 2 * padding - titleBlock) ~/ rowHeight).clamp(0, 5);
        final drawn = 2 * padding + titleBlock + capacity * rowHeight;
        expect(
          drawn,
          lessThanOrEqualTo(box),
          reason: '$box dp kutuda $capacity satir tasar ($drawn dp)',
        );
      }
    });

    test('🔴 kucultme sinirinda kart kirpilmadan cizilebilir', () {
      final info = _stripComments(_read(_infoXmlPath));
      final minResizeHeight = int.parse(
        RegExp(
          r'android:minResizeHeight="(\d+)dp"',
        ).firstMatch(info)!.group(1)!,
      );
      final maxResizeHeight = int.parse(
        RegExp(
          r'android:maxResizeHeight="(\d+)dp"',
        ).firstMatch(info)!.group(1)!,
      );
      final padding = _dpAttr(_element(layout, 'task_widget_root'), 'padding');
      final rowHeight = _dpAttr(
        _element(layout, 'task_widget_row_0'),
        'minHeight',
      );

      expect(
        minResizeHeight,
        lessThan(80),
        reason:
            'sahip "kuculmuyor" dedi; alt sinir en az bir satirlik karta '
            'inmeli',
      );
      expect(
        2 * padding + rowHeight,
        lessThanOrEqualTo(minResizeHeight),
        reason: 'en kucuk kutuda tek satir bile sigmiyor',
      );
      // Ust sinir 5 satir + basliktan fazlasini vaat etmemeli; fazlasi bos
      // alandir.
      final tallestCard = 2 * (padding + 2) + 20 + 5 * rowHeight;
      expect(
        maxResizeHeight,
        lessThanOrEqualTo(tallestCard + rowHeight),
        reason:
            'ust sinir cizilebilen en uzun karttan ($tallestCard dp) cok '
            'daha uzun: aradaki fark bos alan',
      );
    });

    test('WP-706 KORUNUYOR: derin baglanti hedefleri duruyor', () {
      expect(kotlin, contains('WidgetDeepLink.ROUTE_TASKS'));
      for (final id in const [
        'R.id.task_widget_title',
        'R.id.task_widget_empty',
        'R.id.task_widget_root',
        'R.id.task_widget_frame',
      ]) {
        expect(
          kotlin.contains('setOnClickPendingIntent($id, openTasks)'),
          isTrue,
          reason: '$id gorev ekranina acilmiyor; kart kuculunce bos kalan '
              'alanin da bir hedefi olmali',
        );
      }
      expect(
        kotlin,
        contains('togglePendingIntent('),
        reason: 'satirlar hala ana ekrandan isaretlenebilmeli (WP-701)',
      );
    });

    test('prefs tip tuzagi: iki tarafin dokundugu deger metin kalir', () {
      for (final forbidden in const [
        'prefs.getInt(',
        'prefs.getLong(',
        'prefs.getBoolean(',
      ]) {
        expect(
          kotlin.contains(forbidden),
          isFalse,
          reason:
              'Dart setInt diske putLong yazar; native getInt '
              'ClassCastException ile SURECI oldurur (v58)',
        );
      }
    });
  });
}
