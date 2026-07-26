import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  testWidgets('kullanıcı kendi biletindeki yönetim yanıtını görüp geri yazar', (
    tester,
  ) async {
    final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
    addTearDown(repo.dispose);
    final ticket = await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.bug,
      subject: 'Bildirim sorunu',
      message: 'Durdur aksiyonu çalışmıyor.',
    );
    await repo.sendTicketMessage(
      userId: 'admin',
      ticketId: ticket.id,
      message: 'İnceliyoruz.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(
                id: 'u1',
                displayName: 'Kullanıcı',
                createdAt: DateTime(2026),
              ),
            ),
          ),
          adminRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedbackTicketsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Geri bildirimlerim'), findsOneWidget);
    await tester.tap(find.text('Bildirim sorunu'));
    await tester.pumpAndSettle();
    expect(find.text('Yönetim'), findsOneWidget);
    expect(find.text('İnceliyoruz.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ek ayrıntı gönderdim.');
    await tester.tap(find.byKey(const Key('feedback-send-reply')));
    await tester.pumpAndSettle();

    expect(find.text('Ek ayrıntı gönderdim.'), findsOneWidget);
    expect(
      (await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      )).last.message,
      'Ek ayrıntı gönderdim.',
    );
  });
}
