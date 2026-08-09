// WP-574 — kamp ateşinde MOLA görünmüyordu.
//
// `PresenceStatus.onBreak` presence katmanında üretiliyor ama sahneye hiç
// ulaşmıyordu: `_Camper.poseAt` yalnız `studying` + gece/gündüz soruyordu, bu
// yüzden **molada olan üye gündüz çevrimdışı biriyle birebir aynı** çiziliyordu.
//
// 🔴 Bu dosya kasten İKİ katman ölçer:
//   1. Poz seçimi (birim) — `CritterPainter.pose` doğrudan okunur.
//   2. Golden — üç durum üç ayrı kare.
// WP-471 dersi: golden doğruydu ama widget kararsızdı ve golden bunu gizledi.
// Tersi de geçerli — yalnız golden tutulsaydı poz seçiminin neden değiştiği
// (gerçek regresyon mu, alt-piksel mi) kareden okunamazdı.
//
// Golden'lar `--tags=golden` kapısında koşar; poz iddiaları etiketsizdir ve
// ana `flutter test --exclude-tags=golden` turunda koşar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/camp_critter.dart';
import 'package:online_study_room/features/classroom/widgets/campfire/campfire_assets.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_layout.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Sahnedeki hayvanların çizim pozları (yerleşim değil, **karar** okunur).
List<CritterPose> _poses(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is CritterPainter,
      ),
    )
    .map((paint) => (paint.painter! as CritterPainter).pose)
    .toList();

void main() {
  // — 1) Poz seçimi (birim) —————————————————————————————————————————————

  for (final durum in <({PresenceStatus status, CritterPose pose, String ad})>[
    (
      status: PresenceStatus.studying,
      pose: CritterPose.roasting,
      ad: 'çalışan',
    ),
    (
      status: PresenceStatus.onBreak,
      pose: CritterPose.resting,
      ad: 'molada olan',
    ),
    (
      status: PresenceStatus.offline,
      pose: CritterPose.idle,
      ad: 'çevrimdışı',
    ),
  ]) {
    testWidgets(
      'WP-574: ${durum.ad} üye gündüz ${durum.pose.name} pozunda çizilir',
      (tester) async {
        await tester.pumpWidget(_harness(status: durum.status));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(_poses(tester), [durum.pose]);

        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('WP-574: üç durum aynı sahnede üç FARKLI poz üretir', (
    tester,
  ) async {
    await tester.pumpWidget(_ucluHarness());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final poses = _poses(tester);
    expect(poses, hasLength(3));
    // Asıl kabul kriteri: hiçbir iki durum aynı çizilmez. Eskiden molada olan
    // ile çevrimdışı olan aynı `idle` pozunu paylaşıyordu (küme boyu 2 idi).
    expect(poses.toSet(), hasLength(3));
    expect(poses.toSet(), {
      CritterPose.roasting,
      CritterPose.resting,
      CritterPose.idle,
    });

    await tester.pumpWidget(const SizedBox());
  });

  // — 2) Gece dalı: mevcut davranış korunur (regresyon yok) ——————————————

  for (final status in [PresenceStatus.onBreak, PresenceStatus.offline]) {
    testWidgets('WP-574: gece ${status.name} üye uyumaya devam eder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(status: status, now: DateTime(2026, 7, 26, 23)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Gece üç durumu ayırmak **hedef değil**: karanlıkta çalışmayan herkes
      // uyur. Bu iddia gündüz düzeltmesinin geceye sızmadığını kilitler.
      expect(_poses(tester), [CritterPose.sleepy]);

      await tester.pumpWidget(const SizedBox());
    });
  }

  // — 3) Silinen ölü poz geri gelmesin ——————————————————————————————————

  test('WP-574: ölü `working` pozu kataloğa geri dönmedi', () {
    // 🔴 Bu iddia bilerek **enum adı** üzerinden yazıldı. Öncesinde
    // `campfire_scene_test.dart` içinde `isNot(contains(CritterPose.working))`
    // duruyordu; o biçim sembolün VARLIĞINI şart koşuyor, yani ölü kodun
    // silinmesini testin kendisi engelliyordu (WP-558'de aynı tuzağa düşüldü).
    // Bu biçim tersini korur: sembol geri eklenirse test kırmızı düşer.
    expect(
      CritterPose.values.map((pose) => pose.name),
      isNot(contains('working')),
    );
    expect(CritterPose.values.map((pose) => pose.name).toSet(), {
      'roasting',
      'resting',
      'idle',
      'sleepy',
    });
  });

  // — 4) Golden: üç durum üç ayrı kare ——————————————————————————————————

  for (final durum in <({PresenceStatus status, String dosya})>[
    (status: PresenceStatus.studying, dosya: 'studying'),
    (status: PresenceStatus.onBreak, dosya: 'break'),
    (status: PresenceStatus.offline, dosya: 'offline'),
  ]) {
    testWidgets(
      'WP-574 golden · ${durum.dosya}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 380));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_harness(status: durum.status));
        await tester.pump();
        final imageContext = tester.element(
          find.byKey(const ValueKey('campfire-pose-boundary')),
        );
        await tester.runAsync(() async {
          for (final asset in CampfireAssets.stackOrder) {
            await precacheImage(AssetImage(asset), imageContext);
          }
        });
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const ValueKey('campfire-pose-boundary')),
          matchesGoldenFile('goldens/campfire_pose_${durum.dosya}.png'),
        );

        await tester.pumpWidget(const SizedBox());
      },
      tags: 'golden',
    );
  }
}

/// Tek üyeli sahne — poz farkı kareyi domine etsin diye kasten tek hayvan.
Widget _harness({required PresenceStatus status, DateTime? now}) {
  final calisan = status == PresenceStatus.studying;
  return _scene(
    localNow: now ?? DateTime(2026, 7, 26, 12, 30),
    members: [_profil('u1', 'Ada')],
    presence: [
      Presence(
        userId: 'u1',
        status: status,
        todaySeconds: calisan ? 900 : 0,
        // Sabit `startedAt` + enjekte saat: canlı süre metni de deterministik
        // (WP-471 golden kayması buradan geliyordu).
        startedAt: calisan ? DateTime(2026, 7, 26, 12) : null,
      ),
    ],
    today: {'u1': calisan ? 900 : 0},
  );
}

/// Üç durumu tek karede karşılaştıran sahne.
Widget _ucluHarness() => _scene(
  localNow: DateTime(2026, 7, 26, 12, 30),
  members: [_profil('u1', 'Ada'), _profil('u2', 'Bora'), _profil('u3', 'Cem')],
  presence: [
    Presence(
      userId: 'u1',
      status: PresenceStatus.studying,
      todaySeconds: 900,
      startedAt: DateTime(2026, 7, 26, 12),
    ),
    Presence(userId: 'u2', status: PresenceStatus.onBreak, todaySeconds: 600),
    Presence(userId: 'u3', status: PresenceStatus.offline, todaySeconds: 0),
  ],
  today: {'u1': 900, 'u2': 600, 'u3': 0},
);

Profile _profil(String id, String ad) => Profile(
  id: id,
  displayName: ad,
  animal: 'rabbit',
  createdAt: DateTime(2026, 1, 1),
);

Widget _scene({
  required DateTime localNow,
  required List<Profile> members,
  required List<Presence> presence,
  required Map<String, int> today,
}) {
  return ProviderScope(
    overrides: [
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
      groupTodaySecondsProvider.overrideWithValue(today),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(useMaterial3: true),
      // Golden kareler deterministik olmak zorunda: reduce-motion alev fazını
      // sabitler ve köz parçacıklarını kapatır (gerekçe:
      // `campfire_sky_golden_test.dart`). Aynı MediaQuery poz iddialarında da
      // duruyor ki iki katman **aynı** kareyi ölçsün.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF100D14),
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('campfire-pose-boundary'),
            child: SizedBox(
              width: 400,
              height: kCampfireSceneHeight,
              child: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: CampfireScene(
                  clock: () => localNow,
                  // 🔴 Hayvan kasten büyütüldü (`critterScale`, WP-416 önizleme
                  // seam'i). Üretim ölçeğinde tek hayvan 420×380 karenin ~%3'ü
                  // kalıyor ve kolların yukarı/aşağı olması **%0,5'lik platform
                  // rasterleme payının altında** fark üretiyordu: `poseAt`ten
                  // `onBreak` dalı silindiğinde golden YEŞİL geçti (ölçüldü).
                  // Yani golden poz regresyonunu göremeyen bir dekordu. Poz
                  // kararı ölçekten bağımsız olduğu için büyütmek iddiayı
                  // değiştirmez, yalnız görünür kılar; üretim ölçeğindeki
                  // kompozisyonu `campfire_sky_golden_test.dart` koruyor.
                  tuning: const CampfireTuning(critterScale: 2.6),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
