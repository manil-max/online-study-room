// WP-717: widget GORSEL DILI + geri sayimin uygulamadaki karta benzemesi.
//
// Sahibin cihazda gordugu sikayet iki cumleydi: "widgetlar cok cirkin... boyutlari
// kocaman ve yazi sadece. buraya renkli bir bar koysan mesela TERS U seklinde daha
// guzel olur" ve "exam countdown'u uygulamadaki gibi yap". Beta testcisi ayrica
// "sadece 1 sinavin geri sayimi gorunuyor; uygulamadaki gibi 3'u de gorunse" dedi.
//
// Bu dosya izlenimi SAYIYA cevirir. Olculen sey iki katman:
//
//   A) Paylasilan gorsel dil (WP-718/719 de kullanacak):
//      `values/widget_design.xml` + `values-night/widget_design.xml` renk/olcu
//      simgeleri ve `res/drawable/widget_*` cizimleri. Renkler UYGULAMA temasindan
//      da DUVAR KAGIDINDAN da bagimsiz sabit degerlerdir (bu depoda "kirmizi rozet
//      kirmizi temada kayboluyor" kusuru yasandi); okunurluk WCAG kontrast orani
//      hesaplanarak dogrulanir - "guzel gorunuyor" bir iddia degildir.
//
//   B) Geri sayim widget'i: uc sinav birden, uygulamadaki `dday_card.dart` ile
//      ayni siralama/oncelik sozlesmesi, ve gercekten CIZILEN bir yay.
//
// 🔴 Neden kaynak metni okuyoruz: bu depoda `resizeMode` tam da boyle bir "olu
// bayrak" cikti - duzende yaziyordu, kodda karsiligi yoktu (WP-699). O yuzden
// yayin "duzende var" diye kabul edilmez; saglayicinin `setProgressBar` ve
// `setViewVisibility` cagrisi da iddiaya baglanir.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const String _resDir = 'android/app/src/main/res';
const String _kotlinDir =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path yok');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String _stripComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

/// `<color name="x">#RRGGBB</color>` -> {x: '#RRGGBB'}
Map<String, String> _colors(String xml) {
  final result = <String, String>{};
  final pattern = RegExp(r'<color\s+name="([^"]+)"\s*>([^<]+)</color>');
  for (final match in pattern.allMatches(_stripComments(xml))) {
    result[match.group(1)!] = match.group(2)!.trim();
  }
  return result;
}

Map<String, String> _dimens(String xml) {
  final result = <String, String>{};
  final pattern = RegExp(r'<dimen\s+name="([^"]+)"\s*>([^<]+)</dimen>');
  for (final match in pattern.allMatches(_stripComments(xml))) {
    result[match.group(1)!] = match.group(2)!.trim();
  }
  return result;
}

/// WCAG 2.1 bagil parlaklik.
double _luminance(String hex) {
  final value = hex.replaceFirst('#', '');
  expect(value.length, 6, reason: 'renk #RRGGBB olmali: $hex');
  double channel(int offset) {
    final raw = int.parse(value.substring(offset, offset + 2), radix: 16) / 255.0;
    return raw <= 0.03928
        ? raw / 12.92
        : math.pow((raw + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4);
}

double _contrast(String a, String b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Gorsel dilin **paylasilan** simgeleri. WP-718/719 bu adlari kullanacak;
/// listeden bir ad dusurulurse iki widget birden sessizce eski duz metne doner.
const List<String> _designColors = <String>[
  'widget_design_surface',
  'widget_design_ink',
  'widget_design_ink_muted',
  'widget_design_accent',
  'widget_design_track',
];

const List<String> _designDimens = <String>[
  'widget_design_corner',
  'widget_design_padding',
  'widget_design_arc_height',
  'widget_design_row_gap',
];

const List<String> _designDrawables = <String>[
  'widget_card_bg',
  'widget_arc_track_shape',
  'widget_arc_fill_shape',
  'widget_progress_arc',
  'widget_progress_bar',
];

void main() {
  group('WP-717 A · paylasilan gorsel dil kaynaklari', () {
    test('acik ve koyu tema AYNI simge kumesini tanimlar', () {
      final light = _colors(_read('$_resDir/values/widget_design.xml'));
      final dark = _colors(_read('$_resDir/values-night/widget_design.xml'));

      for (final name in _designColors) {
        expect(light.containsKey(name), isTrue, reason: 'acik temada $name yok');
        expect(dark.containsKey(name), isTrue, reason: 'koyu temada $name yok');
      }
      // Bir tarafta tanimlanip digerinde unutulan simge, gece modunda okunmaz
      // metin uretir; iki dosya birebir ayni ad kumesini tasimali.
      expect(dark.keys.toSet(), light.keys.toSet());

      final dimens = _dimens(_read('$_resDir/values/widget_design.xml'));
      for (final name in _designDimens) {
        expect(dimens.containsKey(name), isTrue, reason: 'olcu $name yok');
        expect(dimens[name], endsWith('dp'), reason: '$name dp olmali');
      }
    });

    test('🔴 renkler TEMA PALETINDEN bagimsiz sabit degerdir', () {
      // Bu depoda kirmizi rozet kirmizi temada kayboldu: renk, uzerine
      // cizildigi yuzeyin paletinden turetilirse kontrast garantisi yoktur.
      // Ayni tuzagin Android tarafindaki hali `@android:color/system_*`
      // (Material You) referanslaridir: duvar kagidi renk verir, kontrasti
      // kimse olcmez. Gorsel dil bu yuzden SABIT hex tasir.
      for (final dir in const ['values', 'values-night']) {
        // Yorumlar elenir: bu dosyalarin yorumu tuzagi ANLATIYOR, uygulamiyor.
        final raw = _stripComments(_read('$_resDir/$dir/widget_design.xml'));
        expect(
          raw.contains('@android:color/'),
          isFalse,
          reason: '$dir/widget_design.xml sistem paletine bagli',
        );
        for (final entry in _colors(raw).entries) {
          expect(
            RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(entry.value),
            isTrue,
            reason: '${entry.key} sabit #RRGGBB degil: ${entry.value}',
          );
        }
      }
      // values-v31 (Android 12+ dinamik renk) gorsel dili EZMEMELI.
      final v31 = File('$_resDir/values-v31/widget_design.xml');
      if (v31.existsSync()) {
        final overridden = _colors(v31.readAsStringSync()).keys;
        expect(
          overridden.where(_designColors.contains),
          isEmpty,
          reason: 'dinamik renk gorsel dil simgesini eziyor',
        );
      }
    });

    test('🔴 kontrast OLCULDU: her iki temada da okunur', () {
      for (final dir in const ['values', 'values-night']) {
        final c = _colors(_read('$_resDir/$dir/widget_design.xml'));
        final surface = c['widget_design_surface']!;

        // Kritik metin: WCAG AA = 4.5.
        expect(
          _contrast(c['widget_design_ink']!, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$dir: ana metin yuzeyde okunmuyor',
        );
        expect(
          _contrast(c['widget_design_ink_muted']!, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$dir: ikincil metin yuzeyde okunmuyor',
        );
        // Vurgu rengi hem buyuk sayiyi hem yayin dolu kismini cizer:
        // metin olarak 4.5, grafik olarak (WCAG 1.4.11) 3.0 gerekir.
        expect(
          _contrast(c['widget_design_accent']!, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$dir: vurgu rengi yuzeyde kayboluyor',
        );
        // Yayin DOLU ve BOS parcasi birbirinden ayirt edilebilmeli; yoksa
        // ilerleme gostergesi tek renk bir yay olur ve hicbir sey soylemez.
        expect(
          _contrast(c['widget_design_accent']!, c['widget_design_track']!),
          greaterThanOrEqualTo(3.0),
          reason: '$dir: yayin dolusu ile bosu ayirt edilemiyor',
        );
        // Iz de yuzeyden ayrilmali, yoksa yay yariya kadar hic yokmus gibi durur.
        expect(
          _contrast(c['widget_design_track']!, surface),
          greaterThanOrEqualTo(1.3),
          reason: '$dir: yay izi yuzeyde gorunmuyor',
        );
      }
    });

    test('cizim kaynaklari var ve gorsel dil simgelerini kullanir', () {
      for (final name in _designDrawables) {
        expect(
          File('$_resDir/drawable/$name.xml').existsSync(),
          isTrue,
          reason: 'drawable/$name.xml yok',
        );
      }
      final card = _read('$_resDir/drawable/widget_card_bg.xml');
      expect(card.contains('@color/widget_design_surface'), isTrue);
      expect(card.contains('@dimen/widget_design_corner'), isTrue);
    });

    test('🔴 "ters U" gercekten bir YAY: yay komutu tasiyan cizgi', () {
      // Ters U = yarim daire. Vektorde bunun tek karsiligi eliptik yay
      // komutudur (`A`/`a`). Duz bir cizgi ya da dikdortgen buraya sizarsa
      // sahibin istedigi bicim kaybolur ama dosya adi ayni kalir.
      final arcPath = RegExp(r'android:pathData="([^"]+)"');
      for (final name in const ['widget_arc_track_shape', 'widget_arc_fill_shape']) {
        final xml = _read('$_resDir/drawable/$name.xml');
        expect(xml.trimLeft().startsWith('<?xml'), isTrue);
        expect(xml.contains('<vector'), isTrue, reason: '$name vektor degil');
        final data = arcPath.firstMatch(xml)?.group(1);
        expect(data, isNotNull, reason: '$name pathData tasimiyor');
        expect(
          RegExp(r'[Aa]\s*[-\d.]').hasMatch(data!),
          isTrue,
          reason: '$name yay komutu (A) icermiyor - bu ters U degil',
        );
        // Yay CIZGIdir, dolgu degil: kalinlik + ucu yuvarlak.
        expect(xml.contains('android:strokeWidth'), isTrue);
        expect(xml.contains('android:strokeLineCap="round"'), isTrue);
      }
      expect(
        _read('$_resDir/drawable/widget_arc_track_shape.xml')
            .contains('@color/widget_design_track'),
        isTrue,
      );
      expect(
        _read('$_resDir/drawable/widget_arc_fill_shape.xml')
            .contains('@color/widget_design_accent'),
        isTrue,
      );
    });

    test('🔴 ilerleme cizimi RemoteViews `setProgressBar` ile surulebilir', () {
      // RemoteViews sinirlidir: `Canvas` cizemez, ozel `View` alamaz. Calisan
      // tek surulebilir ilerleme yolu, `ProgressBar`in seviye (level) tabanli
      // `progressDrawable`idir - `@android:id/progress` katmani bir `<clip>`
      // olmak ZORUNDA, cunku seviyeyi yorumlayan sey odur. Katman kimlikleri
      // yanlissa `setProgressBar` sessizce hicbir sey yapmaz.
      for (final name in const ['widget_progress_arc', 'widget_progress_bar']) {
        final xml = _stripComments(_read('$_resDir/drawable/$name.xml'));
        expect(xml.contains('<layer-list'), isTrue, reason: '$name layer-list degil');
        expect(
          xml.contains('android:id="@android:id/background"'),
          isTrue,
          reason: '$name arka plan katmani yok',
        );
        final progressIndex = xml.indexOf('android:id="@android:id/progress"');
        expect(progressIndex, greaterThan(-1), reason: '$name ilerleme katmani yok');
        final clipIndex = xml.indexOf('<clip', progressIndex);
        expect(
          clipIndex,
          greaterThan(progressIndex),
          reason: '$name ilerleme katmani <clip> degil: seviye yok sayilir',
        );
        expect(
          xml.substring(clipIndex).contains('android:clipOrientation="horizontal"'),
          isTrue,
          reason: '$name yatay doldurmuyor',
        );
      }
    });
  });

  group('WP-717 B · geri sayim uygulamadaki karta benziyor', () {
    late String layout;
    late String provider;

    setUp(() {
      layout = _read('$_resDir/layout/odak_countdown_widget.xml');
      provider = _read('$_kotlinDir/CountdownWidget.kt');
    });

    test('duzen: kart zemini + yay + UC satir', () {
      expect(
        layout.contains('android:background="@drawable/widget_card_bg"'),
        isTrue,
        reason: 'widget hala duz bir dikdortgen',
      );
      expect(layout.contains('<ProgressBar'), isTrue, reason: 'yay yok');
      expect(layout.contains('android:id="@+id/countdown_widget_arc"'), isTrue);
      expect(
        layout.contains('android:progressDrawable="@drawable/widget_progress_arc"'),
        isTrue,
        reason: 'ProgressBar varsayilan duz cubugu ciziyor, ters U\'yu degil',
      );
      // 🔴 Beta testcisi: "sadece 1 sinavin geri sayimi gorunuyor;
      // uygulamadaki gibi 3'u de gorunse."
      for (var i = 1; i <= 3; i++) {
        expect(
          layout.contains('android:id="@+id/countdown_widget_row_$i"'),
          isTrue,
          reason: '$i. sinav satiri duzende yok',
        );
        expect(
          layout.contains('android:id="@+id/countdown_widget_row_name_$i"'),
          isTrue,
        );
        expect(
          layout.contains('android:id="@+id/countdown_widget_row_days_$i"'),
          isTrue,
        );
      }
      // Gomulu metin yasak (l10n_android_audit ile ayni kural).
      expect(
        RegExp(r'android:text="(?!@string/)').hasMatch(layout),
        isFalse,
        reason: 'duzende gomulu metin var',
      );
    });

    test('🔴 UC SINAV birden gercekten yaziliyor (olu satir degil)', () {
      // Duzende satirin durmasi yetmez: saglayici o satirlara metin YAZMALI ve
      // gorunurlugunu SURMELI. `resizeMode` bu depoda tam da boyle bir beyan
      // olarak kaldi ve hicbir sey yapmadi (WP-699).
      for (var i = 1; i <= 3; i++) {
        expect(
          provider.contains('R.id.countdown_widget_row_name_$i'),
          isTrue,
          reason: '$i. satirin adi hicbir zaman yazilmiyor',
        );
        expect(
          provider.contains('R.id.countdown_widget_row_days_$i'),
          isTrue,
          reason: '$i. satirin gun sayisi hicbir zaman yazilmiyor',
        );
        expect(
          provider.contains('R.id.countdown_widget_row_$i'),
          isTrue,
          reason: '$i. satirin gorunurlugu hic surulmuyor',
        );
      }
      expect(
        provider.contains('countdownWidgetList('),
        isTrue,
        reason: 'saglayici hala tek kayit okuyor',
      );
    });

    test('🔴 yay OLU BAYRAK degil: hem surulur hem gizlenir', () {
      expect(
        provider.contains('setProgressBar(') &&
            provider.contains('R.id.countdown_widget_arc'),
        isTrue,
        reason: 'yayin ilerleme degeri hic verilmiyor',
      );
      expect(
        RegExp(r'setViewVisibility\(\s*R\.id\.countdown_widget_arc')
            .hasMatch(provider),
        isTrue,
        reason: 'yay bos/gecmis durumda da ciziliyor',
      );
      expect(
        provider.contains('WidgetDesign.arcPercent('),
        isTrue,
        reason: 'yay yuzdesi paylasilan gorsel dilden gelmiyor',
      );
    });

    test('uygulamadaki kartla AYNI oncelik sozlesmesi', () {
      // `dday_card.dart`: one cikarilan kayit varsa buyuk, digerleri altinda
      // satir; one cikarilan yoksa hepsi esit satir. Widget'in ayni kurali
      // uygulamasi, kullanicinin uygulamada gordugu sirayi ana ekranda da
      // gormesi demektir.
      final card = _read('lib/features/home/widgets/dday_card.dart');
      expect(card.contains('final useHero = featured != null'), isTrue,
          reason: 'referans kural degismis - widget tarafi yeniden okunmali');
      expect(
        provider.contains('countdownUsesHero('),
        isTrue,
        reason: 'widget kahraman/liste ayrimini hic yapmiyor',
      );
    });

    test('boyut siniri uc satiri gosterebilecek kadar buyuyebiliyor', () {
      final info = _stripComments(
        _read('$_resDir/xml/odak_countdown_widget_info.xml'),
      );
      final max = RegExp(r'android:maxResizeHeight="(\d+)dp"').firstMatch(info);
      expect(max, isNotNull);
      // Hucre formulu 70n-30: 3 hucre = 180dp, 4 hucre = 250dp. Kahraman
      // duzeni + iki yardimci satir 180dp'de sikisir; kullanici isterse
      // 4 hucreye kadar uzatabilmeli.
      expect(
        int.parse(max!.group(1)!),
        greaterThanOrEqualTo(250),
        reason: 'widget uc sinavi rahat gosterecek kadar uzayamiyor',
      );
    });
  });
}
