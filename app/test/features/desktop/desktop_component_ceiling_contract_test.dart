// WP-677 KUSUR 2 — BILESEN DUZEYINDE TAVAN KAPISI.
//
// ============================ NEDEN VAR ======================================
//
// Ekran kapisi (`desktop_stretch_contract_test.dart`) bir kok nedeni GOREMEZ.
// Olculmus kanit, WP-674 turunda: o ajan `profile_stats_panel.dart` icindeki
// genislik tavanini `double.infinity` yapti; kendi IZOLE olcumu satiri
// **1560 px** gordu, ama ekran kapisi **YESIL** kaldi. Sebep basit: profil
// ekrani panele zaten 496 px'lik bir ray veriyor. Dis kap kok nedeni maskeler.
//
// Sonuc, depoda zaten kayitli olan tuzagin bir baska yuzu: kapi yesil yanar,
// kusur yerinde durur ve panel BASKA bir yuzeye tasindigi ilk gun geri gelir.
//
// SPEC §8 bunu zaten sinanabilir iddia olarak yaziyor:
//   madde 3 — "`ProfileStatsPanel` 1600 px genislikte monte edilir; ... mesafe
//              ≤ 496 px."
//   madde 4 — "`PersonalStatsView` 1200 px'te monte edilir; ... her birinin
//              genisligi ≤ 320 px."
//
// ============================ NE OLCER =======================================
//
// Her bilesen, disinda HICBIR ray olmayan **2400 px**'lik bos bir kapta
// cizilir. 2400, SPEC'in `xlarge` bandinin (>=1600) acikca ustunde ve kapinin
// olctugu en genis pencereden (2560) yalnizca kenar boslugu kadar dar; yani
// "kap ne olursa olsun" sorusunu gercekten sorar. Bilesen kendi tavanini
// tasiyorsa sayi kapla birlikte BUYUMEZ.
//
// Olcum yine CIZILEN KAREDEN okunur (`desktop_stretch_probe.dart`): glif
// kutulari ve kart kutulari. Kaynakta `maxWidth: 496` yazmasi kanit degildir.
//
// ============================ NE OLCMEZ ======================================
//
// - Ekran duzenini. O ayri dosyanin isi; ikisi birbirinin yerine gecmez.
// - Yukseklik / dikey akis. Yalnizca YATAY tavan.
// - Mobil dal. 390 px'lik kapta bu tavanlarin hicbiri baglanmaz (kap zaten
//   daha dar), yani SPEC §7'nin "mobil degismez" kurali burada tehlikede degil.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/profile/widgets/profile_stats_panel.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

import 'desktop_stretch_probe.dart';

/// Bilesenin disinda hicbir ray olmadigini garanti eden kap genisligi.
const double kIsolationWidthPx = 2400;

/// SPEC KURAL 2.2 HEDEFI (Bringhurst 66ch) — bir etiket-deger satirinin
/// etiketinin solu ile degerinin sagi arasindaki mesafe.
///
/// Ekran kapisi yalniz 600 px'lik SERT tavani olcer. Burada HEDEFIN kendisi
/// kilitlenir: bilesen duzeyinde 496'yi asmak icin hicbir mazeret yok, cunku
/// bileseni sinirlayan bir ray yok — asiliyorsa tavan bilesende YOKTUR.
const double kLabelValueTargetPx = DesktopBreakpoints.labelValueTargetWidth;

/// SPEC §2.3 — tek sayilik istatistik dosemesi tavani.
const double kStatTilePx = DesktopBreakpoints.maxStatTileWidth;

void main() {
  final tr = AppLocalizationsTr();

  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Bileseni, disinda hicbir genislik kisiti olmayan bos bir kapta cizer.
  ///
  /// [scope] verilmezse cIplak bir `ProviderScope` kullanilir. (Riverpod'un
  /// `Override` tipi genel barrel'dan disari acilmadigi icin liste parametresi
  /// yerine sarmalayici alinir.)
  Future<void> mountIsolated(
    WidgetTester tester,
    Widget component, {
    Widget Function(Widget app)? scope,
    // Kendi `ListView`ini tasiyan bilesenler (ornegin `PersonalStatsView`)
    // kaydirilabilir bir kaba SARILAMAZ: dikey viewport sinirsiz yukseklik
    // alir ve cizim asamasinda patlar.
    bool scrollable = true,
  }) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(kIsolationWidthPx, 1400);
    addTearDown(tester.view.reset);

    final app = MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: scrollable
            ? SingleChildScrollView(child: component)
            : component,
      ),
    );
    await tester.pumpWidget(
      scope?.call(app) ?? ProviderScope(child: app),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// [finder]'in isaret ettigi alt agacin BOYANAN etiket-deger satirlari.
  List<LabelValueRow> rowsOf(WidgetTester tester, Finder finder) {
    final element = finder.evaluate().first;
    final ro = element.renderObject;
    expect(ro, isNotNull, reason: 'Bilesen cizilmemis; olculecek kare yok.');
    return DesktopStretchProbe.labelValueRowsIn(ro!);
  }

  group('ProfileStatsPanel — kendi tavanini tasiyor mu (SPEC §8 madde 3)', () {
    testWidgets(
      '${kIsolationWidthPx.toInt()} px bos kapta etiket-deger satirlari '
      '${kLabelValueTargetPx.toInt()} pikselde durur',
      (tester) async => onWindows(() async {
        await mountIsolated(
          tester,
          const ProfileStatsPanel(userId: 'me', isSelf: true),
          scope: (app) => ProviderScope(
            overrides: [
              userSessionsProvider.overrideWith((ref) => Stream.value(const [])),
            ],
            child: app,
          ),
        );

        final panel = find.byType(ProfileStatsPanel);
        expect(
          panel,
          findsOneWidget,
          reason:
              'Panel cizilmedi. Ortak grup yoksa panel hic cizilmez; o durumda '
              'bu iddia bir sey olcmez ve SESSIZCE yesil yanar — once panelin '
              'ayakta oldugundan emin ol.',
        );

        final rows = rowsOf(tester, panel);
        expect(
          rows,
          isNotEmpty,
          reason:
              'Panelde hic etiket-deger satiri BOYANMADI. Iddianin bos '
              'kumeye bakip yesil yanmasi, kusurdan daha kotudur.',
        );

        final worst = rows.first;
        debugPrint(
          'WP677COMPONENT | ProfileStatsPanel | kap=${kIsolationWidthPx.toInt()} '
          '| satir=${worst.span.toStringAsFixed(0)} px '
          '| bos aralik=${worst.gap.toStringAsFixed(0)} px '
          '| "${worst.label.text}" -> "${worst.value.text}" '
          '| satir sayisi=${rows.length}',
        );

        final wide = rows
            .where((r) => r.span > kLabelValueTargetPx)
            .map(
              (r) =>
                  '"${r.label.text}" -> "${r.value.text}" '
                  '${r.span.toStringAsFixed(0)} px',
            )
            .toList();

        expect(
          wide,
          isEmpty,
          reason:
              '\nBILESEN KENDI TAVANINI TASIMIYOR.\n'
              'Panel ${kIsolationWidthPx.toInt()} px genisliginde bos bir kapta '
              'cizildi ve ${wide.length} satir '
              '${kLabelValueTargetPx.toInt()} px hedefini asti:\n'
              '${wide.map((w) => "  - $w").join("\n")}\n'
              'Bu, profil ekranindaki ray kaldirildigi ya da panel baska bir '
              'yuzeye tasindigi anda kullanicinin gorecegi mesafedir '
              '(SPEC KURAL 2.2, WCAG 2.1 SC 1.4.8).\n',
        );
      }),
    );
  });

  group('PersonalStatsView — istatistik dosemesi (SPEC §8 madde 4)', () {
    testWidgets(
      '${kIsolationWidthPx.toInt()} px bos kapta dort doseme '
      '${kStatTilePx.toInt()} pikselde durur',
      (tester) async => onWindows(() async {
        // Bos oturum listesinde ekran yalniz "Henuz calisma kaydin yok"
        // yazar ve doseme HIC cizilmez; iddia o durumda bos kumeye bakip
        // sessizce yesil yanardi. Bir oturum tohumlanir.
        final now = DateTime(2026, 8, 10, 9);
        await mountIsolated(
          tester,
          PersonalStatsView(
            sessions: [
              StudySession(
                id: 's1',
                userId: 'me',
                start: now,
                end: now.add(const Duration(minutes: 45)),
                durationSeconds: 45 * 60,
                source: StudySource.live,
              ),
            ],
          ),
          scrollable: false,
        );

        final labels = <String>[
          tr.statsToplam,
          tr.statsGunlukOrtalama,
          tr.statsHaftaIci,
          tr.statsHaftaSonu,
        ];

        final measured = <String, Rect>{};
        for (final label in labels) {
          final text = find.text(label);
          if (text.evaluate().isEmpty) continue;
          final card = find
              .ancestor(of: text.first, matching: find.byType(Card))
              .first;
          final ro = card.evaluate().first.renderObject;
          if (ro is! RenderBox || !ro.hasSize) continue;
          measured[label] = DesktopStretchProbe.globalRect(ro);
        }

        expect(
          measured.length,
          labels.length,
          reason:
              'Dort istatistik dosemesinin hepsi bulunamadi (bulunan: '
              '${measured.keys.join(", ")}). Etiketler degistiyse bu iddia '
              'sessizce hicbir sey olcmez hale gelir — once onu duzelt.',
        );

        debugPrint(
          'WP677COMPONENT | PersonalStatsView | kap=${kIsolationWidthPx.toInt()} '
          '| ${measured.entries.map((e) => "${e.key}=${e.value.width.toStringAsFixed(0)}px@dy${e.value.top.toStringAsFixed(0)}").join(" ~~ ")}',
        );

        final fat = measured.entries
            .where((e) => e.value.width > kStatTilePx)
            .map((e) => '"${e.key}" ${e.value.width.toStringAsFixed(0)} px')
            .toList();

        expect(
          fat,
          isEmpty,
          reason:
              '\nBILESEN KENDI TAVANINI TASIMIYOR.\n'
              '${kIsolationWidthPx.toInt()} px bos kapta ${fat.length} doseme '
              '${kStatTilePx.toInt()} px tavanini asti:\n'
              '${fat.map((f) => "  - $f").join("\n")}\n'
              'Tek sayilik bir doseme pencereyle birlikte buyuyorsa sahibin '
              '"800 px kart, icinde tek bir 2s" sikayeti geri gelir '
              '(SPEC §2.3).\n',
        );
      }),
    );
  });
}
