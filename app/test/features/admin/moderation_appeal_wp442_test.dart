import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_appeal.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/repositories/moderation_repository.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_view.dart';
import 'package:online_study_room/features/safety/blocked_users_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-442: İtiraz, kanıt saklama ve denetim zinciri.
///
/// Kapatılan boşluklar:
/// * yaptırım gören kullanıcı kararın nedenini/süresini göremiyor ve itiraz
///   edemiyordu;
/// * itirazı, yaptırımı uygulayan yöneticinin kendisi karara bağlayabilirdi;
/// * kanıt süresiz duruyordu ve raporlayan kendi satırında sunucunun ürettiği
///   kanonik snapshot'ı okuyabiliyordu.
const String _targetId = '22222222-2222-4222-8222-222222222222';

ModerationSanction _sanction({
  ModerationSanctionState state = ModerationSanctionState.applied,
  String id = 'sanction-1',
}) {
  return ModerationSanction(
    id: id,
    targetUserId: _targetId,
    action: ModerationAction.mute24h,
    reason: 'tekrarlayan hakaret',
    state: state,
    appliedAt: DateTime(2026, 7, 30, 10),
    expiresAt: DateTime(2026, 7, 31, 10),
  );
}

ModerationAppeal _appeal({
  ModerationAppealStatus status = ModerationAppealStatus.open,
  bool decidable = true,
  String id = 'appeal-1',
}) {
  return ModerationAppeal(
    id: id,
    sanctionId: 'sanction-1',
    statement: 'mesajı ben yazmadım, hesabım paylaşımlıydı',
    status: status,
    createdAt: DateTime(2026, 7, 30, 11),
    sanctionAction: ModerationAction.mute24h,
    sanctionReason: 'tekrarlayan hakaret',
    decidable: decidable,
  );
}

Widget _adminHost(InMemoryAdminModerationRepository repo) {
  return ProviderScope(
    overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AdminQueueView()),
    ),
  );
}

Widget _userHost(InMemoryModerationRepository repo) {
  return ProviderScope(
    overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MyRestrictionsSection()),
    ),
  );
}

String _sqlOf(String path) => File(path).readAsStringSync();

void main() {
  group('itiraz sözleşmesi', () {
    test('bilinmeyen itiraz durumu sessizce kabul edilmez', () {
      expect(
        () => ModerationAppealStatus.fromWire('beklemede'),
        throwsArgumentError,
      );
    });

    test('kendi yaptırımının itirazı karara bağlanamaz', () {
      expect(_appeal(decidable: false).canBeDecidedNow, isFalse);
      expect(_appeal().canBeDecidedNow, isTrue);
      expect(
        _appeal(status: ModerationAppealStatus.upheld).canBeDecidedNow,
        isFalse,
      );
    });

    test('sunucu decidable alanını göndermezse eylem kapatılmaz', () {
      // RPC her zaman alanı döndürür; eksikse istemci kilitlenmemeli, sunucu
      // yine de reddeder.
      final decoded = ModerationAppeal.fromWire({
        'id': 'a1',
        'sanction_id': 's1',
        'statement': 'itiraz metni',
        'status': 'open',
        'created_at': '2026-07-30T10:00:00Z',
      });
      expect(decoded.decidable, isTrue);
      expect(decoded.status, ModerationAppealStatus.open);
    });
  });

  group('kullanıcı tarafı', () {
    test('kısa itiraz metni sunucuya hiç gitmez', () async {
      final repo = InMemoryModerationRepository()..sanctions.add(_sanction());
      await expectLater(
        repo.submitAppeal(sanctionId: 'sanction-1', statement: 'kısa'),
        throwsA(isA<ModerationException>()),
      );
      expect(repo.appeals, isEmpty);
    });

    test('aynı yaptırıma ikinci itiraz açılmaz', () async {
      final repo = InMemoryModerationRepository()..sanctions.add(_sanction());
      final first = await repo.submitAppeal(
        sanctionId: 'sanction-1',
        statement: 'mesajı ben yazmadım, hesabım paylaşımlıydı',
      );
      final second = await repo.submitAppeal(
        sanctionId: 'sanction-1',
        statement: 'ikinci kez yazıyorum',
      );
      expect(second.id, first.id);
      expect(repo.appeals, hasLength(1));
    });

    test('geri alınmış yaptırıma itiraz edilemez', () async {
      final repo = InMemoryModerationRepository()
        ..sanctions.add(_sanction(state: ModerationSanctionState.revoked));
      await expectLater(
        repo.submitAppeal(
          sanctionId: 'sanction-1',
          statement: 'zaten kaldırılmış ama itiraz ediyorum',
        ),
        throwsA(isA<ModerationException>()),
      );
    });

    testWidgets('kısıt nedeni, süresi ve itiraz yolu gösterilir', (
      tester,
    ) async {
      final repo = InMemoryModerationRepository()..sanctions.add(_sanction());
      await tester.pumpWidget(_userHost(repo));
      await tester.pumpAndSettle();

      expect(find.text('Hesabındaki kısıtlar'), findsOneWidget);
      expect(find.text('tekrarlayan hakaret'), findsOneWidget);
      expect(find.textContaining('tarihine kadar'), findsOneWidget);
      expect(find.byKey(const Key('appeal-action-sanction-1')), findsOneWidget);
    });

    testWidgets('itiraz gönderilince durum satırı değişir', (tester) async {
      final repo = InMemoryModerationRepository()..sanctions.add(_sanction());
      await tester.pumpWidget(_userHost(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('appeal-action-sanction-1')));
      await tester.pumpAndSettle();

      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('appeal-submit')),
      );
      expect(submit.onPressed, isNull, reason: 'boş itiraz gönderilemez');

      await tester.enterText(
        find.byKey(const Key('appeal-statement-field')),
        'mesajı ben yazmadım, hesabım paylaşımlıydı',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appeal-submit')));
      await tester.pumpAndSettle();

      expect(repo.appeals, hasLength(1));
      expect(find.text('İtiraz inceleniyor'), findsOneWidget);
      expect(find.byKey(const Key('appeal-action-sanction-1')), findsNothing);
    });

    testWidgets('kısıt yoksa boş durum gösterilir', (tester) async {
      await tester.pumpWidget(_userHost(InMemoryModerationRepository()));
      await tester.pumpAndSettle();
      expect(find.text('Hesabında kısıt yok.'), findsOneWidget);
    });
  });

  group('yönetici tarafı', () {
    test('kararı verilmiş itiraz yeniden yazılmaz', () async {
      final repo = InMemoryAdminModerationRepository()
        ..appeals.add(_appeal(status: ModerationAppealStatus.upheld));
      final again = await repo.decideAppeal(
        appeal: repo.appeals.single,
        overturn: true,
        note: 'fikrimi değiştirdim',
      );
      expect(again.status, ModerationAppealStatus.upheld);
      expect(repo.appealDecisions, isEmpty);
    });

    test('kabul edilen itiraz yaptırımı kaldırır', () async {
      final repo = InMemoryAdminModerationRepository();
      final sanction = await repo.applySanction(
        const ModerationSanctionRequest(
          targetUserId: _targetId,
          action: ModerationAction.mute24h,
          reason: 'tekrarlayan hakaret',
          idempotencyKey: 'sanction-key-0001',
        ),
      );
      repo.appeals.add(_appeal(id: 'appeal-1'));

      await repo.decideAppeal(
        appeal: repo.appeals.single,
        overturn: true,
        note: 'kanıt yetersiz',
      );

      final sanctions = await repo.fetchSanctions(_targetId);
      expect(sanctions.single.id, sanction.id);
      expect(sanctions.single.state, ModerationSanctionState.revoked);
      expect(sanctions.single.isActive(DateTime.now()), isFalse);
    });

    test('kendi yaptırımının itirazı karara bağlanamaz', () async {
      final repo = InMemoryAdminModerationRepository()
        ..appeals.add(_appeal(decidable: false));
      await expectLater(
        repo.decideAppeal(
          appeal: repo.appeals.single,
          overturn: true,
          note: 'kendi kararım',
        ),
        throwsA(isA<ModerationException>()),
      );
      expect(repo.appealDecisions, isEmpty);
    });

    test('gerekçesiz karar reddedilir', () async {
      final repo = InMemoryAdminModerationRepository()..appeals.add(_appeal());
      await expectLater(
        repo.decideAppeal(
          appeal: repo.appeals.single,
          overturn: false,
          note: '   ',
        ),
        throwsA(isA<ModerationException>()),
      );
    });

    testWidgets('açık itiraz kuyruğun başında gösterilir', (tester) async {
      final repo = InMemoryAdminModerationRepository()..appeals.add(_appeal());
      await tester.pumpWidget(_adminHost(repo));
      await tester.pumpAndSettle();

      // 🔴 WP-768: itiraz artik ayri bir kuyruk basligi degil, panelin TEK
      // kuyrugundaki bir satirdir; karar kendi sayfasinda verilir.
      expect(
        find.byKey(const Key('admin-queue-row-appeal:appeal-1')),
        findsOneWidget,
      );
      // Hem filtre cipi hem satirin durum etiketi "Itiraz" yazar.
      expect(find.text('İtiraz'), findsWidgets);
      await tester.tap(
        find.byKey(const Key('admin-queue-open-appeal:appeal-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('appeal-overturn-appeal-1')),
        findsOneWidget,
      );
    });

    testWidgets('kendi kararını denetleyemeyen admin eylem göremez', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository()
        ..appeals.add(_appeal(decidable: false));
      await tester.pumpWidget(_adminHost(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appeal-conflict-note')), findsOneWidget);
      expect(find.byKey(const Key('appeal-overturn-appeal-1')), findsNothing);
    });

    testWidgets('karar gerekçe ister ve kuyruğu tazeler', (tester) async {
      final repo = InMemoryAdminModerationRepository()..appeals.add(_appeal());
      await tester.pumpWidget(_adminHost(repo));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('admin-queue-open-appeal:appeal-1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('appeal-overturn-appeal-1')));
      await tester.pumpAndSettle();
      // Gerekçe boşken karar yazılmaz.
      await tester.tap(find.byKey(const Key('moderation-reason-confirm')));
      await tester.pumpAndSettle();
      expect(repo.appealDecisions, isEmpty);

      await tester.tap(find.byKey(const Key('appeal-overturn-appeal-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('moderation-reason-field')),
        'kanıt yetersiz',
      );
      await tester.tap(find.byKey(const Key('moderation-reason-confirm')));
      await tester.pumpAndSettle();

      expect(repo.appealDecisions.single, 'appeal-1=overturned');
      expect(find.text('İtiraz karara bağlandı'), findsOneWidget);
    });
  });

  group('migration sözleşmesi', () {
    String sql() => _sqlOf(
      '../supabase/migrations/0106_moderation_appeal_evidence_audit.sql',
    );

    test('denetim zinciri append-only', () {
      expect(sql(), contains('moderation_audit_events'));
      expect(sql(), contains('before update or delete on public.moderation_audit_events'));
      expect(sql(), contains('before truncate on public.moderation_audit_events'));
      expect(sql(), contains('moderation_audit_append_only'));
    });

    test('itiraz tekil ve çıkar çatışmasına kapalı', () {
      expect(sql(), contains('sanction_id uuid not null unique'));
      expect(sql(), contains('appeal_conflict_of_interest'));
      expect(sql(), contains('submit_moderation_appeal'));
    });

    test('kanıt gövdesi normal kullanıcıya kapalı', () {
      expect(sql(), contains('revoke select on public.ugc_reports from authenticated'));
      expect(sql(), contains('grant select ('));
      expect(
        sql().contains('canonical_snapshot, evidence_hash, content_snapshot\n) on public.ugc_reports to authenticated'),
        isFalse,
        reason: 'kanıt sütunları yeniden verilmemeli',
      );
    });

    test('saklama süresi dolan kanıt imha edilir, imza kalır', () {
      expect(sql(), contains('moderation_purge_expired_evidence'));
      expect(sql(), contains('evidence_redacted_at'));
      expect(sql(), contains('sha256(convert_to('));
    });
  });
}
