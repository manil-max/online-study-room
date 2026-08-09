import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/classroom/widgets/campfire/layered_campfire_fire.dart';
import 'package:online_study_room/features/classroom/widgets/camp_critter.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_layout.dart';
import 'package:online_study_room/core/time_engine/sky_phase.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

Widget _harness({
  required List<Profile> members,
  required List<Presence> presence,
  required Map<String, int> today,
  bool reduceMotion = false,
  DateTime? localNow,
  double width = 400,
  TargetPlatform platform = TargetPlatform.windows,
  double textScale = 1,
  SkyAnchors? anchors,
}) {
  final fixedNow = localNow ?? DateTime(2026, 7, 26, 12);
  final scene = Scaffold(
    body: SizedBox(
      width: width,
      // WP-377: çıpalar üretimde mevsime göre kayar. Faz geçişinin **matematiğini**
      // ölçen testler takvime bağlanmasın diye sabit bir set verebilir.
      child: CampfireScene(clock: () => fixedNow, anchors: anchors),
    ),
  );
  return ProviderScope(
    overrides: [
      groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
      groupTodaySecondsProvider.overrideWithValue(today),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: platform),
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // reduce-motion'ı MaterialApp'in ALTINDA override et (aksi halde MaterialApp
      // kendi MediaQuery'siyle üzerine yazar).
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: scene,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'CampfireScene çalışan + dinlenen üyelerle taşmadan render olur',
    (tester) async {
      final started = DateTime.now().subtract(const Duration(minutes: 5));
      await tester.pumpWidget(
        _harness(
          members: [
            _profile('u1', 'Ada'),
            _profile('u2', 'Bora'),
            _profile('u3', 'Cem'),
          ],
          presence: [
            Presence(
              userId: 'u1',
              status: PresenceStatus.studying,
              todaySeconds: 3600,
              startedAt: started,
            ),
            Presence(
              userId: 'u2',
              status: PresenceStatus.onBreak,
              todaySeconds: 1200,
            ),
            Presence(
              userId: 'u3',
              status: PresenceStatus.offline,
              todaySeconds: 0,
            ),
          ],
          today: {'u1': 3600, 'u2': 1200, 'u3': 0},
        ),
      );
      // Stream değerinin dağıtılması + ilk animasyon karesi.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(CampfireScene), findsOneWidget);
      // WP-62: PNG katmanlı ateş sahnede.
      expect(find.byType(LayeredCampfireFire), findsOneWidget);
      // 1 kişi çalışıyor rozeti.
      expect(find.text('1 · Çalışıyor'), findsOneWidget);
      // Üye adları sahnede.
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bora'), findsOneWidget);
      expect(find.text('Cem'), findsOneWidget);

      final marshmallowPaint =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is MarshmallowPainter,
                    ),
                  )
                  .painter!
              as MarshmallowPainter;
      expect(marshmallowPaint.reachFactor, 0.73);
      expect(marshmallowPaint.cycleMinutes, 12);
      expect(marshmallowPaint.sticks, hasLength(1));

      final critterPoses = tester
          .widgetList<CustomPaint>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint && widget.painter is CritterPainter,
            ),
          )
          .map((paint) => (paint.painter! as CritterPainter).pose)
          .toList();
      // 🔴 WP-574: burada "2 idle" bekleniyordu — yani molada olan üye (u2) ile
      // çevrimdışı üye (u3) sahnede birebir aynı çiziliyordu ve bu test onu
      // doğru sanıyordu. Gündüz üç durum üç FARKLI poz üretir.
      expect(critterPoses, contains(CritterPose.roasting)); // u1 çalışıyor
      expect(critterPoses, contains(CritterPose.resting)); // u2 molada
      expect(critterPoses, contains(CritterPose.idle)); // u3 çevrimdışı
      expect(critterPoses.toSet(), hasLength(3));
      expect(critterPoses, isNot(contains(CritterPose.sleepy)));

      // Çalışan üyenin SecondTicker timer'ını temizlemek için ağacı kaldır.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('CampfireScene kimse çalışmıyorken sönük ateş ipucunu gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        members: [_profile('u1', 'Ada')],
        presence: [
          Presence(
            userId: 'u1',
            status: PresenceStatus.offline,
            todaySeconds: 0,
          ),
        ],
        today: {'u1': 0},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Henüz grup yok'), findsOneWidget);
    expect(find.text('Çalışmaya başla'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'gece gökyüzü ve çalışmayan hayvan aynı saatten uyku fazına geçer',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          members: [_profile('u1', 'Ada'), _profile('u2', 'Bora')],
          presence: [
            Presence(
              userId: 'u1',
              status: PresenceStatus.offline,
              todaySeconds: 0,
            ),
            Presence(
              userId: 'u2',
              status: PresenceStatus.onBreak,
              todaySeconds: 0,
            ),
          ],
          today: {'u1': 0, 'u2': 0},
          localNow: DateTime(2026, 7, 26, 23),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final forest =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is GroundedForestPainter,
                    ),
                  )
                  .painter!
              as GroundedForestPainter;
      final poses = tester
          .widgetList<CustomPaint>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint && widget.painter is CritterPainter,
            ),
          )
          .map((paint) => (paint.painter! as CritterPainter).pose);

      expect(forest.daylight, 0);
      expect(poses, everyElement(CritterPose.sleepy));

      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'telefon viewport profili yalnız mobil platformdaki kısa kenarda açılır',
    () {
      final phone = CampfireViewportProfile.fromConstraints(
        constraints: const BoxConstraints.tightFor(width: 360, height: 640),
        platform: TargetPlatform.android,
      );
      final narrowWindows = CampfireViewportProfile.fromConstraints(
        constraints: const BoxConstraints.tightFor(width: 360, height: 640),
        platform: TargetPlatform.windows,
      );

      expect(phone.isPhone, isTrue);
      expect(phone.ringWidthMultiplier, kCampfirePhoneRingWidthMultiplier);
      expect(phone.critterScaleMultiplier, 0.76);
      expect(phone.fireYOffset, 0.09);
      expect(phone.showTrees, isFalse);
      expect(narrowWindows.isPhone, isFalse);
      expect(narrowWindows.showTrees, isTrue);
    },
  );

  for (final memberCount in [1, 4, 8]) {
    testWidgets(
      'WP-350: telefon $memberCount kişide hayvan ve etiketleri sahne içinde tutar',
      (tester) async {
        final members = [
          for (var index = 0; index < memberCount; index++)
            _profile('u$index', 'Uzun isimli üye $index'),
        ];
        await tester.pumpWidget(
          _harness(
            width: 360,
            platform: TargetPlatform.android,
            members: members,
            presence: [
              for (final member in members)
                Presence(
                  userId: member.id,
                  status: PresenceStatus.offline,
                  todaySeconds: 0,
                ),
            ],
            today: {for (final member in members) member.id: 0},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final sceneRect = tester.getRect(find.byType(CampfireScene));
        final safeScene = sceneRect.deflate(8);
        for (var index = 0; index < memberCount; index++) {
          final body = tester.getRect(find.byKey(ValueKey('b-u$index')));
          final label = tester.getRect(find.byKey(ValueKey('l-u$index')));
          expect(safeScene.contains(body.topLeft), isTrue);
          expect(safeScene.contains(body.bottomRight), isTrue);
          expect(safeScene.contains(label.topLeft), isTrue);
          expect(safeScene.contains(label.bottomRight), isTrue);
        }

        final forest =
            tester
                    .widget<CustomPaint>(
                      find.byWidgetPredicate(
                        (widget) =>
                            widget is CustomPaint &&
                            widget.painter is GroundedForestPainter,
                      ),
                    )
                    .painter!
                as GroundedForestPainter;
        final fire = tester.widget<LayeredCampfireFire>(
          find.byType(LayeredCampfireFire),
        );
        expect(forest.showTrees, isFalse);
        expect(fire.visualScale, 0.78);
        expect(find.text('Çalışmaya başla'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'WP-462: 1/4/8 kişi her telefon genişliği ve büyük metinde çakışmaz',
    (tester) async {
      for (final memberCount in [1, 4, 8]) {
        for (final width in [320.0, 360.0, 412.0, 600.0]) {
          await tester.pumpWidget(
            _harness(
              width: width,
              textScale: 1.3,
              platform: TargetPlatform.android,
              members: [
                for (var index = 0; index < memberCount; index++)
                  _profile('u$index', 'Uzun isimli üye $index'),
              ],
              presence: [
                for (var index = 0; index < memberCount; index++)
                  Presence(
                    userId: 'u$index',
                    status: PresenceStatus.offline,
                    todaySeconds: 0,
                  ),
              ],
              today: {
                for (var index = 0; index < memberCount; index++) 'u$index': 0,
              },
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final sceneRect = tester.getRect(find.byType(CampfireScene));
          final labels = <Rect>[];
          final bodies = <Rect>[];
          for (var index = 0; index < memberCount; index++) {
            final body = tester.getRect(find.byKey(ValueKey('b-u$index')));
            final label = tester.getRect(find.byKey(ValueKey('l-u$index')));
            expect(sceneRect.contains(body.topLeft), isTrue);
            expect(sceneRect.contains(body.bottomRight), isTrue);
            expect(sceneRect.contains(label.topLeft), isTrue);
            expect(sceneRect.contains(label.bottomRight), isTrue);
            labels.add(label);
            bodies.add(body);
          }
          for (var first = 0; first < labels.length; first++) {
            for (var second = first + 1; second < labels.length; second++) {
              expect(
                labels[first].overlaps(labels[second]),
                isFalse,
                reason:
                    '$memberCount kişi, $width dp: etiket $first (${labels[first]}) '
                    'etiket $second (${labels[second]}) ile çakışıyor',
              );
            }
            // İsim kendi figürünün üstüne düşmez. Derinlik katmanları farklı
            // üyelerin ekran dikdörtgenlerini kasıtlı olarak kesiştirebilir;
            // onların görünür sırası sahne painter'ı tarafından belirlenir.
            expect(
              labels[first].overlaps(bodies[first]),
              isFalse,
              reason:
                  '$memberCount kişi, $width dp: etiket $first (${labels[first]}) '
                  'kendi gövdesi (${bodies[first]}) ile çakışıyor',
            );
          }

          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );

  testWidgets('şafakta gökyüzü kademeli aydınlanır ve hayvan uyanıktır', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        members: [_profile('u1', 'Ada')],
        presence: [
          Presence(
            userId: 'u1',
            status: PresenceStatus.onBreak,
            todaySeconds: 0,
          ),
        ],
        today: {'u1': 0},
        // Şafağın tam ortası: smoothstep'in 0.5 vermesi gereken an.
        localNow: DateTime(2026, 7, 26, 6),
        anchors: kDefaultSkyAnchors,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final forest =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is GroundedForestPainter,
                  ),
                )
                .painter!
            as GroundedForestPainter;
    final pose =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is CritterPainter,
                  ),
                )
                .painter!
            as CritterPainter;

    expect(forest.daylight, closeTo(0.5, 0.0001));
    expect(forest.warmth, closeTo(1, 0.0001));
    // WP-574: bu fixture'daki üye `onBreak` — şafakta gece bittiği için
    // uyanık, ama artık çevrimdışı üyeyle aynı değil: molanın kendi pozu var.
    expect(pose.pose, CritterPose.resting);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sekiz çalışan üyede aynı anda en fazla altı dal gösterir', (
    tester,
  ) async {
    final started = DateTime.now().subtract(const Duration(minutes: 3));
    final members = [
      for (var index = 0; index < 8; index++) _profile('u$index', 'Üye $index'),
    ];
    await tester.pumpWidget(
      _harness(
        members: members,
        presence: [
          for (var index = 0; index < 8; index++)
            Presence(
              userId: 'u$index',
              status: PresenceStatus.studying,
              todaySeconds: 180,
              startedAt: started,
            ),
        ],
        today: {for (var index = 0; index < 8; index++) 'u$index': 180},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final marshmallowPaint =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is MarshmallowPainter,
                  ),
                )
                .painter!
            as MarshmallowPainter;
    expect(marshmallowPaint.sticks, hasLength(6));
    expect(find.text('8 · Çalışıyor'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reduce-motion açıkken sonsuz alev döngüsü durur (sahne pumpAndSettle ile '
    'oturur, batarya tüketen animasyon yok)',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          members: [_profile('u1', 'Ada'), _profile('u2', 'Bora')],
          presence: [
            Presence(
              userId: 'u1',
              status: PresenceStatus.offline,
              todaySeconds: 0,
            ),
            Presence(
              userId: 'u2',
              status: PresenceStatus.offline,
              todaySeconds: 0,
            ),
          ],
          today: {'u1': 0, 'u2': 0},
          reduceMotion: true,
        ),
      );

      // Normalde alev AnimationController.repeat() sonsuz döner ve pumpAndSettle
      // 10 dk timeout ile hang eder. reduce-motion'da döngü durdurulduğundan
      // pumpAndSettle sorunsuz oturmalı — bu, animasyonun gerçekten durduğunun
      // davranışsal kanıtı.
      await tester.pumpAndSettle();

      expect(find.byType(CampfireScene), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bora'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    },
  );
}
