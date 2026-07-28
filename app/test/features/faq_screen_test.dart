import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/faq_entry.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/support_providers.dart';
import 'package:online_study_room/data/repositories/support_repository.dart';
import 'package:online_study_room/features/support/faq_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('FAQ shows published entries and filters the search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          supportRepositoryProvider.overrideWithValue(_FakeSupportRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FaqScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Widget nasıl eklenir?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'bildirim');
    await tester.pump();
    expect(find.text('Widget nasıl eklenir?'), findsNothing);
    expect(find.text('Bildirimler nerede?'), findsOneWidget);
  });
}

class _FakeSupportRepository implements SupportRepository {
  @override
  Future<List<FaqEntry>> fetchPublishedFaq(String locale) async => [
    const FaqEntry(
      id: 'one',
      locale: 'tr',
      question: 'Widget nasıl eklenir?',
      answer: 'Ana ekranından widget ekle.',
      sortOrder: 1,
    ),
    const FaqEntry(
      id: 'two',
      locale: 'tr',
      question: 'Bildirimler nerede?',
      answer: 'Ayarlardan yönetebilirsin.',
      sortOrder: 2,
    ),
  ];

  @override
  Future<void> submitQuestion({
    required String question,
    required String userId,
  }) async {}
}
