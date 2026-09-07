import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/sanctions/sanction_ladder.dart';
import 'package:online_study_room/features/admin/tabs/admin_users_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-C — yaptirim yuzeyini birlestir + geri alma
/// (`docs/design/ADMIN-PANEL-PLAN.md` §5 WP-C).
///
/// Sahibin ucuncu sikayeti: *"banlama farkli yere gidiyorum herhalde"*.
/// Olculen kusur: yaptirim uc ayri yerde, **iki farkli basamak listesiyle**
/// yapiliyordu; "cezayi geri alma" sunucuda yaziliydi ama `app/lib/features/`
/// icinde **sifir cagri yeri** vardi.
///
/// Bu dosyanin kurali: **kaynakta gecmek kanit degildir.** Her iddia ya
/// kullanicinin dokundugu seyi taklit eder (`tester.tap`) ve sonra **sahte
/// deponun kaydini** okur, ya da kaynaktaki ikinci listeyi arar.
const String _targetId = '55555555-5555-4555-8555-555555555555';
const String _targetEmail = 'hedef@example.com';

/// Depo casusu: cagri sayilir, `super` gercek isi yapar.
class _SpyModeration extends InMemoryAdminModerationRepository {
  int fetchSanctionsCalls = 0;
  final List<String> revoked = [];

  @override
  Future<List<ModerationSanction>> fetchSanctions(String targetUserId) {
    fetchSanctionsCalls++;
    return super.fetchSanctions(targetUserId);
  }

  @override
  Future<ModerationSanction> revokeSanction({
    required String sanctionId,
    required String reason,
  }) async {
    revoked.add('$sanctionId=$reason');
    return super.revokeSanction(sanctionId: sanctionId, reason: reason);
  }
}

class _SpyAdmin extends InMemoryAdminRepository {
  final List<String> userActions = [];

  @override
  Future<void> performUserAction({
    required String action,
    required String targetUserId,
    required String reason,
  }) async {
    userActions.add('$action:$targetUserId');
  }
}

Widget _host(
  _SpyModeration moderation, {
  _SpyAdmin? admin,
  bool suspended = false,
}) {
  return ProviderScope(
    overrides: [
      adminModerationRepositoryProvider.overrideWithValue(moderation),
      if (admin != null) adminRepositoryProvider.overrideWithValue(admin),
      adminUsersProvider.overrideWith(
        (ref) async => [
          AdminUserDto(
            id: _targetId,
            email: _targetEmail,
            createdAt: DateTime(2026, 7, 1),
            bannedUntil: suspended ? '2030-01-01T00:00:00Z' : null,
          ),
        ],
      ),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AdminUsersTab()),
    ),
  );
}

/// 🔴 Bugun bes ajan sahte yesile dustu. Tuzak (c): bir widget tipi **hata
/// kabugunda da** eslesir. Once govdenin gercek oldugunu dogrula.
void _expectRealBody(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'agac hata kabugunda');
  expect(find.byType(ErrorWidget), findsNothing, reason: 'agac hata kabugunda');
}

/// Hedefte **aktif** bir kisit kurar (yaptirim yolundan, elle degil).
Future<ModerationSanction> _seedActive(
  _SpyModeration moderation,
  ModerationAction action,
) {
  return moderation.applySanction(
    ModerationSanctionRequest(
      targetUserId: _targetId,
      action: action,
      reason: 'tekrarlayan hakaret',
      idempotencyKey: 'wpc-seed-$_targetId',
    ),
  );
}

Future<void> _openDossier(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('admin-user-open-dossier')));
  await tester.pumpAndSettle();
}

/// Gerekce diyalogunu doldurur.
Future<void> _confirmReason(WidgetTester tester, String reason) async {
  await tester.enterText(
    find.byKey(const Key('admin-user-reason-field')),
    reason,
  );
  await tester.tap(find.byKey(const Key('admin-user-reason-confirm')));
  await tester.pumpAndSettle();
}

/// 🔴 WP-820: menu BES basamaktan DOKUZa cikti; alt basamaklar test
/// penceresinde ekran disinda kalabiliyor. Once gorunur yap, sonra dokun --
/// kaydirmadan dokunmak "widget off-screen" uyarisi verip isabetsiz kalirdi.
Future<void> _tapLadderStep(WidgetTester tester, ModerationAction action) async {
  final target = find.byKey(Key('admin-suspend-${action.wire}'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('WP-C/1 — basamak listesi TEK kaynaktan turer', () {
    test('kanonik katalog dosyasi vardir', () {
      expect(
        File('lib/features/admin/sanctions/sanction_ladder.dart').existsSync(),
        isTrue,
        reason: 'basamaklarin tek kanonik kaynagi yok',
      );
    });

    test('kullanicilar sekmesinde elle yazilmis ikinci liste yok', () {
      final source = _read('lib/features/admin/tabs/admin_users_tab.dart');
      expect(
        RegExp(
          r'List<ModerationAction>\s+kAdminSuspensionLadder\s*=\s*\[',
        ).hasMatch(source),
        isFalse,
        reason:
            'basamaklar burada elle sayiliyor; UGC listesiyle ayri kaynaktan '
            'turuyor (sahibin "banlama farkli yere gidiyorum" sikayeti)',
      );
    });

    test('UGC sekmesi de kendi listesini yazmaz', () {
      final source = _read('lib/features/admin/detail/admin_case_detail_page.dart');
      expect(
        RegExp(r'List<ModerationAction>\s+\w+\s*=\s*(const\s*)?\[').hasMatch(
          source,
        ),
        isFalse,
        reason: 'UGC sekmesinde ucuncu bir basamak listesi belirmis',
      );
    });

    test('auth alt kumesi kataloktan TURETILIR, kopyalanmaz', () {
      expect(kAdminSanctionLadder, ModerationAction.values);
      expect(
        kAdminAccountRestrictionLadder,
        ModerationAction.values.where((a) => a.requiresAuthBan).toList(),
        reason: 'liste artik turemiyor',
      );
      // WP-625 sozlesmesi korunur: bes basamak, sonuncusu suresiz.
      expect(kAdminAccountRestrictionLadder, hasLength(5));
    });

    /// 🔴 WP-820 — MENUYU DARALTMANIN YOLU YOK.
    ///
    /// WP-C listeyi tek kaynaktan turetti ama menuyu tek YAPMADI:
    /// `chooseAndApply` varsayilani `kAdminAccountRestrictionLadder`di, yani
    /// yalniz auth'a inen bes basamak. Tam katalogu tek bir cagri yeri
    /// geciyordu. Sonuc uc giris noktasi, IKI menu -- Kullanicilar sekmesinden
    /// ve kisi dosyasindan `Uyar`, `Sustur`, `Isim sifirla` HIC
    /// uygulanamiyordu.
    ///
    /// Bu iddia kaynak duzeyindedir ve bilerek oyle: `ladder` adinda bir
    /// parametre geri gelirse ikinci menu de geri gelir.
    test('🔴 chooseAndApply menuyu daraltan bir parametre KABUL ETMEZ', () {
      final source = _read(
        'lib/features/admin/sanctions/admin_sanction_actions.dart',
      );
      expect(
        source.contains('List<ModerationAction>? ladder'),
        isFalse,
        reason:
            'Menuyu daraltan parametre geri gelmis. Ikinci liste tam olarak '
            'boyle dogmustu: "ileride lazim olur" diye birakilan bir kapi.',
      );
      expect(
        RegExp(r'const\s+steps\s*=\s*kAdminSanctionLadder').hasMatch(source),
        isTrue,
        reason: 'Menu TAM katalogdan gelmeli.',
      );
    });

    test('Kullanicilar sekmesi kendi basamak takma adini TASIMAZ', () {
      final source = _read('lib/features/admin/tabs/admin_users_tab.dart');
      // 🔴 Aranan sey ANMA degil TANIMDIR: dosyanin kendi yorumu bu adi
      // tarihce olarak yaziyor ve yazmali. Ilk yazdigim iddia `contains` idi
      // ve kendi yorumumu yakalayip kirmizi dustu -- test, olcmek istedigi
      // seyi degil metni olcuyordu.
      expect(
        RegExp(r'kAdminSuspensionLadder\s*=').hasMatch(source),
        isFalse,
        reason:
            'Sekmeye ait ayri bir basamak listesi geri TANIMLANMIS; ad geri '
            'gelince menu de daralir.',
      );
    });
  });

  group('WP-C/2 — aktif kisit dosyada gorunur ve GERI ALINIR', () {
    testWidgets('kisi dosyasi tek dokunusla acilir', (tester) async {
      final moderation = _SpyModeration();
      await _seedActive(moderation, ModerationAction.suspend7d);
      await tester.pumpWidget(_host(moderation, suspended: true));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      expect(
        find.byKey(const Key('admin-user-open-dossier')),
        findsOneWidget,
        reason: 'kisinin dosyasina goturen gorunur bir kontrol yok',
      );
      await _openDossier(tester);
      _expectRealBody(tester);
      expect(find.byKey(const Key('admin-person-dossier')), findsOneWidget);
      expect(find.text(_targetEmail), findsWidgets);
    });

    testWidgets('"Kisiti kaldir" GERCEKTEN revokeSanction cagirir', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      final sanction = await _seedActive(
        moderation,
        ModerationAction.suspend7d,
      );
      await tester.pumpWidget(_host(moderation, suspended: true));
      await tester.pumpAndSettle();
      await _openDossier(tester);
      _expectRealBody(tester);

      expect(
        find.byKey(const Key('admin-sanction-revoke')),
        findsOneWidget,
        reason: 'aktif kisitin yaninda kalici geri alma yolu yok',
      );
      await tester.tap(find.byKey(const Key('admin-sanction-revoke')));
      await tester.pumpAndSettle();
      await _confirmReason(tester, 'yanlis ban');

      // 🔴 Kaynakta `revokeSanction` gecmesi kanit degil: deponun kaydini oku.
      expect(
        moderation.revoked,
        hasLength(1),
        reason: 'dugme basildi ama depoya hicbir geri alma inmedi',
      );
      expect(moderation.revoked.single, startsWith(sanction.id));
      final after = (await moderation.fetchSanctions(_targetId)).single;
      expect(after.state, ModerationSanctionState.revoked);
      expect(after.isActive(DateTime.now()), isFalse);
    });
  });

  group('WP-C/3 — moderationSanctionsProvider IZLENIR, gecmis cizilir', () {
    testWidgets('dosya acilinca gecmis okunur ve ekrana yazilir', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await _seedActive(moderation, ModerationAction.suspend7d);
      await tester.pumpWidget(_host(moderation, suspended: true));
      await tester.pumpAndSettle();
      await _openDossier(tester);
      _expectRealBody(tester);

      expect(
        moderation.fetchSanctionsCalls,
        greaterThan(0),
        reason: 'saglayici hic okunmadi (bugun yalniz invalidate ediliyor)',
      );
      expect(find.byKey(const Key('admin-sanction-history')), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        find.text(l10n.adminModerationSanctionSuspend7d),
        findsWidgets,
        reason: 'ceza gecmisi ekranda cizilmiyor',
      );
    });

    testWidgets('geri almadan sonra gecmis KENDILIGINDEN tazelenir', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await _seedActive(moderation, ModerationAction.suspend7d);
      await tester.pumpWidget(_host(moderation, suspended: true));
      await tester.pumpAndSettle();
      await _openDossier(tester);
      final before = moderation.fetchSanctionsCalls;

      await tester.tap(find.byKey(const Key('admin-sanction-revoke')));
      await tester.pumpAndSettle();
      await _confirmReason(tester, 'yanlis ban');
      _expectRealBody(tester);

      // `read` ile alinan bir saglayici invalidate edilse de yeniden
      // okunmazdi: sayacin artmasi dinleyicinin GERCEKTEN var oldugunu olcer.
      expect(
        moderation.fetchSanctionsCalls,
        greaterThan(before),
        reason: 'saglayicinin dinleyicisi yok; ekran bayat kaldi',
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.adminModerationSanctionRevoked), findsWidgets);
    });
  });

  group('WP-C/4 — kalici yasak e-posta YAZILMADAN uygulanmaz', () {
    testWidgets('sert teyit acilir; e-posta bos iken hicbir sey yazilmaz', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();
      await _openDossier(tester);
      _expectRealBody(tester);

      await tester.tap(find.byKey(const Key('admin-sanction-apply-menu')));
      await tester.pumpAndSettle();
      await _tapLadderStep(tester, ModerationAction.banPermanent);
      await _confirmReason(tester, 'agir ihlal');

      expect(
        find.byKey(const Key('admin-sanction-hard-confirm')),
        findsOneWidget,
        reason: 'kalici yasak tek dokunusla uygulaniyor',
      );
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();
      expect(
        await moderation.fetchSanctions(_targetId),
        isEmpty,
        reason: 'e-posta yazilmadan kalici yasak indi',
      );

      await tester.enterText(
        find.byKey(const Key('admin-sanction-hard-email')),
        'baskasi@example.com',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();
      expect(
        await moderation.fetchSanctions(_targetId),
        isEmpty,
        reason: 'yanlis e-posta ile kalici yasak indi',
      );

      await tester.enterText(
        find.byKey(const Key('admin-sanction-hard-email')),
        _targetEmail,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();
      final sanction = (await moderation.fetchSanctions(_targetId)).single;
      expect(sanction.action, ModerationAction.banPermanent);
      expect(sanction.expiresAt, isNull, reason: 'kalici yasak kalici degil');
    });

    testWidgets('hesap silme de e-posta yazdirir', (tester) async {
      final moderation = _SpyModeration();
      final admin = _SpyAdmin();
      await tester.pumpWidget(_host(moderation, admin: admin));
      await tester.pumpAndSettle();
      await _openDossier(tester);
      _expectRealBody(tester);

      await tester.tap(find.byKey(const Key('admin-person-delete')));
      await tester.pumpAndSettle();
      await _confirmReason(tester, 'kullanici talebi');
      expect(find.byKey(const Key('admin-sanction-hard-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();
      expect(
        admin.userActions,
        isEmpty,
        reason: 'e-posta yazilmadan hesap silindi',
      );

      await tester.enterText(
        find.byKey(const Key('admin-sanction-hard-email')),
        _targetEmail,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();
      expect(admin.userActions, ['soft_delete_user:$_targetId']);
    });
  });

  group('WP-C/5 — AYRIMLI yaptirim: hafif kisit teyit istemez, geri alinir', () {
    testWidgets('sureli kisit sert teyit ACMAZ', (tester) async {
      final moderation = _SpyModeration();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();
      await _openDossier(tester);

      await tester.tap(find.byKey(const Key('admin-sanction-apply-menu')));
      await tester.pumpAndSettle();
      await _tapLadderStep(tester, ModerationAction.suspend24h);
      await _confirmReason(tester, 'ilk uyari sonrasi');
      _expectRealBody(tester);

      expect(
        find.byKey(const Key('admin-sanction-hard-confirm')),
        findsNothing,
        reason: 'geri alinabilir kisit teyit istiyor (teyit enflasyonu)',
      );
      expect(
        (await moderation.fetchSanctions(_targetId)).single.action,
        ModerationAction.suspend24h,
      );
      await tester.pumpAndSettle(const Duration(seconds: 12));
    });

    testWidgets('sureli kisitin ardindan "Geri al" seridi cikar ve CALISIR', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();
      await _openDossier(tester);

      await tester.tap(find.byKey(const Key('admin-sanction-apply-menu')));
      await tester.pumpAndSettle();
      await _tapLadderStep(tester, ModerationAction.suspend24h);
      await _confirmReason(tester, 'ilk uyari sonrasi');

      expect(
        find.byKey(const Key('admin-sanction-undo')),
        findsOneWidget,
        reason: '10 sn "Geri al" seridi yok',
      );
      await tester.tap(find.byKey(const Key('admin-sanction-undo')));
      await tester.pumpAndSettle();

      expect(
        moderation.revoked,
        hasLength(1),
        reason: '"Geri al" basildi ama depoya geri alma inmedi',
      );
      expect(
        (await moderation.fetchSanctions(_targetId)).single.state,
        ModerationSanctionState.revoked,
      );
    });
  });

  /// 🔴 WP-812 — BU GRUP BIR KOPRU WIDGET'INI OLCUYORDU, ARTIK GERCEK YOLU
  /// OLCUYOR.
  ///
  /// Eski hali `AdminCaseTargetLink` adli bir dugmeyi bos bir `Scaffold`
  /// icinde kurup ona dokunuyordu. O dugmenin `app/lib` icinde **sifir cagri
  /// yeri** vardi: hicbir vaka sayfasi onu cizmiyordu. Yani test yesildi ama
  /// kanitladigi sey "bu widget calisiyor"du, "vakadan kisiye gecilebiliyor"
  /// degil — deponun tekrar eden kusuru (yazildi, cagrilmadi) bir kez de
  /// TESTIN KENDISINDE.
  ///
  /// Gercek kopru bu arada baska bir yerden kuruldu: vaka sayfasindaki taraf
  /// satiri (`admin_case_detail_page.dart` `_CaseUserRow.onTap`) kisi
  /// profilini aciyor ve WP-809'dan beri o ekranda aktif kisit + geri alma da
  /// var. Yani kopru widget'i yalnizca artik degil, ZARARLI: vakadan DAHA DAR
  /// bir ekrana (hesap silme dugmesi tasiyan kisi dosyasina) giden hazir bir
  /// dugme olarak duruyordu.
  ///
  /// Widget silindi. Bu grubun KENDI degeri korundu: `mute_24h` bir auth ban
  /// DEGILDIR (`ModerationAction.requiresAuthBan == false`) ve WP-C/2 yalniz
  /// `suspend_7d` ile olcuyor. Susturmanin da "aktif kisit" sayilip geri alma
  /// dugmesi kazandigi iddiasi burada, ama artik GERCEK giris noktasindan.
  group('WP-C/6 — susturma da aktif kisittir ve geri alinabilir', () {
    testWidgets('mute_24h dosyada aktif gorunur ve geri alma dugmesi tasir', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await _seedActive(moderation, ModerationAction.mute24h);
      // 🔴 `suspended: false` BILEREK: susturma auth ban kurmaz, yani
      // `bannedUntil` bostur. Aktif kisit yine de gorunmeli — kaynak
      // `moderation_sanctions`, auth tarafi degil.
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();
      _expectRealBody(tester);
      expect(find.byKey(const Key('admin-person-dossier')), findsNothing);

      await _openDossier(tester);
      _expectRealBody(tester);

      expect(find.byKey(const Key('admin-person-dossier')), findsOneWidget);
      expect(find.byKey(const Key('admin-sanction-history')), findsOneWidget);
      expect(
        find.byKey(const Key('admin-sanction-revoke')),
        findsOneWidget,
        reason:
            'susturma geri alinamaz durumda: auth ban olmayan kisitlar da '
            'kaldirilabilmeli',
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        find.text(l10n.adminModerationSanctionMute24h),
        findsWidgets,
        reason: 'hedefin aktif kisiti dosyada gorunmuyor',
      );
    });
  });

  /// Silinen koprunun geri gelmemesi icin bir fren.
  group('WP-812 — olu kopru widget\'i geri gelmez', () {
    test('AdminCaseTargetLink kaynakta yok', () {
      expect(
        File(
          'lib/features/admin/sanctions/admin_case_target_link.dart',
        ).existsSync(),
        isFalse,
        reason:
            'Kopru widget\'i geri gelmis. Vakadan kisiye gecis zaten var '
            '(taraf satiri -> kisi profili) ve o ekran daha genis; bu dugme '
            'vakadan DAHA DAR bir ekrana giden ikinci bir yol acardi.',
      );
    });
  });
}
