import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/tabs/admin_moderation_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-441: Basamaklı yaptırım, karantina, önem/SLA.
///
/// Bu paketin kapattığı hatalar:
/// * `mute_24h` auth ban kuruyordu — susturulan kullanıcı uygulamayı hiç
///   açamıyordu;
/// * `warn_user` hiçbir şey yapmıyordu, uyarı kullanıcıya gitmiyordu;
/// * aynı yaptırım iki kez uygulanınca iki kayıt ve iki denetim satırı
///   düşüyordu.
const String _targetId = '22222222-2222-4222-8222-222222222222';

ModerationCase _case({
  ModerationCaseStatus status = ModerationCaseStatus.open,
  String? caseId = '33333333-3333-4333-8333-333333333333',
  ModerationSeverity severity = ModerationSeverity.high,
  DateTime? slaDueAt,
  bool quarantined = false,
}) {
  return ModerationCase(
    targetType: ReportTargetType.message,
    targetId: _targetId,
    targetIdentity: const ModerationIdentity(
      id: _targetId,
      displayName: 'Mehmet',
    ),
    status: status,
    reportCount: 3,
    reasons: const ['hate'],
    latestAt: DateTime.now(),
    reporters: const [ModerationIdentity(id: 'r1', displayName: 'Ayşe')],
    reportIds: const ['report-1'],
    caseId: caseId,
    severity: severity,
    slaDueAt: slaDueAt,
    quarantined: quarantined,
  );
}

ModerationSanctionRequest _request({
  ModerationAction action = ModerationAction.mute24h,
  String key = 'sanction-key-0001',
}) {
  return ModerationSanctionRequest(
    targetUserId: _targetId,
    action: action,
    reason: 'tekrarlayan hakaret',
    idempotencyKey: key,
  );
}

Widget _host(InMemoryAdminModerationRepository repo) {
  return ProviderScope(
    overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AdminModerationTab()),
    ),
  );
}

String _sqlOf(String path) => File(path).readAsStringSync();

void main() {
  group('yaptırım basamağı sözleşmesi', () {
    test('susturma auth ban değildir — okuma açık kalır', () {
      expect(ModerationAction.mute24h.isRestrictive, isTrue);
      expect(
        ModerationAction.mute24h.requiresAuthBan,
        isFalse,
        reason: 'susturulan kullanıcı uygulamayı okumaya devam etmeli',
      );
      expect(ModerationAction.mute24h.duration, const Duration(hours: 24));
    });

    test('uyarı ve aksiyon-yok kısıt değildir', () {
      expect(ModerationAction.warn.isRestrictive, isFalse);
      expect(ModerationAction.noAction.isRestrictive, isFalse);
      expect(ModerationAction.nameReset.isRestrictive, isFalse);
    });

    test('askı basamakları auth tarafına iner ve süreleri artar', () {
      expect(ModerationAction.suspend24h.requiresAuthBan, isTrue);
      expect(ModerationAction.suspend7d.duration, const Duration(days: 7));
      expect(ModerationAction.suspend14d.duration, const Duration(days: 14));
      expect(ModerationAction.suspend30d.duration, const Duration(days: 30));
      expect(
        ModerationAction.banPermanent.duration,
        isNull,
        reason: 'kalıcı yasak kendiliğinden açılmaz',
      );
    });

    test('bilinmeyen basamak sessizce kabul edilmez', () {
      expect(() => ModerationAction.fromWire('shadowban'), throwsArgumentError);
      expect(
        () => ModerationSanctionState.fromWire('yarim'),
        throwsArgumentError,
      );
    });

    test('bekleyen yaptırım aktif sayılmaz', () {
      final pending = ModerationSanction(
        id: 's1',
        targetUserId: _targetId,
        action: ModerationAction.suspend7d,
        reason: 'x',
        state: ModerationSanctionState.pending,
      );
      expect(
        pending.isActive(DateTime.now()),
        isFalse,
        reason: 'yarım kalan işlem kullanıcıyı cezalı bırakmamalı',
      );
    });

    test('gerekçesiz ve kısa anahtarlı istek geçersizdir', () {
      expect(
        const ModerationSanctionRequest(
          targetUserId: _targetId,
          action: ModerationAction.warn,
          reason: '   ',
          idempotencyKey: 'sanction-key-0001',
        ).isValid,
        isFalse,
      );
      expect(
        const ModerationSanctionRequest(
          targetUserId: _targetId,
          action: ModerationAction.warn,
          reason: 'sebep',
          idempotencyKey: 'kisa',
        ).isValid,
        isFalse,
      );
    });
  });

  group('depo davranışı', () {
    test('aynı anahtar ikinci yaptırım açmaz', () async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      final first = await repo.applySanction(_request());
      final second = await repo.applySanction(_request());

      expect(second.id, first.id);
      expect(await repo.fetchSanctions(_targetId), hasLength(1));
    });

    test('aktif kısıt varken ikinci kısıt reddedilir', () async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await repo.applySanction(_request());

      await expectLater(
        repo.applySanction(
          _request(action: ModerationAction.suspend7d, key: 'sanction-key-0002'),
        ),
        throwsA(isA<ModerationException>()),
      );
      expect(await repo.fetchSanctions(_targetId), hasLength(1));
    });

    test('uyarı aktif kısıtın üstüne yazılabilir', () async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await repo.applySanction(_request());
      await repo.applySanction(
        _request(action: ModerationAction.warn, key: 'sanction-key-0003'),
      );
      expect(await repo.fetchSanctions(_targetId), hasLength(2));
    });

    test('süresi dolan kısıt yeni yaptırımı engellemez', () async {
      var now = DateTime(2026, 7, 30, 10);
      final repo = InMemoryAdminModerationRepository(seed: [_case()])
        ..clock = () => now;
      await repo.applySanction(_request());

      now = now.add(const Duration(hours: 25));
      final second = await repo.applySanction(
        _request(action: ModerationAction.suspend7d, key: 'sanction-key-0004'),
      );
      expect(second.action, ModerationAction.suspend7d);
    });

    test('geri alınan yaptırım etkisini yitirir', () async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      final applied = await repo.applySanction(_request());
      final revoked = await repo.revokeSanction(
        sanctionId: applied.id,
        reason: 'yanlış uygulandı',
      );

      expect(revoked.state, ModerationSanctionState.revoked);
      expect(revoked.isActive(DateTime.now()), isFalse);
      // Geri alındıktan sonra yeni basamak uygulanabilir.
      await repo.applySanction(
        _request(action: ModerationAction.suspend24h, key: 'sanction-key-0005'),
      );
    });

    test('geri alma gerekçesizse reddedilir', () async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      final applied = await repo.applySanction(_request());
      await expectLater(
        repo.revokeSanction(sanctionId: applied.id, reason: '  '),
        throwsA(isA<ModerationException>()),
      );
    });

    test('vakaya bağlı olmayan tarihsel kayıt karantinaya alınamaz', () async {
      final legacy = _case(caseId: null);
      final repo = InMemoryAdminModerationRepository(seed: [legacy]);
      await expectLater(
        repo.setQuarantine(
          moderationCase: legacy,
          quarantined: true,
          reason: 'inceleme',
        ),
        throwsA(isA<ModerationException>()),
      );
      expect(repo.quarantineWrites, isEmpty);
    });

    test('karantina geri alınabilir', () async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await repo.setQuarantine(
        moderationCase: _case(),
        quarantined: true,
        reason: 'inceleme',
      );
      expect((await repo.fetchQueue()).single.quarantined, isTrue);

      await repo.setQuarantine(
        moderationCase: _case(),
        quarantined: false,
        reason: 'inceleme bitti',
      );
      expect((await repo.fetchQueue()).single.quarantined, isFalse);
      expect(repo.quarantineWrites, hasLength(2));
    });
  });

  group('vaka önemi ve SLA', () {
    test('SLA yalnız açık vakada aşılabilir', () {
      final now = DateTime(2026, 7, 30, 12);
      final overdue = _case(
        slaDueAt: now.subtract(const Duration(hours: 1)),
      );
      expect(overdue.isOverdue(now), isTrue);
      expect(
        overdue.copyWith(status: ModerationCaseStatus.resolved).isOverdue(now),
        isFalse,
      );
      expect(_case(slaDueAt: null).isOverdue(now), isFalse);
    });

    test('önem sunucudan okunur, istemci uydurmaz', () {
      expect(ModerationSeverity.fromWire('high'), ModerationSeverity.high);
      expect(ModerationSeverity.fromWire('normal'), ModerationSeverity.normal);
      expect(ModerationSeverity.fromWire(null), ModerationSeverity.normal);
      expect(ModerationSeverity.fromWire('kritik'), ModerationSeverity.normal);
    });
  });

  group('ekran davranışı', () {
    testWidgets('yüksek risk ve karantina rozetleri gösterilir', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(
        seed: [
          _case(
            quarantined: true,
            slaDueAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('moderation-case-badges')), findsOneWidget);
      expect(find.text('Yüksek risk'), findsOneWidget);
      expect(find.text('Süresi aştı'), findsOneWidget);
      expect(find.text('Karantinada'), findsOneWidget);
    });

    testWidgets('yaptırım sayfası gerekçesiz gönderilemez', (tester) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moderation-secondary-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yaptırım uygula').last);
      await tester.pumpAndSettle();

      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('moderation-sanction-submit')),
      );
      expect(submit.onPressed, isNull, reason: 'gerekçe boşken uygulanamaz');

      await tester.enterText(
        find.byKey(const Key('moderation-sanction-reason')),
        'tekrarlayan hakaret',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('moderation-sanction-submit')));
      await tester.pumpAndSettle();

      final sanctions = await repo.fetchSanctions(_targetId);
      expect(sanctions, hasLength(1));
      expect(sanctions.single.action, ModerationAction.warn);
      expect(find.text('Yaptırım uygulandı'), findsOneWidget);
    });

    testWidgets('karantina menüden açılır ve gerekçe ister', (tester) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moderation-secondary-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İçeriği karantinaya al').last);
      await tester.pumpAndSettle();

      // Gerekçe boş bırakılırsa hiçbir şey yazılmaz.
      await tester.tap(find.byKey(const Key('moderation-reason-confirm')));
      await tester.pumpAndSettle();
      expect(repo.quarantineWrites, isEmpty);

      await tester.tap(find.byKey(const Key('moderation-secondary-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İçeriği karantinaya al').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('moderation-reason-field')),
        'inceleme bitene kadar',
      );
      await tester.tap(find.byKey(const Key('moderation-reason-confirm')));
      await tester.pumpAndSettle();

      expect(repo.quarantineWrites.single, endsWith('=true'));
    });

    testWidgets('tarihsel kayıtta karantina seçeneği hiç gösterilmez', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(
        seed: [_case(caseId: null)],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moderation-secondary-actions')));
      await tester.pumpAndSettle();
      expect(find.text('İçeriği karantinaya al'), findsNothing);
      expect(find.text('Yaptırım uygula'), findsOneWidget);
    });
  });

  group('migration sözleşmesi', () {
    test('0105 susturmayı yazma politikasına bağlar, auth ban kurmaz', () {
      final sql = _sqlOf(
        '../supabase/migrations/0105_moderation_enforcement_ladder.sql',
      );
      expect(sql, contains('moderation_is_muted'));
      expect(sql, contains('create policy class_messages_insert'));
      expect(
        sql,
        contains('not public.moderation_is_muted(auth.uid())'),
        reason: 'susturma yazma politikasında uygulanmalı',
      );
    });

    test('0105 tek aktif kısıt ve idempotency anahtarını kurar', () {
      final sql = _sqlOf(
        '../supabase/migrations/0105_moderation_enforcement_ladder.sql',
      );
      expect(sql, contains('moderation_sanctions_one_active_idx'));
      expect(sql, contains('idempotency_key text not null unique'));
      expect(sql, contains('admin_begin_moderation_sanction'));
      expect(sql, contains('admin_finish_moderation_sanction'));
      expect(sql, contains('admin_reconcile_moderation_sanctions'));
    });

    test('0105 vakayı yeniden açmayı RPC allow-listine ekler', () {
      final sql = _sqlOf(
        '../supabase/migrations/0105_moderation_enforcement_ladder.sql',
      );
      expect(
        sql,
        contains("p_status not in ('open', 'in_review', 'resolved', 'rejected')"),
      );
    });

    test('edge function yaptırımı iki fazlı çağırır', () {
      final source = _sqlOf(
        '../supabase/functions/admin-user-actions/index.ts',
      );
      expect(source, contains('admin_begin_moderation_sanction'));
      expect(source, contains('admin_finish_moderation_sanction'));
      expect(
        source.contains('mute_24h: ') && source.contains('ban_duration'),
        isFalse,
        reason: 'susturma artık auth ban listesinde olmamalı',
      );
    });
  });
}
