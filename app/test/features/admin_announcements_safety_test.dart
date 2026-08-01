import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/tabs/admin_announcements_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  Future<void> pumpTab(
    WidgetTester tester,
    _TrackingAnnouncementRepository repository, {
    double textScale = 1,
  }) async {
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
          adminRepositoryProvider.overrideWithValue(repository),
          adminUsersProvider.overrideWith(
            (ref) => Future.value([
              AdminUserDto(
                id: 'user-1',
                email: 'kullanici@example.com',
                createdAt: DateTime(2026),
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const AdminAnnouncementsTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('duyuru açık onay olmadan silinmez', (tester) async {
    final repository = _TrackingAnnouncementRepository(
      superAdminUserIds: const {'admin'},
      announcements: [
        Announcement(
          id: 'announcement-1',
          title: 'Silinmemeli',
          message: 'Önce onay gerekir.',
          targetType: 'all',
          createdAt: DateTime(2026),
          createdBy: 'admin',
        ),
      ],
    );
    addTearDown(repository.dispose);
    await pumpTab(tester, repository);

    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Duyuru silinsin mi?'), findsOneWidget);
    expect(await repository.fetchAnnouncements(), hasLength(1));

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(await repository.fetchAnnouncements(), hasLength(1));

    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(await repository.fetchAnnouncements(), isEmpty);
    expect(find.text('Silinmemeli'), findsNothing);
  });

  testWidgets(
    'duyuru formu alan bazlı doğrular ve kullanıcıyı listeden hedefler',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _TrackingAnnouncementRepository(
        superAdminUserIds: const {'admin'},
      );
      addTearDown(repository.dispose);
      await pumpTab(tester, repository, textScale: 1.6);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
      await tester.pumpAndSettle();
      expect(find.text('Gerekli alanlar doldurulmalıdır.'), findsNWidgets(2));

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Hedefli duyuru',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Güvenli mesaj');
      await tester.tap(find.text('Herkese'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kullanıcıya Özel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
      await tester.pumpAndSettle();
      expect(find.text('Gerekli alanlar doldurulmalıdır.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('announcement-user-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kullanici@example.com').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Gönder'));
      await tester.pumpAndSettle();

      final announcements = await repository.fetchAnnouncements();
      expect(announcements, hasLength(1));
      expect(announcements.single.targetType, 'user');
      expect(announcements.single.targetId, 'user-1');
      expect(find.text('Hedefli duyuru'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _TrackingAnnouncementRepository extends InMemoryAdminRepository {
  _TrackingAnnouncementRepository({
    required super.superAdminUserIds,
    List<Announcement> announcements = const [],
  }) : announcements = List.of(announcements);

  final List<Announcement> announcements;

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    return List.unmodifiable(announcements);
  }

  @override
  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String targetType,
    String? targetId,
    required String adminId,
  }) async {
    announcements.add(
      Announcement(
        id: 'announcement-${announcements.length + 1}',
        title: title,
        message: message,
        targetType: targetType,
        targetId: targetId,
        createdAt: DateTime(2026),
        createdBy: adminId,
      ),
    );
  }

  @override
  Future<void> deleteAnnouncement(String announcementId) async {
    announcements.removeWhere((item) => item.id == announcementId);
  }
}
