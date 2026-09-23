import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tour/tour_models.dart';
import 'package:online_study_room/core/tour/tour_overlay.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

void main() {
  List<TourDefinition> definitions(
    AppLocalizations l10n, {
    required bool hasContent,
  }) {
    final primary = GlobalKey();
    final secondary = GlobalKey();
    return [
      AppTours.home(l10n),
      AppTours.dashboardEdit(l10n),
      AppTours.stats(l10n),
      AppTours.groups(
        l10n,
        contentAnchor: primary,
        switcherAnchor: secondary,
        hasGroup: hasContent,
      ),
      AppTours.campfire(l10n, campfireAnchor: primary, hasGroup: hasContent),
      AppTours.profile(l10n, identityAnchor: primary, actionsAnchor: secondary),
      AppTours.settings(l10n),
    ];
  }

  // 🔴 WP-799 — ÖNCE BUNU OKU. Bu dosyanın iddiaları uzun süre yalnız
  // TANIMI ölçtü ("dört tur var, metinleri kısa"). `campfire` ve `profile`
  // turları `lib/` içinde **hiç çağrılmadığı** hâlde bu kapı yeşil geçiyordu:
  // dört dilde metni olan, sürümlenmiş, testli — ve kullanıcının asla
  // görmediği iki tur. Aşağıdaki `every tour definition is mounted by a real
  // screen` iddiası eksik olan ölçümdür; sayı saymak onun yerine geçmez.
  //
  // 🔴 WP-417: sahip ana ekran turunu tek adıma indirdi ve istatistik dönem
  // turunu tamamen kaldırdı. Sayı burada sabit; yeni bir tur sessizce eklenirse
  // ya da geri gelirse bu test kırılır.
  //
  // 🔴 WP-837 (sahip): dört tur altı oldu — pano düzenleme modu ve istatistik
  // ekranı birer balon kazandı. Her yeni tur **tek adım**; sayı hâlâ sabit.
  //
  // 🔴 WP-849 (sahip): yedinci tur Ayarlar. Sahip "tek kart, sığmazsa 2. kart"
  // dedi; üç yer (görünüm, izinler, hesap) tek balona sığmadı, bu yüzden
  // tam olarak iki adım.
  //
  // 🔴 WP-920 (sahip): *"kartlardaki bilgiler çok az, hiçbir şeyi anlatmıyor
  // … çok karta gerek yok, karttaki bilgileri arttır."* Kart SAYILARI aynı
  // kaldı; değişen gövdenin kapısı. Eski kapı "en fazla iki satır, 110
  // karakter"di ve turları telgraf üslubuna zorluyordu. Yeni kapı iki yönlü:
  //   - ÜST sınır: cihazda en fazla 7 satır / 280 karakter (360 dp telefonda
  //     balon ekranın yarısını geçmesin; küçük ekranda büyük yazı için balon
  //     içinde kaydırma var, bkz. `rich_tours_wp920_test.dart`).
  //   - ALT sınır: en az 120 karakter. Tek kısa cümle geri gelirse bu kapı
  //     kırılır — sahibin şikâyeti tam olarak oydu.
  test('seven tours have stable versioned ids and rich readable steps', () {
    final overflowingSteps = <String>[];
    for (final l10n in [AppLocalizationsTr(), AppLocalizationsEn()]) {
      for (final hasContent in [true, false]) {
        final tours = definitions(l10n, hasContent: hasContent);
        // WP-488: ana ekran turu metni davranış değiştirdiği için v2.
        // WP-799: ilk balon artık kart düzenlemeyi değil sayacı öğretiyor → v3.
        // 🔴 `stats` sürüm 2'den başlar: `stats.v1` WP-324'te gerçekten
        // yayınlanmış ve WP-417'de kaldırılmıştı, o anahtar hâlâ cihazlarda.
        // 🔴 WP-920: metinlerin hepsi değişti → her tur bir sürüm ileri.
        expect(tours.map((tour) => tour.storageId), [
          'home.v5',
          'dashboard_edit.v2',
          'stats.v3',
          'groups.v2',
          'campfire.v2',
          'profile.v2',
          'settings.v2',
        ]);
        expect(tours.last.steps, hasLength(2));
        // 🔴 WP-837 sahip şartı: üç yüzeyin her birinde **tek** kart.
        // WP-920 bunu değiştirmedi ("çok karta gerek yok").
        for (final single in tours.take(3)) {
          expect(single.steps, hasLength(1), reason: single.storageId);
        }
        expect(tours.first.steps.single.id, 'overview');
        expect(tours.map((tour) => tour.id).toSet(), hasLength(tours.length));

        for (final tour in tours) {
          expect(tour.steps, isNotEmpty);
          expect(tour.steps.length, lessThanOrEqualTo(2));
          expect(
            tour.steps.map((step) => step.id).toSet(),
            hasLength(tour.steps.length),
          );
          for (final step in tour.steps) {
            final where = '${l10n.localeName}:${tour.storageId}/${step.id}';
            expect(step.text.trim(), isNotEmpty);
            expect(step.text, isNot(contains('\n')));
            expect(step.text.length, lessThanOrEqualTo(280), reason: where);
            expect(
              step.text.length,
              greaterThanOrEqualTo(120),
              reason: '$where: tek kısa cümle geri geldi (WP-920)',
            );
            expect(step.title, isNotNull, reason: where);
            // 🔴 WP-837 — ÖLÇÜM GENİŞLİĞİ KALİBRE EDİLDİ (288 → 576).
            //
            // Balonun gerçek içerik genişliği 360 dp ekranda 288 dp'dir
            // (balon 328 dp tavan − 2×20 dp iç boşluk) ve bu sayı DOĞRU.
            // Yanlış olan fonttu: `flutter test` her glifi `fontSize` kadar
            // KARE çizer, yani 14 px'te satır başına ~20 karakter sayar;
            // cihazdaki orantılı font (Roboto 14 sp, ortalama ~7 dp) aynı
            // 288 dp'ye ~41 karakter sığdırır. Ölçüm genişliği iki katına
            // alınarak font farkı düzeltilir.
            //
            // WP-920: iddia artık "gövde CİHAZDA yedi satırı geçmesin".
            final bodyLayout = TextPainter(
              text: TextSpan(
                text: step.text,
                style: const TextStyle(fontSize: 14),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 7,
            )..layout(maxWidth: 288 * 2);
            if (bodyLayout.didExceedMaxLines) {
              overflowingSteps.add(where);
            }
          }
        }
      }
    }
    expect(overflowingSteps, isEmpty, reason: 'Tour body exceeds seven lines');
  });

  // 🔴 WP-799 — ÖLÇÜLEN ŞEY BAĞLANTI, TANIM DEĞİL.
  //
  // Denetim bulgusu: `AppTours.campfire` ve `AppTours.profile` tanımlıydı,
  // dört dilde metni vardı, bu dosya onları "dört tur" diye sayıyordu — ama
  // `lib/` içinde tek bir çağıranları yoktu. `classroom_screen.dart` kamp
  // ateşi çapasını oluşturup aşağı geçiriyor, hiçbir tur onu kullanmıyordu.
  // Bir tur yalnız bir ekran onu `TourHost`a verdiğinde vardır.
  test('every tour definition is mounted by a real screen', () {
    const defsPath = 'lib/features/tours/app_tours.dart';
    final names = RegExp(r'static TourDefinition (\w+)\(')
        .allMatches(File(defsPath).readAsStringSync())
        .map((match) => match.group(1)!)
        .toList();
    expect(
      names,
      hasLength(7),
      reason:
          'Tur tanimlari taranamadi ya da sayi degisti; kapi bos olcum '
          'yapmasin diye burasi bilerek sabit.',
    );

    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.replaceAll(r'\', '/').endsWith(defsPath))
        .map((file) => (path: file.path, text: file.readAsStringSync()))
        .toList();
    expect(sources.length, greaterThan(100), reason: 'lib/ taramasi bos.');

    for (final name in names) {
      final callers = sources
          .where((source) => source.text.contains('AppTours.$name('))
          .toList();
      expect(
        callers,
        isNotEmpty,
        reason:
            '`AppTours.$name` tanimli ama lib/ icinde hicbir yerden '
            'cagrilmiyor: metinleri yazilmis, surumlenmis ve kullaniciya hic '
            'gorunmeyen bir tur. Ya bagla ya sil.',
      );
      expect(
        callers.any((source) => source.text.contains('TourHost(')),
        isTrue,
        reason:
            '`AppTours.$name` cagriliyor ama cagiran dosya turu monte eden '
            '`TourHost`u kurmuyor; tanim bir degiskene atanip birakilmis '
            'olabilir.',
      );
    }
  });

  test('empty states never point at content that does not exist', () {
    final l10n = AppLocalizationsTr();

    final home = AppTours.home(l10n);
    final campfire = AppTours.campfire(
      l10n,
      campfireAnchor: GlobalKey(),
      hasGroup: false,
    );

    // WP-488: düzenle butonu kalktı, ana ekran adımı artık çapasız gösteriliyor.
    expect(home.steps.single.anchor, isNull);
    expect(campfire.steps.single.anchor, isNull);
  });

  test('Turkish and English tour content is independently localized', () {
    final tr = definitions(AppLocalizationsTr(), hasContent: true);
    final en = definitions(AppLocalizationsEn(), hasContent: true);

    for (var index = 0; index < tr.length; index++) {
      expect(
        tr[index].steps.map((step) => step.text),
        isNot(equals(en[index].steps.map((step) => step.text))),
      );
    }
  });

  testWidgets('all Turkish and English balloons fit a 360 px screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final allDefinitions = [
      ...definitions(AppLocalizationsTr(), hasContent: true),
      ...definitions(AppLocalizationsTr(), hasContent: false),
      ...definitions(AppLocalizationsEn(), hasContent: true),
      ...definitions(AppLocalizationsEn(), hasContent: false),
    ];

    for (final definition in allDefinitions) {
      for (var index = 0; index < definition.steps.length; index++) {
        final original = definition.steps[index];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TourOverlay(
                step: TourStep(
                  id: original.id,
                  title: original.title,
                  text: original.text,
                ),
                index: index,
                strings: const TourOverlayStrings(
                  skip: 'Atla / Skip',
                  next: 'İleri / Next',
                ),
                onNext: _noop,
                onSkip: _noop,
                onAnchorLost: _noop,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final bubble = tester.getRect(find.byKey(const Key('tour-bubble')));
        expect(bubble.left, greaterThanOrEqualTo(0));
        expect(bubble.top, greaterThanOrEqualTo(0));
        expect(bubble.right, lessThanOrEqualTo(360));
        expect(bubble.bottom, lessThanOrEqualTo(640));
      }
    }
  });
}

void _noop() {}
