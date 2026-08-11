// WP-701: gorev ana ekran widget'i + ana ekrandan isaretleme.
//
// Dosyanin asil konusu **uygulama KAPALIYKEN yapilan isaretleme**dir. Dokunma
// aninda Flutter sureci cogu zaman yoktur; niyet Kotlin tarafinda kalici bir
// kuyruga yazilir, gercek `toggle` uygulama acilinca Dart'ta kosar. Bu yolun
// dort parcasi da ayri ayri olculur:
//
//   1. Ayna: Dart'in yazdigi JSON'u Kotlin AYNI anahtardan okuyor mu?
//   2. Iyimser cizim + kuyruk: Kotlin dokunusta ne yaziyor? (JVM testi
//      `TaskWidgetWp701Test.kt`; burada yalniz anahtar/tip sozlesmesi.)
//   3. Bosaltma: kuyruk gercek `toggle`a ceviriliyor mu?
//   4. Cift uygulama: ayni kuyruk iki kez islenirse isaretleme GERI DONMEZ.
//
// Iddialar bilerek ayrildi: kuyruk bosaltmayi kaldiran bir sabotaj yalniz (3)
// ve (4) grubunu dusurmeli; ayna/boyut/manifest iddialari ayakta kalmali.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kotlinDir =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets';
const String _infoXmlPath = 'android/app/src/main/res/xml/odak_task_widget_info.xml';
const String _layoutPath = 'android/app/src/main/res/layout/odak_task_widget.xml';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path yok');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String _manifest() => _read('android/app/src/main/AndroidManifest.xml');

/// Bir saglayicinin manifest'teki `<receiver …>` baslik blogu.
String _receiverHeader(String className) {
  final manifest = _manifest();
  final start = manifest.indexOf('android:name=".widgets.$className"');
  expect(start, greaterThan(-1), reason: '$className manifest\'te yok');
  final blockStart = manifest.lastIndexOf('<receiver', start);
  final blockEnd = manifest.indexOf('>', start);
  return manifest.substring(blockStart, blockEnd);
}

/// Kotlin kaynagindan `const val AD = "deger"` satirlari (yorumlar elenir).
Map<String, String> _kotlinStrings(String fileName) {
  final pattern = RegExp(r'^\s*(?:internal\s+)?const val (\w+)\s*=\s*"([^"]*)"');
  final values = <String, String>{};
  for (final line in _read('$_kotlinDir/$fileName').split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    final match = pattern.firstMatch(line);
    if (match != null) values[match.group(1)!] = match.group(2)!;
  }
  return values;
}

Map<String, int> _kotlinInts(String fileName) {
  final pattern = RegExp(r'^\s*(?:internal\s+)?const val (\w+)\s*=\s*(\d+)\b');
  final values = <String, int>{};
  for (final line in _read('$_kotlinDir/$fileName').split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    final match = pattern.firstMatch(line);
    if (match != null) values[match.group(1)!] = int.parse(match.group(2)!);
  }
  return values;
}

String? _attr(String xml, String name) {
  final stripped = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  return RegExp('android:$name="([^"]*)"').firstMatch(stripped)?.group(1);
}

int _dp(String xml, String name) {
  final raw = _attr(xml, name);
  expect(raw, isNotNull, reason: 'android:$name beyan edilmemis');
  expect(raw, endsWith('dp'), reason: 'android:$name dp olmali: $raw');
  return int.parse(raw!.substring(0, raw.length - 2));
}

int _int(String xml, String name) {
  final raw = _attr(xml, name);
  expect(raw, isNotNull, reason: 'android:$name beyan edilmemis');
  return int.parse(raw!);
}

/// Launcher hucre -> dp: `70 * n - 30` (1=40, 2=110, 3=180, 4=250, 5=320).
int _cellDp(int cells) => 70 * cells - 30;

UserTask _task(
  String id,
  String title, {
  bool completed = false,
  DateTime? archivedAt,
}) => UserTask(
  id: id,
  title: title,
  completed: completed,
  createdAt: DateTime.utc(2026, 8, 11),
  sortOrder: 0,
  archivedAt: archivedAt,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('WP-701 · ayna (Dart yazar, Kotlin okur)', () {
    test('ayna gorevleri, isaretli durumu ve l10n metinlerini tasir', () {
      final json =
          jsonDecode(
                encodeTaskWidgetMirror(
                  title: l10n.taskListTitle,
                  emptyLabel: l10n.taskListEmpty,
                  tasks: [
                    _task('a', 'Matematik testi'),
                    _task('b', 'Kelime ezberi', completed: true),
                  ],
                ),
              )
              as Map<String, dynamic>;

      expect(json['title'], l10n.taskListTitle);
      expect(json['empty'], l10n.taskListEmpty);
      final tasks = (json['tasks'] as List).cast<Map<String, dynamic>>();
      expect(tasks.map((t) => t['id']), ['a', 'b']);
      expect(tasks[0]['title'], 'Matematik testi');
      expect(tasks[0]['done'], isFalse);
      expect(
        tasks[1]['done'],
        isTrue,
        reason: 'isaretli gorev widget\'ta da isaretli gorunmeli',
      );
    });

    test('arsivli/bos gorev aynaya girmez, satir sayisi layout ile sinirli', () {
      final json =
          jsonDecode(
                encodeTaskWidgetMirror(
                  title: l10n.taskListTitle,
                  emptyLabel: l10n.taskListEmpty,
                  tasks: [
                    _task('arsiv', 'Silinmis', archivedAt: DateTime.utc(2026)),
                    _task('bos', '   '),
                    for (var i = 0; i < 9; i++) _task('t$i', 'Gorev $i'),
                  ],
                ),
              )
              as Map<String, dynamic>;

      final ids = (json['tasks'] as List)
          .cast<Map<String, dynamic>>()
          .map((t) => t['id'])
          .toList();
      expect(ids, hasLength(kTaskWidgetMaxRows));
      expect(ids.contains('arsiv'), isFalse, reason: 'arsivli gorev cizilmemeli');
      expect(ids.contains('bos'), isFalse);
      expect(ids.first, 't0', reason: 'sira korunmali: listenin basi ustte');
    });

    test('Kotlin AYNI prefs anahtarini okur (flutter. onekiyle)', () {
      final kotlin = _kotlinStrings('TaskWidget.kt');
      expect(kotlin, isNotEmpty, reason: 'regex hicbir sey yakalamadi');
      expect(kotlin['TASK_MIRROR_PREFS_KEY'], TaskWidgetPrefsKeys.androidMirror);
      expect(
        kotlin['TASK_PENDING_PREFS_KEY'],
        TaskWidgetPrefsKeys.androidPending,
      );
      expect(kotlin['TASK_PREFS_NAME'], 'FlutterSharedPreferences');
      expect(
        TaskWidgetPrefsKeys.androidMirror,
        '${TaskWidgetPrefsKeys.androidPrefix}${TaskWidgetPrefsKeys.mirror}',
      );
    });

    test('layout Kotlin\'in cizdigi kadar satir tasir', () {
      final layout = _read(_layoutPath);
      for (var i = 0; i < kTaskWidgetMaxRows; i++) {
        expect(
          layout.contains('@+id/task_widget_row_$i'),
          isTrue,
          reason: 'satir $i layout\'ta yok; Kotlin var olmayan id\'ye yazar',
        );
        expect(layout.contains('@+id/task_widget_box_$i'), isTrue);
        expect(layout.contains('@+id/task_widget_label_$i'), isTrue);
      }
      expect(
        layout.contains('@+id/task_widget_row_$kTaskWidgetMaxRows'),
        isFalse,
        reason: 'layout Dart sinirindan fazla satir vaat ediyor',
      );
    });
  });

  group('WP-701 · bekleyen kuyruk cozumu', () {
    test('ayni gorevin son niyeti kazanir', () {
      final ops = decodeTaskWidgetPending(
        jsonEncode({
          'ops': [
            {'id': 'o1', 'taskId': 'a', 'done': true, 'at': '1'},
            {'id': 'o2', 'taskId': 'b', 'done': true, 'at': '2'},
            {'id': 'o3', 'taskId': 'a', 'done': false, 'at': '3'},
          ],
        }),
      );

      expect(ops.map((op) => op.taskId), ['b', 'a']);
      expect(
        ops.firstWhere((op) => op.taskId == 'a').done,
        isFalse,
        reason: 'isaretleyip geri alan kullanicinin SON kararı uygulanmali',
      );
    });

    test('bozuk kayit kuyrugu dusurmez, o satir atlanir', () {
      expect(decodeTaskWidgetPending('bu json degil'), isEmpty);
      expect(decodeTaskWidgetPending(null), isEmpty);
      expect(decodeTaskWidgetPending('{"ops":"metin"}'), isEmpty);
      final ops = decodeTaskWidgetPending(
        jsonEncode({
          'ops': [
            {'id': 'o1', 'taskId': '', 'done': true},
            42,
            {'id': 'o2', 'taskId': 'a', 'done': true},
          ],
        }),
      );
      expect(ops.map((op) => op.taskId), ['a']);
    });
  });

  group('WP-701 · kuyruk gercek toggle\'a cevrilir', () {
    test('yalniz durumu FARKLI olan gorev toggle edilir', () async {
      final toggled = <String>[];
      final applied = await applyPendingTaskToggles(
        pending: const [
          TaskWidgetPendingToggle(opId: 'o1', taskId: 'a', done: true),
          TaskWidgetPendingToggle(opId: 'o2', taskId: 'b', done: true),
        ],
        tasks: [
          _task('a', 'Isaretlenecek'),
          _task('b', 'Zaten isaretli', completed: true),
        ],
        toggle: (id) async => toggled.add(id),
      );

      expect(toggled, ['a']);
      expect(applied, ['a'], reason: 'hedef durumdaki gorev bosa toggle edilmemeli');
    });

    test('uygulamada silinmis gorevin niyeti atlanir', () async {
      final toggled = <String>[];
      await applyPendingTaskToggles(
        pending: const [
          TaskWidgetPendingToggle(opId: 'o1', taskId: 'yok', done: true),
        ],
        tasks: [_task('a', 'Duran gorev')],
        toggle: (id) async => toggled.add(id),
      );

      expect(toggled, isEmpty);
    });

    test('🔴 kuyruk IKI kez islense de isaretleme geri donmez', () async {
      // Cift uygulama korumasi kuyrugun BICIMINDEDIR: kayit toggle degil
      // istenen mutlak durum tasir. Kuyruk toggle tasisaydi ikinci tur
      // kullanicinin isaretini geri alirdi.
      var task = _task('a', 'Matematik');
      final toggled = <String>[];
      Future<void> toggle(String id) async {
        toggled.add(id);
        task = task.copyWith(completed: !task.completed);
      }

      const pending = [
        TaskWidgetPendingToggle(opId: 'o1', taskId: 'a', done: true),
      ];

      await applyPendingTaskToggles(
        pending: pending,
        tasks: [task],
        toggle: toggle,
      );
      expect(task.completed, isTrue);

      await applyPendingTaskToggles(
        pending: pending,
        tasks: [task],
        toggle: toggle,
      );

      expect(toggled, ['a'], reason: 'ikinci tur toggle cagirmamali');
      expect(task.completed, isTrue, reason: 'isaretleme geri donmus');
    });
  });

  // 🔴 Asil iddia burada: kuyruk BOSALIYOR mu? Yukaridaki saf fonksiyon
  // testleri "backend bitmis ama baglanmamis" durumunu goremez — bu grup
  // gercek prefs + gercek gorev saglayicisi ile koprunun ta kendisini kosar.
  group('WP-701 · uygulama acilisi bekleyen kuyrugu bosaltir', () {
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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<(ProviderContainer, SharedPreferences)> boot() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
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
      return (container, prefs);
    }

    test('ana ekranda isaretlenen gorev acilista GERCEKTEN tamamlanir', () async {
      final (container, prefs) = await boot();
      final task = await container
          .read(userTaskActionsProvider)
          .add(rawTitle: 'Matematik testi');
      expect(task, isNotNull);

      // Kotlin'in uygulama kapaliyken yazdigi kuyruk.
      await prefs.setString(
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
        reason: 'kuyruk bosaltilmadi: kullanicinin isareti kayboldu',
      );
      expect(
        prefs.getString(TaskWidgetPrefsKeys.pending),
        isNull,
        reason: 'uygulanan kuyruk silinmeli',
      );
      final mirror =
          jsonDecode(prefs.getString(TaskWidgetPrefsKeys.mirror)!)
              as Map<String, dynamic>;
      final rows = (mirror['tasks'] as List).cast<Map<String, dynamic>>();
      expect(rows.single['title'], 'Matematik testi');
      expect(rows.single['done'], isTrue, reason: 'ayna taze durumu yazmali');
      expect(
        refreshed,
        contains(StudyHomeWidget.task.androidName),
        reason: 'ayna yazildi ama widget yeniden cizilmedi',
      );
    });

    test('silinmis gorevin niyeti kuyrugu tikamaz', () async {
      final (container, prefs) = await boot();
      await prefs.setString(
        TaskWidgetPrefsKeys.pending,
        jsonEncode({
          'ops': [
            {'id': 'o1', 'taskId': 'artik-yok', 'done': true, 'at': '1'},
          ],
        }),
      );

      await container.read(taskWidgetBridgeProvider).start();

      expect(prefs.getString(TaskWidgetPrefsKeys.pending), isNull);
      expect(container.read(userTasksProvider).value, isEmpty);
    });

    test('gorev listesi degisince ayna kendiliginden guncellenir', () async {
      final (container, _) = await boot();
      final prefs = container.read(sharedPreferencesProvider);
      await container.read(taskWidgetBridgeProvider).start();
      refreshed.clear();

      await container
          .read(userTaskActionsProvider)
          .add(rawTitle: 'Kelime ezberi');
      // Dinleyici mikro-görev sırasında koşar.
      await Future<void>.delayed(Duration.zero);

      expect(
        prefs.getString(TaskWidgetPrefsKeys.mirror),
        contains('Kelime ezberi'),
        reason:
            'ayna yalniz acilista yazilirsa widget uygulamadaki degisikligi '
            'hic gormez',
      );
      expect(refreshed, contains(StudyHomeWidget.task.androidName));
    });
  });

  group('WP-701 · native tip tuzagi (putLong/getInt)', () {
    test('Kotlin prefs\'ten sayi/boolean OKUMAZ, yalniz metin', () {
      for (final fileName in const ['TaskWidget.kt', 'TaskActionReceiver.kt']) {
        final source = _read('$_kotlinDir/$fileName');
        for (final forbidden in const [
          'prefs.getInt(',
          'prefs.getLong(',
          'prefs.getBoolean(',
          'prefs.getStringSet(',
        ]) {
          expect(
            source.contains(forbidden),
            isFalse,
            reason:
                '$fileName $forbidden kullaniyor: Dart setInt diske putLong '
                'yazar, native getInt ClassCastException firlatir ve '
                'BroadcastReceiver icinde SURECI oldurur (v58)',
          );
        }
      }
      // Yazma tarafi da metin olmali; kuyruktaki zaman damgasi bile string.
      final receiver = _read('$_kotlinDir/TaskActionReceiver.kt');
      expect(receiver.contains('putString('), isTrue);
      expect(receiver.contains('putLong('), isFalse);
      expect(receiver.contains('putInt('), isFalse);
    });

    test('receiver govdesi runCatching ile korunuyor', () {
      final receiver = _read('$_kotlinDir/TaskActionReceiver.kt');
      expect(
        receiver.contains('runCatching'),
        isTrue,
        reason:
            'receiver icinde yakalanmayan istisna uygulama surecini dusurur',
      );
    });
  });

  group('WP-701 · katalog <-> manifest esligi', () {
    test('gorev widget\'i yayinda ve tazeleme yolu var', () {
      expect(isHomeWidgetPublished(HomeWidgetProvider.task), isTrue);
      expect(
        hasHomeWidgetRefreshPath(HomeWidgetProvider.task),
        isTrue,
        reason: 'yayinda ama guncelleme yolu yoksa widget bir kez cizilir',
      );
      expect(
        StudyHomeWidget.task.catalogProvider,
        HomeWidgetProvider.task,
      );
      expect(
        StudyHomeWidget.task.consumesWidgetData,
        isFalse,
        reason:
            'ayna kendi prefs anahtarindan okunur; true yazmak WP-558 boru '
            'hattini geri acardi',
      );
    });

    test('manifest saglayiciyi yayinda tutuyor (enabled bayragi yok)', () {
      final header = _receiverHeader('TaskWidgetProvider');
      expect(
        header.contains('android:enabled="false"'),
        isFalse,
        reason: 'katalog yayinda diyor, manifest pickerdan dusuruyor',
      );
      expect(header.contains('android:exported="true"'), isTrue);
      expect(header.contains('android:permission='), isFalse);
      expect(
        _manifest().contains('android:resource="@xml/odak_task_widget_info"'),
        isTrue,
      );
    });

    test('dokunma alicisi disariya kapali ve action iki tarafta ayni', () {
      final header = _receiverHeader('TaskActionReceiver');
      expect(
        header.contains('android:exported="false"'),
        isTrue,
        reason: 'baska uygulama gorev isaretleyebilmemeli',
      );

      final action = RegExp(
        r'const val ACTION_TOGGLE_TASK = "([^"]+)"',
      ).firstMatch(_read('$_kotlinDir/TaskActionReceiver.kt'))?.group(1);
      expect(action, isNotNull);
      expect(
        _manifest().contains('<action android:name="$action" />'),
        isTrue,
        reason: 'manifest filtresi Kotlin sabitiyle ayrisirsa dokunma dusmez',
      );
    });
  });

  group('WP-701 · boyut ve esneklik', () {
    test('alt VE ust sinir yazili, iki surum ayni varsayilani soyler', () {
      final xml = _read(_infoXmlPath);

      expect(_attr(xml, 'resizeMode'), 'horizontal|vertical');

      final minWidth = _dp(xml, 'minWidth');
      final minHeight = _dp(xml, 'minHeight');
      final targetCellWidth = _int(xml, 'targetCellWidth');
      final targetCellHeight = _int(xml, 'targetCellHeight');
      final minResizeWidth = _dp(xml, 'minResizeWidth');
      final minResizeHeight = _dp(xml, 'minResizeHeight');
      final maxWidth = _dp(xml, 'maxResizeWidth');
      final maxHeight = _dp(xml, 'maxResizeHeight');

      // Android 12+ `targetCell*`e, oncesi `minWidth/minHeight`e bakar.
      expect(minWidth, _cellDp(targetCellWidth));
      expect(minHeight, _cellDp(targetCellHeight));
      // Sahibin sarti: varsayilan olculu acilsin.
      expect(targetCellWidth, lessThanOrEqualTo(3));
      expect(targetCellHeight, lessThanOrEqualTo(2));
      // Iki yonde de hareket alani olsun.
      expect(minResizeWidth, lessThan(minWidth));
      expect(minResizeHeight, lessThan(minHeight));
      expect(maxWidth, greaterThan(minWidth));
      expect(maxHeight, greaterThan(minHeight));
      expect(maxWidth, lessThanOrEqualTo(_cellDp(5)));
      expect(maxHeight, lessThanOrEqualTo(_cellDp(4)));
    });

    test('Kotlin esikleri [minResize, maxResize] araliginda', () {
      final xml = _read(_infoXmlPath);
      final constants = _kotlinInts('TaskWidget.kt');
      for (final name in const [
        'WIDGET_TASK_DEFAULT_WIDTH_DP',
        'WIDGET_TASK_DEFAULT_HEIGHT_DP',
        'WIDGET_TASK_MEDIUM_WIDTH_DP',
        'WIDGET_TASK_WIDE_WIDTH_DP',
        'WIDGET_TASK_MEDIUM_HEIGHT_DP',
        'WIDGET_TASK_TALL_HEIGHT_DP',
      ]) {
        expect(constants.containsKey(name), isTrue, reason: '$name yok');
      }

      // Varsayilan boyut iki tarafta ayni sayiyi soylemeli.
      expect(constants['WIDGET_TASK_DEFAULT_WIDTH_DP'], _dp(xml, 'minWidth'));
      expect(constants['WIDGET_TASK_DEFAULT_HEIGHT_DP'], _dp(xml, 'minHeight'));

      expect(
        constants['WIDGET_TASK_MEDIUM_WIDTH_DP']!,
        greaterThan(_dp(xml, 'minResizeWidth')),
      );
      expect(
        constants['WIDGET_TASK_WIDE_WIDTH_DP']!,
        greaterThan(constants['WIDGET_TASK_MEDIUM_WIDTH_DP']!),
      );
      expect(
        constants['WIDGET_TASK_WIDE_WIDTH_DP']!,
        lessThanOrEqualTo(_dp(xml, 'maxResizeWidth')),
      );
      expect(
        constants['WIDGET_TASK_TALL_HEIGHT_DP']!,
        greaterThan(constants['WIDGET_TASK_MEDIUM_HEIGHT_DP']!),
      );
      expect(
        constants['WIDGET_TASK_TALL_HEIGHT_DP']!,
        lessThanOrEqualTo(_dp(xml, 'maxResizeHeight')),
      );
    });

    test('yeniden boyutlandirma gercekten yeniden cizer', () {
      // WP-699 kok kusuru: `resizeMode` tek basina yetmez.
      final source = _read('$_kotlinDir/TaskWidget.kt');
      final classStart = source.indexOf('class TaskWidgetProvider ');
      expect(classStart, greaterThan(-1));
      expect(
        source.substring(classStart).contains(
          'override fun onAppWidgetOptionsChanged(',
        ),
        isTrue,
        reason:
            'boyut degisince onUpdate cagrilmaz; updatePeriodMillis=0 oldugu '
            'icin satir sayisi ASLA degismezdi',
      );
    });
  });
}
