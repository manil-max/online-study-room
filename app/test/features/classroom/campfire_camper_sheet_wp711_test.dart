// WP-711 — kamp atesindeki hayvana basinca acilan kampci sayfasi.
//
// Sahip emri (2026-08-11): *"gruplar kisminda kamp atesi ustunde hayvanlara
// bastigimizda acilan yerden profile gidilebilsin, bir de acilan menuye bunu
// eklerken birazda duzenle suan cok verimsiz. sagi solu bos mesela offline
// kismi sol uste alinabilir, today kismi da kucuk bir stats kismi olabilir
// sagda (stats yazmasin yer kaplamasin) burada gunluk serisi, total sure vs
// sigacagi kadar en temel onemli seyler olabilir."*
//
// Bu dosya UC AYRI seyi olcer; ucu de ayri ayri dusebilsin diye ayri
// gruplarda durur (tek bir degisiklik hepsini birden dusuruyorsa iddia tek
// seyi olcuyor demektir):
//
//   1. **Profil yolu** — sayfadan kisinin profiline gidilebiliyor mu.
//   2. **Olu alan** — sayfanin yuzeyinin ne kadari BOS. Olcum yontemi
//      `test/features/desktop/desktop_stretch_probe.dart` ile ayni ilkeye
//      dayanir: kaynakta ne yazdigina degil, karede NE BOYANDIGINA bakilir
//      (glif kutulari + yaprak cizim kutulari). Fark: orada yatay aralik
//      olculuyordu, burada sahibin sikayeti "sagi solu bos" oldugu icin
//      yuzeyin DOLULUK ORANI (4 px izgara) olculur.
//   3. **Islev kaybi yok** — revizyondan ONCE gosterilen her bilgi SONRA da
//      gosteriliyor. Yeniden tasarimlarda en sik kaybolan sey budur, o yuzden
//      her bilgi AYRI bir iddiadir.
//
// Ayrica dar ekran (360 dp) ve buyuk yazi olceginde tasma olmadigi olculur:
// bu depoda tasmalar iki kez tam olarak "yalniz genis ekranda test edildi"
// diye kacti.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/features/profile/social_profile_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 60,
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Komsu',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 60,
);

final _group = StudyGroup(
  id: 'g1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: _me.id,
  createdAt: DateTime(2026, 1, 1),
);

final _fixedNow = DateTime(2026, 7, 26, 12);

/// Uc gun ust uste 90 dk: hem "toplam" hem "rekor seri" (hedef 60 dk) dolu.
List<DailyStat> _dailyStats() => [
  for (var i = 0; i < 3; i++)
    DailyStat(
      userId: _peer.id,
      day: DateTime(2026, 7, 24 + i),
      seconds: 90 * 60,
    ),
];

/// Sahnedeki bir kampciya dokunur (cipa `AnimatedPositioned` anahtaridir).
Future<void> _tapCamper(WidgetTester tester, String userId) async {
  await tester.tap(find.byKey(ValueKey('b-$userId')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpCampfire(
  WidgetTester tester, {
  bool peerIsStudying = false,
  Size size = const Size(360, 720),
  double textScale = 1.0,
  List<DailyStat>? stats,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final nudges = InMemoryNudgeRepository()..currentUserId = _me.id;
  addTearDown(nudges.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userGroupProvider.overrideWithValue(AsyncData(_group)),
        groupMembersProvider.overrideWith((ref) => Stream.value([_me, _peer])),
        groupPresenceProvider.overrideWith(
          (ref) => Stream.value([
            Presence(
              userId: _peer.id,
              groupId: _group.id,
              status: peerIsStudying
                  ? PresenceStatus.studying
                  : PresenceStatus.offline,
              todaySeconds: 0,
              startedAt: peerIsStudying
                  ? _fixedNow.subtract(const Duration(minutes: 12))
                  : null,
            ),
          ]),
        ),
        groupDailyStatsProvider.overrideWith(
          (ref) => Stream.value(stats ?? _dailyStats()),
        ),
        groupTodaySecondsProvider.overrideWithValue(<String, int>{
          _peer.id: 25 * 60,
        }),
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        nudgeRepositoryProvider.overrideWithValue(nudges),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: Scaffold(body: CampfireScene(clock: () => _fixedNow)),
      ),
    ),
  );
  // 🔴 Sahne sonsuz alev animasyonu barindirir: `pumpAndSettle` asla oturmaz.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
}

// ─────────────────────────── OLCUM KATMANI ─────────────────────────────────

/// Bir render dugumu ekrana bir sey CIZER mi (kap degil, isaret)?
bool _isMark(RenderObject node) =>
    node is RenderCustomPaint || node is RenderImage || node is RenderDecoratedBox;

/// Bundan ince bir kutu isaret degil, cetveldir (`Divider` kabin tamamini
/// kaplar; sayilsaydi ayrac iceren her yuzey "dolu" gorunurdu).
const double _kMinMarkExtent = 4;

bool _hasMarkOrTextDescendant(RenderObject node) {
  var found = false;
  void visit(RenderObject current) {
    if (found) return;
    current.visitChildren((child) {
      if (found) return;
      if (!current.paintsChild(child)) return;
      if (child is RenderParagraph || _isMark(child)) {
        found = true;
        return;
      }
      visit(child);
    });
  }

  visit(node);
  return found;
}

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// Ikon fontu da bir `RenderParagraph`tir; glif kutusu gecerli bir isarettir,
/// bu yuzden (masaustu sondasinin aksine) burada ELENMEZ: doluluk olcerken bir
/// ikon da ekranda yer kaplar.
Rect? _inkOf(RenderParagraph p) {
  if (!p.hasSize) return null;
  final text = p.text.toPlainText();
  if (text.trim().isEmpty) return null;
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  if (boxes.isEmpty) return null;
  var local = boxes.first.toRect();
  for (final box in boxes.skip(1)) {
    local = local.expandToInclude(box.toRect());
  }
  return MatrixUtils.transformRect(p.getTransformTo(null), local);
}

/// [root] altinda BOYANAN butun yaprak isaretlerin ekran kutulari.
List<Rect> paintedMarks(RenderObject root) {
  final out = <Rect>[];
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      final r = _inkOf(node);
      if (r != null) out.add(r);
    } else if (node is RenderBox && node.hasSize && _isMark(node)) {
      final r = _globalRect(node);
      final hairline =
          r.height < _kMinMarkExtent || r.width < _kMinMarkExtent;
      if (!hairline && !_hasMarkOrTextDescendant(node)) out.add(r);
    }
    node.visitChildren((child) {
      if (!node.paintsChild(child)) return;
      visit(child);
    });
  }

  visit(root);
  return out;
}

/// Bir yuzeyin DOLULUK oranini 4 px izgarayla olcer.
///
/// Neden izgara: birlesim dikdortgeni (masaustu sondasinin olcusu) "sagi solu
/// bos" sorusuna yanit vermez — tek genis bir satir birlesimi doldurur ama
/// yuzey yine bos gorunur. Izgara ust uste binen kutulari bir kez sayar.
class SurfaceFill {
  const SurfaceFill(this.surface, this.filledRatio);

  final Rect surface;
  final double filledRatio;

  double get emptyRatio => 1 - filledRatio;

  @override
  String toString() =>
      '${surface.width.toStringAsFixed(0)}x${surface.height.toStringAsFixed(0)} '
      'dolu=%${(filledRatio * 100).toStringAsFixed(1)} '
      'bos=%${(emptyRatio * 100).toStringAsFixed(1)}';
}

SurfaceFill measureFill(RenderBox surface) {
  final rect = _globalRect(surface);
  const cell = 4.0;
  final cols = (rect.width / cell).ceil();
  final rows = (rect.height / cell).ceil();
  final grid = List<bool>.filled(cols * rows, false);
  for (final mark in paintedMarks(surface)) {
    final clipped = mark.intersect(rect);
    if (clipped.isEmpty) continue;
    final x0 = ((clipped.left - rect.left) / cell).floor().clamp(0, cols - 1);
    final x1 = ((clipped.right - rect.left) / cell).ceil().clamp(0, cols);
    final y0 = ((clipped.top - rect.top) / cell).floor().clamp(0, rows - 1);
    final y1 = ((clipped.bottom - rect.top) / cell).ceil().clamp(0, rows);
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        grid[y * cols + x] = true;
      }
    }
  }
  final filled = grid.where((c) => c).length;
  return SurfaceFill(rect, cols * rows == 0 ? 0 : filled / (cols * rows));
}

/// Acik olan kampci alt sayfasinin GORUNEN yuzeyi.
///
/// 🔴 `BottomSheet`in kendi render kutusu DEGIL: `showModalBottomSheet`e
/// `constraints` verildiginde cerceve sayfayi `Align` + `ConstrainedBox` ile
/// sarar (`bottom_sheet.dart:411`), yani `BottomSheet` kutusu pencerenin
/// TAMAMI kadar genis kalir ama boyanan yuzey (`Material`) dardir. Kullanicinin
/// gordugu kutu ikincisidir.
RenderBox _sheetSurface(WidgetTester tester) {
  final sheet = find.byType(BottomSheet);
  expect(sheet, findsOneWidget, reason: 'kampci alt sayfasi acilmadi');
  return tester.renderObject<RenderBox>(
    find.descendant(of: sheet, matching: find.byType(Material)).first,
  );
}

void main() {
  // ── IDDIA 1: profile gidilebiliyor ────────────────────────────────────────
  group('WP-711/1 — kampci sayfasindan profile gidilir', () {
    testWidgets('sayfada profil dugmesi var', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      expect(find.byKey(const Key('camper-sheet-profile')), findsOneWidget);
    });

    testWidgets('dugme gercekten sosyal profil ekranini aciyor', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      // 🔴 "Dugme var" yetmez: bu depoda daha once kamp atesindeki profil yolu
      // AGACTA vardi ama jest arenasinda hic kazanmiyordu (WP-511/E1). Olcu
      // ekranin gercekten acilmasidir.
      await tester.tap(find.byKey(const Key('camper-sheet-profile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SocialProfileScreen), findsOneWidget);
      // Alt sayfa kapanmali; altinda acilan ekran gorulemezdi.
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('acilan profil dokunulan KISININ profili', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      await tester.tap(find.byKey(const Key('camper-sheet-profile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final screen = tester.widget<SocialProfileScreen>(
        find.byType(SocialProfileScreen),
      );
      expect(screen.profile.id, _peer.id);
    });
  });

  // ── IDDIA 2: olu alan ─────────────────────────────────────────────────────
  group('WP-711/2 — sayfanin sagi solu bos degil', () {
    testWidgets('360 dp: bos alan orani esigin altinda', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      final fill = measureFill(_sheetSurface(tester));
      debugPrint('WP-711 OLCUM 360dp (cevrimdisi uye): $fill');

      // 🔴 Esik TAHMIN degil, OLCUM: ayni sonda revizyondan onceki tek sutunlu
      // yerlesimi **%20,5 dolu** (=%79,5 bos), sonrakini **%26,5 dolu** olctu.
      // Esik ikisinin arasindadir; eski yerlesim bu iddiayi GECEMEZ, yani
      // yerlesim geri alinirsa kapi kirmiziya doner.
      //
      // Mutlak sayinin dusuk gorunmesi olcunun dogasidir: metin yuzeylerinde
      // glif kutulari sayfanin ancak ceyregini kaplar (360 px genisliginde tam
      // dolu tek satir govde yazisi ≈ %3,5). Onemli olan ONCE/SONRA farkidir.
      expect(
        fill.filledRatio,
        greaterThan(0.24),
        reason: 'kampci sayfasi yuzeyinin cogu bos: $fill',
      );
    });

    testWidgets('genis ekran (720 dp): bos alan orani esigin altinda', (
      tester,
    ) async {
      // Sahibin sikayeti telefonda dogdu ama sayfa masaustunde de aciliyor;
      // "sagi solu bos" genis ekranda daha da kotudur.
      await _pumpCampfire(tester, size: const Size(720, 900));
      await _tapCamper(tester, _peer.id);

      final fill = measureFill(_sheetSurface(tester));
      debugPrint('WP-711 OLCUM 720dp (cevrimdisi uye): $fill');

      // Olculdu: once 720 px genisliginde bir yuzeyde **%18,8 dolu**; sonra
      // yuzey 600 px'e (SPEC §2.3 etiket–deger tavani) sinirlandi ve **%23,8
      // dolu**. Iki degisiklik de gerekliydi: yalniz iki kolon ya da yalniz
      // genislik tavani esigi gecirmiyor.
      expect(
        fill.filledRatio,
        greaterThan(0.22),
        reason: 'genis ekranda kampci sayfasi neredeyse bos: $fill',
      );
      // Yuzey pencereyle birlikte sonsuza kadar genislemez.
      expect(fill.surface.width, lessThanOrEqualTo(600));
    });

    testWidgets('bugunku toplam SAG yarida ve kimlikle AYNI hizada', (
      tester,
    ) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      final rect = _globalRect(_sheetSurface(tester));
      final today = _globalRect(
        tester.renderObject<RenderBox>(
          find.byKey(const Key('camper-stat-today')),
        ),
      );
      final name = _globalRect(
        tester.renderObject<RenderBox>(
          find.text(_peer.displayName).hitTestable(at: Alignment.topLeft),
        ),
      );

      // 🔴 "Sag yarida bir seyler var" YETMEZ: sabotaj turunda rayi tumuyle
      // kaldirinca sol kimlik blogu genisleyip sag yariya tasiyor ve boyle bir
      // iddia yesil kaliyordu (olculdu). Olcu, DOSEMENIN kendisidir.
      expect(
        today.left,
        greaterThan(rect.center.dx),
        reason: 'bugunku toplam sayfanin sag yarisinda degil',
      );
      // Sahibin istegi "today kismi sagda" — yani adin ALTINDA degil, YANINDA.
      expect(
        today.top,
        lessThan(name.bottom + 8),
        reason: 'sayi rayi kimligin altina dusmus, yan yana degil',
      );
      debugPrint(
        'WP-711 today dosemesi: ${today.left.toStringAsFixed(0)}..'
        '${today.right.toStringAsFixed(0)} (yuzey merkezi '
        '${rect.center.dx.toStringAsFixed(0)})',
      );
    });

    // WP-731: rozet artik sayfanin tepesinde degil, kimlik blogunun (hayvan +
    // ad) HEMEN ALTINDA durur -- sahibin istedigi yer orasi ve o bosluk
    // calisan uyede canli kronometreyle dolar. Yerlesimin kendisi
    // `test/features/campfire/campfire_wp731_test.dart` icinde olculur;
    // burada korunan sey rozetin SOLA yasli kalmasidir.
    testWidgets('durum rozeti kimligin altinda ve sola yasli', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      final surface = _sheetSurface(tester);
      final rect = _globalRect(surface);
      final header = _globalRect(
        tester.renderObject<RenderBox>(
          find.byKey(const Key('camper-sheet-identity-header')),
        ),
      );
      final status = tester.renderObject<RenderBox>(
        find.byKey(const Key('camper-sheet-status')),
      );
      final statusRect = _globalRect(status);

      expect(statusRect.left - rect.left, lessThan(rect.width * 0.25));
      expect(
        statusRect.top,
        greaterThanOrEqualTo(header.bottom),
        reason: 'rozet kimlik blogunun altina inmemis',
      );
    });
  });

  // ── IDDIA 3: islev kaybi yok (her bilgi AYRI iddia) ───────────────────────
  group('WP-711/3 — revizyon oncesi gosterilen hicbir bilgi kaybolmadi', () {
    testWidgets('ad', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(_peer.displayName),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hayvan etiketi', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('🏕️'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('durum metni', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Çevrimdışı'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bugunku toplam etiketi VE degeri', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      expect(find.text('Bugünkü toplam'), findsOneWidget);
      // 🔴 Etiket yetmez: bu depoda etiketi cizilip degeri cizilmeyen yuzey
      // ("kullanicinin GORDUGU satiri test et", 0126) kapi boyunca yesil kaldi.
      expect(
        find.descendant(
          of: find.byKey(const Key('camper-stat-today')),
          matching: find.text(formatHumanSeconds(25 * 60)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('su anki oturum (yalniz calisan uyede)', (tester) async {
      await _pumpCampfire(tester, peerIsStudying: true);
      await _tapCamper(tester, _peer.id);
      expect(find.text('Şu anki oturum'), findsOneWidget);
      expect(find.byKey(const Key('camper-stat-session')), findsOneWidget);
    });

    testWidgets('su anki oturum calismayan uyede YOK', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      expect(find.text('Şu anki oturum'), findsNothing);
    });

    testWidgets('durtme dugmesi', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      expect(find.widgetWithText(FilledButton, 'Dürt'), findsOneWidget);
    });

    testWidgets('bildir ve engelle satirlari', (tester) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);
      expect(find.byKey(const ValueKey('peer-safety-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('peer-safety-block')), findsOneWidget);
    });

    testWidgets('kendi kartinda durtme ve guvenlik satirlari yok', (
      tester,
    ) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _me.id);
      expect(find.widgetWithText(FilledButton, 'Dürt'), findsNothing);
      expect(find.byKey(const ValueKey('peer-safety-block')), findsNothing);
      // ...ama profil yolu kendi kartinda da acik.
      expect(find.byKey(const Key('camper-sheet-profile')), findsOneWidget);
    });
  });

  // ── IDDIA 4: yeni sayilarin gercek kaynagi var ────────────────────────────
  group('WP-711/4 — sag koloncaki sayilar gercek kaynaktan', () {
    testWidgets('toplam sure grup gunluk toplamlarindan geliyor', (
      tester,
    ) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      // 3 gun x 90 dk = 270 dk.
      expect(
        find.descendant(
          of: find.byKey(const Key('camper-stat-total')),
          matching: find.text(formatHuman(3 * 90 * 60)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rekor seri uyenin KENDI hedefiyle hesaplaniyor', (
      tester,
    ) async {
      await _pumpCampfire(tester);
      await _tapCamper(tester, _peer.id);

      // Hedef 60 dk, uc gun ust uste 90 dk → 3 gun.
      expect(
        find.descendant(
          of: find.byKey(const Key('camper-stat-streak')),
          matching: find.text('3 gün'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('gorulebilir kayit yoksa toplam/seri UYDURULMAZ', (
      tester,
    ) async {
      await _pumpCampfire(tester, stats: const []);
      await _tapCamper(tester, _peer.id);

      // 🔴 "0" yazmak "bu kisi hic calismadi" demektir; dogrusu "goremiyoruz".
      // `group_daily_totals` bos donduyse dosemeler HIC cizilmez.
      expect(find.byKey(const Key('camper-stat-total')), findsNothing);
      expect(find.byKey(const Key('camper-stat-streak')), findsNothing);
      // Bugunku toplam baska kaynaktan geldigi icin yerinde kalir.
      expect(find.byKey(const Key('camper-stat-today')), findsOneWidget);
    });
  });

  // ── IDDIA 5: dar ekran + buyuk yazi ───────────────────────────────────────
  group('WP-711/5 — dar ekranda ve buyuk yazida tasma yok', () {
    testWidgets('360 dp, olcek 1.0', (tester) async {
      await _pumpCampfire(tester, peerIsStudying: true);
      await _tapCamper(tester, _peer.id);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360 dp, olcek 1.6 (erisilebilirlik)', (tester) async {
      await _pumpCampfire(tester, peerIsStudying: true, textScale: 1.6);
      await _tapCamper(tester, _peer.id);
      expect(tester.takeException(), isNull);
    });

    testWidgets('320 dp gibi cok dar bir cihazda da tasmaz', (tester) async {
      await _pumpCampfire(
        tester,
        peerIsStudying: true,
        size: const Size(320, 640),
      );
      await _tapCamper(tester, _peer.id);
      expect(tester.takeException(), isNull);
    });
  });
}
