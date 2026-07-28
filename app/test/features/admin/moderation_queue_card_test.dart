import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/admin/models/moderation_queue_report.dart';
import 'package:online_study_room/features/admin/widgets/moderation_queue_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'kuyruk kartı adı gösterir, değişmez kimliği kopyalanabilir tutar',
    (tester) async {
      const reporterId = '11111111-1111-4111-8111-111111111111';
      const targetId = '22222222-2222-4222-8222-222222222222';
      const report = ModerationQueueReport(
        id: 'report-1',
        targetType: 'message',
        reason: 'hate',
        status: 'open',
        contentSnapshot: 'Tam bağlam sonraki WPde açılır.',
        reporter: ModerationQueueIdentity(id: reporterId, displayName: 'Ayşe'),
        target: ModerationQueueIdentity(id: targetId, displayName: 'Mehmet'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ModerationQueueCard(
              report: report,
              onStatusSelected: _ignore,
            ),
          ),
        ),
      );

      expect(find.text('Şikâyet eden: Ayşe'), findsOneWidget);
      expect(find.text('Şikâyet edilen: Mehmet'), findsOneWidget);
      expect(find.text(reporterId), findsOneWidget);
      expect(find.text(targetId), findsOneWidget);
      expect(find.byKey(const Key('ugc-copy-id-$reporterId')), findsOneWidget);
    },
  );

  testWidgets('çözülemeyen profil boş değil silinmiş kullanıcı olur', (
    tester,
  ) async {
    const report = ModerationQueueReport(
      id: 'report-2',
      targetType: 'profile',
      reason: 'spam',
      status: 'open',
      contentSnapshot: null,
      reporter: ModerationQueueIdentity(id: 'reporter', displayName: 'Ayşe'),
      target: ModerationQueueIdentity(
        id: 'missing-user',
        displayName: '',
        isDeleted: true,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ModerationQueueCard(report: report, onStatusSelected: _ignore),
        ),
      ),
    );

    expect(find.text('Şikâyet edilen: Silinmiş kullanıcı'), findsOneWidget);
  });
}

void _ignore(String _) {}
