import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/tabs/admin_users_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-625 — "Askıya Al" düğmesi ve admin fonksiyonlarının deploy boşluğu.
///
/// Denetim (`docs/denetim/DENETIM-sunucu-admin.md`) üç şey söyledi ve üçü de
/// koddan doğrulandı:
///
/// * **K2** — Kullanıcılar sekmesindeki tek düğme ≈100 yıllık, süresi
///   sorulmayan bir ban kuruyordu ve `moderation_sanctions`'a hiçbir satır
///   yazmıyordu: askı Moderasyon sekmesinde görünmüyor, geri alınamıyor,
///   kendiliğinden dolmuyordu.
/// * **R1** — bir uyarıyı geri almak, ilgisiz kalıcı yasağı da kaldırıyordu.
/// * **R4** — `admin-user-actions` ve `admin-operations` hiçbir iş akışında
///   deploy edilmiyordu; uygulama ikisini de çağırıyor.
///
/// Sunucu tarafının saf kararları `supabase/functions/_shared/
/// admin_sanction_policy_wp625.test.ts` içinde ölçülüyor (deno). Buradaki
/// kapılar Dart'tan ölçülebilen iki şeyi tutuyor: **arayüz hangi yolu
/// çağırıyor** ve **repodaki iki uç birbirinden haberdar mı**.
const String _targetId = '44444444-4444-4444-8444-444444444444';

Widget _host(InMemoryAdminModerationRepository moderation, {bool suspended = false}) {
  return ProviderScope(
    overrides: [
      adminModerationRepositoryProvider.overrideWithValue(moderation),
      adminUsersProvider.overrideWith(
        (ref) async => [
          AdminUserDto(
            id: _targetId,
            email: 'hedef@example.com',
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

Future<void> _chooseLadderStep(WidgetTester tester, ModerationAction action) async {
  await tester.tap(find.byKey(const Key('admin-user-suspend-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('admin-suspend-${action.wire}')));
  await tester.pumpAndSettle();
}

Future<void> _confirmReason(WidgetTester tester, String reason) async {
  if (reason.isNotEmpty) {
    await tester.enterText(
      find.byKey(const Key('admin-user-reason-field')),
      reason,
    );
  }
  await tester.tap(find.byKey(const Key('admin-user-reason-confirm')));
  await tester.pumpAndSettle();
}

String _read(String path) => File(path).readAsStringSync();

/// Bir iş akışındaki `supabase functions deploy <ad>` çağrılarının adları.
List<String> _deployedFunctions(String workflow) => RegExp(
  r'supabase functions deploy ([a-z0-9-]+)',
).allMatches(workflow).map((match) => match.group(1)!).toList();

void main() {
  group('WP-625/1 — askı süreli ve KAYITLI uygulanır', () {
    testWidgets('süre basamağı sorulur; seçim yaptırım kaydı yazar', (
      tester,
    ) async {
      final moderation = InMemoryAdminModerationRepository();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin-user-suspend-menu')));
      await tester.pumpAndSettle();
      // Beş basamağın hepsi seçilebilir olmalı: süresiz tek düğme yok.
      for (final action in kAdminSuspensionLadder) {
        expect(
          find.byKey(Key('admin-suspend-${action.wire}')),
          findsOneWidget,
          reason: '${action.wire} basamağı arayüzde yok',
        );
      }

      await tester.tap(
        find.byKey(Key('admin-suspend-${ModerationAction.suspend7d.wire}')),
      );
      await tester.pumpAndSettle();
      await _confirmReason(tester, 'tekrarlayan hakaret');

      final sanctions = await moderation.fetchSanctions(_targetId);
      expect(
        sanctions,
        hasLength(1),
        reason: 'askı Moderasyon sekmesinde görünmeli, kayıtsız kalmamalı',
      );
      expect(sanctions.single.action, ModerationAction.suspend7d);
      expect(sanctions.single.reason, 'tekrarlayan hakaret');
      expect(
        sanctions.single.expiresAt,
        isNotNull,
        reason: 'askı kendiliğinden dolmalı; eski dal ≈100 yıl yazıyordu',
      );
      expect(
        sanctions.single.expiresAt!.difference(sanctions.single.appliedAt!),
        const Duration(days: 7),
      );
    });

    testWidgets('kalıcı yasak hâlâ kalıcıdır', (tester) async {
      final moderation = InMemoryAdminModerationRepository();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();

      await _chooseLadderStep(tester, ModerationAction.banPermanent);
      await _confirmReason(tester, 'ağır ihlal');
      // 🔴 WP-C (PLAN §4.4/1, sahip kararı S3): kalıcı yasak artık hedefin
      // e-postası **yazılmadan** uygulanmaz. Bu satırdan önce iddia bayattı —
      // geri alınamayan tek yaptırım tek dokunuşla iniyordu.
      await tester.enterText(
        find.byKey(const Key('admin-sanction-hard-email')),
        'hedef@example.com',
      );
      await tester.tap(find.byKey(const Key('admin-sanction-hard-submit')));
      await tester.pumpAndSettle();

      final sanction = (await moderation.fetchSanctions(_targetId)).single;
      expect(sanction.action, ModerationAction.banPermanent);
      expect(
        sanction.expiresAt,
        isNull,
        reason: 'kalıcı yasak kendiliğinden açılmamalı',
      );
      expect(sanction.isActive(DateTime.now()), isTrue);
    });

    testWidgets('gerekçesiz askı hiç uygulanmaz', (tester) async {
      final moderation = InMemoryAdminModerationRepository();
      await tester.pumpWidget(_host(moderation));
      await tester.pumpAndSettle();

      await _chooseLadderStep(tester, ModerationAction.suspend24h);
      await _confirmReason(tester, '');

      expect(await moderation.fetchSanctions(_targetId), isEmpty);
    });

    test('askı basamaklarının hepsi auth tarafına iner ve süreleri artar', () {
      expect(kAdminSuspensionLadder, hasLength(5));
      for (final action in kAdminSuspensionLadder) {
        expect(action.requiresAuthBan, isTrue, reason: action.wire);
      }
      expect(
        kAdminSuspensionLadder.map((a) => a.duration).toList(),
        [
          const Duration(hours: 24),
          const Duration(days: 7),
          const Duration(days: 14),
          const Duration(days: 30),
          null,
        ],
      );
    });
  });

  group('WP-625/2 — sunucu dalı basamağa bağlı', () {
    final source = _read('../supabase/functions/admin-user-actions/index.ts');
    final policy = _read('../supabase/functions/_shared/admin_sanction_policy.ts');

    test('yüzyıllık ban süresi admin fonksiyonunda gömülü değil', () {
      // Tek kanonik yer `_shared`; fonksiyon gövdesine geri yazılırsa kırmızı.
      expect(
        source.contains('876000h'),
        isFalse,
        reason: 'ban süresi yalnız _shared/admin_sanction_policy.ts içinde durmalı',
      );
      expect(policy, contains("PERMANENT_BAN_DURATION = '876000h'"));
    });

    test('eski suspend dalları silinmiş, takma ad tablosuna bağlanmış', () {
      expect(source.contains("case 'suspend_user'"), isFalse);
      expect(source.contains("case 'suspend_permanent'"), isFalse);
      expect(source.contains("case 'warn_user'"), isFalse);
      expect(source, contains('legacyLadderActionFor'));
      expect(policy, contains("suspend_user: 'suspend_24h'"));
      expect(policy, contains("suspend_permanent: 'ban_permanent'"));
    });

    test('geri alma auth ban kararını politikadan sorar', () {
      expect(source, contains('shouldClearAuthBanOnRevoke'));
      // Askıyı kaldırmak yaptırım kaydını da geri almalı; yoksa hedefte
      // `applied` satır kalır ve bir daha yaptırım uygulanamaz.
      expect(source, contains('admin_revoke_moderation_sanction'));
      expect(source, contains('requiresAuthBan'));
    });
  });

  group('WP-625/3 — deploy listesi ile dosyalar birbirinden habersiz değil', () {
    final functionsDir = Directory('../supabase/functions');
    final workflowsDir = Directory('../.github/workflows');

    /// Diskteki Edge Function dizinleri (`_shared` bir fonksiyon değil).
    List<String> onDisk() => [
      for (final entity in functionsDir.listSync().whereType<Directory>())
        entity.path.split(RegExp(r'[\\/]')).last,
    ]..removeWhere((name) => name.startsWith('_'));

    Map<String, String> workflows() => {
      for (final file in workflowsDir.listSync().whereType<File>())
        if (file.path.endsWith('.yml'))
          file.path.split(RegExp(r'[\\/]')).last: file.readAsStringSync(),
    };

    /// 🔴 Henüz hiçbir iş akışında deploy EDİLMEYENLER (WP-626'nın işi).
    /// Liste yalnız "eksik olmasına izin verilir" der; WP-626 bunları deploy
    /// listesine eklediğinde bu kapı yine yeşil kalır.
    const allowedMissing = {'collect-reports', 'send-report'};

    test('admin fonksiyonları iki ortamın da deploy listesinde', () {
      for (final name in const [
        'production-purge-activation.yml',
        'staging-purge-activation.yml',
      ]) {
        final deployed = _deployedFunctions(workflows()[name]!);
        expect(
          deployed,
          containsAll(<String>['admin-user-actions', 'admin-operations']),
          reason: '$name admin panelinin sunucu tarafını deploy etmiyor',
        );
      }
    });

    test('deploy edilen her ad diskte gerçekten var', () {
      final names = onDisk();
      for (final entry in workflows().entries) {
        for (final deployed in _deployedFunctions(entry.value)) {
          expect(
            names,
            contains(deployed),
            reason: '${entry.key} olmayan bir fonksiyonu deploy ediyor: $deployed',
          );
        }
      }
    });

    test('deploy edilmeyen fonksiyon sessizce eklenemez', () {
      final deployed = <String>{
        for (final source in workflows().values) ..._deployedFunctions(source),
      };
      for (final name in onDisk()) {
        expect(
          deployed.contains(name) || allowedMissing.contains(name),
          isTrue,
          reason:
              '$name hiçbir iş akışında deploy edilmiyor; canlıdaki sürümün '
              'repodaki kod olduğunun kanıtı yok',
        );
      }
    });

    test('admin fonksiyonlarında JWT doğrulaması kapatılmamış', () {
      for (final source in workflows().values) {
        final segments = source.split('supabase functions deploy ');
        for (final segment in segments.skip(1)) {
          final name = RegExp(r'^[a-z0-9-]+').firstMatch(segment)?.group(0);
          if (name == null || !name.startsWith('admin-')) continue;
          // Bir sonraki deploy çağrısına kadar olan bayraklar bu çağrının.
          final flags = segment.split('\n\n').first;
          expect(
            flags.contains('--no-verify-jwt'),
            isFalse,
            reason: '$name JWT doğrulaması kapalı deploy ediliyor',
          );
        }
      }
    });
  });
}
