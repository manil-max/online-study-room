// WP-662 — Sayaç kartı: dokunma hedefi 48 px'in ALTINA inmez, içerik küçük
// hücrede GİZLENİR (kaydırılmaz).
//
// 🔴 İki ölçülmüş kusur, ikisi de bir önceki turun düzeltmesinin yan ürünü:
//
// (Karar 3) WP-659 üst şeridin kırpılmasını `((stripWidth - 24) / 3)
//   .clamp(32, 48)` ile kapattı. Kırpma bitti, yerine bir ERİŞİLEBİLİRLİK
//   kusuru geldi: 160×160 hücrede üç düğme de **36.7 × 36.7 px** çıkıyordu.
//   48 px altı bir dokunma hedefi "biraz küçük" değildir; parmak ucu o alanı
//   güvenilir bulamaz ve yanlış düğmeye basmak kural olur.
//
// (Karar 4) WP-646 jesti doğru yere yolladı ama kalan borcu kendi kod notunda
//   yazdı: "küçük hücrelerde içerik GERÇEKTEN taştığı için orada hâlâ kaydırma
//   kalır". Ölçüldü: 160×160 hücrede **433 px** (yazı ×1.3'te 514, ×1.6'da
//   686 px) kart-içi kaydırma payı. Yani kullanıcı kartın dörtte birini
//   görüyordu ve kalanına parmağını kartın üstünde sürüyerek ulaşıyordu.
//
// Bu dosya üç şeyi ölçer: (a) şeritteki HER dokunma hedefi ≥ 48 px, (b)
// sığmayan aksiyon kaybolmaz — taşma menüsünden AÇILIR (kullanıcının gördüğü
// yol), (c) hücre başına kart-içi kaydırma payı ölçülen çıtayı aşmaz.
//
// ⚠️ Üç yazı ölçeğinde ölçülür: bu turda bulunan iki kusur yalnız 1.3'te
// görünüyordu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/clock_style.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ana Sayfa ızgarasının gerçek geometrisi (`home_screen.dart` → `_MatrixGrid`).
const double _kGap = 8.0;
const int _kColumns = 32;
double _cell(double content) => (content - (_kColumns - 1) * _kGap) / _kColumns;
double _span(double content, int units) =>
    units * _cell(content) + (units - 1) * _kGap;

typedef _Screen = ({String name, double content});
typedef _Box = ({String name, int w, int h});

const List<_Screen> _screens = [
  (name: 'dar telefon', content: 328),
  (name: 'geniş telefon', content: 396),
  (name: 'tablet/masaüstü', content: 840),
];

const List<_Box> _boxes = [
  (name: 'yarım 16×16', w: 16, h: 16),
  (name: 'tam 32×16', w: 32, h: 16),
  (name: 'büyütülmüş 32×26', w: 32, h: 26),
];

const List<double> _textScales = [1.0, 1.3, 1.6];

/// ÇITA — WP-662'de ölçülen kart-içi dikey kaydırma payı (px).
///
/// Bu sayılar hedef değil **fotoğraftır**; listelenmeyen her üçlünün payı 0
/// olmak zorundadır. Sıfırdan büyük her satır bir borçtur.
///
/// 🔴 tablet 416 px yüksek hücreler (`yarım 16×16` / `tam 32×16`) KASTEN
/// düşürülmedi: onlar "küçük hücre" değil, tam kartın çizildiği yerdir ve orada
/// hangi satırın gizleneceği bu turda verilmiş dört karardan biri DEĞİLDİR
/// (§6 — kapsamı kendi başına genişletme). Ölçülen artık: tam kart 416 px genişte
/// ~543 px istiyor.
const Map<String, double> _budget = {
  'dar telefon|yarım 16×16|1.0': 34.7,
  'dar telefon|yarım 16×16|1.3': 64.9,
  'dar telefon|yarım 16×16|1.6': 95.0,
  'dar telefon|tam 32×16|1.0': 2.0,
  'dar telefon|tam 32×16|1.3': 16.1,
  'dar telefon|tam 32×16|1.6': 28.3,
  'dar telefon|büyütülmüş 32×26|1.0': 11.0,
  'dar telefon|büyütülmüş 32×26|1.3': 31.7,
  'dar telefon|büyütülmüş 32×26|1.6': 50.6,
  'geniş telefon|yarım 16×16|1.6': 66.9,
  'geniş telefon|tam 32×16|1.6': 6.2,
  'geniş telefon|büyütülmüş 32×26|1.6': 18.3,
  'tablet/masaüstü|yarım 16×16|1.0': 126.0,
  'tablet/masaüstü|yarım 16×16|1.3': 192.4,
  'tablet/masaüstü|yarım 16×16|1.6': 335.2,
  'tablet/masaüstü|tam 32×16|1.0': 132.0,
  'tablet/masaüstü|tam 32×16|1.3': 189.0,
  'tablet/masaüstü|tam 32×16|1.6': 246.0,
};

final _me = Profile(
  id: 'u1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 240,
);

const _subjects = <Subject>[
  Subject(id: 's1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
  Subject(id: 's2', userId: 'u1', name: 'Fizik', color: 'chart-2'),
];

/// Gerçek notifier kanal/dinleyici kurar; sahne hiç durulmaz.
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

List<Override> _overrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  authStateProvider.overrideWith((ref) => Stream.value(_me)),
  userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
  todayRecordedSecondsProvider.overrideWithValue(7200),
  dailyGoalMinutesProvider.overrideWithValue(240),
  studyTimerProvider.overrideWith(_IdleTimerNotifier.new),
];

final _cardKey = GlobalKey();

Future<void> _pump(
  WidgetTester tester, {
  required _Screen screen,
  required _Box box,
  required double textScale,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  final width = _span(screen.content, box.w);
  final height = _span(screen.content, box.h);
  final outer = ScrollController();
  addTearDown(outer.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs),
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          // Ana Sayfa'nın gerçek kabuğu: dış sayfa kaydırıcısı + sabit hücre.
          child: Scaffold(
            body: SingleChildScrollView(
              controller: outer,
              child: Column(
                children: [
                  SizedBox(
                    width: width,
                    height: height,
                    child: KeyedSubtree(
                      key: _cardKey,
                      child: dashboardCardFor(
                        DashboardCardType.timer,
                        DashboardCardConfig(
                          DashboardCardType.timer,
                          w: box.w,
                          h: box.h,
                        ).sizeForColumns(_kColumns),
                        height: height,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // `pumpAndSettle` yok: saniyelik ticker'lar sahneyi hiç durdurmaz.
  await tester.pump();
  await tester.pump();
}

/// Üst şeritteki dokunma hedeflerinin GERÇEK boyutları.
///
/// 🔴 `constraints` ile GERÇEK boyut aynı şey değildir (`card_scaffold.dart`
/// → `cardHeaderAction` notunda ölçülmüştü): `visualDensity`/`tapTargetSize`
/// verilen kutuyu daha da küçültebilir. Bu yüzden `RenderBox.size` ölçülür.
List<Size> _stripTargets(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_StripActions',
            ),
            matching: find.byType(IconButton),
          )
          .evaluate())
    (e.renderObject! as RenderBox).size,
];

double _verticalScrollExtent(WidgetTester tester) {
  var worst = 0.0;
  for (final e
      in find
          .descendant(of: find.byKey(_cardKey), matching: find.byType(Scrollable))
          .evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    if (!state.position.hasContentDimensions) continue;
    // AxisDirection: up=0, right=1, down=2, left=3.
    if (!state.axisDirection.index.isEven) continue;
    if (state.position.maxScrollExtent > worst) {
      worst = state.position.maxScrollExtent;
    }
  }
  return worst;
}

Finder _byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

void main() {
  void widen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  final l10n = lookupAppLocalizations(const Locale('tr'));

  group('WP-662 · Karar 3 — şeritteki hiçbir dokunma hedefi 48 px altına inmez',
      () {
    for (final screen in _screens) {
      for (final box in _boxes) {
        for (final scale in _textScales) {
          testWidgets('${screen.name} · ${box.name} · yazı ×$scale', (
            tester,
          ) async {
            widen(tester);
            await _pump(tester, screen: screen, box: box, textScale: scale);
            expect(tester.takeException(), isNull);

            final targets = _stripTargets(tester);
            expect(
              targets,
              isNotEmpty,
              reason: 'üst şeritte hiç aksiyon yok; ölçüm anlamsız olur',
            );
            // 🔴 Eşik BURADA yazılı, `kMinTouchTarget` sabitinden okunmuyor:
            // sabitten okusaydı biri sabiti 36.7'ye düşürdüğünde kapı da onunla
            // birlikte düşer ve sessizce yeşil kalırdı. Bir kapı ölçtüğü şeyin
            // kendi tanımını kullanamaz.
            for (final s in targets) {
              expect(
                s.width,
                greaterThanOrEqualTo(48.0),
                reason:
                    '${screen.name}/${box.name}/×$scale: dokunma hedefi '
                    '${s.width.toStringAsFixed(1)} px geniş — 48 px altı bir '
                    'erişilebilirlik kusurudur. Sığmıyorsa düğme KÜÇÜLMEZ, '
                    'taşma menüsüne alınır.',
              );
              expect(
                s.height,
                greaterThanOrEqualTo(48.0),
                reason:
                    '${screen.name}/${box.name}/×$scale: dokunma hedefi '
                    '${s.height.toStringAsFixed(1)} px yüksek (48 px altı).',
              );
            }
          });
        }
      }
    }
  });

  group('WP-662 · Karar 3 — sığmayan aksiyon kaybolmaz, menüden AÇILIR', () {
    testWidgets('160×160 hücre: 2 yuva → 1 düğme + taşma menüsü', (
      tester,
    ) async {
      widen(tester);
      await _pump(
        tester,
        screen: (name: 'dar telefon', content: 328),
        box: (name: 'yarım 16×16', w: 16, h: 16),
        textScale: 1.0,
      );
      expect(tester.takeException(), isNull);

      // 134 px'lik şeritte 48 px'lik iki yuva var; menü düğmesi de bir yuva
      // harcadığı için ekranda 1 aksiyon + menü kalır.
      expect(_stripTargets(tester).length, 2);
      expect(
        find.descendant(
          of: find.byKey(_cardKey),
          matching: find.byIcon(Icons.more_vert),
        ),
        findsOneWidget,
      );
      // En değerli aksiyon (tam ekran odak) ekranda kalır.
      expect(
        find.descendant(
          of: find.byKey(_cardKey),
          matching: find.byIcon(Icons.fullscreen),
        ),
        findsOneWidget,
      );

      // 🔴 §3 — KULLANICININ GÖRDÜĞÜ YOL: gizlenen aksiyonun hâlâ AÇILABİLİR
      // olduğu ölçülür. "Menüye taşıdık" demek yetmez; menü açılmıyorsa
      // aksiyon silinmiş demektir.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text(l10n.classroomGecmisOturumlar), findsOneWidget);
      expect(find.text(l10n.classroomSaatGorunumu), findsOneWidget);
    });

    testWidgets('328×160 hücre: 3 yuva → menü hiç çizilmez', (tester) async {
      widen(tester);
      await _pump(
        tester,
        screen: (name: 'dar telefon', content: 328),
        box: (name: 'tam 32×16', w: 32, h: 16),
        textScale: 1.0,
      );
      expect(tester.takeException(), isNull);
      expect(_stripTargets(tester).length, 3);
      expect(
        find.descendant(
          of: find.byKey(_cardKey),
          matching: find.byIcon(Icons.more_vert),
        ),
        findsNothing,
      );
    });
  });

  group('WP-662 · Karar 4 — küçük hücrede ikincil satırlar GİZLENİR', () {
    testWidgets('160×160: ders seçici hapı ve hedef çubuğu çizilmez', (
      tester,
    ) async {
      widen(tester);
      await _pump(
        tester,
        screen: (name: 'dar telefon', content: 328),
        box: (name: 'yarım 16×16', w: 16, h: 16),
        textScale: 1.0,
      );
      expect(tester.takeException(), isNull);
      expect(
        _byTypeName('_SubjectSelector'),
        findsNothing,
        reason:
            '160 px yüksek hücrede ders seçici hapı çiziliyor; kartın çekirdeği '
            '(geçen süre + Başlat/Durdur) kaydırıcının altına iniyor.',
      );
      expect(_byTypeName('_GoalProgress'), findsNothing);
      // Çekirdek DURUYOR: saat + birincil eylem.
      expect(find.byType(StudyClock), findsOneWidget);
      expect(find.text(l10n.classroomCalismayaBasla), findsOneWidget);
    });

    testWidgets('840×681: tam kart çizilir (gizleme kuralı taşmıyor)', (
      tester,
    ) async {
      widen(tester);
      await _pump(
        tester,
        screen: (name: 'tablet/masaüstü', content: 840),
        box: (name: 'büyütülmüş 32×26', w: 32, h: 26),
        textScale: 1.0,
      );
      expect(tester.takeException(), isNull);
      expect(_byTypeName('_SubjectSelector'), findsOneWidget);
      expect(_byTypeName('_GoalProgress'), findsOneWidget);
      expect(find.text(l10n.classroomManuelSureEkle), findsOneWidget);
    });
  });

  group('WP-662 · Karar 4 — kart-içi kaydırma payı çıtası', () {
    for (final screen in _screens) {
      for (final box in _boxes) {
        for (final scale in _textScales) {
          final key = '${screen.name}|${box.name}|$scale';
          testWidgets('${screen.name} · ${box.name} · yazı ×$scale', (
            tester,
          ) async {
            widen(tester);
            await _pump(tester, screen: screen, box: box, textScale: scale);
            expect(tester.takeException(), isNull);
            // +0.5 px yalnız kayan nokta payı (hücre genişliği 32'ye bölünüyor).
            final allowed = (_budget[key] ?? 0.0) + 0.5;
            expect(
              _verticalScrollExtent(tester),
              lessThanOrEqualTo(allowed),
              reason:
                  '$key: kart-içi dikey kaydırma payı ölçülen çıtayı aştı '
                  '(izin $allowed px). Kart yoğunlaştıysa küçük hücrede '
                  'gizlenecek satırı arttır — çıtayı yükseltme.',
            );
          });
        }
      }
    }
  });
}
