// WP-500 (V58-N04 / rapor T11): "İngilizce arayüzde '2 aktif'".
//
// 🔴 `active_members_card.dart` rozeti `'${active.length} aktif'` ile
// çiziyordu — dil ne olursa olsun Türkçe. l10n kapısı bunu **iki kuralın
// kesişiminde** kaçırdı:
//   1. `TECHNICAL_RE` içindeki "tamamı interpolasyon" muafiyeti `^\$` idi ve
//      yalnız **başlangıcı** kontrol ediyordu → `$` ile başlayan her literal
//      muaf sayılıyordu;
//   2. `PROSE_RE` literalin **harfle başlamasını** şart koşuyordu → `$` ile
//      başlayan cümle "cümle" sayılmıyordu.
// İkisi de `scripts/l10n_audit.py` içinde düzeltildi ve kapı artık kendini
// sınıyor (`--self-test`).
//
// Bu dosya ürün tarafını sabitler: rozet **katalogdan** gelir ve dil değişince
// gerçekten değişir. Sayı çoğul kuralına bağlı (0/1/çok).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
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

Profile _member(int i) =>
    Profile(id: 'u$i', displayName: 'Uye $i', createdAt: DateTime(2026, 1, 1));

Presence _studying(int i) => Presence(
  userId: 'u$i',
  groupId: _group.id,
  status: PresenceStatus.studying,
  todaySeconds: 600,
  startedAt: DateTime(2026, 1, 1, 9).add(Duration(minutes: i)),
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required int count,
  required Locale locale,
}) async {
  final members = [for (var i = 1; i <= count; i++) _member(i)];
  final presence = [for (var i = 1; i <= count; i++) _studying(i)];

  await tester.pumpWidget(
    ProviderScope(
      // Aynı testte ikinci kez pump edilirse konteyner yeniden kurulmalı
      // (WP-481 dersi); yoksa Riverpod eski değeri bir tur daha gösterir.
      key: ValueKey('$count-$locale'),
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_member(1))),
        userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
        groupPresenceProvider.overrideWith((ref) => Stream.value(presence)),
        groupMembersProvider.overrideWith((ref) => Stream.value(members)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(width: 320, height: 260, child: ActiveMembersCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('rozet dile göre değişir', () {
    testWidgets('İngilizce arayüzde "2 active"', (tester) async {
      await _pumpCard(tester, count: 2, locale: const Locale('en'));

      expect(find.text('2 active'), findsOneWidget);
      // 🔴 Asıl şikâyet: İngilizce arayüzde Türkçe kelime.
      expect(find.text('2 aktif'), findsNothing);
      expect(find.textContaining('aktif'), findsNothing);
    });

    testWidgets('Türkçe arayüzde "2 aktif"', (tester) async {
      await _pumpCard(tester, count: 2, locale: const Locale('tr'));

      expect(find.text('2 aktif'), findsOneWidget);
      expect(find.text('2 active'), findsNothing);
    });
  });

  group('çoğul kuralı 0/1/çok', () {
    testWidgets('tek üye', (tester) async {
      await _pumpCard(tester, count: 1, locale: const Locale('en'));
      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('hiç üye yok — rozet yine sayıyı söyler', (tester) async {
      // Kart "kimse yok" metnini gövdede gösterir; rozet ise 0'ı yazar
      // (WP-495: sayaç yalnız gerçek veriyle çizilir, ama veri geldiyse 0 da
      // gerçek bir sayıdır).
      await _pumpCard(tester, count: 0, locale: const Locale('en'));
      expect(find.text('0 active'), findsOneWidget);
    });

    testWidgets('çok üye', (tester) async {
      await _pumpCard(tester, count: 6, locale: const Locale('tr'));
      expect(find.text('6 aktif'), findsOneWidget);
    });
  });
}
