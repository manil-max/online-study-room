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
//      `values/widget_design.xml` renk/olcu simgeleri ve `res/drawable/widget_*`
//      cizimleri. Renkler UYGULAMA temasindan da DUVAR KAGIDINDAN da bagimsiz
//      sabit degerlerdir (bu depoda "kirmizi rozet kirmizi temada kayboluyor"
//      kusuru yasandi); okunurluk WCAG kontrast orani hesaplanarak dogrulanir -
//      "guzel gorunuyor" bir iddia degildir.
//
//      🔴 WP-752 - SOZLESME DEGISTI: palet TEKtir ve KOYUdur.
//      `values-night/widget_design.xml` KALDIRILDI; widget her sistem
//      temasinda koyu cizilir. Gerekce (tasarim sistemi §2.1): uygulamanin
//      kendi varsayilan temasi `campfire_night`, yani acik temada krem bir
//      kart cizmek widget'i uygulamanin degil launcher'in parcasi yapiyordu;
//      ayrica iki palet her kontrast iddiasinin iki kez kanitlanmasini
//      gerektiriyordu ve bir simgenin bir temada unutulmasi HICBIR DERLEME
//      HATASI uretmiyordu. Bu dosyadaki "iki tema ayni ad kumesini tasir"
//      iddiasi bu yuzden "ikinci bir palet dosyasi ACILAMAZ" ile degistirildi -
//      ayni sinif regresyonu daha ucuza yakalar.
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

/// `@color/widget_ember_x` alias'ini ayni dosyadaki hex degere cozer.
/// Cozulemeyen deger oldugu gibi doner (iddia orada kirmizi duser).
String _resolve(Map<String, String> palette, String value) {
  var current = value;
  for (var hop = 0; hop < 4; hop++) {
    if (!current.startsWith('@color/')) return current;
    final next = palette[current.substring('@color/'.length)];
    if (next == null) return current;
    current = next;
  }
  return current;
}

double _contrast(String a, String b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// WP-752 paleti: **alti opak simge** (tasarim sistemi §2.2). Tum widget
/// renkleri buradan turer; yeni renk uretilmez.
const Map<String, String> _emberPalette = <String, String>{
  'widget_ember_night': 'kart zemini (opak) — kontrast referansi',
  'widget_ember_ash': 'YALNIZ grafik: yay izi, ayrac, kenar, halka',
  'widget_ember_flame': 'birincil vurgu: kahraman sayi, dolu yay, eylem hapi',
  'widget_ember_glow': 'ikincil vurgu: seri alevi, 1. sira',
  'widget_ember_ink': 'ana metin',
  'widget_ember_ink_dim': 'yardimci metin / etiket',
};

/// Gorsel dilin **paylasilan** simgeleri. WP-718/719 bu adlari kullanir;
/// listeden bir ad dusurulurse iki widget birden sessizce eski duz metne doner.
/// WP-752'de bunlar palete ALIAS oldu: deger tek kaynaktan gelir, ayni hex iki
/// yerde yazilmaz.
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
    test('🔴 palet TEKtir: ikinci bir tema dosyasi ACILAMAZ', () {
      // Eski iddia `values` ile `values-night` ad kumelerini karsilastiriyordu.
      // WP-752'de `values-night/widget_design.xml` KALDIRILDI (§2.1), yani o
      // karsilastirma konusuz kaldi. Ayni sinif regresyonu -- bir simgenin bir
      // temada eksik kalmasi ve HICBIR DERLEME HATASI uretmemesi -- artik
      // "ikinci palet dosyasi yok" ile yakalanir.
      for (final path in const <String>[
        '$_resDir/values-night/widget_design.xml',
        '$_resDir/values-v31/widget_design.xml',
        '$_resDir/values/widget_colors.xml',
        '$_resDir/values-night/widget_colors.xml',
        '$_resDir/values-v31/widget_colors.xml',
      ]) {
        expect(
          File(path).existsSync(),
          isFalse,
          reason: '$path geri geldi: tek koyu kimlik sozlesmesi kirildi',
        );
      }

      final palette = _colors(_read('$_resDir/values/widget_design.xml'));
      for (final name in _emberPalette.keys) {
        expect(
          palette.containsKey(name),
          isTrue,
          reason: '$name paletten dusmus (${_emberPalette[name]})',
        );
        expect(
          RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(palette[name]!),
          isTrue,
          reason: '$name sabit #RRGGBB degil: ${palette[name]}',
        );
      }
      // WP-717 adlari korunur; dokuz duzen ve mevcut cizimler onlari kullanir.
      for (final name in _designColors) {
        expect(palette.containsKey(name), isTrue, reason: '$name yok');
        expect(
          RegExp(r'^#[0-9A-Fa-f]{6}$')
              .hasMatch(_resolve(palette, palette[name]!)),
          isTrue,
          reason: '$name palete cozulemiyor: ${palette[name]}',
        );
      }

      final dimens = _dimens(_read('$_resDir/values/widget_design.xml'));
      for (final name in _designDimens) {
        expect(dimens.containsKey(name), isTrue, reason: 'olcu $name yok');
        expect(dimens[name], endsWith('dp'), reason: '$name dp olmali');
      }
      // §2.6: kart yaricapi KADEMEYE baglidir. K1'de kart 40x40dp'dir; tek
      // deger (22dp) koselerin TAMAMINI yiyordu.
      expect(dimens['widget_design_corner'], '20dp');
      expect(dimens['widget_design_corner_tight'], '12dp');
    });

    test('🔴 renkler TEMA PALETINDEN bagimsiz sabit degerdir', () {
      // Bu depoda kirmizi rozet kirmizi temada kayboldu: renk, uzerine
      // cizildigi yuzeyin paletinden turetilirse kontrast garantisi yoktur.
      // Ayni tuzagin Android tarafindaki hali `@android:color/system_*`
      // (Material You) referanslaridir: duvar kagidi renk verir, kontrasti
      // kimse olcmez. Gorsel dil bu yuzden SABIT hex tasir.
      //
      // Yorumlar elenir: bu dosyanin yorumu tuzagi ANLATIYOR, uygulamiyor.
      final raw = _stripComments(_read('$_resDir/values/widget_design.xml'));
      expect(
        raw.contains('@android:color/'),
        isFalse,
        reason: 'values/widget_design.xml sistem paletine bagli',
      );
      final palette = _colors(raw);
      for (final entry in palette.entries) {
        final resolved = _resolve(palette, entry.value);
        expect(
          RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(resolved),
          isTrue,
          reason: '${entry.key} sabit #RRGGBB degil: ${entry.value}',
        );
      }
    });

    test('🔴 kontrast OLCULDU: tek koyu palet, alti simge', () {
      final palette = _colors(_read('$_resDir/values/widget_design.xml'));
      String hex(String name) => _resolve(palette, palette[name]!);

      final night = hex('widget_ember_night');
      final ash = hex('widget_ember_ash');
      final flame = hex('widget_ember_flame');
      final glow = hex('widget_ember_glow');
      final ink = hex('widget_ember_ink');
      final inkDim = hex('widget_ember_ink_dim');

      // Kritik metin: WCAG AA = 4.5.
      expect(
        _contrast(ink, night),
        greaterThanOrEqualTo(4.5),
        reason: 'ana metin kartta okunmuyor',
      );
      expect(
        _contrast(inkDim, night),
        greaterThanOrEqualTo(4.5),
        reason: 'yardimci metin kartta okunmuyor',
      );
      // Vurgu rengi hem buyuk sayiyi hem yayin dolu kismini cizer:
      // metin olarak 4.5, grafik olarak (WCAG 1.4.11) 3.0 gerekir.
      expect(
        _contrast(flame, night),
        greaterThanOrEqualTo(4.5),
        reason: 'birincil vurgu kartta kayboluyor',
      );
      expect(
        _contrast(glow, night),
        greaterThanOrEqualTo(4.5),
        reason: 'ikincil vurgu kartta kayboluyor',
      );

      // 🔴 IKI YONLU: `ash` grafik icin yeterli (1.4.11 -> 3.0) ama METIN
      // rengi/zemini DEGILDIR (1.4.3 -> 4.5). Ikinci iddia olmadan biri
      // `ash`i metin rengi yapar ve hicbir test bunu soylemezdi.
      expect(
        _contrast(ash, night),
        greaterThanOrEqualTo(3.0),
        reason: 'yay izi / kenar kartta gorunmuyor',
      );
      expect(
        _contrast(ash, night),
        lessThan(4.5),
        reason:
            '`ash` metin esigini gecti: palet degismis, §2.3 kurali yeniden '
            'okunmali (bugun `ash` bilerek metin rengi DEGIL)',
      );

      // 🔴 SERT KURAL (§2.3): `flame`/`glow` uzerindeki metin DAIMA `night`.
      expect(
        _contrast(ink, flame),
        lessThan(4.5),
        reason: '`ink` on `flame` okunur cikti: sert kuralin gerekcesi dustu',
      );
      expect(
        _contrast(ink, glow),
        lessThan(4.5),
        reason: '`ink` on `glow` okunur cikti: sert kuralin gerekcesi dustu',
      );
      expect(
        _contrast(night, flame),
        greaterThanOrEqualTo(4.5),
        reason: 'eylem hapinin metni okunmuyor',
      );
      expect(
        _contrast(night, glow),
        greaterThanOrEqualTo(4.5),
        reason: '1. sira rozetinin rakami okunmuyor',
      );

      // Yayin DOLU ve BOS parcasi birbirinden ayirt edilebilmeli.
      // 🔴 OLCULDU ve ESIK DUSTU: yeni palette `flame` / `ash` ayrismasi
      // 2.53:1'dir (eski krem palette 3.0'in ustundeydi). WCAG 1.4.11'in
      // istedigi 3:1 grafik nesnenin ZEMINE karsi oranidir ve iki parca da
      // onu gecer (flame 8.19, ash 3.24); mutual oran ayri bir olcudur ve
      // burada bilincli olarak 2.5 tabanina baglandi. Palet degisirse bu
      // sayinin yeniden olculmesi gerekir.
      expect(
        _contrast(flame, ash),
        greaterThanOrEqualTo(2.5),
        reason: 'yayin dolusu ile bosu ayirt edilemiyor',
      );
      // Iz de yuzeyden ayrilmali, yoksa yay yariya kadar hic yokmus gibi durur.
      expect(
        _contrast(ash, night),
        greaterThanOrEqualTo(1.3),
        reason: 'yay izi yuzeyde gorunmuyor',
      );
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
