import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-440: Kuyruğun kod borcu kapanışı.
///
/// Ekran artık Supabase istemcisiyle konuşmuyor ve vaka sözleşmesi
/// RPC'lerden geçiyor. WP-441 (`0105`) ile `open` da yazılabilir oldu:
/// yanlışlıkla kapatılan vaka `in_review`e sapmadan geri açılır.
ModerationCase _case({
  ModerationCaseStatus status = ModerationCaseStatus.open,
  String id = '22222222-2222-4222-8222-222222222222',
}) {
  return ModerationCase(
    targetType: ReportTargetType.message,
    targetId: id,
    targetIdentity: ModerationIdentity(id: id, displayName: 'Mehmet'),
    status: status,
    reportCount: 3,
    reasons: const ['hate'],
    latestAt: DateTime.now(),
    reporters: const [ModerationIdentity(id: 'r1', displayName: 'Ayşe')],
    reportIds: const ['report-1'],
  );
}

Widget _host(InMemoryAdminModerationRepository repo) {
  return ProviderScope(
    overrides: [
      adminModerationRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: AdminQueueView()),
    ),
  );
}

/// Kaynağı yorumsuz okur — sözleşme iddiaları koda bakmalı, açıklamaya değil.
String _codeOf(String path) {
  final lines = File(path)
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'));
  return lines.join('\n');
}

void main() {
  group('kod borcu: ekran doğrudan Supabase okumuyor', () {
    test('kuyruk ve vaka sayfası Supabase istemcisine referans vermiyor', () {
      // Yorum satırları elenmeli: WP-440 açıklaması kaldırılan çağrının adını
      // anlatıyor, kodun kendisi değil.
      //
      // WP-768: eski `tabs/admin_moderation_tab.dart` silindi; aynı borç
      // kapısı yerine geçen iki dosyada koşar.
      for (final path in const [
        'lib/features/admin/queue/admin_queue_view.dart',
        'lib/features/admin/detail/admin_case_detail_page.dart',
      ]) {
        final source = _codeOf(path);

        expect(
          source.contains('Supabase.instance'),
          isFalse,
          reason: '$path doğrudan Supabase istemcisi kullanıyor',
        );
        expect(
          source.contains("from('ugc_reports')"),
          isFalse,
          reason: '$path tabloyu doğrudan okuyor/yazıyor',
        );
        expect(source.contains('supabase_flutter'), isFalse, reason: path);
      }
    });

    test('durum yazımı RPC sözleşmesinden geçiyor', () {
      final source = _codeOf(
        'lib/data/repositories/supabase/supabase_admin_moderation_repository.dart',
      );

      expect(source, contains('admin_ugc_report_groups'));
      expect(source, contains('admin_set_ugc_report_group_status'));
      // Doğrudan tablo UPDATE'i (WP-424 kod borcu) kalkmalı.
      expect(source.contains(".update({"), isFalse);
    });
  });

  group('vaka sözleşmesi', () {
    test('WP-441: kapatılan vaka gerçekten yeniden açılır', () async {
      final repo = InMemoryAdminModerationRepository(
        seed: [_case(status: ModerationCaseStatus.resolved)],
      );
      await repo.setCaseStatus(
        moderationCase: _case(),
        status: ModerationCaseStatus.open,
      );
      expect(repo.statusWrites.single, endsWith('=open'));
      final queue = await repo.fetchQueue();
      expect(queue.single.status, ModerationCaseStatus.open);
    });

    test('0105 sonrası dört durum da yazılabilir', () {
      expect(ModerationCaseStatus.writableValues, [
        ModerationCaseStatus.open,
        ModerationCaseStatus.inReview,
        ModerationCaseStatus.resolved,
        ModerationCaseStatus.rejected,
      ]);
      expect(ModerationCaseStatus.open.writable, isTrue);
      expect(ModerationCaseStatus.resolved.isClosed, isTrue);
      expect(ModerationCaseStatus.rejected.isClosed, isTrue);
      expect(ModerationCaseStatus.inReview.isClosed, isFalse);
    });

    test('vaka anahtarı tür + kimliktir (grup ≠ grup adı)', () {
      final asGroup = ModerationCase(
        targetType: ReportTargetType.group,
        targetId: 'g1',
        targetIdentity: null,
        status: ModerationCaseStatus.open,
        reportCount: 1,
        reasons: const [],
        latestAt: DateTime.now(),
        reporters: const [],
        reportIds: const [],
      );
      expect(asGroup.caseKey, 'group:g1');
      expect(
        asGroup.copyWith(status: ModerationCaseStatus.inReview).caseKey,
        'group:g1',
      );
    });

    test('bilinmeyen durum metni sessizce kabul edilmez', () {
      expect(
        () => ModerationCaseStatus.fromWire('kapali'),
        throwsArgumentError,
      );
    });
  });

  group('ekran davranışı', () {
    // WP-768: durum hapı karttan kalktı. Vaka artık "Detaylı incele" ile kendi
    // sayfasında açılır ve durum orada, karar şeridinden yazılır.
    Finder open(String id) => find.byKey(Key('admin-queue-open-case:message:$id'));
    const targetId = '22222222-2222-4222-8222-222222222222';

    testWidgets('kuyruk boşsa boş durum gösterilir', (tester) async {
      final repo = InMemoryAdminModerationRepository();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen iş yok.'), findsOneWidget);
    });

    testWidgets('karar şeridinden seçilen durum vaka bazında yazılır', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(open(targetId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('moderation-decision-resolved')));
      await tester.pumpAndSettle();

      expect(repo.statusWrites, ['message:$targetId=resolved']);
    });

    testWidgets('yanlışlıkla kapatılan vaka kuyrukta kalır ve geri açılır', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(
        seed: [_case(status: ModerationCaseStatus.resolved)],
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      // 🔴 IDDIA YON DEGISTIRDI (WP-792, sahip cihazda): eskiden "kapatilan
      // vaka listeden dusmez, dibe iner" idi ve sahip tam bunu sikayet etti:
      // "resolved isaretliyorum ama gitmiyor". Kuyruk BEKLEYEN isin
      // listesidir; kapanan varsayilan gorunumden DUSER. Geri acma yolu
      // kaybolmaz: "Kapananlar" cipi altinda durur.
      expect(open(targetId), findsNothing);
      await tester.tap(find.byKey(kAdminQueueClosedFilterKey));
      await tester.pumpAndSettle();
      expect(open(targetId), findsOneWidget);

      await tester.tap(open(targetId));
      await tester.pumpAndSettle();
      // Geri açma yolu: karar verilir, sonra "Geri al".
      await tester.tap(find.byKey(const Key('moderation-decision-rejected')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('moderation-undo-button')));
      await tester.pumpAndSettle();

      expect(repo.statusWrites.last, endsWith('=resolved'));
      final queue = await repo.fetchQueue();
      expect(queue.single.status, ModerationCaseStatus.resolved);
    });

    /// 🔴 SAHIBIN SIKAYETI BIREBIR (WP-792): *"kartlarda resolved
    /// isaretliyorum ama gitmiyor."* Ayni akis: vakayi ac, Coz, geri don.
    /// Kart artik bekleyenlerde YOK, Kapananlar'da VAR. Bu test kullanicinin
    /// gordugu satiri olcer, saglayicinin dondugu listeyi degil.
    testWidgets('cozulen vaka kuyruktan GIDER, Kapananlar altinda durur', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(open(targetId), findsOneWidget);

      await tester.tap(open(targetId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('moderation-decision-resolved')));
      await tester.pumpAndSettle();
      // `pageBack` Cupertino dugmesi arar; sayfa Material `AppBar` tasir.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(
        open(targetId),
        findsNothing,
        reason: 'Cozulen vaka bekleyen isin arasinda duruyor -- sahibin '
            '"gitmiyor" dedigi sey tam bu.',
      );
      expect(find.text('Bekleyen iş yok.'), findsOneWidget);

      await tester.tap(find.byKey(kAdminQueueClosedFilterKey));
      await tester.pumpAndSettle();
      expect(open(targetId), findsOneWidget);
    });

    testWidgets('Kapananlar bosken kendi bos metnini yazar', (tester) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kAdminQueueClosedFilterKey));
      await tester.pumpAndSettle();
      // "Bekleyen is yok" yazsaydi yalan olurdu: bekleyen is VAR, gizli.
      expect(find.text('Kapanmış iş yok.'), findsOneWidget);
      expect(find.text('Bekleyen iş yok.'), findsNothing);
    });

    testWidgets('sunucu hatası kullanıcıya bildirilir, kuyruk çökmez', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()])
        ..failNextWrite = true;
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(open(targetId));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('moderation-decision-resolved')));
      await tester.pumpAndSettle();

      expect(find.text('Sunucuya ulaşılamadı.'), findsOneWidget);
      expect(repo.statusWrites, isEmpty);
    });
  });
}
