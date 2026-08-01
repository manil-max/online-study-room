// WP-483 (V57-N07): "Muted kısmı var ayarlarda ama grupta mute işaretini
// bulamadım; eklememiş de olabilirsin."
//
// Sahip haklıydı: `muteNudgesFrom` WP-444'te arayüze, iki repository'ye, RLS'e
// ve testlere yazılmıştı ama `app/lib` içinden **hiçbir yerden çağrılmıyordu**.
// Kullanıcının birini susturmasının yolu yoktu; ayarlardaki liste tanımı gereği
// hep boştu. Testler InMemory katmanını sürdüğü için boşluk yeşil göründü.
//
// Bu dosya "ölü özellik" regresyonunun bekçisidir: tetikleyici kaldırılırsa
// ilk iki test kırmızıya döner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/features/safety/muted_nudges_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _owner = Profile(
  id: 'owner-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Komsu',
  createdAt: DateTime(2026, 1, 1),
);

/// Susturma çağrılarını kaydeden repository.
///
/// Kartın "artık `lib/` içinden çağrılıyor" iddiasının bekçisi budur: düğme
/// silinirse `muted` listesi boş kalır.
class _SpyNudgeRepository extends InMemoryNudgeRepository {
  final List<String> mutedCalls = [];
  final List<String> unmutedCalls = [];

  @override
  Future<void> muteNudgesFrom(String userId) {
    mutedCalls.add(userId);
    return super.muteNudgesFrom(userId);
  }

  @override
  Future<void> unmuteNudgesFrom(String userId) {
    unmutedCalls.add(userId);
    return super.unmuteNudgesFrom(userId);
  }
}

Future<(Widget, _SpyNudgeRepository)> _detail({required Profile viewer}) async {
  final groups = InMemoryGroupRepository();
  final group = await groups.createGroup(name: 'Odak Grubu', creator: _owner);
  await groups.joinGroup(inviteCode: group.inviteCode, member: _peer);
  final nudges = _SpyNudgeRepository()..currentUserId = viewer.id;

  return (
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        nudgeRepositoryProvider.overrideWithValue(nudges),
        authStateProvider.overrideWith((ref) => Stream.value(viewer)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClassDetailScreen(group: group),
      ),
    ),
    nudges,
  );
}

/// Ayarlar ekranı, grup ekranıyla **aynı** override sayısıyla kurulur:
/// Riverpod ağaç değişiminde override sayısının sabit kalmasını şart koşuyor.
Widget _mutedList(InMemoryNudgeRepository nudges) => ProviderScope(
  overrides: [
    groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
    nudgeRepositoryProvider.overrideWithValue(nudges),
    authStateProvider.overrideWith((ref) => Stream.value(_owner)),
  ],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const MutedNudgesScreen(),
  ),
);

Future<void> _scrollToPeer(WidgetTester tester) => tester.scrollUntilVisible(
  find.text(_peer.displayName),
  300,
  scrollable: find.byType(Scrollable).first,
);

void main() {
  testWidgets('grup üye satırında susturma eylemi var ve çalışıyor', (
    tester,
  ) async {
    final (widget, nudges) = await _detail(viewer: _owner);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _scrollToPeer(tester);

    // Eylem satırda görünür; ayarlara gitmek gerekmiyor.
    expect(find.byTooltip('Dürtmesini sustur'), findsOneWidget);

    await tester.tap(find.byTooltip('Dürtmesini sustur'));
    await tester.pumpAndSettle();

    // 🔴 "Ölü özellik" iddiasının bekçisi: çağrı gerçekten lib/ içinden geldi.
    expect(nudges.mutedCalls, [_peer.id]);
    expect(await nudges.listMutedNudgeSenderIds(), [_peer.id]);
    expect(find.text('Dürtmesi susturuldu.'), findsOneWidget);
  });

  testWidgets('susturulan üye satırda işaretli görünür ve geri alınabilir', (
    tester,
  ) async {
    final (widget, nudges) = await _detail(viewer: _owner);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _scrollToPeer(tester);

    expect(find.byIcon(Icons.notifications_off), findsNothing);

    await tester.tap(find.byTooltip('Dürtmesini sustur'));
    await tester.pumpAndSettle();

    // Görünür işaret: dolu simge + eylem artık geri almayı öneriyor.
    expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    expect(find.byTooltip('Susturmayı kaldır'), findsOneWidget);
    expect(find.byTooltip('Dürtmesini sustur'), findsNothing);

    await tester.tap(find.byTooltip('Susturmayı kaldır'));
    await tester.pumpAndSettle();

    expect(nudges.unmutedCalls, [_peer.id]);
    expect(find.byIcon(Icons.notifications_off), findsNothing);
    expect(find.byTooltip('Dürtmesini sustur'), findsOneWidget);
  });

  testWidgets('ayarlardaki liste grup ekranından gelen kaydı gösterir', (
    tester,
  ) async {
    final (widget, nudges) = await _detail(viewer: _owner);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await _scrollToPeer(tester);
    await tester.tap(find.byTooltip('Dürtmesini sustur'));
    await tester.pumpAndSettle();

    // Aynı repository'yi ayarlar ekranı okuyor: liste artık boş değil.
    await tester.pumpWidget(_mutedList(nudges));
    await tester.pumpAndSettle();

    expect(find.text('Susturulan kullanıcı'), findsOneWidget);
    expect(find.text('Kimseyi susturmadın.'), findsNothing);
  });

  testWidgets('yan kanal yok: susturma karşı tarafın ekranına yansımaz', (
    tester,
  ) async {
    // Sahip komşuyu sustursun.
    final (ownerView, ownerNudges) = await _detail(viewer: _owner);
    await tester.pumpWidget(ownerView);
    await tester.pumpAndSettle();
    await _scrollToPeer(tester);
    await tester.tap(find.byTooltip('Dürtmesini sustur'));
    await tester.pumpAndSettle();
    expect(ownerNudges.mutedCalls, [_peer.id]);

    // Komşu aynı gruba baktığında hiçbir işaret görmez: susturma tercihi
    // hesap kapsamlıdır ve `listMutedNudgeSenderIds` yalnız çağıranınkini verir.
    final (peerView, _) = await _detail(viewer: _peer);
    await tester.pumpWidget(peerView);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_off), findsNothing);
    expect(find.byTooltip('Susturmayı kaldır'), findsNothing);
  });
}
