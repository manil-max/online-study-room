import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/onboarding/onboarding_prefs.dart';
import 'package:online_study_room/main.dart';

/// Giriş yapmış bir kullanıcıyla seed'lenmiş repo döndürür.
Future<InMemoryAuthRepository> _signedInRepo() async {
  final repo = InMemoryAuthRepository();
  await repo.signUp(
    email: 'ali@ornek.com',
    password: '123456',
    displayName: 'Ali',
  );
  // WP-166: onboarding kullanıcıya özel; entegrasyon testleri ana kabuğu test eder.
  final profile = await repo.authStateChanges().first;
  if (profile != null) {
    await _prefs.setBool(onboardingCompletedKeyFor(profile.id), true);
  }
  return repo;
}

late SharedPreferences _prefs;

Widget _appWith(InMemoryAuthRepository repo) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
      sharedPreferencesProvider.overrideWithValue(_prefs),
    ],
    child: const OnlineStudyRoomApp(),
  );
}

void main() {
  setUp(() async {
    // Ana Sayfa varsayılan kartlarından sayacı çıkar: sayaç kartının saniyelik
    // periyodik zamanlayıcısı pumpAndSettle'ı bekletir. Testte sayaçsız düzen.
    SharedPreferences.setMockInitialValues({
      'dashboard_layout': ['today', 'leaderboard'],
    });
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('Giriş yapılmamışken giriş ekranı görünür', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(InMemoryAuthRepository()),
          groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
          sharedPreferencesProvider.overrideWithValue(_prefs),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsWidgets);
    expect(find.text('I forgot my password'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('Giriş yapılınca 4 sekme görünür', (tester) async {
    await tester.pumpWidget(_appWith(await _signedInRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Groups'), findsWidgets);
    expect(find.text('Statistics'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('Sınıfı olmayan kullanıcı oluştur/katıl seçeneklerini görür', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith(await _signedInRepo()));
    await tester.pumpAndSettle();

    // Sayaç artık Ana Sayfa'da; Gruplar sekmesine geç.
    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();

    expect(find.text('Create group'), findsOneWidget);
    expect(find.text('Join with code'), findsOneWidget);
  });

  testWidgets('İstatistik sekmesine geçilebilir', (tester) async {
    await tester.pumpWidget(_appWith(await _signedInRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 3);
  });

  testWidgets('Çıkış yapınca giriş ekranına dönülür', (tester) async {
    final repo = await _signedInRepo();
    await tester.pumpWidget(_appWith(repo));
    await tester.pumpAndSettle();

    // Profil sekmesine geç ve çıkış yap (Başarılar kartı üstte; kaydır).
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final logoutButton = find.widgetWithText(FilledButton, 'Sign Out');
    await tester.ensureVisible(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('Gruplar sekmesinde boş durum eylemleri gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(_appWith(await _signedInRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();

    expect(find.text("You're not in a group yet"), findsOneWidget);
    expect(find.text('Create group'), findsOneWidget);
    expect(find.text('Join with code'), findsOneWidget);
  });
}
