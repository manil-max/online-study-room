// WP-642 — "tıklanabilir görünüyor ama tıklanmıyor".
//
// Proje sahibi cihazda bildirdi:
//   "kartın sağ üstünde kalem simgesi var, edit için koymuşsun sanırım ama
//    basınca bir şey olmuyor; editlemek için soldan listeye basmak gerekiyor."
//
// 🔴 Bu dosya KULLANICININ DOKUNDUĞU PİKSELİ ölçer, gövdedeki dokunma hedefini
// değil. Var olan `dday_*` testlerinin hepsi ya doğrudan sağlayıcıyı ya da
// gövdedeki `Key('dday-card-open-editor')` InkWell'ini kullanıyordu; kalem
// simgesine **hiçbiri** dokunmadı, o yüzden simgenin süs olduğu kapılardan
// sızdı (`hunter/SKILL.md §3` — "kullanıcının GÖRDÜĞÜ satırı ölç").
//
// Kart yine pano fabrikasından (`dashboardCardFor`) kurulur: widget'ı elle
// kurmak, kartın gerçek kabuğa bağlanmadığı bir dünyada da yeşil yanardı.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/features/home/widgets/card_scaffold.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _examDay = DateTime(2026, 8, 20);
final _now = DateTime.utc(2026, 8, 10, 9);

Future<SharedPreferences> _prefs({bool withExam = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (withExam) {
    await prefs.setString(kExamDateKey, encodeExamDay(_examDay));
  }
  return prefs;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required SharedPreferences prefs,
  double height = 260,
  DashboardCardSize size = DashboardCardSize.medium,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ddayClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              child: dashboardCardFor(
                DashboardCardType.dday,
                size,
                height: height,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('WP-642 · başlıktaki kalem simgesi', () {
    testWidgets('kurulum gerçekten hatanın penceresinde: simge başlıkta, '
        'gövde dokunma hedefinin DIŞINDA', (tester) async {
      await _pumpCard(tester, prefs: await _prefs(withExam: true));

      final icon = find.byIcon(Icons.edit_outlined);
      expect(
        icon,
        findsOneWidget,
        reason: 'Kurulum bozuk: kalem simgesi kartta hiç yok.',
      );
      // Kurulumun kalbi: simge ekranda VAR ve gövdedeki dokunma hedefinin
      // torunu DEĞİL. Bu doğruysa simgeye dokunmak hiçbir şey yapmaz.
      expect(
        find.descendant(
          of: find.byKey(const Key('dday-card-open-editor')),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsNothing,
        reason:
            'Kurulum bozuk: simge zaten gövde InkWell\'inin içinde; bu testin '
            'ölçtüğü kusur artık bu kod yolunda değil.',
      );
      // Simge gerçekten dokunulabilir bir yerde duruyor (kırpılmamış,
      // 0 boyutlu değil) — yani "basınca bir şey olmuyor" şikâyeti
      // görünmezlikten değil, BAĞLANMAMIŞ olmaktan geliyor.
      expect(icon.hitTestable(), findsOneWidget);
    });

    testWidgets('kaleme basınca düzenleme penceresi AÇILIR (kayıt varken)', (
      tester,
    ) async {
      await _pumpCard(tester, prefs: await _prefs(withExam: true));

      expect(find.text(l10n.homeSinavlariDuzenle), findsNothing);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.homeSinavlariDuzenle),
        findsOneWidget,
        reason:
            'Kalem simgesi düzenleme penceresini açmadı. Simge kartın '
            'BAŞLIĞINDA, dokunma hedefi ise GÖVDEDE olduğu için simge süs '
            'gibi duruyor (proje sahibi cihaz bildirimi, WP-642).',
      );
      expect(find.byKey(const Key('dday-add-exam')), findsOneWidget);
    });

    testWidgets('kayıt yokken de kaleme basınca pencere açılır', (
      tester,
    ) async {
      await _pumpCard(tester, prefs: await _prefs());

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text(l10n.homeSinavlariDuzenle), findsOneWidget);
    });

    testWidgets('küçük kartta (kaydırma yolu) da kalem çalışır', (
      tester,
    ) async {
      // `CardScaffold` kısa hücrede doldurma yerine kaydırma dalına düşer;
      // başlık o dalda da kurulur. Aynı iddia iki kod yolunda da geçmeli.
      await _pumpCard(
        tester,
        prefs: await _prefs(withExam: true),
        height: 120,
        size: DashboardCardSize.small,
      );
      expect(
        cardShouldFill(120),
        isFalse,
        reason: 'Kurulum bozuk: bu yükseklik hâlâ doldurma dalına düşüyor.',
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text(l10n.homeSinavlariDuzenle), findsOneWidget);
    });

    testWidgets('gövdeye dokunmak da hâlâ çalışır (regresyon)', (tester) async {
      await _pumpCard(tester, prefs: await _prefs(withExam: true));

      await tester.tap(find.byKey(const Key('dday-card-open-editor')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.homeSinavlariDuzenle), findsOneWidget);
    });
  });

  // ==========================================================================
  // YAPISAL ÖNLEM
  //
  // Tek kartı düzeltmek sınıfı kapatmaz: yarın başka bir kart başlığına çıplak
  // bir Icon konur ve aynı sessiz kusur geri gelir. Aşağıdaki iki ölçüm
  // "başlığa aksiyon koymak" hareketini tıklanabilir olmaya ZORLAR.
  // ==========================================================================
  group('WP-642 · yapısal önlem', () {
    test('hiçbir CardScaffold başlığında çıplak Icon() yok', () {
      final offenders = _headerViolations();
      expect(
        offenders,
        isEmpty,
        reason:
            'Kart BAŞLIĞI, gövdenin dışında duran ayrı bir çocuktur; gövdeye '
            'kurulan dokunma hedefi oraya ulaşmaz. Başlığa konan çıplak bir '
            'Icon kullanıcıya düğme gibi görünür, basınca hiçbir şey olmaz '
            '(WP-642, proje sahibi cihaz bildirimi). Başlığa simge koymanın '
            'tek yolu `cardHeaderAction` yardımcısıdır — o `onPressed` almadan '
            'derlenmez.\nİhlaller: $offenders',
      );
    });

    test('tarama gerçekten çalışıyor (sabotaj)', () {
      // 🔴 Sabote edilmemiş kapı kapı değildir (SKILL §5). Üç ayrı yönden
      // sınanır; biri bile geçmezse tarama sessizce kör demektir.

      // 1) Doğrudan verilen başlıktaki çıplak Icon yakalanmalı.
      expect(
        _scanHeaders('''
          return CardScaffold(
            header: Row(children: [Text('x'), Icon(Icons.edit)]),
            bodyBuilder: (c, h) => const SizedBox(),
          );
        '''),
        ['<satır içi>'],
      );

      // 2) Değişkenle verilen başlık da çözülmeli — weekly/line kartları bu
      //    biçimi kullanıyor; çözülmezse tarama gerçek kartların yarısını hiç
      //    görmezdi.
      expect(
        _scanHeaders('''
          final header = Column(children: [Icon(Icons.star)]);
          return CardScaffold(header: header, bodyBuilder: (c, h) => x);
        '''),
        ['header'],
      );

      // 3) Yanlış pozitif yok: doğru yol temiz geçmeli.
      expect(
        _scanHeaders('''
          return CardScaffold(
            header: Row(children: [
              cardHeaderAction(icon: Icons.edit, onPressed: f, tooltip: 't'),
            ]),
            bodyBuilder: (c, h) => const SizedBox(),
          );
        '''),
        isEmpty,
      );

      // 4) SKILL §5'in somut tuzağı: bu taramanın kendisi KAYNAK METNİ okuyor
      //    ve dday_card.dart'taki düzeltme yorumu "Icon" kelimesini birebir
      //    taşıyor. Yorumlar temizlenmezse test DÜZELTİLMİŞ dosyada kırmızı
      //    düşerdi. Ölçüm yalnız koşan satırlara daraltılmış olmalı.
      expect(
        _scanHeaders('''
          return CardScaffold(
            // eskiden burada Icon(Icons.edit) vardi
            header: Row(children: [cardHeaderAction(icon: Icons.edit)]),
            bodyBuilder: (c, h) => const SizedBox(),
          );
        '''),
        isEmpty,
        reason: 'Tarama yorum satırlarını ölçüyor; koşan satırlara daraltılmalı.',
      );
    });

    testWidgets('cardHeaderAction başlığı BÜYÜTMEZ (gövdeden piksel çalmaz)', (
      tester,
    ) async {
      // 🔴 Bu ölçüm bir REGRESYONDAN doğdu. İlk düzeltme dokunma hedefini
      // 32x32 verdi ve `dday_multi_exam` küçük kartta 7.47 / 10.94 px taşma
      // ile kırmızı düştü. Sebep `constraints` değil, MaterialTapTargetSize
      // varsayılanının (`padded`) butonun etrafına kendi kutusunu eklemesiydi:
      // `constraints` 32'den 24'e indirildiğinde taşma HİÇ DEĞİŞMEDİ.
      // Pano hücresi karta sabit yükseklik verdiği için başlıkta büyüyen her
      // piksel doğrudan gövdeden çalınır. Kusur uzak bir kartın testinde
      // patlamıştı; artık yardımcının kendi kapısı var.
      // 🔴 Sonda gerçek kartın başlığını taklit eder: başlık metni `cardTitle`
      // (titleMedium) ile kurulur. Düz `Text` ile ölçmek yanıltıcıydı —
      // titleMedium satırı daha yüksek olduğu için aksiyon onun altında
      // kalabilir; farklı bir stille ölçen kapı yanlış eşiği korur.
      Future<double> heightOf(Widget Function(BuildContext) trailing) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: Builder(
                    builder: (context) => Row(
                      key: const Key('probe-row'),
                      children: [
                        Expanded(child: cardTitle(context, 'Başlık')),
                        trailing(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        return tester.getSize(find.byKey(const Key('probe-row'))).height;
      }

      final bare = await heightOf((_) => const SizedBox.shrink());
      final withAction = await heightOf(
        (_) => cardHeaderAction(
          icon: Icons.edit_outlined,
          onPressed: () {},
          tooltip: 'x',
        ),
      );

      expect(
        withAction,
        bare,
        reason:
            'Başlık aksiyonu başlığı ${withAction - bare} px büyüttü. Pano '
            'hücresi karta sabit yükseklik verir: bu piksel doğrudan gövdeden '
            'çalınır ve küçük kartta içerik taşar. `IconButton.styleFrom('
            'tapTargetSize: MaterialTapTargetSize.shrinkWrap)` kaldırılmış '
            'olabilir.',
      );
      // 🔴 Dokunma hedefinin GERÇEK boyutu ölçülür, verilen `constraints`
      // değil. İkisi aynı değil: `visualDensity: compact` varken 40x24 istenip
      // 32x16 alınıyordu — yani "düğme yaptık" denip 16 px yüksekliğinde bir
      // hedef gönderilebilirdi. Bu iddia o sapmayı yakalar.
      expect(
        tester.getSize(find.byType(IconButton)),
        const Size(40, 24),
        reason:
            'Dokunma hedefi ölçülen değerden saptı. `visualDensity` geri '
            'eklenmiş olabilir: `constraints`i sessizce (-8,-8) küçültür.',
      );
    });
  });
}

// ===========================================================================
// Kaynak taraması
// ===========================================================================

/// `lib/` altındaki her `CardScaffold(...)` çağrısının başlığını tarar ve
/// çıplak `Icon(` içerenleri döner.
List<String> _headerViolations() {
  final out = <String>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    // Yardımcının kendi evi hariç: `cardHeaderAction` Icon'u orada kurar ve
    // orada Icon zaten bir düğmenin içindedir.
    if (f.path.replaceAll(r'\', '/').endsWith('widgets/card_scaffold.dart')) {
      continue;
    }
    for (final label in _scanHeaders(f.readAsStringSync())) {
      out.add('${f.path} → header: $label');
    }
  }
  return out;
}

/// Verilen kaynaktaki ihlalli başlıkların etiketlerini döner.
///
/// Başlık ifadesi `header:` ile `bodyBuilder:` arasında kalan metindir (bu
/// depodaki her `CardScaffold` çağrısı header'ı bodyBuilder'dan önce verir).
/// İfade düz bir tanımlayıcıysa (`header: header`) aynı dosyadaki
/// `final header = ... ;` ataması çözülür.
List<String> _scanHeaders(String rawSrc) {
  final src = _stripComments(rawSrc);
  final out = <String>[];
  for (final m in RegExp(r'CardScaffold\s*\(').allMatches(src)) {
    final h = src.indexOf('header:', m.end);
    if (h < 0) continue;
    var end = src.indexOf('bodyBuilder:', h);
    if (end < 0) end = src.length;
    var expr = src.substring(h + 'header:'.length, end).trim();
    if (expr.endsWith(',')) expr = expr.substring(0, expr.length - 1).trim();

    var label = '<satır içi>';
    if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(expr)) {
      label = expr;
      expr = _assignment(src, expr) ?? expr;
    }
    if (expr.contains('Icon(')) out.add(label);
  }
  return out;
}

/// Dart kaynağından yorumları atar.
///
/// 🔴 SKILL §5'te kayıtlı tuzak: sözleşme testi **koşan satırları** ölçmeli.
/// Düzeltmeyi anlatan bir yorum aranan metni birebir taşıyorsa, test
/// düzeltilmiş dosyada kırmızı düşer.
String _stripComments(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    if (i + 1 < src.length && src[i] == '/' && src[i + 1] == '/') {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
    } else if (i + 1 < src.length && src[i] == '/' && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < src.length && !(src[i] == '*' && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
    } else {
      out.write(src[i]);
      i++;
    }
  }
  return out.toString();
}

/// `final <name> = <ifade>;` atamasını derinlik farkındalı okur.
String? _assignment(String src, String name) {
  final m = RegExp('(?:final|var|Widget)\\s+$name\\s*=').firstMatch(src);
  if (m == null) return null;
  var depth = 0;
  for (var i = m.end; i < src.length; i++) {
    final c = src[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (c == ';' && depth == 0) return src.substring(m.end, i).trim();
  }
  return null;
}
