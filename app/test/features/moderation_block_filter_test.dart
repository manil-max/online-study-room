import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/chat_message.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-538: engelleme süzgeci **hata hâlinde de** tutmalı.
///
/// 🔴 Bu dosyanın eski hâlinde "message filter hides blocked authors" adında
/// bir test vardı ve ÜRETİM KODUNDAN HİÇBİR ŞEY import etmiyordu: süzgeci
/// test içinde yeniden yazıp kendi çıktısını doğruluyordu. `class_chat_card`
/// içindeki süzgeç tamamen silinse bile yeşil kalırdı. Adı kapsam varmış
/// izlenimi veriyordu; denetimde yakalandı ve gerçek testle değiştirildi.
///
/// Ölçülen sözleşme: engelli kümesi **bilinmiyorsa mesaj çizilmez**. Eski kod
/// hata dalında süzgeçsiz listeye düşüyordu, yani ağ hatası engellemeyi
/// sessizce kapatıyordu.
void main() {
  final group = StudyGroup(
    id: 'g1',
    name: 'Grup',
    inviteCode: 'ABC123',
    createdBy: 'user-a',
    createdAt: DateTime(2026, 8, 1),
  );

  final messages = [
    ChatMessage(
      id: 'm1',
      groupId: 'g1',
      userId: 'user-a',
      body: 'temiz mesaj',
      createdAt: DateTime(2026, 8, 8, 10),
    ),
    ChatMessage(
      id: 'm2',
      groupId: 'g1',
      userId: 'user-b',
      body: 'engellenen mesaj',
      createdAt: DateTime(2026, 8, 8, 11),
    ),
  ];

  Widget harness(Iterable<Object> overrides) => ProviderScope(
    overrides: [
      classMessagesProvider(
        group.id,
      ).overrideWith((ref) => Stream.value(messages)),
      authStateProvider.overrideWith((ref) => const Stream.empty()),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ClassChatCard(group: group)),
    ),
  );

  testWidgets('engelli kume BILINIYORSA engellenen mesaj gizlenir', (
    tester,
  ) async {
    final repository = InMemoryModerationRepository();
    await repository.blockUser('user-b');

    await tester.pumpWidget(
      harness([moderationRepositoryProvider.overrideWithValue(repository)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('temiz mesaj'), findsOneWidget);
    expect(find.text('engellenen mesaj'), findsNothing);
  });

  testWidgets('engelli kume HATA verirse hicbir mesaj cizilmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness([
        blockedUserIdsProvider.overrideWith(
          (ref) => Future<Set<String>>.error(
            StateError('engelli listesi alinamadi'),
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // 🔴 Asıl iddia: engellenen mesaj görünmemeli. Eski kod burada süzgeçsiz
    // listeye düşüyordu ve "engellenen mesaj" ekrana geliyordu.
    expect(find.text('engellenen mesaj'), findsNothing);
    expect(find.text('temiz mesaj'), findsNothing);
  });
}
