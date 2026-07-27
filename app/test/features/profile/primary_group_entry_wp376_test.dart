// WP-376 (V49-2): birincil grup bloğu Başarımlar ekranının gövdesinden çıkıp
// sağ üstteki girişe taşındı; seçim yokken uyarı rozeti üç yüzeyde birden
// görünür.
//
// Üç yüzey: Profil sekmesi (WP-352, `home_shell.dart`) · Başarımlar ekranındaki
// şerit · sağ üstteki ayar ikonu. Üçü de **tek** kaynaktan beslenir:
// `primaryGroupSelectionMissingProvider`. Bu testler o kaynağın iki yeni
// yüzeyini ve ekranın yapısını kilitler.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/features/profile/widgets/primary_group_entry.dart';
import 'package:online_study_room/features/profile/widgets/primary_group_selector_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _actionKey = Key('primary-group-appbar-action');
const _badgeKey = Key('primary-group-appbar-badge');
const _bannerKey = Key('primary-group-missing-banner');
const _warningKey = ValueKey('primary-group-missing-warning');

StudyGroup _group(String id, String name) => StudyGroup(
  id: id,
  name: name,
  inviteCode: 'INV$id',
  createdBy: 'owner-1',
  createdAt: DateTime.utc(2026, 7, 1),
  timeZone: 'Europe/Istanbul',
);

Widget _screen({
  List<StudyGroup>? groups,
  String? primaryGroupId,
  bool emitPreference = true,
}) {
  return ProviderScope(
    overrides: [
      userGroupsProvider.overrideWith(
        (ref) => groups == null
            ? const Stream<List<StudyGroup>>.empty()
            : Stream.value(groups),
      ),
      primaryGroupPreferenceProvider.overrideWith(
        (ref) => emitPreference
            ? Stream.value(
                PrimaryGroupPreference(
                  primaryGroupId: primaryGroupId,
                  selectionRevision: primaryGroupId == null ? 0 : 1,
                ),
              )
            : const Stream<PrimaryGroupPreference>.empty(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        appBar: null,
        body: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: PrimaryGroupAppBarAction(),
            ),
            PrimaryGroupMissingBanner(),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('seçim yokken rozet ve şerit birlikte görünür', (tester) async {
    await tester.pumpWidget(
      _screen(groups: [_group('g1', 'Kamp A')], primaryGroupId: null),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_actionKey), findsOneWidget);
    expect(find.byKey(_badgeKey), findsOneWidget);
    expect(find.byKey(_bannerKey), findsOneWidget);
    expect(find.byKey(_warningKey), findsOneWidget);
  });

  testWidgets('seçim yapılınca rozet de şerit de kaybolur', (tester) async {
    await tester.pumpWidget(
      _screen(groups: [_group('g1', 'Kamp A')], primaryGroupId: 'g1'),
    );
    await tester.pumpAndSettle();

    // Giriş her zaman durur — kartı silip yerine hiçbir giriş koymamak seçimi
    // erişilemez yapardı.
    expect(find.byKey(_actionKey), findsOneWidget);
    expect(find.byKey(_badgeKey), findsNothing);
    expect(find.byKey(_bannerKey), findsNothing);
  });

  testWidgets('hiç grubu olmayan kullanıcı boşuna telaşlandırılmaz', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(groups: const [], primaryGroupId: null));
    await tester.pumpAndSettle();

    expect(find.byKey(_badgeKey), findsNothing);
    expect(find.byKey(_bannerKey), findsNothing);
  });

  testWidgets('yükleme sırasında olmayan bir kayıp ilan edilmez', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(emitPreference: false));
    await tester.pump();

    expect(find.byKey(_badgeKey), findsNothing);
    expect(find.byKey(_bannerKey), findsNothing);
  });

  testWidgets('sağ üstteki giriş seçim yüzeyini açar', (tester) async {
    await tester.pumpWidget(
      _screen(
        groups: [_group('g1', 'Kamp A'), _group('g2', 'Kamp B')],
        primaryGroupId: null,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_actionKey));
    await tester.pumpAndSettle();

    expect(find.byType(PrimaryGroupSelectorCard), findsOneWidget);
    expect(find.text('Kamp A'), findsOneWidget);
    expect(find.text('Kamp B'), findsOneWidget);
  });

  testWidgets('şeride dokunmak da aynı seçim yüzeyini açar', (tester) async {
    await tester.pumpWidget(
      _screen(groups: [_group('g1', 'Kamp A')], primaryGroupId: null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_bannerKey));
    await tester.pumpAndSettle();

    expect(find.byType(PrimaryGroupSelectorCard), findsOneWidget);
  });

  test('Başarımlar ekranının gövdesinde artık seçim kartı yok', () {
    final source = File(
      'lib/features/profile/social_profile_screen.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    // 🔴 Kapan: kart gövdeye geri konursa bu iddia düşer (V49-2'nin kendisi).
    expect(source.contains('PrimaryGroupSelectorCard('), isFalse);
    // Giriş ve şerit ekranda duruyor.
    expect(source.contains('const PrimaryGroupAppBarAction()'), isTrue);
    expect(source.contains('const PrimaryGroupMissingBanner()'), isTrue);
    // Giriş yalnız kendi profilinde; başkasının profilinde görünmez.
    expect(
      source.contains('if (isSelf) const PrimaryGroupAppBarAction()'),
      isTrue,
    );
    expect(
      source.contains('if (isSelf) const PrimaryGroupMissingBanner()'),
      isTrue,
    );
  });
}
