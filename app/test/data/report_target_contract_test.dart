import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_moderation_repository.dart';
import 'package:online_study_room/features/safety/report_sheet.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-439: Mesaj/profil/grup/grup-adı rapor hedef sözleşmesi.
///
/// Kabul kriteri: **rapor hedefi yanlış tür/ID ile başka içeriğe bağlanamaz.**
/// WP-439 öncesinde grubun kendisi ile grubun adı aynı `('group', group.id)`
/// çiftini gönderiyordu; `ugc_reports`'un
/// `unique (reporter_id, target_type, target_id, reason)` kısıtı ikisini tek
/// satıra çöktürüyordu. Aşağıdaki testler ayrımın kaybolmasını engeller.
void main() {
  group('hedef kimliği tür ile birlikte kanoniktir', () {
    test('grup ile grup adı aynı kimliği taşısa da ayrı vakadır', () {
      const groupId = 'g-42';
      final asGroup = ReportTarget.group(groupId: groupId);
      final asName = ReportTarget.groupName(groupId: groupId);

      expect(asGroup.id, asName.id);
      expect(asGroup.caseKey, isNot(asName.caseKey));
      expect(asGroup, isNot(asName));
      expect({asGroup, asName}, hasLength(2));
    });

    test('caseKey tür + kimlik biçimindedir', () {
      expect(ReportTarget.group(groupId: 'g1').caseKey, 'group:g1');
      expect(ReportTarget.groupName(groupId: 'g1').caseKey, 'group_name:g1');
      expect(ReportTarget.profile(userId: 'u1').caseKey, 'profile:u1');
      expect(
        ReportTarget.message(messageId: 'm1', groupId: 'g1').caseKey,
        'message:m1',
      );
    });

    test('aynı kimlik farklı türlerde asla eşleşmez', () {
      final profile = ReportTarget.profile(userId: 'x1');
      final asGroup = ReportTarget.group(groupId: 'x1');
      expect(profile.caseKey, isNot(asGroup.caseKey));
    });
  });

  group('hedef doğrulaması ağa çıkmadan yapılır', () {
    test('boş veya yalnız boşluk kimlik reddedilir', () {
      expect(() => ReportTarget.profile(userId: ''), throwsArgumentError);
      expect(() => ReportTarget.group(groupId: '   '), throwsArgumentError);
    });

    test('boşluk içeren veya aşırı uzun kimlik reddedilir', () {
      expect(() => ReportTarget.group(groupId: 'a b'), throwsArgumentError);
      expect(() => ReportTarget.profile(userId: 'u' * 65), throwsArgumentError);
    });

    test('kimlik kırpılır ama içeriği değişmez', () {
      expect(ReportTarget.profile(userId: '  u1  ').id, 'u1');
    });

    test('mesaj hedefi grup bağlamı olmadan kurulamaz', () {
      expect(
        () => ReportTarget.message(messageId: 'm1', groupId: ''),
        throwsArgumentError,
      );
    });

    test('mesaj kimliği grup kimliğiyle aynı olamaz', () {
      expect(
        () => ReportTarget.message(messageId: 'g1', groupId: 'g1'),
        throwsArgumentError,
      );
    });

    test('yalnız mesaj hedefi bağlam grubu taşır', () {
      expect(
        ReportTarget.message(messageId: 'm1', groupId: 'g1').contextGroupId,
        'g1',
      );
      expect(ReportTarget.group(groupId: 'g1').contextGroupId, isNull);
      expect(ReportTarget.profile(userId: 'u1').contextGroupId, isNull);
      expect(ReportTarget.groupName(groupId: 'g1').contextGroupId, isNull);
      expect(ReportTargetType.message.requiresContextGroup, isTrue);
      expect(ReportTargetType.group.requiresContextGroup, isFalse);
    });
  });

  group('wire sözleşmesi', () {
    test('tür metinleri sabittir', () {
      expect(ReportTargetType.message.wire, 'message');
      expect(ReportTargetType.profile.wire, 'profile');
      expect(ReportTargetType.group.wire, 'group');
      expect(ReportTargetType.groupName.wire, 'group_name');
    });

    test('tarihsel `user` türü profile olarak okunur', () {
      expect(ReportTargetType.fromWire('user'), ReportTargetType.profile);
      expect(ReportTargetType.fromWire('profile'), ReportTargetType.profile);
    });

    test('bilinmeyen tür reddedilir — sessizce başka türe düşmez', () {
      expect(() => ReportTargetType.fromWire('grup'), throwsArgumentError);
      expect(() => ReportTargetType.fromWire(''), throwsArgumentError);
    });

    test('toWire → fromWire tur atınca hedef korunur', () {
      final targets = [
        ReportTarget.message(messageId: 'm1', groupId: 'g1', hint: 'metin'),
        ReportTarget.profile(userId: 'u1', hint: 'Ada'),
        ReportTarget.group(groupId: 'g1'),
        ReportTarget.groupName(groupId: 'g1', hint: 'Kötü Ad'),
      ];
      for (final t in targets) {
        expect(ReportTarget.fromWire(t.toWire()), t, reason: t.caseKey);
      }
    });
  });

  group('istemci ipucu kanıt değildir', () {
    test('ipucu 200 karaktere kırpılır, boş ipucu null olur', () {
      final long = ReportTarget.profile(userId: 'u1', hint: 'x' * 500);
      expect(long.clientHint, hasLength(ReportTarget.maxHintLength));
      expect(
        ReportTarget.profile(userId: 'u1', hint: '   ').clientHint,
        isNull,
      );
      expect(ReportTarget.profile(userId: 'u1').clientHint, isNull);
    });

    test('ipucu hedef kimliğini değiştirmez ve eşitliğe girmez', () {
      final a = ReportTarget.group(groupId: 'g1', hint: 'A');
      final b = ReportTarget.group(groupId: 'g1', hint: 'B');
      expect(a, b);
      expect(a.id, 'g1');
    });
  });

  group('RPC parametre sözleşmesi (0104)', () {
    test('mesaj bağlamı server doğrulaması için gönderilir', () {
      final params = reportUgcRpcParams(
        target: ReportTarget.message(
          messageId: 'm1',
          groupId: 'g1',
          hint: 'metin',
        ),
        reason: 'spam',
        details: 'ayrıntı',
        attachmentPath: 'u1/a.png',
      );
      expect(params.keys.toSet(), kReportUgcRpcParams);
      expect(params['p_target_type'], 'message');
      expect(params['p_target_id'], 'm1');
      expect(params['p_snapshot'], 'metin');
      expect(params['p_context_group_id'], 'g1');
    });

    test('group_name 0104 ile sunucuda açıktır', () {
      expect(
        kReportTargetTypesLiveOnServer,
        contains(ReportTargetType.groupName),
      );
      expect(
        kReportTargetTypesLiveOnServer,
        containsAll([
          ReportTargetType.message,
          ReportTargetType.profile,
          ReportTargetType.group,
        ]),
      );
    });
  });

  group('repository katmanı hedefi bozmadan taşır', () {
    test('mesaj raporu grup bağlamını ve vaka anahtarını saklar', () async {
      final repo = InMemoryModerationRepository();
      await repo.reportUgc(
        target: ReportTarget.message(
          messageId: 'm1',
          groupId: 'g1',
          hint: 'kötü söz',
        ),
        reason: 'harassment',
      );
      final row = repo.reports.single;
      expect(row['type'], 'message');
      expect(row['id'], 'm1');
      expect(row['context_group_id'], 'g1');
      expect(row['case_key'], 'message:m1');
      expect(row['client_hint'], 'kötü söz');
    });

    test('grup ve grup adı raporu iki ayrı vaka açar', () async {
      final repo = InMemoryModerationRepository();
      await repo.reportUgc(
        target: ReportTarget.group(groupId: 'g1'),
        reason: 'spam',
      );
      await repo.reportUgc(
        target: ReportTarget.groupName(groupId: 'g1'),
        reason: 'spam',
      );
      expect(repo.caseKeys, {'group:g1', 'group_name:g1'});
    });
  });

  testWidgets('rapor sayfası hedefi olduğu gibi depoya geçirir', (
    tester,
  ) async {
    final repo = InMemoryModerationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showReportSheet(
                  context,
                  ref,
                  target: ReportTarget.message(
                    messageId: 'm7',
                    groupId: 'g9',
                    hint: 'sohbet metni',
                  ),
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final row = repo.reports.single;
    expect(row['case_key'], 'message:m7');
    expect(row['context_group_id'], 'g9');
    expect(row['client_hint'], 'sohbet metni');
  });
}
