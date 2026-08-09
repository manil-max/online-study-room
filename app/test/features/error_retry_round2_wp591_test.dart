// WP-591: WP-560'in ortak "hata + tekrar dene" cozumu bes cikmaz dala daha
// uygulandi. Denetimde (WP-581) hepsi ayni siniftaydi: kullanici hatayi goruyor
// ama yapabilecegi bir sey yok.
//
// Iki dalda metin de YANLISTI:
//   * `announcements_screen` "Beklenmeyen bir hata olustu." diyordu — neyin
//     yuklenemedigini soylemiyor.
//   * uc safety dali `safetyActionFailed` kullaniyordu; o cumle bir EYLEMIN
//     basarisiz oldugunu anlatir ("islem yapilamadi"), oysa orada YUKLEME
//     basarisiz. Kullaniciya yanlis sey soyleniyordu.
//
// 🔴 Bu dosya "dugme var mi"ya bakmakla yetinmez. WP-560'in dersi: "dugme var
// ama hicbir sey yapmiyor" hatanin kendisinden kotudur — kullanici basar, ekran
// degismez, uygulamayi donmus sayar. Bu yuzden olculen sey SAYAC: tekrar-dene'ye
// basilinca provider'in gercekten yeniden kuruldugu (1 -> 2) dogrulanir.
//
// 🔴 Yeni l10n anahtari eklenmedi (`homeVerilerYuklenemedi` +
// `profileBasarilarYuklenemedi` yetti): bu tur sirasinda uc ajan ayni `.arb`
// dosyalarina yaziyordu ve bir commit tam bu yuzden kirlenmisti.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/widgets/error_retry_view.dart';
import 'package:online_study_room/data/models/moderation_appeal.dart';
import 'package:online_study_room/data/models/nudge_mute.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/features/safety/blocked_users_screen.dart';
import 'package:online_study_room/features/safety/muted_nudges_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  testWidgets('kendi yaptirimlarim: tekrar-dene provider i YENIDEN kurar', (
    tester,
  ) async {
    var builds = 0;

    await tester.pumpWidget(
      _app([
        // 🔴 Sayac ICIN BILEREK `mySanctionsProvider` secildi: o `FutureProvider`,
        // yani autoDispose DEGIL. Kardesleri (`blockedProfilesProvider`,
        // `nudgeMutesProvider`) `FutureProvider.autoDispose` ve widget testinde
        // her karede yeniden kuruluyorlar (olculdu: tek `pumpAndSettle` icinde
        // 11 kurulum). Boyle bir provider uzerinde "1 -> 2" iddiasi sessizce
        // anlamsizlasirdi -- bu repoda bilinen Riverpod 3 tuzagi.
        mySanctionsProvider.overrideWith((ref) async {
          builds++;
          throw Exception('ag yok');
        }),
        blockedProfilesProvider.overrideWith((ref) async => const <Profile>[]),
        myAppealsProvider.overrideWith(
          (ref) async => const <ModerationAppeal>[],
        ),
      ], const BlockedUsersScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);

    // 🔴 "1 -> 2" diye SABIT sayi iddia etmek burada YANLIS olurdu: ilk
    // yerlesme sirasinda provider birden fazla kez kuruluyor (olculdu: tek
    // `pumpAndSettle` icinde 11). Bu repoda bilinen Riverpod 3 tuzagi ve
    // sayiyi ezberlemek testi kirilgan yapar. Olculen sey DOGAL CHURN ile
    // TIKLAMANIN farki: once dokunmadan ayni kadar kare ilerletilip durgun
    // durumdaki artis olculur, sonra tiklamanin artisi onunla kiyaslanir.
    final beforeIdle = builds;
    await tester.pumpAndSettle();
    final idleChurn = builds - beforeIdle;

    final beforeTap = builds;
    await tester.tap(find.byKey(kErrorRetryButtonKey));
    await tester.pumpAndSettle();
    final tapChurn = builds - beforeTap;

    expect(
      tapChurn,
      greaterThan(idleChurn),
      reason:
          'Tekrar-dene provider i yeniden kurmadi (dokunmadan $idleChurn, '
          'dokununca $tapChurn): dugme var ama hicbir sey yapmiyor -- hatanin '
          'kendisinden kotusu.',
    );
  });

  testWidgets('susturulan durtmeler: hata dalinda cikis GORUNUR', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        nudgeMutesProvider.overrideWith((ref) async {
          throw Exception('ag yok');
        }),
      ], const MutedNudgesScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
    // Eski metin `safetyActionFailed` idi: bir EYLEMIN basarisiz oldugunu
    // anlatiyordu, oysa burada YUKLEME basarisiz.
    expect(find.text('Veriler yüklenemedi.'), findsOneWidget);
  });

  testWidgets('veri gelince tekrar-dene HIC cizilmez (tek yonlu iddia kapani)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        nudgeMutesProvider.overrideWith((ref) async => const <NudgeMute>[]),
      ], const MutedNudgesScreen()),
    );
    await tester.pumpAndSettle();

    // Bu olmadan "dugmeyi kosulsuz ciz" sabotaji testi gecerdi.
    expect(find.byKey(kErrorRetryButtonKey), findsNothing);
  });

  test('bes hata dalinin hepsi ortak cikisi kullanir (kaynak sozlesmesi)', () {
    // 🔴 Yukaridaki widget testleri iki ekrani GERCEKTEN suruyor. Kalan uc dal
    // (duyurular, kendi yaptirimlarim, basarim karti) daha derin harness
    // gerektiriyor; bagi kaynak duzeyinde sabitliyoruz ki eski desen sessizce
    // geri donmesin. Bu repoda "kural yaziliydi ama cagiran yoktu" hatasi
    // defalarca uretime cikti — olculmeyen bag yok sayilir.
    const targets = <String, int>{
      'lib/features/notifications/announcements_screen.dart': 1,
      'lib/features/safety/muted_nudges_screen.dart': 1,
      'lib/features/safety/blocked_users_screen.dart': 2,
      'lib/features/profile/widgets/gamification_card.dart': 1,
    };

    for (final entry in targets.entries) {
      final source = File(entry.key).readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        'ErrorRetryView('.allMatches(code).length,
        entry.value,
        reason: '${entry.key}: beklenen sayida ortak cikis yok.',
      );
      expect(
        code,
        contains('onRetry: () => ref.invalidate('),
        reason:
            '${entry.key}: tekrar-dene gercek bir yeniden okuma cagirmiyor.',
      );
      expect(
        code.contains('l10n.safetyActionFailed') &&
            code.contains('error: (_, _) => Text('),
        isFalse,
        reason:
            '${entry.key}: yukleme hatasi yine bir EYLEM hatasi cumlesiyle '
            'anlatiliyor.',
      );
    }

    final announcements = File(
      'lib/features/notifications/announcements_screen.dart',
    ).readAsStringSync();
    expect(
      announcements.contains('error: (_, _) => _Message('),
      isFalse,
      reason:
          'Duyurular yine "Beklenmeyen bir hata olustu." diyor: neyin '
          'yuklenemedigini soylemiyor ve cikis vermiyor.',
    );
  });
}
