// WP-495 (V58-N02, N07 / rapor T04): "yükleniyor" durumunun "veri yok"
// sayılması.
//
// İki ayrı belirti, tek kök neden:
//   (a) `ActiveMembersCard` `userGroupProvider.value == null` görünce doğrudan
//       "Bir gruba katılınca burada… + Grup Oluştur" kartını çiziyordu. İlk
//       yüklemede bu değer *her zaman* null olduğu için grubu olan kullanıcı da
//       açılışta bir kare bu daveti görüyordu (sahibin gördüğü "create group"
//       flaşı).
//   (b) `LiveCrownedAvatar` rütbeyi `asData?.value` ile okuyordu. `asData`
//       yalnız `AsyncData` durumunda doludur; provider izlediği bir bağımlılık
//       değiştiği için yeniden yüklendiğinde durum `AsyncLoading` olur (önceki
//       değer korunur) ve taç bir kare kaybolup geri gelirdi.
//
// Ölçüt "daha az titriyor" değil: yükleme karesinde **hangi widget'ın çizildiği**.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/features/home/widgets/active_members_card.dart';
import 'package:online_study_room/features/home/widgets/group_card_shell.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

final _owner = Profile(
  id: 'owner-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Ada',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: _owner.id,
  createdAt: DateTime(2026, 1, 1),
);

Presence _studying(String userId) => Presence(
  userId: userId,
  groupId: _group.id,
  status: PresenceStatus.studying,
  todaySeconds: 600,
  startedAt: DateTime(2026, 1, 1, 9),
);

/// Kartı verilen async durumlarla kurar. `null` geçilen akış **hiç emisyon
/// yapmaz** → provider `AsyncLoading` (değersiz) kalır; cihazda ağ turunun
/// beklendiği kare budur.
Future<void> _pumpCard(
  WidgetTester tester, {
  required AsyncValue<StudyGroup?> group,
  List<Presence>? presence,
  List<Profile>? members,
  Object? presenceError,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_owner)),
        userGroupProvider.overrideWithValue(group),
        groupPresenceProvider.overrideWith(
          (ref) => presenceError != null
              ? Stream<List<Presence>>.error(presenceError)
              : (presence == null
                    ? const Stream<List<Presence>>.empty()
                    : Stream.value(presence)),
        ),
        groupMembersProvider.overrideWith(
          (ref) => members == null
              ? const Stream<List<Profile>>.empty()
              : Stream.value(members),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(width: 320, height: 260, child: ActiveMembersCard()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('grup yükleniyorken "Grup Oluştur" daveti çizilmez', (
    tester,
  ) async {
    await _pumpCard(tester, group: const AsyncValue.loading());

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    // Eski kod burada daveti çiziyordu: `.value == null` → GroupCardShell.
    expect(find.text(l10n.homeGrupOlustur), findsNothing);
    expect(find.text(l10n.homeKodaKatil), findsNothing);
    expect(find.byKey(kGroupCardSkeletonKey), findsOneWidget);
    // Başlık kalır: kart yerini korur, boyut zıplamaz.
    expect(find.text(l10n.homeSuAnCalisanlar), findsOneWidget);
  });

  testWidgets('gerçekten grubu olmayan kullanıcıda davet hâlâ görünür', (
    tester,
  ) async {
    await _pumpCard(tester, group: const AsyncValue.data(null));

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.homeGrupOlustur), findsOneWidget);
    expect(find.byKey(kGroupCardSkeletonKey), findsNothing);
  });

  testWidgets('grup yüklenemezse boş durum değil hata metni çizilir', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      group: AsyncValue.error('ağ yok', StackTrace.empty),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    // WP-495B: grup akışının hatası ortak kapıdan geçtiği için mesaj grup
    // odaklı; presence/üye hatası kartın kendi metnini kullanmaya devam eder.
    expect(find.text(l10n.homeGrupBilgisiYuklenemedi), findsOneWidget);
    // Tuzak: hatayı "yükleniyor" sayıp sonsuz iskelet göstermek.
    expect(find.byKey(kGroupCardSkeletonKey), findsNothing);
    expect(find.text(l10n.homeGrupOlustur), findsNothing);
  });

  testWidgets('presence yüklenirken "kimse yok" ve "0 aktif" yazılmaz', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      group: AsyncValue.data(_group),
      presence: null, // akış henüz veri vermedi
      members: [_owner, _peer],
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.homeSuAnCalisanKimse), findsNothing);
    expect(find.text('0 aktif'), findsNothing);
    expect(find.byKey(kGroupCardSkeletonKey), findsOneWidget);
  });

  testWidgets('presence geldiğinde liste ve sayaç normal çizilir', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      group: AsyncValue.data(_group),
      presence: [_studying(_peer.id)],
      members: [_owner, _peer],
    );
    await tester.pump();

    expect(find.text(_peer.displayName), findsOneWidget);
    expect(find.text('1 aktif'), findsOneWidget);
    expect(find.byKey(kGroupCardSkeletonKey), findsNothing);
  });

  testWidgets('presence hatasında boş durum değil hata metni çizilir', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      group: AsyncValue.data(_group),
      presenceError: 'kanal düştü',
      members: [_owner, _peer],
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.homeCalisanlarYuklenemedi), findsOneWidget);
    expect(find.text(l10n.homeSuAnCalisanKimse), findsNothing);
  });

  testWidgets('taç, provider bağımlılığı değişip yeniden yüklenirken kalır', (
    tester,
  ) async {
    // Riverpod 3'te durum sınıfı tetikleyiciye göre değişir (ölçüldü):
    //   `invalidate(provider)`      → `AsyncData` + isLoading → `asData` DOLU
    //   bağımlılık değişti (watch)  → `AsyncLoading` + önceki değer → `asData` NULL
    // Taç yalnız ikinci durumda kayboluyordu; test o durumu kurar ve durumun
    // gerçekten öyle olduğunu ayrıca doğrular (yoksa iddia sessizce yeşil kalır).
    final container = ProviderContainer(
      overrides: [
        gamificationProfileProvider(_peer.id).overrideWith((ref) {
          ref.watch(_reloadTriggerProvider);
          return _RankStream.instance.stream;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiveCrownedAvatar(
                userId: _peer.id,
                displayName: _peer.displayName,
                radius: 32,
              ),
            ),
          ),
        ),
      ),
    );

    _RankStream.instance.emit(
      GamificationProfile(
        userId: _peer.id,
        streakFreezes: 0,
        xp: 5000,
        crownRank: 'gold_achiever',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await tester.pump();
    expect(_crowns(tester), 1, reason: 'rütbe geldiğinde taç çizilir');

    // Yeniden yükleme: akış yeniden dinlenir, ilk kare veri getirmez.
    container.invalidate(_reloadTriggerProvider);
    await tester.pump();

    final state = container.read(gamificationProfileProvider(_peer.id));
    expect(
      state,
      isA<AsyncLoading<GamificationProfile>>(),
      reason: 'test doğru kareyi ölçmeli: yeniden yükleme durumu',
    );
    expect(state.hasValue, isTrue, reason: 'önceki değer korunuyor olmalı');
    expect(state.asData, isNull, reason: 'eski kodun okuduğu alan boş');

    // Eski kodda bu kare taçsızdı.
    expect(_crowns(tester), 1, reason: 'yeniden yükleme karesinde taç kalmalı');
  });
}

/// `gamificationProfileProvider` gerçekte `gamificationRepositoryProvider`ı
/// izler; bu provider onun testteki karşılığıdır.
final _reloadTriggerProvider = Provider<Object>((ref) => Object());

int _crowns(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<CrownPainter>()
    .length;

/// Yeniden dinlenebilen tek kaynak: `invalidate` sonrası provider aynı akışa
/// tekrar abone olur ve ilk karede veri gelmez.
class _RankStream {
  _RankStream._();
  static final _RankStream instance = _RankStream._();

  final StreamController<GamificationProfile> _controller =
      StreamController<GamificationProfile>.broadcast();

  Stream<GamificationProfile> get stream => _controller.stream;

  void emit(GamificationProfile profile) => _controller.add(profile);
}
