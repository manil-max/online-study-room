import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/admin_screen.dart';

void main() {
  testWidgets('AdminScreen özetleri ve raporları gösterir', (tester) async {
    final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
    addTearDown(repo.dispose);
    await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.bug,
      subject: 'Bildirim aksiyonu',
      message: 'Durdur butonu uygulamayı açıyor.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(
                id: 'admin',
                displayName: 'Admin',
                createdAt: DateTime(2026),
              ),
            ),
          ),
          adminRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yönetim Paneli'), findsOneWidget);
    expect(find.text('Kullanıcılar'), findsWidgets);
    expect(find.text('Raporlar'), findsWidgets);
    
    // Raporlar sekmesine geç
    await tester.tap(find.text('Raporlar').first);
    await tester.pumpAndSettle();

    final listFinder = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Bildirim aksiyonu'),
      200,
      scrollable: listFinder,
    );
    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
  });

  testWidgets('AdminScreen admin olmayan kullanıcıyı engeller', (tester) async {
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(
                id: 'u1',
                displayName: 'Normal',
                createdAt: DateTime(2026),
              ),
            ),
          ),
          adminRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu alan yalnızca süper-admin içindir.'), findsOneWidget);
    expect(find.text('Kullanıcılar'), findsNothing);
  });
}
