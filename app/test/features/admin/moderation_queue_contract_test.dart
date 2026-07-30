import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/tabs/admin_moderation_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-440: Kuyruğun kod borcu kapanışı.
///
/// Ekran artık Supabase istemcisiyle konuşmuyor, vaka sözleşmesi RPC'lerden
/// geçiyor ve `open` durumu yazılabilir görünmüyor.
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
      home: const Scaffold(body: AdminModerationTab()),
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
    test('admin_moderation_tab.dart Supabase istemcisine referans vermiyor', () {
      // Yorum satırları elenmeli: WP-440 açıklaması kaldırılan çağrının adını
      // anlatıyor, kodun kendisi değil.
      final source = _codeOf('lib/features/admin/tabs/admin_moderation_tab.dart');

      expect(
        source.contains('Supabase.instance'),
        isFalse,
        reason: 'ekran doğrudan Supabase istemcisi kullanıyor',
      );
      expect(
        source.contains("from('ugc_reports')"),
        isFalse,
        reason: 'ekran tabloyu doğrudan okuyor/yazıyor',
      );
      expect(source.contains('supabase_flutter'), isFalse);
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
    test('open sunucuya yazılamaz — çağrı fail-closed reddedilir', () async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await expectLater(
        repo.setCaseStatus(
          moderationCase: _case(),
          status: ModerationCaseStatus.open,
        ),
        throwsA(isA<ModerationException>()),
      );
      expect(repo.statusWrites, isEmpty);
    });

    test('yazılabilir durumlar yalnız üçü', () {
      expect(ModerationCaseStatus.writableValues, [
        ModerationCaseStatus.inReview,
        ModerationCaseStatus.resolved,
        ModerationCaseStatus.rejected,
      ]);
      expect(ModerationCaseStatus.open.writable, isFalse);
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
    testWidgets('kuyruk boşsa boş durum gösterilir', (tester) async {
      final repo = InMemoryAdminModerationRepository();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(find.text('UGC raporu yok'), findsOneWidget);
    });

    testWidgets('çipten seçilen durum vaka bazında sunucuya yazılır', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moderation-status-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çözüldü').last);
      await tester.pumpAndSettle();

      expect(repo.statusWrites, [
        'message:22222222-2222-4222-8222-222222222222=resolved',
      ]);
    });

    testWidgets('yanlışlıkla kapatılan vaka kuyrukta kalır ve geri açılır', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moderation-status-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çözüldü').last);
      await tester.pumpAndSettle();

      // Kapatılan vaka listeden düşmez; çipi hâlâ oradadır.
      expect(find.byKey(const Key('moderation-status-chip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('moderation-status-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İnceleniyor').last);
      await tester.pumpAndSettle();

      expect(repo.statusWrites.last, endsWith('=in_review'));
      final queue = await repo.fetchQueue();
      expect(queue.single.status, ModerationCaseStatus.inReview);
    });

    testWidgets('sunucu hatası kullanıcıya bildirilir, kuyruk çökmez', (
      tester,
    ) async {
      final repo = InMemoryAdminModerationRepository(seed: [_case()])
        ..failNextWrite = true;
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('moderation-status-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çözüldü').last);
      await tester.pumpAndSettle();

      expect(find.text('Sunucuya ulaşılamadı.'), findsOneWidget);
      expect(repo.statusWrites, isEmpty);
    });
  });
}
