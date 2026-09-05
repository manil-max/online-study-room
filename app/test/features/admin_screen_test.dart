import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/admin_screen.dart';
import 'package:online_study_room/features/admin/ticket/admin_ticket_detail_page.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

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
          adminModerationRepositoryProvider.overrideWithValue(
            InMemoryAdminModerationRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yönetim Paneli'), findsOneWidget);

    // 🔴 WP-A (ADMIN-PANEL-PLAN §5): yedi sekmelik `TabBar` KALKTI, yerine üç
    // yüzey + `NavigationRail` geldi. Bu testin eski "Kullanıcılar sekmesi
    // ekranda yazıyor" iddiası bu yüzden bayattır: 'Kullanıcılar' artık
    // "Kişiler & Gruplar" yüzeyinin bir bölümüdür ve o yüzeye geçmeden
    // çizilmez. Yedi eski sekmenin yedisinin de hâlâ ulaşılabilir olduğunu
    // ölçen harita testi: `test/features/admin/admin_shell_layout_test.dart`
    // ("yedi eski sekmenin hepsi uc yuzeyden ulasilir").
    expect(find.byType(TabBar), findsNothing);

    // 🔴 WP-768: "Raporlar" ayri bir bolum degil. Kuyruk yuzeyi TEK listedir;
    // destek kaydi bolum secmeden ekranda olmali.
    final listFinder = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Bildirim aksiyonu'),
      200,
      scrollable: listFinder,
    );
    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Detaylı incele'), findsOneWidget);
    expect(find.text('Ekran Görüntüsü'), findsNothing);
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
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu alan yalnızca süper-admin içindir.'), findsOneWidget);
    expect(find.text('Kullanıcılar'), findsNothing);
  });

  testWidgets(
    'ekli rapor görsel bağlantısı kurulamazsa hata ve yeniden dene gösterir',
    (tester) async {
      final repo = _FailingAttachmentRepository();
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Görselli hata',
        message: 'Ekran görüntüsü ektedir.',
        attachmentBytes: Uint8List.fromList([1, 2, 3]),
        attachmentExt: 'png',
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
            adminFeedbackTicketsProvider(
              null,
            ).overrideWith((ref) => Future.value([ticket])),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // WP-770: ek onizlemesi biletin kendi sayfasinda, satir ici.
            home: AdminTicketDetailPage(ticket: ticket),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Görsel yüklenemedi.'), findsOneWidget);
      expect(find.byTooltip('Tekrar dene'), findsOneWidget);

      await tester.tap(find.byTooltip('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(repo.attachmentUrlRequestCount, 2);
      expect(find.text('Görsel yüklenemedi.'), findsOneWidget);
    },
  );
}

class _FailingAttachmentRepository extends InMemoryAdminRepository {
  _FailingAttachmentRepository() : super(superAdminUserIds: const {'admin'});

  int attachmentUrlRequestCount = 0;

  @override
  Future<String?> getFeedbackAttachmentUrl(String path) {
    attachmentUrlRequestCount++;
    throw const AdminException(
      'Görsel bağlantısı oluşturulamadı.',
      code: 'attachment_signed_url',
    );
  }
}
