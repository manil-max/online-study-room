// WP-374 (V51-3 + V51-4): geri bildirim yazışmasının sohbet düzeni ve
// yöneticinin kullanıcıya giden yolunun iç notlardan ayrılması.
//
// Bu iki bulgu birlikte kayda geçiyor çünkü aynı yüzeyin iki ucudur: kullanıcı
// tarafında görünen pencere en eskide takılı kalıyordu, yönetici tarafında da
// "İç Notlar" bir sohbet gibi göründüğü için kullanıcıya hiç yazılmıyordu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/tabs/admin_reports_tab.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Widget _wrap(InMemoryAdminRepository repo, String userId, Widget home) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(
            id: userId,
            displayName: userId,
            createdAt: DateTime(2026),
          ),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Sekme uretimde Scaffold'un body'sinde duruyor (admin_screen.dart);
      // kosum bunu taklit etmezse Material isteyen widget'lar patlar.
      home: Scaffold(body: home),
    ),
  );
}

void main() {
  testWidgets('yazışma açılınca en yeni mesaj görünür, en eski görünmez', (
    tester,
  ) async {
    final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
    addTearDown(repo.dispose);
    final ticket = await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.bug,
      subject: 'Uzun yazışma',
      message: 'İlk kayıt.',
    );
    // Diyalog gövdesi 440 px; 30 balon kesin taşırır.
    for (var i = 1; i <= 30; i++) {
      await repo.sendTicketMessage(
        userId: i.isEven ? 'admin' : 'u1',
        ticketId: ticket.id,
        message: 'Mesaj $i',
      );
    }

    await tester.pumpWidget(_wrap(repo, 'u1', const FeedbackTicketsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzun yazışma'));
    await tester.pumpAndSettle();

    // 🔴 Kapan: kaydırma yoksa pencere en eskide kalır ve bu iki iddia yer
    // değiştirir. Sona kaydırma kaldırılınca test kırmızı düşer.
    expect(find.text('Mesaj 30'), findsOneWidget);
    expect(find.text('Mesaj 1'), findsNothing);
  });

  testWidgets('yeni mesaj gönderilince görünüm yine sona kayar', (
    tester,
  ) async {
    final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
    addTearDown(repo.dispose);
    final ticket = await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.bug,
      subject: 'Uzun yazışma',
      message: 'İlk kayıt.',
    );
    for (var i = 1; i <= 30; i++) {
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'Mesaj $i',
      );
    }

    await tester.pumpWidget(_wrap(repo, 'u1', const FeedbackTicketsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzun yazışma'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Son sözüm.');
    await tester.tap(find.byKey(const Key('feedback-send-reply')));
    await tester.pumpAndSettle();

    expect(find.text('Son sözüm.'), findsOneWidget);
  });

  testWidgets('yönetici kartında kullanıcıya yanıt yolu iç notlardan önce gelir', (
    tester,
  ) async {
    final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
    addTearDown(repo.dispose);
    await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.bug,
      subject: 'Sıralama bileti',
      message: 'Gövde.',
    );

    await tester.pumpWidget(_wrap(repo, 'admin', const AdminReportsTab()));
    await tester.pumpAndSettle();

    final reply = find.text('Yanıt yaz');
    final notes = find.text('İç Notlar');
    expect(reply, findsOneWidget);
    expect(notes, findsOneWidget);
    // Kullanıcıya giden yol her zaman iç notların üstünde/solunda durmalı;
    // ikisinin yer değiştirmesi V51-4'ün ta kendisiydi.
    final replyTop = tester.getTopLeft(reply);
    final notesTop = tester.getTopLeft(notes);
    expect(
      replyTop.dy < notesTop.dy ||
          (replyTop.dy == notesTop.dy && replyTop.dx < notesTop.dx),
      isTrue,
      reason: 'Yanıt yaz eylemi iç notlardan önce gelmeli.',
    );
  });

  testWidgets('iç not diyaloğu kullanıcıya görünmediğini açıkça yazar', (
    tester,
  ) async {
    final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
    addTearDown(repo.dispose);
    final ticket = await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.bug,
      subject: 'Not bileti',
      message: 'Gövde.',
    );

    await tester.pumpWidget(_wrap(repo, 'admin', const AdminReportsTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('feedback-notes-${ticket.id}')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('yalnız yöneticiler görür'),
      findsOneWidget,
    );
  });
}
