// WP-662 — Liderlik kartı: "kaç KİŞİ görünüyor" ölçülür; sığmak yetmez.
//
// 🔴 WP-659 aritmetiği doğrulttu: kart artık kutusuna sığmayan satırı
// paketlemiyor. Ama sonuç ölçüldüğünde (bu turun envanter probu) şu çıktı:
//
//   160×160 hücre → **1 kişi**   (yazı ölçeği 1.0 / 1.3 / 1.6, hepsinde)
//   328×160 hücre → **1 kişi** + 17 / 29 / 41 px kart-içi kaydırma
//   396×194 hücre → **1 kişi**
//
// Tek kişilik bir "sıralama" tablosu bilgi taşımaz: sıralama en az bir
// karşılaştırma demektir. Yani WP-659 doğru bir hesabı doğru yaptı ve YANLIŞ
// bir ürünü onayladı. Bu dosya o boşluğu kapatır ve üç şeyi birlikte ölçer:
//
//   1. her hücrede **en az iki kişi** çizilir (Karar 1),
//   2. "geniş ama kısa" hücrede grup hedefi bloğu **çizilmez** (Karar 2),
//   3. sıkıştırılmış satır içeriği **kırpmaz** — satırın gerçek intrinsic
//      yüksekliği dayatılan `itemExtent`in altındadır.
//
// 🔴 (3) neden intrinsic ile ölçülüyor: `ListView.itemExtent` çocuğa TIGHT bir
// yükseklik verir. Satırın gövdesi yatay bir `Row`dur ve yatay flex DİKEY
// taşmayı **raporlamaz** — yani içerik ekrandan sessizce silinir, hiçbir
// istisna düşmez, `takeException()` mutlu mesut yeşil kalır. Ölçülebilecek tek
// dürüst değer `getMaxIntrinsicHeight`tir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

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

/// Bu turda bulunan iki kusur YALNIZ 1.3'te görünüyordu; tek ölçekte ölçen bir
/// kapı bu sınıfı göremez.
const List<double> _textScales = [1.0, 1.3, 1.6];

/// "Geniş ama kısa" hücreler: grup hedefi bloğunun **gizlenmesi** gereken yer.
/// (`isCompact` eşiği 220 px; bu üçü ondan geniş ama iki normal satır + başlık +
/// blok için yeterince yüksek değil.)
const Set<String> _shortWideCells = {
  'dar telefon|tam 32×16', // 328 × 160
  'geniş telefon|tam 32×16', // 396 × 194
};

final DateTime _now = DateTime.now();

final _me = Profile(
  id: 'u1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 240,
);

final _group = StudyGroup(
  id: 'g1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: 'u1',
  createdAt: DateTime(2026, 1, 1),
);

/// Üç üye: "en az iki kişi" iddiasının VERİ tarafında karşılığı olsun. Daha
/// azıyla ölçüm kendini kandırır (2 üyeyle "2 gösterdi" demek kolay).
const int _memberCount = 3;

List<Profile> _members() => [
  for (var i = 1; i <= _memberCount; i++)
    Profile(id: 'u$i', displayName: 'Üye $i', createdAt: DateTime(2026, 1, 1)),
];

List<DailyStat> _stats() {
  final today = DateTime(_now.year, _now.month, _now.day);
  return [
    for (var d = 0; d < 30; d++)
      for (var i = 1; i <= _memberCount; i++)
        DailyStat(
          userId: 'u$i',
          day: today.subtract(Duration(days: d)),
          seconds: 1800 * (i + 1),
        ),
  ];
}

List<Override> _overrides() => [
  authStateProvider.overrideWith((ref) => Stream.value(_me)),
  userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
  groupMembersProvider.overrideWith((ref) => Stream.value(_members())),
  groupDailyStatsProvider.overrideWith((ref) => Stream.value(_stats())),
  groupAlphaScoresProvider.overrideWith(
    (ref) async => {for (var i = 1; i <= _memberCount; i++) 'u$i': 100 * i},
  ),
];

final _cardKey = GlobalKey();

Future<void> _pump(
  WidgetTester tester, {
  required _Screen screen,
  required _Box box,
  required double textScale,
}) async {
  final width = _span(screen.content, box.w);
  final height = _span(screen.content, box.h);
  final outer = ScrollController();
  addTearDown(outer.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
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
                        DashboardCardType.leaderboard,
                        DashboardCardConfig(
                          DashboardCardType.leaderboard,
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
  await tester.pump();
  await tester.pump();
}

Finder _rowFinder() => find.descendant(
  of: find.byKey(_cardKey),
  matching: find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_Row',
  ),
);

/// (dayatılan boy, içeriğin gerçek istediği boy) çiftleri.
List<({double imposed, double natural})> _rows(WidgetTester tester) => [
  for (final e in _rowFinder().evaluate())
    (
      imposed: (e.renderObject! as RenderBox).size.height,
      natural: (e.renderObject! as RenderBox).getMaxIntrinsicHeight(
        (e.renderObject! as RenderBox).size.width,
      ),
    ),
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

void main() {
  // 840 px içerik genişliği varsayılan 800×600 test penceresine sığmaz;
  // görünüm alanı yetmezse kart kırpılır ve ölçüm yalan söyler.
  void widen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('WP-662 · Karar 1 — hiçbir hücrede tek kişilik sıralama yok', () {
    for (final screen in _screens) {
      for (final box in _boxes) {
        for (final scale in _textScales) {
          testWidgets('${screen.name} · ${box.name} · yazı ×$scale', (
            tester,
          ) async {
            widen(tester);
            await _pump(tester, screen: screen, box: box, textScale: scale);
            expect(tester.takeException(), isNull);

            final rows = _rows(tester);
            expect(
              rows.length,
              greaterThanOrEqualTo(2),
              reason:
                  '${screen.name}/${box.name}/×$scale: kart ${rows.length} kişi '
                  'çizdi. Tek kişilik bir sıralama tablosu karşılaştırma '
                  'içermez; kısa hücrede satır sıkıştırılmış varyanta geçmeli '
                  '(bkz. kLeaderboardDenseRowExtent).',
            );

            // Dayatılan boy içeriği KIRPMAMALI. `Row` dikey taşmayı
            // raporlamadığı için tek dürüst ölçü intrinsic yüksekliktir.
            for (final r in rows) {
              expect(
                r.natural,
                lessThanOrEqualTo(r.imposed + 0.01),
                reason:
                    '${screen.name}/${box.name}/×$scale: satırın içeriği '
                    '${r.natural.toStringAsFixed(2)} px istiyor ama '
                    '${r.imposed.toStringAsFixed(2)} px dayatıldı — fark '
                    'SESSİZCE kırpılır, kimse göremez.',
              );
            }

            // Satırlar tek tip olmalı; karışık boy "kaç kişi sığar"ı
            // cevaplanamaz yapar.
            for (final r in rows) {
              expect(r.imposed, closeTo(rows.first.imposed, 0.01));
            }

            expect(
              _verticalScrollExtent(tester),
              lessThanOrEqualTo(0.5),
              reason:
                  '${screen.name}/${box.name}/×$scale: sığan içerik için '
                  'kart-içi dikey kaydırıcı kaldı.',
            );
          });
        }
      }
    }
  });

  group('WP-662 · Karar 2 — grup hedefi bloğu kısa hücrede çizilmez', () {
    for (final screen in _screens) {
      for (final box in _boxes) {
        for (final scale in _textScales) {
          final key = '${screen.name}|${box.name}';
          final short = _shortWideCells.contains(key);
          testWidgets(
            '${screen.name} · ${box.name} · yazı ×$scale '
            '(${short ? "gizli" : "serbest"})',
            (tester) async {
              widen(tester);
              await _pump(tester, screen: screen, box: box, textScale: scale);
              expect(tester.takeException(), isNull);

              // Blok kimliği: `Icons.flag_outlined` yalnız grup hedefi
              // satırında kullanılır (kartın başka yerinde bayrak yok).
              final flag = find.descendant(
                of: find.byKey(_cardKey),
                matching: find.byIcon(Icons.flag_outlined),
              );
              if (short) {
                expect(
                  flag,
                  findsNothing,
                  reason:
                      '$key/×$scale: hücre ${_span(screen.content, box.h)} px '
                      'yüksek; grup hedefi bloğu başlığı şişirip listeyi '
                      'kaydırıcıya düşürüyor. Görünürlük kararı yalnız '
                      'GENİŞLİĞE bakıyorsa bu satır kırmızı düşer.',
                );
              }
              // Uzun/geniş hücrede blok görünür kalmalı; yoksa "gizle" kuralı
              // sessizce her yere yayılır ve grup hedefi kaybolur.
              if (!short &&
                  _span(screen.content, box.w) >= 228 &&
                  _span(screen.content, box.h) >= 260) {
                expect(
                  flag,
                  findsOneWidget,
                  reason:
                      '$key/×$scale: hücre bloğu taşıyacak kadar büyük ama '
                      'blok çizilmemiş — gizleme kuralı fazla geniş.',
                );
              }
            },
          );
        }
      }
    }
  });
}
