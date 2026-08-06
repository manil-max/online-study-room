@Tags(['golden'])
library;

// WP-497 (V58-N11, N04 / rapor T10): "Şu an çalışanlar" kartında satır
// yüksekliği varsayımı.
//
// 🔴 Kök neden bir aritmetikti, bir çizim hatası değil: kart kaç satırın
// sığacağını `rowHeight = 42` ve `headerHeight = 68` sabitlerinden hesaplıyordu.
// Taçlı avatar kendi kutusunu büyütüyor (`crowned_avatar.dart`:
// `height: top + base + outlineW`), `radius 16` için satır dikey dolguyla
// ~61 px ediyor — bütçe %45 aşılıyor. İki sonucu vardı:
//   (a) bütçeye göre "sığar" denen son satır alttan **kırpılıyordu**;
//   (b) `maxItems` bütçeye sığmayan üyeleri **tamamen düşürüyordu** — o üyeler
//       kaydırılarak bile görülemiyordu.
//
// ⚠️ Kartın tuzak maddesi: `maxItems`i "biraz büyüterek" yamamak yasak, çünkü
// yazı ölçeği / taç kademesi / avatar boyutu değiştikçe aynı hata geri gelir.
// Bu yüzden aşağıdaki testler tek bir sayıyı değil **varsayımın yokluğunu**
// ölçüyor: taçlı üyelerle kırpılma yok, üye düşmüyor, kısa hücrede taşma yok.
//
// 🔴 Taçsız kurulumla bu testlerin hiçbiri hatayı göremezdi (taçsız satır
// bütçeye sığıyor). Bütün senaryolar bilerek **taçlı** kuruluyor.
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
import 'package:online_study_room/l10n/app_localizations.dart';

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'ABC123',
  createdBy: 'u1',
  createdAt: DateTime(2026, 1, 1),
);

String _name(int i) => 'Uye $i';

Profile _member(int i) =>
    Profile(id: 'u$i', displayName: _name(i), createdAt: DateTime(2026, 1, 1));

Presence _studying(int i) => Presence(
  userId: 'u$i',
  groupId: _group.id,
  status: PresenceStatus.studying,
  todaySeconds: 600,
  // Sıra `startedAt`e göre: 1 en üstte, n en altta.
  startedAt: DateTime(2026, 1, 1, 9).add(Duration(minutes: i)),
);

GamificationProfile _crowned(int i) => GamificationProfile(
  userId: 'u$i',
  streakFreezes: 0,
  xp: 5000,
  crownRank: 'gold_achiever',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Kartı `count` **taçlı** aktif üyeyle kurar.
///
/// Taç şart: hatanın kaynağı taçlı avatarın kutusudur. `crowned: false` yalnız
/// karşılaştırma amaçlı.
Future<void> _pumpCard(
  WidgetTester tester, {
  required int count,
  double width = 320,
  double height = 260,
  double textScale = 1.0,
  bool crowned = true,
}) async {
  final members = [for (var i = 1; i <= count; i++) _member(i)];
  final presence = [for (var i = 1; i <= count; i++) _studying(i)];

  await tester.pumpWidget(
    ProviderScope(
      // Aynı testte ikinci kez pump edilirse konteyner tamamen yeniden
      // kurulmalı; yoksa Riverpod eski değeri bir tur daha gösterir ve
      // "taçsız" ölçüm sessizce taçlı çıkardı (WP-481 dosyasındaki ders).
      key: ValueKey('$count-$crowned-$width-$height-$textScale'),
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_member(1))),
        userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
        groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
        groupMembersProvider.overrideWith((ref) => Stream.value(members)),
        for (var i = 1; i <= count; i++)
          gamificationProfileProvider('u$i').overrideWith(
            (ref) => crowned
                ? Stream.value(_crowned(i))
                : const Stream<GamificationProfile>.empty(),
          ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: const ActiveMembersCard(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // İki kare: ilki presence/üye akışlarını, ikincisi rütbe akışını (dolayısıyla
  // tacı) yerine oturtur. Tek kare ile taçsız ölçüm yapılırdı.
  await tester.pump();
  await tester.pump();
}

/// Kartın çizim alanı — hiçbir satır bunun dışına taşmamalı.
Rect _cardRect(WidgetTester tester) =>
    tester.getRect(find.byType(ActiveMembersCard));

/// Çizilmiş (görünür) üye satırlarının avatar dikdörtgenleri.
List<Rect> _avatarRects(WidgetTester tester) => [
  for (final element in find.byType(CrownedAvatar).evaluate())
    tester.getRect(find.byElementPredicate((e) => e == element)),
];

void main() {
  group('taçlı satırlar kırpılmıyor', () {
    // ⚠️ Kabul "kırpılmış piksel yok" diyordu. Kaydırılabilir bir listede
    // alt kenardaki YARIM satır kırpılma değil, kaydırma işaretidir — ve
    // içeriği bütçeye zorlamadan bundan kaçınmanın yolu yok (üyeyi düşürmek
    // hatanın kendisiydi). Ölçülen şey bu yüzden şudur: hiçbir satır
    // **kalıcı olarak** kırpık kalmaz; ilk satır durağan hâlde, son satır
    // sona kaydırıldığında tam görünür.
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('ilk satır durağan hâlde tam görünür · ölçek $scale', (
        tester,
      ) async {
        await _pumpCard(tester, count: 6, textScale: scale);

        final card = _cardRect(tester);
        final avatars = _avatarRects(tester);
        expect(
          avatars,
          isNotEmpty,
          reason: 'kurulum bozuk: hiç satır çizilmemiş',
        );

        final first = avatars.first;
        expect(
          first.top,
          greaterThanOrEqualTo(card.top - 0.5),
          reason: 'ölçek $scale: ilk satır kartın üstünden taşıyor ($first)',
        );
        expect(
          first.bottom,
          lessThanOrEqualTo(card.bottom + 0.5),
          reason:
              'ölçek $scale: daha ilk satır kartın altından taşıyor ($first) — '
              'liste aşağı kaymış demektir (V58-N11)',
        );
      });

      testWidgets('son satır sona kaydırılınca tam görünür · ölçek $scale', (
        tester,
      ) async {
        await _pumpCard(tester, count: 6, textScale: scale);

        await tester.scrollUntilVisible(
          find.text(_name(6)),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        final card = _cardRect(tester);
        final last = tester.getRect(find.byType(CrownedAvatar).last);
        expect(
          last.bottom,
          lessThanOrEqualTo(card.bottom + 0.5),
          reason:
              'ölçek $scale: son satır sonuna kadar kaydırıldığında bile '
              'alttan kırpık ($last) — sabit 42 px bütçesinin belirtisi',
        );
        expect(
          last.top,
          greaterThanOrEqualTo(card.top - 0.5),
          reason: 'ölçek $scale: son satır üstten kırpık ($last)',
        );
      });
    }

    testWidgets('taçlı satır taçsızdan yüksek: hatanın kaynağı doğrulanır', (
      tester,
    ) async {
      // Bu iddia olmadan yukarıdaki testler "taçlı" olduklarını sanıp taçsız
      // ölçebilirdi. Ölçülen şey kurulumun gerçekten riskli olduğu.
      await _pumpCard(tester, count: 2, crowned: false);
      final plain = tester.getSize(find.byType(CrownedAvatar).first).height;

      await _pumpCard(tester, count: 2);
      final withCrown = tester.getSize(find.byType(CrownedAvatar).first).height;

      expect(
        withCrown,
        greaterThan(plain),
        reason: 'taç kutuyu büyütmüyorsa bu dosyanın ölçtüğü risk yok demektir',
      );
    });
  });

  group('sığmayan üye düşmüyor, kaydırılıyor', () {
    testWidgets('10 üyenin sonuncusuna kaydırarak ulaşılır', (tester) async {
      await _pumpCard(tester, count: 10);

      // Küçük hücrede son üye başta görünmez (liste tembel kurulur).
      expect(find.text(_name(10)), findsNothing);

      await tester.scrollUntilVisible(
        find.text(_name(10)),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // 🔴 Eski kodda bu satır hiç KURULMUYORDU: `maxItems` bütçeye sığmayan
      // üyeleri listeden düşürüyordu, kaydırma da yoktu
      // (`NeverScrollableScrollPhysics`). Kullanıcı onlara ulaşamıyordu.
      expect(find.text(_name(10)), findsOneWidget);
    });

    testWidgets(
      'sayaç gerçek toplamı söyler, gösterilen satır sayısını değil',
      (tester) async {
        await _pumpCard(tester, count: 10);
        expect(find.text('10 aktif'), findsOneWidget);
      },
    );
  });

  group('kenar durumlar taşma üretmiyor', () {
    for (final count in <int>[0, 1, 2, 10]) {
      testWidgets('$count aktif üye · taşma yok', (tester) async {
        await _pumpCard(tester, count: count);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('başlıktan bile kısa hücrede taşma yok', (tester) async {
      // Eski kodda bu durumu `fill` bayrağı ve sabit 68 px kurtarıyordu.
      // Varsayım kalktığına göre kısa hücre de kendi başına doğru olmalı.
      await _pumpCard(tester, count: 4, height: 40);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dar kart (compact dal) taşma üretmiyor', (tester) async {
      await _pumpCard(tester, count: 4, width: 180, height: 200);
      expect(tester.takeException(), isNull);
      // Compact dalda ad düşer, süre kalır — kart içeriği değişmedi.
      expect(find.text(_name(1)), findsNothing);
    });

    testWidgets('sınırsız yükseklikte iç kaydırma yok, kart içerikçe uzar', (
      tester,
    ) async {
      // ⚠️ Bu sahada görülmüş bir belirti DEĞİL: pano kartı bugün her zaman
      // `SizedBox(height: ...)` içinde çiziliyor (`dashboard_card.dart:500`),
      // yani yükseklik daima sınırlı. Test yazdığım `!isHeightBounded` dalını
      // kapsamsız bırakmamak için var — kart bir gün kaydırılabilir bir listeye
      // doğrudan konursa iç içe kaydırma (WP-172) ve `Expanded` çökmesi
      // buradan yakalanır. (Eski kod bu kurulumda 34 istisna atıyordu.)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(_member(1))),
            userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
            groupPresenceProvider.overrideWith(
              (ref) =>
                  Stream.value([for (var i = 1; i <= 6; i++) _studying(i)]),
            ),
            groupMembersProvider.overrideWith(
              (ref) => Stream.value([for (var i = 1; i <= 6; i++) _member(i)]),
            ),
            for (var i = 1; i <= 6; i++)
              gamificationProfileProvider(
                'u$i',
              ).overrideWith((ref) => Stream.value(_crowned(i))),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListView(
                children: const [
                  SizedBox(width: 320, child: ActiveMembersCard()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Altı üyenin altısı da çizili: sınırsız yükseklikte kırpma yok.
      expect(find.byType(CrownedAvatar), findsNWidgets(6));
      // Kartın kendi kaydırıcısı yok; sahnedeki tek `Scrollable` dış liste.
      expect(find.byType(Scrollable), findsOneWidget);
    });
  });

  group('golden', () {
    testWidgets('taçlı üyelerle pano hücresi', (tester) async {
      await _pumpCard(tester, count: 5);
      await tester.pump(const Duration(milliseconds: 16));

      await expectLater(
        find.byType(ActiveMembersCard),
        matchesGoldenFile('goldens/active_members_crowned_wp497.png'),
      );
    });
  });
}
