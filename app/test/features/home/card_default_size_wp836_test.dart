// WP-836 — Ana ekran kartları düzgün boyutla eklensin + ekleme önizlemesi.
//
// Sahip (gerçek cihaz, v85):
//   1. *"sayaç widget'ının uzunluğu artsın, ilk hali az"*
//   2. *"kartları eklediğinde genelde hepsini elle boyutunu ayarlamak
//      gerekiyor, hep bozuk geliyor"*
//   3. *"yeni kart eklemek için olan yerde kartların nasıl bir şey olduğunu
//      önizleme gibi görse iyi olur"*
//
// 🔴 ÖLÇÜLEN ESKİ KURAL (bu WP'nin dayandığı ölçüm):
//   `dashboard_providers.dart` `addCard` → `DashboardCardConfig.defaultAddWidth`
//   / `defaultAddHeight` — kart TÜRÜNDEN bağımsız, 6-sütun 3×3 ölçeği, yani
//   32-ızgarada her kart için **16×16 hücre**. Dar telefonda (içerik 328 px)
//   hücre 2.5 px, boşluk 8 px → 160×160 px. Sayaç kartı ise varsayılan düzende
//   21 satır = **212.5 px** ile geliyordu; `study_timer_card.dart`
//   `kTimerCoreMaxHeight` (240 px) eşiğinin ALTINDA, yani ilk açılışta yalnız
//   çekirdek düzeni (süre + Başlat/Durdur) çiziliyordu.
//
// Bu dosya dört şeyi ölçer:
//   (a) her kart türü KENDİ ilan ettiği hücreyle eklenir,
//   (b) sayacın varsayılanı çekirdek eşiğini gerçekten aşar (sahip maddesi 1),
//   (c) KAYDEDİLMİŞ bir düzen bu değişiklikten sonra bir piksel oynamaz
//       (geriye uyumluluk — mevcut kullanıcının kartları yeniden boyutlanmaz),
//   (d) seçici her tür için bir önizleme çizer ve bunu VERİ OKUMADAN yapar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dashboard_providers.dart';
import 'package:online_study_room/features/home/widgets/card_picker.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _kColumns = 32;
const String _kLayoutKey = 'dashboard_layout_v2_32';

// Ana Sayfa ızgarasının gerçek geometrisi (`home_screen.dart` → `_MatrixGrid`).
// Test kendi piksel sabitini uydurmaz; ürünün formülünü kullanır.
const double _kGap = 8.0;
const double _kNarrowPhoneContent = 328;

double _cell(double content) => (content - (_kColumns - 1) * _kGap) / _kColumns;

double _span(double content, int units) =>
    units * _cell(content) + (units - 1) * _kGap;

/// Dinleyicisiz provider Riverpod 3'te her `read`de yeniden kurulur ve
/// regresyonu gizler; her kapta bir abone tutulur.
ProviderContainer _container(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  final sub = c.listen(dashboardLayoutProvider, (_, _) {});
  addTearDown(sub.close);
  return c;
}

Future<SharedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  // =====================================================================
  // (a) Her kart türü kendi ilan ettiği hücreyle gelir
  // =====================================================================
  group('WP-836 · yeni kart türünün kendi varsayılan hücresiyle eklenir', () {
    for (final type in DashboardCardType.values) {
      test(type.name, () async {
        // Boş pano: varsayılan düzen devreye girmesin, ölçülen tek şey
        // EKLEME kuralı olsun.
        final prefs = await _prefs({_kLayoutKey: <String>[]});
        final c = _container(prefs);
        expect(c.read(dashboardLayoutProvider), isEmpty);

        c.read(dashboardLayoutProvider.notifier).addCard(type);
        final added = c
            .read(dashboardLayoutProvider)
            .firstWhere((card) => card.type == type);

        final expected = type.defaultCells(_kColumns);
        expect(
          (added.w, added.h),
          (expected.w, expected.h),
          reason:
              '${type.name} ilan ettiği hücreyle eklenmedi; kullanıcı kartı '
              'elle boyutlandırmak zorunda kalır (sahip: "hep bozuk geliyor").',
        );
        // Diske de aynı hücre yazılmalı: bu depoda bellekte doğru olup diske
        // yazılmayan bir değişiklik daha önce sessizce kaybolmuştu.
        expect(prefs.getStringList(_kLayoutKey), [added.encode()]);
      });
    }

    test('hiçbir tür ızgaranın dışına taşmaz', () {
      for (final type in DashboardCardType.values) {
        final cells = type.defaultCells(_kColumns);
        expect(cells.w, inInclusiveRange(1, _kColumns));
        expect(cells.h, greaterThanOrEqualTo(1));
      }
    });
  });

  // =====================================================================
  // (b) Sahip maddesi 1 — sayaç artık çekirdek eşiğinin üstünde geliyor
  // =====================================================================
  group('WP-836 · sayacın ilk boyu', () {
    test('varsayılan düzen çekirdek eşiğini (240 px) aşar', () async {
      final prefs = await _prefs(const {});
      final c = _container(prefs);
      final timer = c
          .read(dashboardLayoutProvider)
          .firstWhere((card) => card.type == DashboardCardType.timer);

      expect(timer.h, DashboardCardType.timer.defaultCells(_kColumns).h);

      final px = _span(_kNarrowPhoneContent, timer.h);
      expect(
        px,
        greaterThan(kTimerCoreMaxHeight),
        reason:
            'Dar telefonda sayaç hücresi ${px.toStringAsFixed(1)} px; '
            '$kTimerCoreMaxHeight px altında kart yalnız ÇEKİRDEĞİNİ çizer '
            '("Bugün" toplamı, büyük saat ve faz satırı olmadan) — sahibin '
            '"ilk hali az" dediği durum tam olarak budur.',
      );

      // Eski değer (21 satır) aynı ekranda eşiğin altında kalıyordu; kapı
      // sayının BÜYÜDÜĞÜNÜ değil, EŞİĞİ geçtiğini ölçüyor.
      expect(_span(_kNarrowPhoneContent, 21), lessThan(kTimerCoreMaxHeight));
    });

    test('kart olarak eklenen sayaç da aynı boyla gelir', () async {
      final prefs = await _prefs({_kLayoutKey: <String>[]});
      final c = _container(prefs);
      c.read(dashboardLayoutProvider.notifier).addCard(DashboardCardType.timer);
      final timer = c
          .read(dashboardLayoutProvider)
          .firstWhere((card) => card.type == DashboardCardType.timer);
      expect(
        _span(_kNarrowPhoneContent, timer.h),
        greaterThan(kTimerCoreMaxHeight),
      );
    });
  });

  // =====================================================================
  // (c) Geriye uyumluluk — kaydedilmiş düzen bir piksel oynamaz
  // =====================================================================
  group('WP-836 · kaydedilmiş düzen dokunulmadan kalır', () {
    /// Kullanıcının elle boyutlandırdığı bir pano: HER tür var ve hiçbiri
    /// yeni varsayılanla aynı değil, yani bir "göç" olsaydı mutlaka görünürdü.
    List<String> storedLayout() {
      final raw = <String>[];
      var y = 0;
      for (final type in DashboardCardType.values) {
        raw.add('${type.name}:0:$y:16:9');
        y += 9;
      }
      return raw;
    }

    test('yeniden kurulumda hiçbir kartın x/y/w/h değeri değişmez', () async {
      final stored = storedLayout();
      final prefs = await _prefs({_kLayoutKey: stored});
      final c = _container(prefs);

      final layout = c.read(dashboardLayoutProvider);
      expect(
        layout.map((card) => card.encode()).toList(),
        stored,
        reason:
            'Kaydedilmiş düzen yeni varsayılanlara göre yeniden boyutlandı. '
            'Varsayılan tablo yalnız YENİ eklenen karta uygulanır; mevcut '
            'kullanıcının panosu bir güncellemeyle yeniden dizilemez.',
      );
      // Diskteki kayıt da olduğu gibi durmalı (sessiz yeniden yazma yok).
      expect(prefs.getStringList(_kLayoutKey), stored);
    });

    test(
      'mevcut bir kart çıkarılıp geri eklenirse YENİ varsayılanı alır',
      () async {
        // Göç yok demek "yeni kural ölü" demek değil: kullanıcı kartı kendisi
        // yeniden eklediğinde yeni boy devreye girer.
        final prefs = await _prefs({
          _kLayoutKey: <String>['heatmap:0:0:16:9'],
        });
        final c = _container(prefs);
        final notifier = c.read(dashboardLayoutProvider.notifier);

        notifier.toggle(DashboardCardType.heatmap);
        expect(c.read(dashboardLayoutProvider), isEmpty);
        notifier.toggle(DashboardCardType.heatmap);

        final expected = DashboardCardType.heatmap.defaultCells(_kColumns);
        final card = c.read(dashboardLayoutProvider).single;
        expect((card.w, card.h), (expected.w, expected.h));
      },
    );

    test('düzeni sıfırlamak yeni varsayılanı getirir', () async {
      final prefs = await _prefs({
        _kLayoutKey: <String>['timer:0:0:32:21'],
      });
      final c = _container(prefs);
      expect(
        c.read(dashboardLayoutProvider).single.h,
        21,
        reason: 'sıfırlamadan ÖNCE kaydedilmiş değer korunmalı',
      );

      c.read(dashboardLayoutProvider.notifier).reset();
      expect(
        c
            .read(dashboardLayoutProvider)
            .firstWhere((card) => card.type == DashboardCardType.timer)
            .h,
        DashboardCardType.timer.defaultCells(_kColumns).h,
      );
    });
  });

  // =====================================================================
  // (d) Önizleme — her tür için var ve VERİ OKUMUYOR
  // =====================================================================
  group('WP-836 · kart ekleme önizlemesi', () {
    // 🔴 Bu grubun kanıt biçimi kasıtlı: önizleme `ProviderScope` OLMADAN
    // pompalanır. Riverpod'da `ProviderScope` bulunmayan bir ağaçta herhangi
    // bir `ref.watch`/`ref.read` istisna atar. Yani "önizleme ağ isteği
    // yapmaz" burada bir SÖZ değil, ölçülen bir sınırdır: önizleme hiçbir
    // provider'a — dolayısıyla hiçbir repository/Supabase akışına —
    // ulaşamaz. Seçici 18 kartı birden çizdiği için bu kapı olmasaydı tek bir
    // `ref.watch` sızması 18 yeni aboneliğe dönüşürdü.
    for (final type in DashboardCardType.values) {
      testWidgets('${type.name} · ProviderScope olmadan çizilir', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 150,
                  child: DashboardCardPreview(type: type),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(DashboardCardPreview), findsOneWidget);
      });
    }

    testWidgets('seçicide HER tür için bir önizleme kutusu var', (
      tester,
    ) async {
      // Telefon genişliği → seçicinin alt sayfa yolu (masaüstü dialog değil).
      // Görünüm alanı KASTEN çok uzun: `ListView` tembeldir, kısa bir
      // pencerede yalnız ilk birkaç döşeme kurulur ve "her tür" iddiası
      // ölçülemez. 4000 px'lik alanda 18 döşemenin hepsi çizilir.
      tester.view.physicalSize = const Size(400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefs = await _prefs({_kLayoutKey: <String>[]});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showCardPicker(context),
                    child: const Text('ac'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      for (final type in DashboardCardType.values) {
        expect(
          find.byKey(cardPreviewKey(type)),
          findsOneWidget,
          reason:
              '${type.name} seçicide önizlemesiz çiziliyor; kullanıcı ne '
              'eklediğini yalnız simgeden tahmin eder (sahip isteği).',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });
}
