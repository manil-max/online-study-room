import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/main.dart';

void main() {
  testWidgets('Uygulama 3 sekmeyle açılır ve Sınıf sekmesi seçilidir',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: OnlineStudyRoomApp()),
    );

    // Üç sekme etiketi de var.
    expect(find.text('Sınıf'), findsWidgets);
    expect(find.text('İstatistik'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);

    // Başlangıçta ilk sekme (Sınıf) seçili.
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);
  });

  testWidgets('İstatistik sekmesine geçilebilir', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: OnlineStudyRoomApp()),
    );

    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
  });
}
