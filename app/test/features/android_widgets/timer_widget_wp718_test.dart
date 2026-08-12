// WP-718 — sayac widget'lari: 1x1 okunurluk, ders hafizasi, ders secimi,
// minimal sayac.
//
// Bu dosya BEYAN tarafini olcer (layout/xml/manifest/Kotlin kaynagi) ve en
// onemlisi **iki uclu** anahtar sozlesmesini: native tarafin okudugu prefs
// anahtarlari Dart'in yazdigi anahtarlarla birebir ayni mi?
//
// 🔴 Neden iki uclu. Bu depoda cihaz senkronu WP-341'den WP-373'e kadar OLU
// kaldi cunku iki taraf farkli sozcuk kullaniyordu ve hicbir test ikisini yan
// yana koymuyordu. Ders hafizasi tam olarak ayni bicimde sessizce olebilir:
// native yanlis anahtari okur, hicbir sey patlamaz, kullanici sadece "widget
// dersimi hatirlamiyor" der.
//
// Davranis tarafi (punto aritmetigi, halka, tercih dogrulamasi) JVM testinde:
// `android/app/src/test/kotlin/.../widgets/TimerWidgetWp718Test.kt`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';

const String _kotlinDir =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets';
const String _layoutDir = 'android/app/src/main/res/layout';
const String _xmlDir = 'android/app/src/main/res/xml';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path yok');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String _manifest() => _read('android/app/src/main/AndroidManifest.xml');

/// `android:ad="deger"`; yorum bloklari elenir (WP-640 tuzagi: yorumdaki
/// ornek nitelik gercek nitelik sanilmasin).
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

/// Launcher hucre -> dp: `70 * n - 30` (1=40, 2=110, 3=180, 4=250).
int _cellDp(int cells) => 70 * cells - 30;

/// `<receiver …>` acilis etiketi.
String _receiverHeader(String className) {
  final manifest = _manifest();
  final start = manifest.indexOf('android:name=".widgets.$className"');
  expect(start, greaterThan(-1), reason: '$className manifest\'te yok');
  return manifest.substring(
    manifest.lastIndexOf('<receiver', start),
    manifest.indexOf('>', start),
  );
}

/// Bir XML dugumunun (ornegin belirli bir `TextView`) nitelik blogu.
String _viewBlock(String layout, String viewId) {
  final start = layout.indexOf('android:id="@+id/$viewId"');
  expect(start, greaterThan(-1), reason: '$viewId layout\'ta yok');
  final blockStart = layout.lastIndexOf('<', start);
  final blockEnd = layout.indexOf('>', start);
  return layout.substring(blockStart, blockEnd);
}

void main() {
  // =========================================================================
  // IS 1 — 1x1 okunabilirlik + 48dp dokunma hedefi
  // =========================================================================
  group('WP-718 · IS 1 · okunurluk ve dokunma hedefi', () {
    test('Baslat/Durdur hapi 48dp — eski 32dp degil', () {
      final layout = _read('$_layoutDir/odak_timer_widget.xml');
      final action = _viewBlock(layout, 'timer_widget_action');
      // 🔴 Olculen "once": minHeight=32dp. Android'in widget kilavuzundaki
      // asgari dokunma hedefi 48dp; 32dp onun ucte ikisi.
      expect(
        _attr(action, 'minHeight'),
        '48dp',
        reason: 'dokunma hedefi yine kilavuzun altinda',
      );
      expect(
        action.contains('android:layout_width="0dp"'),
        isTrue,
        reason:
            'hap sabit genislikte: ders hapi gizlendiginde satirin tamamini '
            'kaplamaz ve hedef gereksiz kucuk kalir',
      );
      expect(action.contains('android:layout_weight="1"'), isTrue);
    });

    test('layout ve Kotlin AYNI punto sayisini soyler', () {
      // previewLayout (widget secicisindeki onizleme) `onUpdate` calismadan
      // cizilir; XML'deki punto orada gorunen seydir. Kotlin ile ayrisirsa
      // kullanici secicide baska, ana ekranda baska bir sey gorur.
      final layout = _read('$_layoutDir/odak_timer_widget.xml');
      final kotlin = _read('$_kotlinDir/StudyWidgetProviders.kt');
      final narrow = RegExp(
        r'val timerTime = SpRamp\((\d+)f',
      ).firstMatch(kotlin);
      expect(narrow, isNotNull, reason: 'timerTime merdiveni bulunamadi');
      expect(
        _attr(_viewBlock(layout, 'timer_widget_elapsed'), 'textSize'),
        '${narrow!.group(1)}sp',
      );
      // Sabotaj capasi: eski merdiven 15/22/30 idi.
      expect(
        int.parse(narrow.group(1)!),
        greaterThan(15),
        reason: 'en dar sinifta punto WP-718 oncesi degerine dondu',
      );
    });

    test('en kucuk boyutta kok baslat/durdur olur, derin baglanti degil', () {
      // Kontrol satiri o boyutta cizilmedigi icin kok tek aksiyondur; aksi
      // halde widget'in en kucuk halinde HICBIR aksiyonu kalmazdi.
      final kotlin = _read('$_kotlinDir/StudyWidgetProviders.kt');
      expect(
        kotlin.contains('if (controlsVisible) {'),
        isTrue,
        reason: 'kok tiklamasi boyuta bagli degil',
      );
      expect(kotlin.contains('timerControlsVisible(size.height)'), isTrue);
    });
  });

  // =========================================================================
  // IS 2 — ders hafizasi (iki uclu anahtar sozlesmesi)
  // =========================================================================
  group('WP-718 · IS 2 · ders hafizasi anahtarlari Dart ile ayni', () {
    late String receiver;
    setUpAll(() => receiver = _read('$_kotlinDir/TimerActionReceiver.kt'));

    /// Kotlin `internal const val AD = "deger"`.
    String kotlinConst(String name) {
      final match = RegExp(
        'const val $name = "([^"]*)"',
      ).firstMatch(receiver);
      expect(match, isNotNull, reason: '$name sabiti yok');
      return match!.group(1)!;
    }

    /// Dart `static const _ad = 'deger';`
    String dartConst(String path, String pattern) {
      final match = RegExp(pattern).firstMatch(_read(path));
      expect(match, isNotNull, reason: '$path icinde $pattern bulunamadi');
      return match!.group(1)!;
    }

    test('kalici tercih anahtari birebir ayni', () {
      // Dart: `_kSelectedStudySubjectPrefix` (study_providers.dart)
      final dart = dartConst(
        'lib/data/providers/study_providers.dart',
        r"_kSelectedStudySubjectPrefix = '([^']*)'",
      );
      expect(
        kotlinConst('WIDGET_SUBJECT_PREF_PREFIX'),
        'flutter.$dart',
        reason:
            'native yanlis anahtari okur: widget dersi HIC hatirlamaz ve '
            'hicbir sey patlamaz (sessiz kusur)',
      );
    });

    test('ders listesi aynasinin anahtari birebir ayni', () {
      // Dart: `subjectsCacheKey(userId)` (subject_providers.dart, WP-697)
      final dart = dartConst(
        'lib/data/providers/subject_providers.dart',
        r"subjectsCacheKey\(String userId\) => '([^']*)\$userId'",
      );
      expect(kotlinConst('WIDGET_SUBJECTS_CACHE_PREFIX'), 'flutter.$dart');
    });

    test('"ders yok" isareti birebir ayni', () {
      final dart = dartConst(
        'lib/data/providers/study_providers.dart',
        r"_kGeneralStudySubject = '([^']*)'",
      );
      expect(kotlinConst('WIDGET_SUBJECT_GENERAL'), dart);
    });

    test('KOSAN kosunun anlik goruntusu kalici tercih SANILMAZ', () {
      // 🔴 WP-697 dersi: `timer_active_subject` calisan sayacin snapshot'idir
      // ve durunca silinir (`study_providers.dart` -> stop yolunda
      // `prefs.remove(_kActiveSubject)`). Kalici hafiza icin okunamaz.
      final remembered = receiver.substring(
        receiver.indexOf('internal fun rememberedSubjectId('),
      );
      expect(
        remembered.contains('KEY_SUBJECT'),
        isFalse,
        reason:
            'kalici hafiza, sayac durunca SILINEN anahtardan okunuyor: '
            '"en son neyi kullandim" sorusu hep bos donerdi',
      );
      expect(remembered.contains('subjectPreferenceKey('), isTrue);
    });

    test('widget baslatmasi ders TASIR (eski hali bos gonderiyordu)', () {
      // 🔴 Kok neden: `StudyTimerService`in `ACTION_TOGGLE` dali
      // `subjectId = ""` yazar ve ders extra'sini hic okumaz. Bu yuzden
      // receiver bosta iken dogrudan `ACTION_START` gonderir.
      expect(receiver.contains('StudyTimerService.ACTION_START'), isTrue);
      expect(receiver.contains('subjectId = rememberedSubjectId(prefs)'), isTrue);
      // Durdurma yolu DEGISMEDI: `native_widget` kokenli durdurma karari
      // (ayna rolu, kuyruk, V2 zarfi) servisin isidir.
      expect(receiver.contains('StudyTimerService.ACTION_TOGGLE'), isTrue);
    });

    test('sayisal anahtar okunmaz — Dart setInt/native getInt tuzagi', () {
      // 🔴 Flutter `setInt` diske `putLong` yazar; ayni anahtari `getInt` ile
      // okumak `ClassCastException` firlatir ve BroadcastReceiver icinde bu,
      // uygulama SURECINI oldurur (v58 sahasindaki cokme).
      expect(
        receiver.contains('.getInt('),
        isFalse,
        reason: 'receiver bir sayisal anahtari dogrudan okuyor',
      );
      expect(receiver.contains('.getLong('), isFalse);
    });
  });

  // =========================================================================
  // IS 3 — widget'tan ders secimi
  // =========================================================================
  group('WP-718 · IS 3 · ders secimi uygulama KAPALIYKEN calisir', () {
    test('secim yolu Flutter motoru gerektirmez', () {
      final receiver = _read('$_kotlinDir/TimerActionReceiver.kt');
      // Yol: widget -> BroadcastReceiver -> prefs. Aktivite acilmaz, method
      // channel yoktur, Dart calismaz.
      expect(receiver.contains('ACTION_CYCLE_SUBJECT'), isTrue);
      expect(
        receiver.contains('MethodChannel') ||
            receiver.contains('FlutterEngine') ||
            receiver.contains('startActivity'),
        isFalse,
        reason:
            'ders secimi uygulamayi acmaya/Dart calistirmaya bagliysa '
            'uygulama kapaliyken calismaz',
      );
      // Yazim `commit()` (senkron): `apply()` ile yazilan deger, hemen
      // ardindan gelen widget tazelemesinde henuz diskte olmayabilirdi.
      expect(receiver.contains('.commit()'), isTrue);
    });

    test('receiver iki aksiyonu da manifest\'te beyan eder', () {
      final header = _manifest();
      expect(
        header.contains(
          '<action android:name="com.manilmax.online_study_room'
          '.ACTION_CYCLE_WIDGET_SUBJECT" />',
        ),
        isTrue,
      );
      expect(
        _receiverHeader('TimerActionReceiver').contains(
          'android:exported="false"',
        ),
        isTrue,
        reason: 'WP-118: yalniz kendi PendingIntent\'imiz tetiklemeli',
      );
    });

    test('kosarken ders degistirilemez (Dart ile ayni kural)', () {
      final receiver = _read('$_kotlinDir/TimerActionReceiver.kt');
      final cycle = receiver.substring(
        receiver.indexOf('private fun handleCycleSubject('),
      );
      expect(
        cycle.contains('if (TimerStateStore.isRunning(prefs)) return@runCatching'),
        isTrue,
        reason:
            'kosarken ders degisirse yazilmakta olan oturumun dersi '
            'ortasinda degisir (Dart `selectSubject` de bunu reddeder)',
      );
    });
  });

  // =========================================================================
  // IS 4 — minimal sayac widget'i
  // =========================================================================
  group('WP-718 · IS 4 · minimal sayac widget\'i', () {
    late String info;
    setUpAll(
      () => info = _read('$_xmlDir/odak_minimal_timer_widget_info.xml'),
    );

    test('varsayilan boyut iki kanalda da AYNI seyi soyler', () {
      // Android 12+ `targetCell*`e, oncesi `minWidth/minHeight`e bakar.
      // Ayrisirlarsa ayni widget surume gore farkli boyutta acilir.
      final targetW = int.parse(_attr(info, 'targetCellWidth')!);
      final targetH = int.parse(_attr(info, 'targetCellHeight')!);
      expect(_dp(info, 'minWidth'), _cellDp(targetW));
      expect(_dp(info, 'minHeight'), _cellDp(targetH));
      expect(targetW, 2, reason: 'varsayilan 2x1 olmali (gerekce info xml\'de)');
      expect(targetH, 1);
    });

    test('1x1 GERCEKTEN ulasilabilir — sayac widget\'inda degildi', () {
      // Sahibin istegi: "1x1'lik devam etsin". Sayac widget'inin alt siniri
      // 110x80dp, yani tek hucre hic secilemiyor.
      expect(_dp(info, 'minResizeWidth'), _cellDp(1));
      expect(_dp(info, 'minResizeHeight'), _cellDp(1));
      expect(_attr(info, 'resizeMode'), 'horizontal|vertical');
      // Ust sinir: minimal kalmali.
      expect(_dp(info, 'maxResizeWidth'), lessThanOrEqualTo(_cellDp(4)));
      expect(_dp(info, 'maxResizeHeight'), lessThanOrEqualTo(_cellDp(2)));
    });

    test('periyodik uyandirma yok', () {
      // Tek dinamik oge kendi kendine tiklayan Chronometer'dir.
      expect(_attr(info, 'updatePeriodMillis'), '0');
    });

    test('yeniden boyutlandirma ekrana YANSIR (WP-699 dersi)', () {
      // 🔴 `AppWidgetProvider.onAppWidgetOptionsChanged` govdesi BOSTUR.
      // Gecersiz kilinmazsa boyut degisimi `onUpdate` tetiklemez ve
      // `updatePeriodMillis=0` olan bu widget bir daha ASLA cizilmez.
      final source = _read('$_kotlinDir/MinimalTimerWidget.kt');
      expect(
        source.contains('override fun onAppWidgetOptionsChanged('),
        isTrue,
        reason: 'punto merdiveni beyanda kalir, ekranda hic degismez',
      );
    });

    test('tazeleme yolu gercekten bagli', () {
      // `updatePeriodMillis=0` oldugu icin tek tazeleme yolu budur; liste
      // eksik kalsaydi baslat/durdur sonrasi widget bayat kalirdi.
      final widgets = _read('$_kotlinDir/TimerWidgets.kt');
      expect(widgets.contains('MinimalTimerWidgetProvider::class.java'), isTrue);
      expect(widgets.contains('TimerWidgetProvider::class.java'), isTrue);
    });

    test('manifest kaydi kurulabilir halde', () {
      final header = _receiverHeader('MinimalTimerWidgetProvider');
      expect(
        header.contains('android:enabled="false"'),
        isFalse,
        reason: 'kapali bir saglayici Android widget secicisinde gorunmez',
      );
      expect(
        header.contains('android:exported="true"'),
        isTrue,
        reason: 'launcher baglayamaz',
      );
      expect(
        _manifest().contains('@xml/odak_minimal_timer_widget_info'),
        isTrue,
      );
    });

    // WP-726: bilincli acik borc kapandi. Saglayici manifestte etkin oldugu
    // gibi uygulamanin kendi katalog enum'u ve yayin listesinde de yer alir.
    // Kart, boyut ve dokunma davranisinin tamligi WP-705 testinde olculur.
    test('minimal widget uygulamanin kendi katalogunda yayinda', () {
      expect(
        HomeWidgetProvider.values.map((provider) => provider.name),
        contains('minimalTimer'),
      );
      expect(
        isHomeWidgetPublished(HomeWidgetProvider.minimalTimer),
        isTrue,
        reason: 'manifestte etkin minimal saglayici katalogda da yayinlanmali',
      );
    });
  });

  // =========================================================================
  // KORUMA — mevcut baslat/durdur ve derin baglanti yollari bozulmadi
  // =========================================================================
  group('WP-718 · koruma', () {
    late String providers;
    setUpAll(() => providers = _read('$_kotlinDir/StudyWidgetProviders.kt'));

    test('WP-700/706 derin baglantisi duruyor', () {
      expect(providers.contains('WidgetDeepLink.ROUTE_TIMER'), isTrue);
    });

    test('TimerActionReceiver yolu duruyor', () {
      expect(
        providers.contains('TimerActionReceiver.ACTION_TOGGLE_TIMER'),
        isTrue,
      );
      final minimal = _read('$_kotlinDir/MinimalTimerWidget.kt');
      expect(
        minimal.contains('TimerActionReceiver.ACTION_TOGGLE_TIMER'),
        isTrue,
        reason: 'minimal widget baslat/durdur uretmiyor',
      );
    });

    test('WP-717 paylasilan gorsel dili kullanilir (ikinci dil acilmadi)', () {
      for (final layout in <String>[
        'odak_timer_widget.xml',
        'odak_minimal_timer_widget.xml',
      ]) {
        final source = _read('$_layoutDir/$layout');
        expect(
          source.contains('@drawable/widget_card_bg'),
          isTrue,
          reason: '$layout paylasilan kart zeminini kullanmiyor',
        );
        expect(
          RegExp(r'android:textColor="#').hasMatch(source),
          isFalse,
          reason: '$layout gomulu hex renk tasiyor: ikinci bir gorsel dil',
        );
        expect(
          RegExp(r'android:background="#').hasMatch(source),
          isFalse,
          reason: '$layout gomulu hex zemin tasiyor',
        );
      }
    });
  });
}
