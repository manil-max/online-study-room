import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/main.dart';

/// Giriş yapmış bir kullanıcıyla seed'lenmiş repo döndürür.
Future<InMemoryAuthRepository> _signedInRepo() async {
  final repo = InMemoryAuthRepository();
  await repo.signUp(email: 'ali@ornek.com', password: '123456', displayName: 'Ali');
  return repo;
}

Widget _appWith(InMemoryAuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: const OnlineStudyRoomApp(),
  );
}

void main() {
  testWidgets('Giriş yapılmamışken giriş ekranı görünür', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OnlineStudyRoomApp()));
    await tester.pumpAndSettle();

    expect(find.text('Giriş yap'), findsWidgets);
    expect(find.text('E-posta'), findsOneWidget);
  });

  testWidgets('Giriş yapılınca 3 sekme görünür', (tester) async {
    await tester.pumpWidget(_appWith(await _signedInRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Sınıf'), findsWidgets);
    expect(find.text('İstatistik'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);
  });

  testWidgets('Sınıfı olmayan kullanıcı oluştur/katıl seçeneklerini görür',
      (tester) async {
    await tester.pumpWidget(_appWith(await _signedInRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Sınıf oluştur'), findsOneWidget);
    expect(find.text('Koda katıl'), findsOneWidget);
  });

  testWidgets('İstatistik sekmesine geçilebilir', (tester) async {
    await tester.pumpWidget(_appWith(await _signedInRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
  });

  testWidgets('Çıkış yapınca giriş ekranına dönülür', (tester) async {
    final repo = await _signedInRepo();
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    // Profil sekmesine geç ve çıkış yap.
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıkış yap'));
    await tester.pumpAndSettle();

    expect(find.text('E-posta'), findsOneWidget);
  });
}
