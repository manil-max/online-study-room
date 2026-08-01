// WP-484 (V57-N08 davranış yarısı): "Bir kere çıktı, daha çıkmadı."
//
// Kök neden iki yolun ikincisiydi: presence güncellenince dürtme düğmesi
// `onPressed: null` oluyordu. Devre dışı `IconButton` dokunmaya **hiç** tepki
// vermez; açıklama yalnız `tooltip`te kalır, tooltip ise mobilde uzun basmayla
// çıkar. Kullanıcı dokunuyor, hiçbir şey olmuyordu.
//
// Bu dosya o regresyonun bekçisidir. Düğme yeniden devre dışı bırakılırsa ilk
// test kırmızıya döner; "yalnız bir kez göster" davranışı geri gelirse üçüncü
// test kırmızıya döner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
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

const _studyingNotice =
    'Bu kişi şu an çalışıyor; odağını bölmemek için dürtme kapalı.';

/// Gönderim denemesini **sayan** repository.
///
/// Kapının istemcide kaldığını kanıtlar: çalışan üyeye dokunmak sunucuya çağrı
/// üretmemelidir, aksi hâlde spam koruması boşa çıkar.
class _CountingNudgeRepository extends InMemoryNudgeRepository {
  int sendCount = 0;

  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) {
    sendCount += 1;
    return super.sendNudge(
      groupId: groupId,
      sender: sender,
      recipient: recipient,
      message: message,
    );
  }
}

Future<(Widget, _CountingNudgeRepository)> _harness({
  required bool peerIsStudying,
}) async {
  final groups = InMemoryGroupRepository();
  final group = await groups.createGroup(name: 'Odak Grubu', creator: _owner);
  await groups.joinGroup(inviteCode: group.inviteCode, member: _peer);
  final nudges = _CountingNudgeRepository()..currentUserId = _owner.id;

  final presence = <Presence>[
    Presence(
      userId: _peer.id,
      groupId: group.id,
      status: peerIsStudying ? PresenceStatus.studying : PresenceStatus.onBreak,
      todaySeconds: 0,
    ),
  ];

  return (
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        nudgeRepositoryProvider.overrideWithValue(nudges),
        authStateProvider.overrideWith((ref) => Stream.value(_owner)),
        groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
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

Future<Finder> _peerNudgeButton(WidgetTester tester) async {
  final button = find.byTooltip(_studyingNotice);
  await tester.scrollUntilVisible(
    find.text(_peer.displayName),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  return button;
}

void main() {
  testWidgets('çalışan üyenin düğmesi devre dışı DEĞİL', (tester) async {
    final (widget, _) = await _harness(peerIsStudying: true);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final button = await _peerNudgeButton(tester);
    expect(button, findsOneWidget);

    // 🔴 Kartın kök nedeni tam olarak buydu: `onPressed: null`.
    final icon = tester.widget<IconButton>(
      find.ancestor(of: button, matching: find.byType(IconButton)),
    );
    expect(
      icon.onPressed,
      isNotNull,
      reason: 'devre dışı düğme dokunmaya hiç tepki vermez (V57-N08)',
    );
  });

  testWidgets('dokunmak her seferinde görünür açıklama veriyor', (
    tester,
  ) async {
    final (widget, nudges) = await _harness(peerIsStudying: true);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(await _peerNudgeButton(tester));
    await tester.pump();
    expect(find.text(_studyingNotice), findsOneWidget);

    // Sunucuya çağrı yok — kapı istemcide.
    expect(nudges.sendCount, 0);
  });

  testWidgets('art arda dokunuş uyarıyı yığmaz, süre dolunca tekrar çıkar', (
    tester,
  ) async {
    final (widget, _) = await _harness(peerIsStudying: true);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final button = await _peerNudgeButton(tester);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();

    // Üç dokunuş, tek uyarı: SnackBar kuyruğu şişmiyor.
    expect(find.text(_studyingNotice), findsOneWidget);

    // Uyarı kapandıktan sonra tekrar dokunmak yeniden gösterir. "Bir kere
    // çıktı, daha çıkmadı" regresyonu yalnız bu iddiayla kapanır.
    // Önce giriş animasyonunun bitmesi gerekiyor: `ScaffoldMessenger` görünürlük
    // sayacını ancak o zaman kuruyor. Tek büyük `pump` ile atlanırsa sayaç hiç
    // kurulmaz ve test yanlış yere "kapanmadı" der.
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text(_studyingNotice), findsNothing);

    await tester.tap(button);
    await tester.pump();
    expect(find.text(_studyingNotice), findsOneWidget);
  });

  testWidgets('çalışmayan üyede davranış değişmedi: dürtme gider', (
    tester,
  ) async {
    final (widget, nudges) = await _harness(peerIsStudying: false);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(_peer.displayName),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Dürt'));
    await tester.pumpAndSettle();

    expect(nudges.sendCount, 1);
    expect(find.text(_studyingNotice), findsNothing);
  });
}
