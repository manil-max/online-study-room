import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/repositories/supabase/report_attachment_upload.dart';
import 'package:online_study_room/features/safety/report_sheet.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-423: şikâyete tek foto eki. Ek **opsiyoneldir** ve public bucket'a
/// konmaz — sunucu kapıları `supabase/tests/025_report_attachments` altında.
void main() {
  test('ek public avatars bucket''ına değil ayrı bucket''a gider', () {
    expect(kReportAttachmentBucket, 'report_attachments');
    expect(kReportAttachmentBucket, isNot('avatars'));
    expect(kReportAttachmentExtensions, ['jpg', 'jpeg', 'png', 'webp']);
  });

  test('ek olmadan şikâyet gönderilebilir', () async {
    final repo = InMemoryModerationRepository();
    await repo.reportUgc(
      target: ReportTarget.profile(userId: 'u1'),
      reason: 'spam',
    );
    expect(repo.reports, hasLength(1));
    expect(repo.reports.single['attachment'], isNull);
  });

  test('ek verildiğinde repository katmanına taşınır', () async {
    final repo = InMemoryModerationRepository();
    await repo.reportUgc(
      target: ReportTarget.message(messageId: 'm1', groupId: 'g1'),
      reason: 'hate',
      attachmentBytes: Uint8List.fromList([1, 2, 3]),
      attachmentExt: 'png',
    );
    expect(repo.reports.single['attachment'], 'png');
  });

  testWidgets('şikâyet sayfasında ek düğmesi var ve ölü değil', (tester) async {
    final repo = InMemoryModerationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [moderationRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showReportSheet(
                    context,
                    ref,
                    target: ReportTarget.profile(userId: 'u1'),
                  ),
                  child: const Text('ac'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();

    // Ek düğmesi görünür ve etkin (ölü anahtar yasak).
    final attach = find.widgetWithIcon(OutlinedButton, Icons.attach_file);
    expect(attach, findsOneWidget);
    expect(tester.widget<OutlinedButton>(attach).onPressed, isNotNull);

    // Ek seçilmeden gönderim çalışır: şikâyet kaydedilir, eki null'dır.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(repo.reports, hasLength(1));
    expect(repo.reports.single['attachment'], isNull);
  });
}
