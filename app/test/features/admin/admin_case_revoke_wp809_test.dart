// WP-809 — vakadan acilan kisi ekranindan KISIT KALDIRILABILIR.
//
// Olculmus kusur: moderasyon vakasinda taraf satirina dokununca
// (`detail/admin_case_detail_page.dart:884` -> `openAdminUserProfile`)
// `detail/admin_user_profile_page.dart` acilir. O ekran yaptirim UYGULUYOR
// (`kAdminUserSanctionApplyKey`) ve ceza gecmisini cizIYORdu, ama
// **yururlukteki kisiti hic gostermiyor** ve kaldirma yolu sunmuyordu.
// Kaldirma yalniz `sanctions/admin_person_dossier.dart` icindeydi ve o sayfaya
// SADECE Kullanicilar sekmesinden (`tabs/admin_users_tab.dart:223`)
// gidiliyordu. Yani yikici yon vakadan tek dokunus, kurtarma yonu baska
// sekmede — WP-775'in kapatmasi gereken is akisinin ortada kalmis parcasi.
//
// 🔴 Bu dosyanin kurali depoda kayitli iki dersten cikar:
//   * "bitmis backend, baglanmamis UI" — `revokeSanction` sunucuda hazirdi ve
//     `lib/features/` icinde cagri yeri yoktu. O yuzden dikis testi dugmenin
//     VARLIGINI degil, sahte deponun KAYDINI olcer.
//   * `riverpod3-autodispose-test-trap` — dinleyicisiz `family` saglayici
//     sonsuza kadar `AsyncLoading` doner, dugme sessizce hicbir sey yapmaz.
//     "Dugme var" ile "dugme calisiyor" ayri iddialardir; ikisi de olculur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/detail/admin_user_profile_page.dart';
// `kAdminSanctionRevokeKey` buraya kisi dosyasinin **re-export**'undan gelir
// (`admin_person_dossier.dart` -> `admin_active_restriction_card.dart`).
// Anahtar ortak widget'a tasindi ama eski adresinden gorunmeye devam ediyor;
// bu satirin derlenmesi o sozlesmenin kendisidir.
import 'package:online_study_room/features/admin/sanctions/admin_person_dossier.dart';
import 'package:online_study_room/features/admin/sanctions/sanction_ladder.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const String _userId = '3f9b2c71-5a44-4c8e-9d10-77aa6b2e4f18';
const String _email = 'hedef@example.com';

/// Depo casusu: `super` gercek isi yapar, cagri kayda gecer.
class _SpyModeration extends InMemoryAdminModerationRepository {
  final List<String> revoked = [];

  @override
  Future<ModerationSanction> revokeSanction({
    required String sanctionId,
    required String reason,
  }) async {
    revoked.add('$sanctionId=$reason');
    return super.revokeSanction(sanctionId: sanctionId, reason: reason);
  }
}

/// Vakadan acilan yuzey: `openAdminUserProfile` tam olarak bunu iter.
Widget _profileHost(_SpyModeration repo) => ProviderScope(
  overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AdminUserProfilePage(userId: _userId, caseId: 'case-809'),
  ),
);

/// Eski yuzey: Kullanicilar sekmesinden acilan kisi dosyasi.
Widget _dossierHost(_SpyModeration repo) => ProviderScope(
  overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(
      body: AdminPersonDossier(targetUserId: _userId, targetEmail: _email),
    ),
  ),
);

/// 🔴 Bir widget tipi **hata kabugunda da** eslesir; once govdenin gercek
/// oldugunu dogrula. (`admin_sanction_surface_test.dart` ayni nobetciyi tutar.)
void _expectRealBody(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'agac hata kabugunda');
  expect(find.byType(ErrorWidget), findsNothing, reason: 'agac hata kabugunda');
}

/// Panel uzun; tembel liste her seyi cizsin diye pencere yukseltilir.
Future<void> _tallWindow(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

AppLocalizations _l10n(WidgetTester tester, Type host) =>
    AppLocalizations.of(tester.element(find.byType(host)));

/// Hedefte **aktif** bir kisit kurar — elle degil, gercek yaptirim yolundan.
Future<ModerationSanction> _seedActive(
  _SpyModeration repo, {
  ModerationAction action = ModerationAction.suspend7d,
}) {
  return repo.applySanction(
    ModerationSanctionRequest(
      targetUserId: _userId,
      action: action,
      reason: 'tekrarlayan hakaret',
      idempotencyKey: 'wp809-seed-$_userId',
    ),
  );
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

void main() {
  group('WP-809/1 — vakadan acilan profilde KALDIRMA yolu vardir', () {
    testWidgets('aktif kisitli kullanicida "Kisiti kaldir" GORUNUR', (
      tester,
    ) async {
      await _tallWindow(tester);
      final repo = _SpyModeration();
      await _seedActive(repo);

      await tester.pumpWidget(_profileHost(repo));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      // 🔴 Asil iddia: WP-809 oncesi bu satir KIRMIZI olurdu — vakadan acilan
      // ekranda kaldirma yolu HIC yoktu.
      expect(
        find.byKey(kAdminSanctionRevokeKey),
        findsOneWidget,
        reason:
            'vakadan acilan kisi ekraninda aktif kisiti kaldirma yolu yok; '
            'yasaklama tek dokunus, kurtarma baska sekmede',
      );

      final l10n = _l10n(tester, AdminUserProfilePage);
      expect(
        find.text(
          l10n.adminModerationSanctionActive(
            adminSanctionLabel(l10n, ModerationAction.suspend7d),
          ),
        ),
        findsOneWidget,
        reason: 'yururlukteki kisit ekranda adiyla yazmiyor',
      );
      expect(find.text(l10n.adminSanctionNoActiveRestriction), findsNothing);
    });

    testWidgets('aktif kisit YOKKEN dugme yok, "Aktif kisit yok" yazar', (
      tester,
    ) async {
      await _tallWindow(tester);
      final repo = _SpyModeration();

      await tester.pumpWidget(_profileHost(repo));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      expect(
        find.byKey(kAdminSanctionRevokeKey),
        findsNothing,
        reason: 'kaldiracak kisit yokken kaldirma dugmesi cikiyor (olu tus)',
      );
      expect(
        find.text(
          _l10n(tester, AdminUserProfilePage).adminSanctionNoActiveRestriction,
        ),
        findsOneWidget,
      );
    });
  });

  group('WP-809/2 — "aktif" sozlesmesi: pending ve suresi gecmis sayilmaz', () {
    testWidgets('pending yaptirim aktif SAYILMAZ', (tester) async {
      await _tallWindow(tester);
      final repo = _SpyModeration();
      // Sunucuda `pending` satir acildi, auth adiminin sonucu hic yazilmadi.
      // Bu satir kullaniciyi cezali BIRAKMAZ; kaldirilacak bir sey yoktur.
      repo.seedPendingSanction(
        targetUserId: _userId,
        action: ModerationAction.suspend30d,
        openedAt: DateTime.now(),
      );

      await tester.pumpWidget(_profileHost(repo));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      // Once satirin GERCEKTEN var oldugunu goster: bos liste de testi
      // gecerdi ve sozlesme olculmemis olurdu.
      final sanctions = await repo.fetchSanctions(_userId);
      expect(sanctions.single.state, ModerationSanctionState.pending);
      expect(sanctions.single.isActive(DateTime.now()), isFalse);

      expect(
        find.byKey(kAdminSanctionRevokeKey),
        findsNothing,
        reason: 'yarim kalmis (pending) yaptirim aktif kisit gibi cizildi',
      );
      expect(
        find.text(
          _l10n(tester, AdminUserProfilePage).adminSanctionNoActiveRestriction,
        ),
        findsOneWidget,
      );
    });

    testWidgets('suresi gecmis yaptirim aktif SAYILMAZ', (tester) async {
      await _tallWindow(tester);
      final repo = _SpyModeration();
      // 30 gun once uygulanmis 7 gunluk kisit: suresi 23 gun once doldu.
      repo.clock = () => DateTime.now().subtract(const Duration(days: 30));
      final expired = await _seedActive(repo);
      repo.clock = DateTime.now;

      expect(expired.expiresAt, isNotNull);
      expect(expired.state, ModerationSanctionState.applied);
      expect(
        expired.isActive(DateTime.now()),
        isFalse,
        reason: 'suresi dolan kisit hala yururlukte sayiliyor',
      );

      await tester.pumpWidget(_profileHost(repo));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      expect(
        find.byKey(kAdminSanctionRevokeKey),
        findsNothing,
        reason: 'suresi dolmus kisit icin kaldirma dugmesi cizildi',
      );
      expect(
        find.text(
          _l10n(tester, AdminUserProfilePage).adminSanctionNoActiveRestriction,
        ),
        findsOneWidget,
      );
    });
  });

  group('WP-809/3 — ortak widget ESKI yuzeyi bozmadi', () {
    testWidgets('kisi dosyasinda ayni anahtar hala bulunur', (tester) async {
      await _tallWindow(tester);
      final repo = _SpyModeration();
      await _seedActive(repo, action: ModerationAction.mute24h);

      await tester.pumpWidget(_dossierHost(repo));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      expect(
        find.byKey(kAdminSanctionRevokeKey),
        findsOneWidget,
        reason: 'ortak widgeta tasima kisi dosyasindaki yolu dusurdu',
      );
      final l10n = _l10n(tester, AdminPersonDossier);
      expect(
        find.text(
          l10n.adminModerationSanctionActive(
            adminSanctionLabel(l10n, ModerationAction.mute24h),
          ),
        ),
        findsOneWidget,
      );
      // Dosyanin kendi bloklari yerinde: gecmis ve yaptirim menusu.
      expect(find.byKey(kAdminSanctionHistoryKey), findsOneWidget);
      expect(find.byKey(kAdminSanctionApplyMenuKey), findsOneWidget);
    });
  });

  group('WP-809/4 — DIKIS: dugme gercekten revokeSanction cagirir', () {
    testWidgets('profilde "Kisiti kaldir" depoya iner ve kisit kalkar', (
      tester,
    ) async {
      await _tallWindow(tester);
      final repo = _SpyModeration();
      final sanction = await _seedActive(repo);

      await tester.pumpWidget(_profileHost(repo));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      await tester.tap(find.byKey(kAdminSanctionRevokeKey));
      await tester.pumpAndSettle();
      await _confirmReason(tester, 'yanlis vakada uygulandi');
      _expectRealBody(tester);

      // 🔴 Kaynakta `revokeSanction` gecmesi kanit degil: deponun kaydini oku.
      expect(
        repo.revoked,
        hasLength(1),
        reason:
            'dugme basildi ama depoya hicbir geri alma inmedi '
            '(Riverpod autodispose tuzagi bu depoda yasandi)',
      );
      expect(repo.revoked.single, '${sanction.id}=yanlis vakada uygulandi');

      final after = (await repo.fetchSanctions(_userId)).single;
      expect(after.state, ModerationSanctionState.revoked);
      expect(after.isActive(DateTime.now()), isFalse);

      // Ekran kendiliginden tazelenir: kart artik "aktif kisit yok" der.
      await tester.pumpAndSettle();
      expect(find.byKey(kAdminSanctionRevokeKey), findsNothing);
      expect(
        find.text(
          _l10n(tester, AdminUserProfilePage).adminSanctionNoActiveRestriction,
        ),
        findsOneWidget,
        reason: 'geri almadan sonra ekran bayat kaldi',
      );
    });
  });
}
