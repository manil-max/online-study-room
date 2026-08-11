// WP-E (WP-691 FAZ 2) — hesap silme kuyrugu saglik paneli.
//
// ONCE KIRMIZI. Dort kabul olcutu gorev kartindan birebir alindi:
//
//   1. `get_account_purge_health` cagrilir ve durumu EKRANDA gorunur.
//   2. Kuyruk bozukken kart `colorScheme.error` rengine doner.
//   3. Panel "Kayit & Yayin" yuzeyinin EN SONUNDA durur (sahip karari).
//   4. Saglik iddiasi `configuration_status == "configured"` uzerinedir.
//
// 🔴 4. olcutun sebebi `supabase/migrations/0113_account_purge_scheduler.sql:295`
// ve `production-purge-activation.yml:15` yorumunda kayitli: yapilandirilmamis
// bir kuyruk SIFIR hata uretir ve "saglikli" gorunur. Ayni yanilgiyi UI'da
// tekrar etmemek icin buradaki iddia "hata sayisi sifir mi" degil,
// "yapilandirma yazili mi" sorusudur.
//
// 🔴 Olculen sey KULLANICININ GORDUGU seydir: ekrandaki metin ve `Text.style`
// icindeki GERCEK renk. Kaynakta RPC adinin gecmesi kanit degildir — o yuzden
// 1. olcut ayrica `SupabaseWireHarness` ile KABLOYA ne gittigini olcer.
//
// 🔴 Kabuk tuzagi: `find.byType(X)` bos/hatali bir govdeyle de eslesir. Her
// duzen iddiasinin yaninda GOVDENIN GERCEK oldugunu gosteren bir SAYI
// araniyor (2026-08-11'de bes ajan bu tuzaga dustu).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_admin_repository.dart';
import 'package:online_study_room/features/admin/health/account_purge_health_panel.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../support/supabase_wire_harness.dart';

/// Kablodan gelen satirin birebir sekli (`0113` `returns table (...)`).
Map<String, dynamic> _wireRow({
  String configurationStatus = 'configured',
  int dueCount = 0,
  int processingCount = 0,
  int staleLeaseCount = 0,
  int terminalFailedCount = 0,
  int oldestDueAgeSeconds = 0,
  int purgedLast30d = 0,
}) => {
  'configuration_status': configurationStatus,
  'due_count': dueCount,
  'processing_count': processingCount,
  'stale_lease_count': staleLeaseCount,
  'terminal_failed_count': terminalFailedCount,
  'oldest_due_age_seconds': oldestDueAgeSeconds,
  'purged_last_30d': purgedLast30d,
};

AccountPurgeHealth _health({
  String configurationStatus = 'configured',
  int dueCount = 0,
  int processingCount = 0,
  int staleLeaseCount = 0,
  int terminalFailedCount = 0,
  int oldestDueAgeSeconds = 0,
  int purgedLast30d = 0,
}) => AccountPurgeHealth.fromMap(
  _wireRow(
    configurationStatus: configurationStatus,
    dueCount: dueCount,
    processingCount: processingCount,
    staleLeaseCount: staleLeaseCount,
    terminalFailedCount: terminalFailedCount,
    oldestDueAgeSeconds: oldestDueAgeSeconds,
    purgedLast30d: purgedLast30d,
  ),
);

final _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
);

Future<InMemoryAdminRepository> _pumpPanel(
  WidgetTester tester, {
  required AccountPurgeHealth health,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = InMemoryAdminRepository(
    superAdminUserIds: const {'admin'},
    accountPurgeHealth: health,
  );
  addTearDown(repo.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: 'admin', displayName: 'Admin', createdAt: DateTime(2026)),
          ),
        ),
        adminRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        theme: _theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: AccountPurgeHealthPanel()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Ekranda GERCEKTEN cizilen durum rengi.
Color _statusColor(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(kAdminPurgeHealthStatusKey));
  final color = text.style?.color;
  expect(
    color,
    isNotNull,
    reason:
        'Durum satirinin rengi temadan turemis olmali; null ise kart hicbir '
        'sinyal tasimiyor demektir.',
  );
  return color!;
}

void main() {
  // ---------------------------------------------------------------------
  // KABUL 1 — RPC cagrilir ve durumu ekranda gorunur.
  // ---------------------------------------------------------------------
  group('WP-E kabul 1 — get_account_purge_health cagrilir ve gorunur', () {
    test('kabloya `get_account_purge_health` RPC adi gider', () async {
      final wire = SupabaseWireHarness();
      wire.respond('get_account_purge_health', [
        _wireRow(dueCount: 3, purgedLast30d: 9),
      ]);
      final repo = SupabaseAdminRepository(wire.client());

      final health = await repo.fetchAccountPurgeHealth();

      // Kablo: cagri gercekten gitti mi, adi dogru mu.
      expect(wire.rpc('get_account_purge_health').method, 'POST');
      // Govde: donen satir gercekten ayristirildi mi (bos kabuk degil).
      expect(health.dueCount, 3);
      expect(health.purgedLast30d, 9);
      expect(health.isConfigured, isTrue);
    });

    testWidgets('kuyruk sayilari EKRANDA gorunur', (tester) async {
      await _pumpPanel(
        tester,
        health: _health(dueCount: 7, processingCount: 2, purgedLast30d: 41),
      );

      expect(find.byKey(kAdminPurgeHealthPanelKey), findsOneWidget);
      // 🔴 Kabuk degil GOVDE: RPC'den gelen uc sayi da cizilmis olmali.
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('41'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // KABUL 2 — bozuk kuyruk `error` rengine doner.
  // ---------------------------------------------------------------------
  group('WP-E kabul 2 — bozuk kuyruk error rengi', () {
    testWidgets('kilitli kalan is varken durum error rengindedir', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        health: _health(dueCount: 4, staleLeaseCount: 1),
      );

      expect(find.text('1'), findsOneWidget);
      expect(_statusColor(tester), _theme.colorScheme.error);
    });

    testWidgets('kalici hata varken durum error rengindedir', (tester) async {
      await _pumpPanel(tester, health: _health(terminalFailedCount: 2));

      expect(_statusColor(tester), _theme.colorScheme.error);
    });

    testWidgets('saglikli kuyruk error rengine DUSMEZ', (tester) async {
      await _pumpPanel(tester, health: _health(dueCount: 1, purgedLast30d: 5));

      expect(find.text('5'), findsOneWidget);
      expect(_statusColor(tester), isNot(_theme.colorScheme.error));
    });

    testWidgets('saglik okunamazsa kart error rengine doner', (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = InMemoryAdminRepository(
        superAdminUserIds: const {'admin'},
        accountPurgeHealthError: const AdminException(
          'kuyruk okunamadi',
          code: 'rls_denied',
        ),
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                Profile(
                  id: 'admin',
                  displayName: 'Admin',
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            adminRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            theme: _theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: AccountPurgeHealthPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 🔴 Okunamayan saglik "saglikli" DEGILDIR; sessiz bos durum yasak.
      expect(_statusColor(tester), _theme.colorScheme.error);
    });
  });

  // ---------------------------------------------------------------------
  // KABUL 3 — panel "Kayit & Yayin" yuzeyinin EN SONUNDA durur.
  //
  // 🔴 BLOKE: kablolama `features/admin/shell/admin_shell.dart` icindedir ve
  // bu WP'nin SAHIP yollarina dahil DEGILDIR. Panel + saglayici + katalog
  // hazir; lider yolu acinca `skip` kaldirilir ve iddia oldugu gibi kosar.
  // Testi silmek yerine `skip` birakiliyor ki kabul olcutu kaybolmasin.
  // ---------------------------------------------------------------------
  group(
    'WP-E kabul 3 — Kayit & Yayin yuzeyinin sonunda',
    () {
      testWidgets('panel yuzeyin son bolumudur ve kuyrugun ustune cikmaz', (
        tester,
      ) async {
        fail('Kablolama SAHIP disi: features/admin/shell/**');
      });
    },
    skip:
        'BLOKE (WP-E): panelin yuzeye baglanmasi admin_shell.dart '
        'degisikligi ister; o dosya bu WP\'nin SAHIP yollarinda degil. '
        'Lider yol acinca skip kaldirilacak.',
  );

  // ---------------------------------------------------------------------
  // KABUL 4 — "yapilandirilmamis = saglikli" tuzagi.
  // ---------------------------------------------------------------------
  group('WP-E kabul 4 — yapilandirilmamis kuyruk saglikli DEGILDIR', () {
    test('sifir hatali ama yapilandirilmamis kuyruk saglikli sayilmaz', () {
      // 0113'un uyarisinin birebir hali: her sayac SIFIR.
      final health = _health(configurationStatus: 'not_configured');

      expect(health.dueCount, 0);
      expect(health.staleLeaseCount, 0);
      expect(health.terminalFailedCount, 0);
      // Sifir hata "saglikli" DEMEK DEGILDIR.
      expect(health.level, AccountPurgeHealthLevel.notConfigured);
      expect(health.level, isNot(AccountPurgeHealthLevel.healthy));
    });

    testWidgets('yapilandirilmamis kuyruk ekranda saglikli GORUNMEZ', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        health: _health(configurationStatus: 'not_configured'),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.adminPurgeDurumYapilandirilmamis), findsOneWidget);
      expect(find.text(l10n.adminPurgeDurumSaglikli), findsNothing);
      // Govde gercek: sayaclar da cizilmis olmali (bos kabuk degil).
      expect(find.text(l10n.adminPurgeBekleyen), findsOneWidget);
      // Sifir hataya ragmen error rengi.
      expect(_statusColor(tester), _theme.colorScheme.error);
    });

    testWidgets('yapilandirilmis ve temiz kuyruk saglikli GORUNUR', (
      tester,
    ) async {
      await _pumpPanel(tester, health: _health(purgedLast30d: 3));

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.adminPurgeDurumSaglikli), findsOneWidget);
      expect(find.text(l10n.adminPurgeDurumYapilandirilmamis), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });

    test('birikmis is esigi saatlik cron\'dan turer', () {
      // `0113`teki zamanlayici SAATLIK. Ucuncu turu da kaciran is birikmistir.
      expect(AccountPurgeHealth.backlogToleranceSeconds, 3 * 3600);

      final fresh = _health(dueCount: 2, oldestDueAgeSeconds: 3599);
      expect(fresh.level, AccountPurgeHealthLevel.healthy);

      final stuck = _health(
        dueCount: 2,
        oldestDueAgeSeconds: AccountPurgeHealth.backlogToleranceSeconds + 1,
      );
      expect(stuck.level, AccountPurgeHealthLevel.failing);
    });
  });
}
