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
import 'package:online_study_room/features/admin/sanctions/admin_case_target_link.dart';
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
      final source = _read('lib/features/admin/tabs/admin_moderation_tab.dart');
      expect(
        RegExp(r'List<ModerationAction>\s+\w+\s*=\s*(const\s*)?\[').hasMatch(
          source,
        ),
        isFalse,
        reason: 'UGC sekmesinde ucuncu bir basamak listesi belirmis',
      );
    });

    test('kullanicilar basamagi kataloktan TURETILIR, kopyalanmaz', () {
      // Ayni nesne olmasi "turedi"nin en sert kaniti: kopya bir liste esit
      // olabilir ama ayni olamaz.
      expect(identical(kAdminSuspensionLadder, kAdminAccountRestrictionLadder), isTrue);
      expect(kAdminSanctionLadder, ModerationAction.values);
      expect(
        kAdminSuspensionLadder,
        ModerationAction.values.where((a) => a.requiresAuthBan).toList(),
        reason: 'liste artik turemiyor',
      );
      // WP-625 sozlesmesi korunur: bes basamak, sonuncusu suresiz.
      expect(kAdminSuspensionLadder, hasLength(5));
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
      await tester.tap(
        find.byKey(Key('admin-suspend-${ModerationAction.banPermanent.wire}')),
      );
      await tester.pumpAndSettle();
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
      await tester.tap(
        find.byKey(Key('admin-suspend-${ModerationAction.suspend24h.wire}')),
      );
      await tester.pumpAndSettle();
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
      await tester.tap(
        find.byKey(Key('admin-suspend-${ModerationAction.suspend24h.wire}')),
      );
      await tester.pumpAndSettle();
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

  group('WP-C/6 — vakadan hedefin dosyasina TEK dokunus', () {
    testWidgets('kopruye bir kez dokun; aktif kisit ve gecmis ekranda', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await _seedActive(moderation, ModerationAction.mute24h);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminModerationRepositoryProvider.overrideWithValue(moderation),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Vaka kartinin yerine duran en kucuk kabuk: kopru bir vakadan
            // yalniz hedefin kimligini bilir.
            home: const Scaffold(
              body: AdminCaseTargetLink(
                targetUserId: _targetId,
                targetEmail: _targetEmail,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin-person-dossier')), findsNothing);

      // TEK dokunus. Bugunku yol: UUID'yi kopyala, sekme degistir, aramasiz
      // listede gozle ara.
      await tester.tap(find.byKey(const Key('admin-case-target-link')));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      expect(find.byKey(const Key('admin-person-dossier')), findsOneWidget);
      expect(find.byKey(const Key('admin-sanction-history')), findsOneWidget);
      expect(find.byKey(const Key('admin-sanction-revoke')), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        find.text(l10n.adminModerationSanctionMute24h),
        findsWidgets,
        reason: 'hedefin aktif kisiti dosyada gorunmuyor',
      );
    });
  });
}
