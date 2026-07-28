import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-413 — kamp ateşi **kapsam dışıdır ve öyle kalmalıdır.**
///
/// Sahip cihazda doğruladı: engellenen kişi kamp ateşinde "Engellenen kullanıcı"
/// etiketiyle görünüyor ve bu **doğru davranış**. Sahneden silinmez,
/// anonimleşir; böylece katılımcı sayısı bozulmaz. Sunucu tarafında
/// `group_member_directory` de bu sözleşmeyi tutar (satırı döndürür, yalnız
/// kimliği boşaltır — bkz. `supabase/tests/024_block_visibility_enforcement`).
///
/// Bu dosya, ileride birinin yaptırımı "tamamen gizle"ye çevirmesini durdurur.
const _blockedId = 'blocked-user';
const _normalId = 'normal-user';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

Widget _harness({required Set<String> blocked}) {
  final repo = InMemoryModerationRepository();
  for (final id in blocked) {
    repo.blockUser(id);
  }
  final members = [
    _profile(_normalId, 'Normal Uye'),
    _profile(_blockedId, 'Gercek Ad'),
  ];

  final scene = Scaffold(
    body: SizedBox(
      width: 400,
      child: CampfireScene(clock: () => DateTime(2026, 7, 26, 12)),
    ),
  );

  return ProviderScope(
    overrides: [
      moderationRepositoryProvider.overrideWithValue(repo),
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupPresenceProvider.overrideWith(
        (ref) => Stream.value(const <Presence>[]),
      ),
      groupTodaySecondsProvider.overrideWithValue(const <String, int>{}),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: scene,
    ),
  );
}

void main() {
  testWidgets('kamp ateşi engellenen üyeyi sahneden SİLMEZ, anonimleştirir', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(blocked: const {_blockedId}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 1) Kimlik gizlenir.
    expect(find.text('Gercek Ad'), findsNothing);
    expect(find.text('Engellenen kullanıcı'), findsOneWidget);

    // 2) 🔴 Ama sahneden düşmez — katılımcı sayısı bozulmaz.
    //    Her kamperin gövdesi `b-<id>` anahtarını taşır.
    expect(find.byKey(const ValueKey('b-$_blockedId')), findsOneWidget);
    expect(find.byKey(const ValueKey('b-$_normalId')), findsOneWidget);

    // 3) Engellenmeyen üyenin adı olduğu gibi kalır (aşırı maskeleme yok).
    expect(find.text('Normal Uye'), findsOneWidget);
  });

  testWidgets('engel yokken gerçek ad görünür (etiket engelden geliyor)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(blocked: const {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Gercek Ad'), findsOneWidget);
    expect(find.text('Engellenen kullanıcı'), findsNothing);
  });
}
