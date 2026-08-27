// WP-659 — Liderlik kartı: "kaç satır sığar" aritmetiği ÖLÇÜLÜR, tahmin edilmez.
//
// 🔴 Kusur (ölçüldü, 2026-08-10): `leaderboard_card.dart` satır yüksekliğini
// `const rowHeight = 36.0`, başlığı ise `32 + 24 + 12 (+48)` ile **tahmin**
// ediyordu. Gerçekte:
//
//   satır          : 53.44 px  (taçlı avatar kutusu 45.44 + 2×4 px padding)
//   başlık (dar)   : 44 / 51 / 58 px   (yazı ölçeği 1.0 / 1.3 / 1.6)
//   başlık (geniş) : 91 / 103 / 115 px (grup hedefi bloğu dahil)
//
// Yani satır **%48 küçük**, başlık ise sabit sayılmış. İki hata aynı yöne
// çalışıyor: kart her seferinde sığmayacak kadar çok satır paketliyor, kalanı
// kart-içi kaydırıcıya düşüyor ve sahibin "parmağım takılıyor" şikâyeti geri
// geliyor. 36 px bir zamanlar doğruydu — taçsız avatar (r=14 → 28 px) + 8 px
// padding tam 36 px'tir; taç geldiğinde sabit güncellenmedi.
//
// Bu dosyanın ölçtüğü sözleşme tek cümle: **kart, kutusuna sığmayan bir satırı
// paketlemez.** Sayıyı (kaç kişi) dayatmaz — yalnız paketlenen satır sayısının
// gerçekten sığdığını ölçer, böylece düzeltme "3 yerine 2 gösterelim" gibi bir
// ÜRÜN kararına dönüşmeden doğrulanabilir.
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
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

// Ana Sayfa ızgarasının gerçek geometrisi (`home_screen.dart` → `_MatrixGrid`).
const double _kGap = 8.0;
const int _kColumns = 32;
double _cell(double content) =>
    (content - (_kColumns - 1) * _kGap) / _kColumns;
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

/// Başlık yüksekliği yazı ölçeğiyle büyür; tahmin edilen sabit büyümez. Kusur
/// tam olarak burada patlar, bu yüzden üç ölçek de sınanır.
const List<double> _textScales = [1.0, 1.3, 1.6];

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

/// Mütevazı üye sayısı: 12 kişilik bir liste 160 px hücreye zaten sığmaz ve
/// orada kaydırmak DOĞRUdur (WP-497). Ölçülen şey makul bir listenin bile
/// kartı kaydırıcıya düşürüp düşürmediği.
const int _memberCount = 3;

List<Profile> _members() => [
  for (var i = 1; i <= _memberCount; i++)
    Profile(id: 'u$i', displayName: 'Üye $i', createdAt: DateTime(2026, 1, 1)),
];

List<DailyStat> _stats() {
  // 🔴 Takvim gunu CIHAZIN yerel saatinden TURETILEMEZ. Kart satirlari
  // `todaySecondsByUser` ile suzulur ve o `dayOf` (= Istanbul) kullanir;
  // `isSameDay` iki tarafi da normalize ETMEZ, ham y/a/g karsilastirir.
  // Fikstur `DateTime.now()`un yerel gunuyle kurulunca UTC bir makinede
  // 21:00-24:00 arasi Istanbul zaten ERTESI GUNE gecmis olur: uretilen 30
  // gunun hicbiri kartin aradigi gun degildir, kart BOS cizer ve test her
  // gece ayni uc saatte kirmizi yanar. (Olculdu: CI 20:24Z yesil,
  // 21:06Z kirmizi, arada yalniz surum meta commit'i vardi.)
  final today = dayOf(_now);
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

/// Karta çizilmiş sıralama satırlarının yükseklikleri.
List<double> _rowHeights(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byKey(_cardKey),
            matching: find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_Row',
            ),
          )
          .evaluate())
    (e.renderObject! as RenderBox).size.height,
];

/// Satırların içine çizildiği liste kutusunun yüksekliği (yoksa `null`).
double? _listViewportHeight(WidgetTester tester) {
  final lv = find.descendant(
    of: find.byKey(_cardKey),
    matching: find.byType(ListView),
  );
  if (lv.evaluate().isEmpty) return null;
  return tester.getSize(lv.first).height;
}

double _verticalScrollExtent(WidgetTester tester) {
  var worst = 0.0;
  for (final e
      in find
          .descendant(
            of: find.byKey(_cardKey),
            matching: find.byType(Scrollable),
          )
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

/// Kartı **sınırsız** yükseklikte kurar (Gruplar ekranındaki `ListView` yolu).
/// Orada `itemExtent` dayatılmaz, yani satırlar DOĞAL boylarını alır — bu
/// kurulum `kLeaderboardRowExtent`in gerçekten yeterli olup olmadığını ölçmenin
/// tek yolu.
Future<void> _pumpUnbounded(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
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
          child: Scaffold(
            body: SingleChildScrollView(
              controller: outer,
              child: SizedBox(
                width: width,
                child: KeyedSubtree(
                  key: _cardKey,
                  child: const LeaderboardCard(),
                ),
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

void main() {
  // 840 px içerik genişliği varsayılan 800×600 test penceresine sığmaz.
  void widen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // 🔴 `itemExtent` bir satırı KÜÇÜLTÜRSE içerik sessizce kırpılır: satırın
  // gövdesi yatay bir `Row`dur ve yatay flex DİKEY taşmayı raporlamaz — yani
  // ekranda kaybolur, hiçbir istisna düşmez. Bu yüzden dayatılan boy, satırın
  // doğal boyuyla ayrıca karşılaştırılır.
  group('WP-659 — dayatılan satır boyu içeriği kırpmıyor', () {
    for (final width in [152.0, 186.0, 320.0, 832.0]) {
      for (final scale in _textScales) {
        testWidgets('genişlik $width · yazı ×$scale', (tester) async {
          widen(tester);
          await _pumpUnbounded(tester, width: width, textScale: scale);
          expect(tester.takeException(), isNull);
          final rows = _rowHeights(tester);
          expect(rows, isNotEmpty);
          expect(
            rows.reduce((a, b) => a > b ? a : b),
            lessThanOrEqualTo(kLeaderboardRowExtent),
            reason:
                'satırın doğal boyu dayatılan $kLeaderboardRowExtent px\'i '
                'aşıyor ($rows); `itemExtent` içeriği kırpar ve kimse görmez.',
          );
        });
      }
    }
  });

  group('WP-659 — paketlenen satır sayısı gerçekten sığar', () {
    for (final screen in _screens) {
      for (final box in _boxes) {
        for (final scale in _textScales) {
          testWidgets('${screen.name} · ${box.name} · yazı ×$scale', (
            tester,
          ) async {
            widen(tester);
            await _pump(tester, screen: screen, box: box, textScale: scale);
            expect(tester.takeException(), isNull);

            final rows = _rowHeights(tester);
            final listH = _listViewportHeight(tester);
            expect(
              rows,
              isNotEmpty,
              reason: 'sıralama hiç çizilmemiş; ölçüm anlamsız olur',
            );
            expect(listH, isNotNull, reason: 'liste kutusu bulunamadı');

            // Satırlar tek tip olmalı: farklı yükseklikte satırlar "kaç satır
            // sığar" sorusunu cevaplanamaz yapar (taçlı/taçsız üye karışımı).
            for (final h in rows) {
              expect(
                h,
                closeTo(rows.first, 0.01),
                reason: 'satır yükseklikleri tek tip değil: $rows',
              );
            }

            final needed = rows.length * rows.first;
            // 🔴 Sözleşme: ya paketlenen satırlar kutuya sığar, ya da kutu tek
            // satır bile almıyordur (o zaman TEK satır paketlenir ve kaydırma
            // WP-497 güvenlik ağıdır).
            if (listH! >= rows.first) {
              expect(
                needed,
                lessThanOrEqualTo(listH + 0.5),
                reason:
                    '${screen.name}/${box.name}/×$scale: kart ${rows.length} '
                    'satır paketledi (${needed.toStringAsFixed(2)} px) ama '
                    'listeye ${listH.toStringAsFixed(2)} px yer kaldı. '
                    'Satır/başlık yüksekliği TAHMİN ediliyor.',
              );
              expect(
                _verticalScrollExtent(tester),
                lessThanOrEqualTo(0.5),
                reason:
                    '${screen.name}/${box.name}/×$scale: sığan içerik için '
                    'kart-içi dikey kaydırıcı kaldı; parmak kartın üstündeyken '
                    'ana ekran kaymaz.',
              );
            } else {
              expect(
                rows.length,
                1,
                reason:
                    '${screen.name}/${box.name}/×$scale: kutuya tek satır bile '
                    'sığmıyor (${listH.toStringAsFixed(2)} px < '
                    '${rows.first.toStringAsFixed(2)} px) ama kart '
                    '${rows.length} satır paketledi.',
              );
            }
          });
        }
      }
    }
  });
}
