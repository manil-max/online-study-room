// WP-703/1 — `NumberStepper` 360 dp telefon genisliginde tasiyor.
//
// 🔴 Neden bugune kadar gorunmedi: bilesenin **hicbir** testi onu telefon
// genisliginde cizmiyordu. `ux_quick_wins_wp555_test.dart` hedef diyalogunu
// bilerek 800 dp'de aciyor ve dosyanin icine sunu yaziyor: *"goal_editor_dialog
// 360dp'de 8px RenderFlex tasmasi uretiyor ... tasma ayri kart olarak
// raporlandi"*. Yani kusur biliniyordu, olculuyordu ve hicbir iddia onu
// tutmuyordu. Ayni kor nokta bir tur once `_StatCard`'ta 73 px sakladi.
//
// ## ONCE OLCULDU (2026-08-11, bu dosyanin ilk kosumu, duzeltmeden once)
//
//   A RenderFlex overflowed by 8.0 pixels on the right.
//   ... Row  <- NumberStepper  <- Expanded  <- Row  <- Column (AlertDialog)
//
// Aritmetigi: `AlertDialog` 360 dp ekranda 40 dp kenar bosluguyla 280 dp'ye
// kilitlenir, 24 dp ic dolgu duser, aradaki 12 dp bosluk duser, iki
// `NumberStepper`a **110 dp** kalir. Iki `IconButton.filledTonal` 48+48 = 96 dp
// ve deger metni ("23" / "59", `titleLarge`) ~22 dp: toplam 118 dp.
//
// Iddia bu yuzden **iki katmanda** durur:
//   1. bilesen kendi basina 110 dp'lik kutuda tasmamali (SAHIP dosya),
//   2. kullanicinin gordugu gercek yuzey (hedef diyalogu) 360 dp'de tasmamali.
// Yalniz (2) yazilsaydi, tasmayi cagri yerinde gizleyen bir yama da yesil
// yapardi; yalniz (1) yazilsaydi gercek ekranin olculdugu iddia edilemezdi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/widgets/number_stepper.dart';
import 'package:online_study_room/features/profile/widgets/goal_editor_dialog.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Yaygin telefon genisligi. Sayi burada durur: cagri yerindeki bir sabite
/// baglanmaz, yoksa o sabiti buyutmek iddiayi da buyutur.
const double _kPhoneWidth = 360;

/// Diyalogun iki sayaca biraktigi olculen genislik (280 − 24 dolgu − 12 ara)/2.
const double _kStepperSlot = 110;

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void _phone(WidgetTester tester, {double width = _kPhoneWidth}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('WP-703/1 — dar ekranda sayac tasmaz', () {
    testWidgets('bilesen 110 dp kutuda tasmaz (en buyuk deger cizilir)', (
      tester,
    ) async {
      _phone(tester);
      var value = 59;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: _kStepperSlot,
                child: NumberStepper(
                  label: 'Dakika',
                  value: value,
                  min: 0,
                  max: 59,
                  onChanged: (v) => value = v,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Govde gercek mi? Bos bir kabugu olcmuyoruz.
      expect(find.text('59'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason:
            'NumberStepper $_kStepperSlot dp kutuda tasti; hedef diyalogu '
            '360 dp telefonda tam bu kutuyu veriyor.',
      );

      // Cizilen satir kutuyu gercekten asmiyor mu — istisna yutulsa bile bu
      // olcum duser.
      final row = find.descendant(
        of: find.byType(NumberStepper),
        matching: find.byType(Row),
      );
      expect(
        tester.getSize(row).width,
        lessThanOrEqualTo(_kStepperSlot),
        reason: 'Sayac satiri kendisine verilen kutudan genis cizildi.',
      );
    });

    testWidgets('gunluk hedef diyalogu 360 dp telefonda tasmaz', (tester) async {
      _phone(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      // 23sa 59dk: her iki sayac da en genis degerini cizer.
      showGoalEditorDialog(ctx, initialMinutes: 23 * 60 + 59);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
      expect(find.text('59'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason:
            'ux_quick_wins_wp555_test.dart bu diyalogu 360 dp yerine 800 dp\'de '
            'aciyor cunku burada "RenderFlex overflowed by 8.0 pixels" dusuyor.',
      );
    });

    testWidgets('+/- dugmeleri dar ekranda da 48 dp dokunma hedefi', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: _kStepperSlot,
                child: NumberStepper(
                  label: 'Dakika',
                  value: 59,
                  min: 0,
                  max: 59,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttons = find.descendant(
        of: find.byType(NumberStepper),
        matching: find.byType(IconButton),
      );
      expect(buttons, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final size = tester.getSize(buttons.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(48),
          reason:
              'Tasmayi dugmeyi kucultmek pahasina kapatmak yasak: '
              'DoD 48 dp dokunma hedefi istiyor. Olculen: $size',
        );
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('dar ekranda sayac hala calisir (deger artar)', (tester) async {
      _phone(tester);
      var value = 5;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: _kStepperSlot,
                  child: NumberStepper(
                    label: 'Dakika',
                    value: value,
                    min: 0,
                    max: 59,
                    onChanged: (v) => setState(() => value = v),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(
        value,
        6,
        reason: 'Tasma duzeltmesi dugmenin isini bozmamali.',
      );
      expect(find.text('6'), findsOneWidget);
    });
  });
}
