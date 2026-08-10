// WP-646 — pano kartlarının kaydırma sözleşmesi, **kart kart değil sınıf olarak**.
//
// 🔴 Neden bu dosya var. Proje sahibi aynı şikâyeti ikinci kez bildirdi:
// *"bazı kartlarda hâlâ gereksiz kart içinde aşağı yukarı kaydırma var; parmağım
// onların üstündeyse takılıyor. Weekly rhythm ve sayaç kartı mesela. Kartı ne
// kadar büyütürsem büyüteyim gene var. **başkaları da olabilir, her kartı kontrol
// et.**"*
//
// WP-508 bu sınıf için ortak kuralı (`cardScrollIfOverflows` +
// `CardOverflowScrollPhysics`) yazmıştı ve `card_scaffold.dart`'ın başlığı o
// kuralı "Ana Sayfa kartlarının **ortak** kaydırma kuralı" diye tanıtıyordu.
// Ölçüldüğünde ortak olmadığı çıktı: `study_timer_card.dart` kuralı hiç
// kullanmıyor, çıplak bir `SingleChildScrollView` kuruyordu — ne `physics` ne
// `primary`. Yani:
//
//   1. Varsayılan `AlwaysScrollableScrollPhysics`e düşüyor → içerik **sığsa
//      bile** dikey sürüklemeyi yutuyor (sahibin "parmağım takılıyor"u).
//   2. `primary` varsayılanı `true` → dış sayfanın `PrimaryScrollController`'ına
//      bağlanıyor; kart, üzerinde olmadığı bir kaydırıcıyı sürüklüyor.
//
// 🔴 Neden metin ölçülüyor. Davranış ölçümü zaten var
// (`card_scroll_gesture_wp508_test.dart` altı kartı, `card_scroll_inventory_test.dart`
// her kartın kaydırma payını ölçer). İkisi de **bir kartın unutulmasına** karşı
// koruma vermiyordu: davranış testi listelenmemiş kartı hiç kurmaz. Buradaki
// ölçüm listeye değil **kayıt defterine** (`dashboardCardFor`) bakar, yani yarın
// eklenen kart hiçbir şey yapılmadan kapsama girer.
//
// ⚠️ Bu kapı "kart hiç kaydırmasın" DEMİYOR. Sahibin bağlayıcı kuralı:
// *sığıyorsa dış sayfa akar, taşıyorsa kart içi kayar.* Taşan içerik için
// kaydırıcı meşrudur — ölçülen şey o kaydırıcının **jesti doğru koşulda**
// alması.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = _read('lib/features/home/dashboard_card.dart');

  /// Kayıt defterinden türetilen kart kaynak dosyaları.
  ///
  /// Liste elle yazılmaz: `dashboard_card.dart` hangi dosyaları import ediyorsa
  /// kapsam odur. Yeni bir kart eklendiğinde bu testte hiçbir şey değişmez.
  List<String> cardSources() {
    final imports = RegExp(r"^import '([^']+_card\.dart)';", multiLine: true)
        .allMatches(registry)
        .map((m) => m.group(1)!)
        .toList();
    expect(
      imports.length,
      greaterThanOrEqualTo(15),
      reason:
          'Kart kaynagi taramasi bos/eksik: kayit defterinin import bicimi '
          'degismis olabilir, kapi sessizce hicbir sey olcmez.',
    );
    return imports
        .map((rel) => _resolve('lib/features/home/dashboard_card.dart', rel))
        .toList();
  }

  /// Kayıt defterinde gerçekten çizilen kart sayısı — kapsamın alt sınırı.
  test('kayit defteri taranabiliyor (kapi bos olcum yapmiyor)', () {
    final drawn = RegExp(r'DashboardCardType\.\w+ => \w+Card\(')
        .allMatches(_stripComments(registry))
        .length;
    expect(
      drawn,
      greaterThanOrEqualTo(15),
      reason:
          '`dashboardCardFor` esleme bicimi degismis; asagidaki iddialar '
          'kartlarin bir kismina kor kalabilir.',
    );
  });

  test('🔴 hicbir pano karti CIPLAK dikey kaydirici kurmaz', () {
    final offenders = <String>[];

    for (final path in cardSources()) {
      // Yorumlar DUSURULUR. WP-640'ta olculdu: duzeltmeyi anlatan yorum
      // aranan hatali metni birebir tasiyabilir ve kapi DUZELTILMIS dosyada
      // kirmizi duser.
      //
      // 🔴 DURUST OLCUM: bugun hicbir kart yorumu bu deseni birebir
      // (parantezle) tasimiyor, yani bu satir su an KIRMIZIYI ONLEMIYOR --
      // sabote edilip olculdu, kapi yesil kaldi. Yine de duruyor cunku ilk
      // `SingleChildScrollView(` yazan yorum kapiyi yanlis yere dusururdu.
      // Yuk tasidigini bos yere iddia etmemek icin asagida KENDI testi var.
      final source = _stripComments(_read(path));

      for (final ctor in const [
        'SingleChildScrollView(',
        'ListView(',
        'ListView.builder(',
        'ListView.separated(',
      ]) {
        for (final args in _invocations(source, ctor)) {
          // Yatay kaydirici dikey jesti yutmaz; kural onu baglamaz.
          if (args.contains('scrollDirection: Axis.horizontal')) continue;
          if (!args.contains('physics:')) {
            offenders.add('$path → $ctor  (physics verilmemis)');
          } else if (!args.contains('primary:')) {
            offenders.add('$path → $ctor  (primary verilmemis)');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '`physics` verilmemis dikey bir ScrollView '
          '`AlwaysScrollableScrollPhysics`e duser: icerik SIGSA BILE dikey '
          'suruklemeyi yutar ve ana ekran akmaz. `primary` verilmemis olan ise '
          'dis sayfanin PrimaryScrollController\'ina baglanir. Kart icin dogru '
          'yol `cardScrollIfOverflows` (ikisini de dogru kurar):\n'
          '${offenders.join('\n')}',
    );
  });

  group('tarayicinin kendi kapisi', () {
    // Kapi kaynak METNI okuyor; o hâlde tarayicinin kendisi de olculmeli.
    // Olculmeyen tarayici, kapiyi sessizce hicbir sey olcmez hale getirir.
    const fixture = '''
// Bu bir yorum: SingleChildScrollView( physics yok ) -- SAYILMAMALI.
Widget build() => SingleChildScrollView(
  primary: false,
  physics: kCardOverflowScrollPhysics,
  child: Column(children: [ListView(physics: x, primary: false)]),
);
Widget yatay() => ListView(
  scrollDirection: Axis.horizontal,
  children: const [],
);
''';

    test('yorum icindeki cagri SAYILMAZ', () {
      expect(_invocations(fixture, 'SingleChildScrollView('), hasLength(2));
      expect(
        _invocations(_stripComments(fixture), 'SingleChildScrollView('),
        hasLength(1),
        reason:
            'Yorum temizligi calismiyor: duzeltmeyi ANLATAN bir yorum kapiyi '
            'duzeltilmis dosyada kirmiziya dusurur (WP-640 tuzagi).',
      );
    });

    test('argüman govdesi ic ice cagrilarda DOGRU kapanir', () {
      final args = _invocations(_stripComments(fixture), 'SingleChildScrollView(');
      expect(args.single, contains('physics: kCardOverflowScrollPhysics'));
      expect(
        args.single,
        contains('ListView(physics: x'),
        reason:
            'Ic ice cagri erken kapaniyor: uzun argüman listelerinde kapi '
            'gercek siniri okuyamaz ve yanlis karar verir.',
      );
    });

    test('yatay kaydirici muaf, dikey degil', () {
      final horizontal = _invocations(_stripComments(fixture), 'ListView(');
      expect(horizontal.length, 2);
      expect(
        horizontal.any((a) => a.contains('scrollDirection: Axis.horizontal')),
        isTrue,
        reason: 'Muafiyet dali hic olculmuyor; yanlislikla genisletilebilir.',
      );
    });
  });

  test('sayac karti ortak kurala BAGLI (WP-646 kok neden)', () {
    // Ozel olarak sabitlenir: envanterin en kotu kartiydi (840x416 tablet
    // hucresinde bile 132 px tasiyordu) ve kurali hic kullanmiyordu.
    final source = _stripComments(
      _read('lib/features/classroom/widgets/study_timer_card.dart'),
    );
    final views = _invocations(source, 'SingleChildScrollView(');
    expect(
      views,
      isNotEmpty,
      reason: 'Kartin kaydiricisi kaldirilmis; bu testin iddiasi guncellenmeli.',
    );
    expect(
      views.first,
      contains('physics: kCardOverflowScrollPhysics'),
      reason:
          'Sayac karti yine ortak kuralin disinda: icerik sigsa bile dikey '
          'jesti yutar.',
    );
    expect(
      views.first,
      contains('primary: false'),
      reason: 'Kart dis sayfanin kaydiricisini calmaya devam ediyor.',
    );
  });
}

/// [ctor] ile başlayan her çağrının **dengeli parantezli** argüman gövdesi.
///
/// Satır penceresine bakan bir iddia (ör. "sonraki 5 satırda `physics` geçiyor
/// mu") uzun argüman listelerinde sessizce yanılır; burada gerçek sınır okunur.
/// İç içe çağrılar da doğru kapanır.
List<String> _invocations(String source, String ctor) {
  final result = <String>[];
  var index = source.indexOf(ctor);
  while (index >= 0) {
    var depth = 0;
    var i = index + ctor.length - 1; // açılış parantezi
    final start = i + 1;
    for (; i < source.length; i++) {
      final ch = source[i];
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (depth == 0) result.add(source.substring(start, i));
    index = source.indexOf(ctor, index + ctor.length);
  }
  return result;
}

/// `//` ve `/* */` yorumlarını düşürür; dize içindeki `//` (ör. `https://`)
/// yorum sanılmaz.
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'(?<!:)//.*'), '');

String _resolve(String from, String relative) {
  final base = from.substring(0, from.lastIndexOf('/'));
  final parts = <String>[...base.split('/'), ...relative.split('/')];
  final out = <String>[];
  for (final part in parts) {
    if (part == '..') {
      out.removeLast();
    } else if (part != '.') {
      out.add(part);
    }
  }
  return out.join('/');
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('Kaynak bulunamadi: $path (calisma dizini: ${Directory.current.path})');
  }
  // Depoda satir sonu KARISIK; iddialar \n tasiyor (bkz. WP-614 notu).
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}
