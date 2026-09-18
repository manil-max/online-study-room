import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/home/widgets/group_card_shell.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// 🔴 WP-843 — sahibin ilk açılış ekran görüntüsünde (WP-835 kareleri) grup
/// kartındaki "Grup oluştur" düğmesi **ortadan kesilmişti**. Kart varsayılan
/// düzende yarım genişlikte ve ~160 px yüksekliktedir; başlık + açıklama
/// cümlesi + iki düğme oraya sığmıyor, iç kaydırma açılıyor ve kullanıcı
/// kırpılmış bir düğme görüyor.
///
/// Ölçüm: düğmenin alt kenarı kartın görünür alanının içinde mi?
Widget _host({required double height}) {
  return MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 180,
          height: height,
          child: GroupCardShell(
            title: 'Grup sıralaması',
            onCreateGroup: () {},
            onJoinGroup: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('dar hücrede düğme tam görünür, kesilmez', (tester) async {
    await tester.pumpWidget(_host(height: 160));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Grup oluştur');
    expect(button, findsOneWidget);

    final cardBox = tester.getRect(find.byType(GroupCardShell));
    final buttonBox = tester.getRect(button);
    expect(
      buttonBox.bottom,
      lessThanOrEqualTo(cardBox.bottom),
      reason: 'düğme kartın alt kenarından taşıyor — kesik görünür',
    );
  });

  testWidgets('dar hücrede açıklama cümlesi düşer, davet kalır', (
    tester,
  ) async {
    await tester.pumpWidget(_host(height: 160));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bir gruba katılınca'), findsNothing);
    expect(find.text('Grup oluştur'), findsOneWidget);
    expect(find.text('Koda katıl'), findsOneWidget);
  });

  testWidgets('geniş hücrede açıklama cümlesi korunur', (tester) async {
    await tester.pumpWidget(_host(height: 320));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bir gruba katılınca'), findsOneWidget);
    expect(find.text('Grup oluştur'), findsOneWidget);
  });
}
