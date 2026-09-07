// WP-813 — ad sifirlamanin "Geri al" dugmesi YALAN soyluyordu.
//
// Olculen kusur (zincir, hepsi kaynaktan dogrulandi):
//   1. `ModerationAction.nameReset.isRestrictive == false`
//      (`lib/data/models/moderation_sanction.dart`).
//   2. `adminSanctionNeedsHardConfirm` kisitlayici + suresiz ister; ad
//      sifirlama icin **false** (`lib/features/admin/sanctions/
//      sanction_ladder.dart:62-63`).
//   3. Sert teyit istemeyen basamak uygulaninca 10 sn "Geri al" seridi cikar
//      ve dugme `revokeSanction` cagirir
//      (`lib/features/admin/sanctions/admin_sanction_actions.dart:178-210`).
//   4. Sunucuda `moderation_revoke` dali satiri `revoked` yapiyor, sonra
//      YALNIZ auth ban'ini temizliyordu; ada hic dokunmuyordu. Yonetici BASARI
//      mesaji goruyor, kullanicinin adi yer tutucuda kaliyordu.
//
// 🔴 BU DOSYANIN OLCEMEDIGI SEY — bilerek ve acikca:
// "Geri al'a basilinca ad geri gelir" iddiasi burada OLCULEMEZ. Onarimi yapan
// kod Edge Function'da (`supabase/functions/admin-user-actions/index.ts`
// `moderation_revoke` dali) ve karari
// `supabase/functions/_shared/admin_sanction_policy.ts` →
// `shouldRestoreNameOnRevoke` veriyor. Dart tarafinda WP-813'un **sifir**
// satirlik degisikligi var: `SupabaseAdminModerationRepository.revokeSanction`
// (`lib/data/repositories/supabase/supabase_admin_moderation_repository.dart:
// 247-270`) yalnizca Edge Function'a POST atar, ne profil adini tutar ne de
// onarim kararini bilir. Burada "ad geri geldi" diyen bir sahte depo kurmak,
// testin KENDI taklidini olcmesi olurdu: sunucudaki onarim satiri tamamen
// silinse bile yesil kalirdi. Bu depoda tam olarak o hata (yesil ama hicbir
// sey kanitlamayan test) birden fazla kez yakalandi.
// Ad onarimi iddiasi bu yuzden Deno tarafinda olculur:
// `supabase/functions/_shared/admin_sanction_policy_wp625.test.ts` → "WP-813"
// bolumu.
//
// Burada olculen sey, sunucudaki onarimin **on kosulu**: istemci ad
// sifirlamayi geri alinabilir yola sokuyor ve "Geri al" gercekten sunucunun
// geri alma dalina iniyor mu? Bu kirilirsa onarim kodu ulasilamaz olur ve
// sunucu testi yesil kaldigi hâlde kullanici yine adsiz kalir.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/detail/admin_user_profile_page.dart';
import 'package:online_study_room/features/admin/sanctions/admin_sanction_actions.dart';
import 'package:online_study_room/features/admin/sanctions/admin_sanction_dialogs.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const String _targetId = '2f6b90c1-4a35-4d7e-8b21-90c3e5a7d418';

/// Depo casusu: `revokeSanction` cagrisi kaydedilir, `super` gercek isi yapar.
class _SpyModeration extends InMemoryAdminModerationRepository {
  final List<String> revoked = [];

  @override
  Future<ModerationSanction> revokeSanction({
    required String sanctionId,
    required String reason,
  }) async {
    revoked.add(sanctionId);
    return super.revokeSanction(sanctionId: sanctionId, reason: reason);
  }
}

Widget _host(_SpyModeration moderation) => ProviderScope(
  overrides: [adminModerationRepositoryProvider.overrideWithValue(moderation)],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AdminUserProfilePage(userId: _targetId),
  ),
);

/// Widget tipi **hata kabugunda da** eslesir; once govdenin gercek oldugunu
/// dogrula.
void _expectRealBody(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'agac hata kabugunda');
  expect(find.byType(ErrorWidget), findsNothing, reason: 'agac hata kabugunda');
}

/// Yaptirimi kullanicinin dokundugu yoldan uygular: dugme → basamak → gerekce.
Future<void> _applyFromUi(
  WidgetTester tester,
  ModerationAction action, {
  required String reason,
}) async {
  await tester.tap(find.byKey(kAdminUserSanctionApplyKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(adminSanctionLadderKey(action)));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(kAdminReasonFieldKey), reason);
  await tester.tap(find.byKey(kAdminReasonConfirmKey));
  await tester.pumpAndSettle();
}

void main() {
  group('WP-813 — ad sifirlama geri alinabilir yolda kalir', () {
    testWidgets('ad sifirlama sert teyit istemez, "Geri al" seridi cikar', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();

      await _applyFromUi(
        tester,
        ModerationAction.nameReset,
        reason: 'uygunsuz gorunen ad',
      );
      _expectRealBody(tester);

      // Sert teyit cikarsa serit HIC cikmaz (`admin_sanction_actions.dart:
      // 178-183`) ve sunucudaki onarim dali ulasilamaz olur.
      expect(
        find.byKey(kAdminHardConfirmKey),
        findsNothing,
        reason: 'ad sifirlama sert teyide kaydi; geri alma seridi olusmaz',
      );
      expect(
        find.byKey(kAdminSanctionUndoKey),
        findsOneWidget,
        reason: '10 sn "Geri al" seridi yok',
      );

      // Yaptirim gercekten depoya indi mi (serit "bosa" cikmiyor).
      final applied = await moderation.fetchSanctions(_targetId);
      expect(applied, hasLength(1));
      expect(applied.single.action, ModerationAction.nameReset);

      await tester.pumpAndSettle(const Duration(seconds: 12));
    });

    testWidgets('"Geri al" sunucunun geri alma dalina GERCEKTEN iner', (
      tester,
    ) async {
      final moderation = _SpyModeration();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();

      await _applyFromUi(
        tester,
        ModerationAction.nameReset,
        reason: 'uygunsuz gorunen ad',
      );
      final applied = (await moderation.fetchSanctions(_targetId)).single;

      await tester.tap(find.byKey(kAdminSanctionUndoKey));
      await tester.pumpAndSettle();
      _expectRealBody(tester);

      // 🔴 Onarim sunucuda `moderation_revoke` dalinda yasiyor. Istemci o dala
      // TAM O YAPTIRIMIN kimligiyle inmezse onarim hicbir zaman kosmaz.
      expect(
        moderation.revoked,
        [applied.id],
        reason: '"Geri al" basildi ama depoya geri alma inmedi',
      );
      expect(
        (await moderation.fetchSanctions(_targetId)).single.state,
        ModerationSanctionState.revoked,
      );

      await tester.pumpAndSettle(const Duration(seconds: 12));
    });

    testWidgets('ad sifirlama basamagi yaptirim menusunde SUNULUR', (
      tester,
    ) async {
      // Menude olmazsa yukaridaki iki iddia da hic kosamaz; "bulunamadi"
      // hatasi yerine anlasilir bir kirmizi dussun.
      final moderation = _SpyModeration();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(kAdminUserSanctionApplyKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(adminSanctionLadderKey(ModerationAction.nameReset)),
        findsOneWidget,
        reason: 'ad sifirlama hicbir yuzeyden uygulanamiyor',
      );
    });
  });

  /// Yapisal nobetci — davranis kaniti DEGIL, yon kaybini engelleyen kural.
  test('istemcide ayri bir "adi geri yukle" yolu YOKTUR', () {
    // 🔴 Onarim sunucuda kosar cunku yalnizca orada "su anki ad hâlâ yer
    // tutucu mu" sorusu yanitlanabilir. Istemci `restore_user_name` cagirsaydi
    // bu kosul atlanir ve kullanicinin bu arada kendi sectigi ad EZILIRDI
    // (lider karari: Tasarim A secilmedi). Bu nobetci o kaymayi yakalar.
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains("'restore_user_name'")) {
        hits.add(entity.path);
      }
    }
    expect(
      hits,
      isEmpty,
      reason: 'istemci adi kendi geri yukluyor; yer tutucu kosulu atlanir',
    );
  });
}
