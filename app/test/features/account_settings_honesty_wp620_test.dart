// 🔴 WP-620 — Hesabim ekrani KENDI BILMEDIGI seyi biliyormus gibi konusuyordu.
//
// Denetim: `docs/denetim/DENETIM-auth.md` (RISK-3, RISK-4). Uc ayri kusur, tek
// ortak deseni var: *belirsizligi bir hale yuvarlamak*.
//
//   1. `account_settings_screen.dart:435-472`
//      `final active = failed || snap.data?.active == true;`
//      Silme durumu OKUNAMAYINCA da "aktif" sayiliyordu. Ag kotuyken Hesabim'a
//      giren, silmeyi hic istememis kullanici kirmizi
//      "Silme planlandi - iptal et" kartini goruyor, dokununca sunucudan
//      `no_active_request` yiyor ve ekran ona "Beklenmeyen bir hata olustu."
//      diyordu. Ayni anda gercekten silmek isteyen kullanici da "Hesabi sil"
//      dugmesine HIC ulasamiyordu.
//      Koddaki gerekce yorumu "iptal cagrisi zararsizdir" diyordu; SQL bunu
//      curutuyor: `supabase/migrations/0037_account_deletion_core.sql:146-149`
//      bekleyen istek yoksa `no_active_request` FIRLATIR.
//
//   2. `account_settings_screen.dart:201-218` (ve ikizi `profile_screen.dart`)
//      Cevrimdisi cikista kullanici GERCEKTEN cikiyor - gotrue once yerel
//      oturumu siler, sonra sunucuya gider - ama ekran "cikis yapilirken bir
//      hata olustu" deyip kullaniciyi ekranda tutuyordu. Profil ekranindaki
//      ikiz cagri ise hic `await`lenmiyor ve hic yakalanmiyordu: hata islenmemis
//      async hata olarak zone'a dusuyor, ekranda hicbir sey yazmiyordu.
//
//   3. `account_settings_screen.dart:131-168`
//      Giris yapmis Windows kullanicisinda "Sifremi unuttum" hala e-posta
//      gonderip "gonderildi" diyordu. WP-616 masaustunde calisan bir yol
//      OLMADIGINI kanitladi ve karari `password_reset_platform.dart` icine
//      koydu; giris ekrani kapandi, oturum ICINDEKI kol acik kalmisti.
//
// 🔴 Sahte depo bilerek **alan disi** hata firlatir (`SocketException`).
// `AuthException` firlatan bir sahte depo bu sinif kusuru olcemez - bu turda
// tam bu yuzden bes yerde gozden kacti (bkz. WP-610 dosyasindaki ayni not).
//
// Sabotaj testi: `failed ||` geri konursa 1. grup, `catch` dallari geri
// alinirsa 4./5. grup, platform kapisi silinirse 6. grup kirmiziya doner.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette degil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/account_deletion_status.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/features/profile/profile_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _socketFailure = SocketException('Connection reset by peer');

/// Kopuk baglantiyi **gercekci** turle taklit eden depo.
class _FakeAuthRepository extends InMemoryAuthRepository {
  Object? statusError;
  Object? cancelError;
  Object? signOutError;
  AccountDeletionStatus status = AccountDeletionStatus.inactive;

  int statusCalls = 0;
  int cancelCalls = 0;
  int signOutCalls = 0;
  int resetCalls = 0;

  @override
  Future<AccountDeletionStatus> fetchAccountDeletionStatus() async {
    statusCalls++;
    final error = statusError;
    if (error != null) throw error;
    return status;
  }

  @override
  Future<AccountDeletionStatus> cancelAccountDeletion() async {
    cancelCalls++;
    final error = cancelError;
    if (error != null) throw error;
    status = AccountDeletionStatus.inactive;
    return status;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    // gotrue sirasi taklit ediliyor: **once** yerel oturum silinir, **sonra**
    // sunucuya haber verilir. Ag ikinci adimda duserse kullanici coktan
    // cikmistir - bu testlerin olctugu sey tam olarak budur.
    await super.signOut();
    final error = signOutError;
    if (error != null) throw error;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls++;
    return super.sendPasswordResetEmail(email);
  }
}

/// Hesabim ekrani bir alt sayfadir; cikistan sonra geri donulen bir kok gerek.
class _HomeShell extends StatelessWidget {
  const _HomeShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute<void>(
                builder: (_) => const AccountSettingsScreen(),
              ),
            ),
            child: const Text('KOK EKRAN'),
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<_FakeAuthRepository> signedUpRepo() async {
    final repo = _FakeAuthRepository();
    addTearDown(repo.dispose);
    await repo.signUp(
      email: 'ali@ornek.com',
      password: 'guvenli123',
      displayName: 'Ali',
    );
    return repo;
  }

  Future<List<Override>> overridesFor(_FakeAuthRepository repo) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(repo),
    ];
  }

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget app(List<Override> overrides, Widget home) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  /// Hesabim'i **dogrudan** acar (silme karti / sifre yolu testleri icin).
  Future<_FakeAuthRepository> pumpAccount(
    WidgetTester tester, {
    Object? statusError,
    Object? cancelError,
    AccountDeletionStatus status = AccountDeletionStatus.inactive,
  }) async {
    tallView(tester);
    final repo = await signedUpRepo();
    repo.statusError = statusError;
    repo.cancelError = cancelError;
    repo.status = status;
    // 🔴 Ayni testte ikinci kez pump edilirse Flutter ayni tipteki elemani
    // yeniden KULLANIR: `initState` calismaz, silme sorgusu eski depoya bagli
    // kalir ve capraz kontrol sessizce onceki durumu olcer. Once agaci bosalt.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      app(await overridesFor(repo), const AccountSettingsScreen()),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  /// Hesabim'i **kok ekranin ustune** acar (cikis testleri icin).
  Future<_FakeAuthRepository> pumpAccountOverHome(
    WidgetTester tester, {
    Object? signOutError,
  }) async {
    tallView(tester);
    final repo = await signedUpRepo();
    repo.signOutError = signOutError;
    await tester.pumpWidget(app(await overridesFor(repo), const _HomeShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KOK EKRAN'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountSettingsScreen), findsOneWidget);
    return repo;
  }

  AppLocalizations l10nOf(WidgetTester tester, Type screen) =>
      AppLocalizations.of(tester.element(find.byType(screen)));

  final activeStatus = AccountDeletionStatus(
    active: true,
    purgeAfter: DateTime.utc(2026, 8, 22),
  );

  group('0 - on kosul: sahte depo AuthException DISI hata firlatir', () {
    test('durum sorgusu ve cikis SocketException atar', () async {
      final repo = await signedUpRepo();
      repo.statusError = _socketFailure;
      repo.signOutError = _socketFailure;

      await expectLater(
        repo.fetchAccountDeletionStatus(),
        throwsA(allOf(isA<SocketException>(), isNot(isA<AuthException>()))),
      );
      await expectLater(
        repo.signOut(),
        throwsA(allOf(isA<SocketException>(), isNot(isA<AuthException>()))),
      );
    });

    test('cikis hatasi atsa da YEREL oturum gitmistir', () async {
      final repo = await signedUpRepo();
      repo.signOutError = _socketFailure;
      expect(repo.currentUser, isNotNull);

      await expectLater(repo.signOut(), throwsA(isA<SocketException>()));

      expect(
        repo.currentUser,
        isNull,
        reason:
            'gotrue once yerel oturumu siler; "cikis yapilamadi" demek bu '
            'yuzden yalandir',
      );
    });
  });

  group('1 - silme karti UC AYRI durum gosterir', () {
    testWidgets('durum A - silme AKTIF: iptal kapisi ve son tarih', (
      tester,
    ) async {
      await pumpAccount(tester, status: activeStatus);
      final l10n = l10nOf(tester, AccountSettingsScreen);

      expect(find.text(l10n.accountSilmePlanlandiIptalEt), findsOneWidget);
      expect(find.text(l10n.accountSilmeGeriAlmaPenceresi), findsNothing);
      expect(find.text(l10n.accountSilmeDurumuOkunamadiBaslik), findsNothing);
      expect(find.byKey(const Key('accountDeletionStatusUnknown')), findsNothing);
    });

    testWidgets('durum B - silme YOK: silme kapisi ve geri alma penceresi', (
      tester,
    ) async {
      await pumpAccount(tester);
      final l10n = l10nOf(tester, AccountSettingsScreen);

      expect(find.text(l10n.accountSilmeGeriAlmaPenceresi), findsOneWidget);
      expect(find.text(l10n.accountSilmePlanlandiIptalEt), findsNothing);
      expect(find.text(l10n.accountSilmeDurumuOkunamadiBaslik), findsNothing);
      expect(find.byKey(const Key('accountDeletionStatusUnknown')), findsNothing);
    });

    testWidgets('durum C - durum OKUNAMADI: "hesabin silinecek" DEMEZ', (
      tester,
    ) async {
      await pumpAccount(tester, statusError: _socketFailure);
      final l10n = l10nOf(tester, AccountSettingsScreen);

      expect(
        find.byKey(const Key('accountDeletionStatusUnknown')),
        findsOneWidget,
      );
      expect(find.text(l10n.accountSilmeDurumuOkunamadiBaslik), findsOneWidget);
      expect(
        find.text(l10n.accountSilmePlanlandiIptalEt),
        findsNothing,
        reason:
            'olcum: eskiden 1 - silmeyi hic istememis kullanici, sadece ag '
            'kotu diye "Silme planlandi" kirmizi kartini goruyordu',
      );
      expect(find.text(l10n.accountSilmeGeriAlmaPenceresi), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uc durumun isareti CAPRAZ olarak ayrisir', (tester) async {
      // Her durumun kendine ozel bir isareti var; digerlerinde gorunmuyor.
      // Ucu de ayni goruntuye dusulurse bu tablo kirmiziya doner.
      var repo = await pumpAccount(tester, status: activeStatus);
      var l10n = l10nOf(tester, AccountSettingsScreen);
      final aktif = l10n.accountSilmePlanlandiIptalEt;
      final yok = l10n.accountSilmeGeriAlmaPenceresi;
      final bilinmiyor = l10n.accountSilmeDurumuOkunamadiBaslik;
      expect({aktif, yok, bilinmiyor}, hasLength(3));

      expect(find.text(aktif), findsOneWidget);
      expect(find.text(yok), findsNothing);
      expect(find.text(bilinmiyor), findsNothing);
      expect(repo.statusCalls, 1);

      await pumpAccount(tester);
      expect(find.text(aktif), findsNothing);
      expect(find.text(yok), findsOneWidget);
      expect(find.text(bilinmiyor), findsNothing);

      repo = await pumpAccount(tester, statusError: _socketFailure);
      expect(find.text(aktif), findsNothing);
      expect(find.text(yok), findsNothing);
      expect(find.text(bilinmiyor), findsOneWidget);
    });
  });

  group('2 - durum bilinmezken IKI kapi da acik kalir', () {
    testWidgets('gercekten silmek isteyen kullanici dugmeye ULASIR', (
      tester,
    ) async {
      await pumpAccount(tester, statusError: _socketFailure);

      await tester.tap(find.byKey(const Key('accountDeletionRequestAnyway')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('deleteAccountPassword')),
        findsOneWidget,
        reason:
            'olcum: eskiden 0 - okunamayan durum "aktif" sayildigi icin silme '
            'diyalogunun tek girisi kayboluyordu',
      );
    });

    testWidgets('bekleyen silmesi olan kullanici IPTAL edebilir', (
      tester,
    ) async {
      final repo = await pumpAccount(tester, statusError: _socketFailure);
      final l10n = l10nOf(tester, AccountSettingsScreen);

      await tester.tap(find.byKey(const Key('accountDeletionCancelPending')));
      await tester.pumpAndSettle();

      expect(repo.cancelCalls, 1);
      expect(find.text(l10n.accountSilmeIptalEdildi), findsOneWidget);
    });

    testWidgets('yenile dugmesi sorguyu GERCEKTEN tazeler', (tester) async {
      final repo = await pumpAccount(tester, statusError: _socketFailure);
      final before = repo.statusCalls;

      await tester.tap(find.byKey(const Key('accountDeletionStatusRetry')));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, greaterThan(before));
    });
  });

  group('3 - iptal hatasi: sunucunun NEDENI kullaniciya cevrilir', () {
    testWidgets('no_active_request -> "bekleyen istegin yok"', (tester) async {
      final repo = await pumpAccount(
        tester,
        statusError: _socketFailure,
        // 0037_account_deletion_core.sql:146-149 tam olarak bunu firlatir.
        cancelError: const AuthException('no_active_request'),
      );
      final l10n = l10nOf(tester, AccountSettingsScreen);

      await tester.tap(find.byKey(const Key('accountDeletionCancelPending')));
      await tester.pumpAndSettle();

      expect(repo.cancelCalls, 1);
      expect(find.text(l10n.accountSilmeBekleyenIstekYok), findsOneWidget);
      expect(
        find.text(l10n.authBeklenmeyenBirHataOlustu),
        findsNothing,
        reason:
            'sunucunun EN OLASI cevabi "beklenmeyen" degildir; kullaniciya '
            'hesabinin silinmek uzere OLMADIGI soylenmeli',
      );
    });

    testWidgets('too_late -> "iptal penceresi kapandi"', (tester) async {
      await pumpAccount(
        tester,
        statusError: _socketFailure,
        cancelError: const AuthException('too_late'),
      );
      final l10n = l10nOf(tester, AccountSettingsScreen);

      await tester.tap(find.byKey(const Key('accountDeletionCancelPending')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountSilmeIptalPenceresiKapandi), findsOneWidget);
    });

    testWidgets('alan disi hata: coker degil, generic mesaj', (tester) async {
      await pumpAccount(
        tester,
        statusError: _socketFailure,
        cancelError: _socketFailure,
      );
      final l10n = l10nOf(tester, AccountSettingsScreen);

      await tester.tap(find.byKey(const Key('accountDeletionCancelPending')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.authBeklenmeyenBirHataOlustu), findsOneWidget);
    });
  });

  group('4 - Hesabim: cevrimdisi cikis PANIK mesaji vermez', () {
    Future<void> confirmSignOut(WidgetTester tester) async {
      final l10n = l10nOf(tester, AccountSettingsScreen);
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, l10n.profileCikisYap));
      await tester.pumpAndSettle();
    }

    testWidgets('ag dusse de kullanici CIKMIS sayilir', (tester) async {
      final repo = await pumpAccountOverHome(
        tester,
        signOutError: _socketFailure,
      );
      final l10n = l10nOf(tester, AccountSettingsScreen);
      await confirmSignOut(tester);

      expect(repo.signOutCalls, 1);
      expect(repo.currentUser, isNull);
      expect(
        find.text('KOK EKRAN'),
        findsOneWidget,
        reason:
            'olcum: eskiden ekran acik kaliyor ve kullanici hala iceride '
            'oldugunu saniyordu',
      );
      expect(
        find.text(l10n.profileCikisYapilirkenBirHata),
        findsNothing,
        reason: 'kullanici CIKTI; "cikis yapilamadi" demek yalandir',
      );
      expect(
        find.text(l10n.profileCikisYapildiSunucuyaUlasilamadi),
        findsOneWidget,
        reason:
            'sessiz de kalinmaz: kapatilamayan sey diger cihazlardaki '
            'oturumdur, kullanici bunu bilmeli',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('cevrimici cikis: uyari YOK, ekran kapanir', (tester) async {
      final repo = await pumpAccountOverHome(tester);
      final l10n = l10nOf(tester, AccountSettingsScreen);
      await confirmSignOut(tester);

      expect(repo.signOutCalls, 1);
      expect(find.text('KOK EKRAN'), findsOneWidget);
      expect(
        find.text(l10n.profileCikisYapildiSunucuyaUlasilamadi),
        findsNothing,
        reason: 'basarili cikista uyari gosterilirse mesaj anlamini yitirir',
      );
      expect(find.text(l10n.profileCikisYapilirkenBirHata), findsNothing);
    });
  });

  group('5 - Profil ekrani: ikiz cagri artik awaitleniyor', () {
    Future<_FakeAuthRepository> pumpProfile(
      WidgetTester tester, {
      Object? signOutError,
    }) async {
      tallView(tester);
      final repo = await signedUpRepo();
      repo.signOutError = signOutError;
      await tester.pumpWidget(
        app(await overridesFor(repo), const ProfileScreen()),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('ag dusse de islenmemis hata YOK, kullaniciya soylenir', (
      tester,
    ) async {
      final repo = await pumpProfile(tester, signOutError: _socketFailure);
      final l10n = l10nOf(tester, ProfileScreen);

      await tester.tap(find.byKey(const Key('profile-sign-out')));
      await tester.pumpAndSettle();

      expect(repo.signOutCalls, 1);
      expect(
        tester.takeException(),
        isNull,
        reason:
            'olcum: eskiden cagri ne awaitleniyor ne yakalaniyordu; hata '
            'islenmemis async hata olarak zone\'a dusuyordu',
      );
      expect(
        find.text(l10n.profileCikisYapildiSunucuyaUlasilamadi),
        findsOneWidget,
      );
    });

    testWidgets('cevrimici cikis sessizdir', (tester) async {
      final repo = await pumpProfile(tester);
      final l10n = l10nOf(tester, ProfileScreen);

      await tester.tap(find.byKey(const Key('profile-sign-out')));
      await tester.pumpAndSettle();

      expect(repo.signOutCalls, 1);
      expect(
        find.text(l10n.profileCikisYapildiSunucuyaUlasilamadi),
        findsNothing,
      );
    });
  });

  group('6 - oturum icinde sifre sifirlama: platforma gore', () {
    // Platform **enjekte** edilir; gercek host platformuna bagli test yazilmaz.
    // Bayrak test govdesinin sonunda sifirlanmali: `tearDown` cok gec kalir,
    // binding degismemis olmasini test biter bitmez dogruluyor.
    Future<void> onPlatform(
      TargetPlatform platform,
      Future<void> Function() body,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    Future<void> tapForgotPassword(WidgetTester tester) async {
      final passwordRow = find.ancestor(
        of: find.byIcon(Icons.lock_outline),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: passwordRow, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('changePasswordForgot')));
      await tester.pumpAndSettle();
    }

    testWidgets('Windows: e-posta GONDERILMEZ, calisan yol anlatilir', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.windows, () async {
        final repo = await pumpAccount(tester);
        final l10n = l10nOf(tester, AccountSettingsScreen);

        await tapForgotPassword(tester);

        expect(
          repo.resetCalls,
          0,
          reason:
              'olcum: eskiden 1 - masaustunde acilamayacak bir baglanti '
              'gonderiliyordu',
        );
        expect(
          find.text(l10n.profileSifreSifirlamaGonderildi),
          findsNothing,
          reason: '"gonderildi" cumlesi masaustunde yalandi',
        );
        expect(
          find.byKey(const Key('account-reset-desktop-unavailable')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('account-reset-desktop-body')),
          findsOneWidget,
          reason: 'kullaniciya CALISAN yol (telefondaki uygulama) soylenmeli',
        );
      });
    });

    testWidgets('Android kolu BOZULMADI: e-posta gider ve onay gorunur', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.android, () async {
        final repo = await pumpAccount(tester);
        final l10n = l10nOf(tester, AccountSettingsScreen);

        await tapForgotPassword(tester);

        expect(repo.resetCalls, 1);
        expect(find.text(l10n.profileSifreSifirlamaGonderildi), findsOneWidget);
        expect(
          find.byKey(const Key('account-reset-desktop-unavailable')),
          findsNothing,
        );
      });
    });
  });
}
