import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/features/admin/widgets/moderation_queue_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _reporterId = '11111111-1111-4111-8111-111111111111';
const _targetId = '22222222-2222-4222-8222-222222222222';

ModerationCase _case({
  ModerationCaseStatus status = ModerationCaseStatus.open,
  String targetName = 'Mehmet',
  int reportCount = 1,
  ReportTargetType type = ReportTargetType.message,
}) {
  return ModerationCase(
    targetType: type,
    targetId: _targetId,
    targetIdentity: ModerationIdentity(id: _targetId, displayName: targetName),
    status: status,
    reportCount: reportCount,
    reasons: const ['hate'],
    latestAt: DateTime.now().subtract(const Duration(hours: 3)),
    reporters: const [ModerationIdentity(id: _reporterId, displayName: 'Ayşe')],
    reportIds: const ['report-1'],
  );
}

Widget _host(
  ModerationCase moderationCase, {
  ValueChanged<ModerationCaseStatus>? onStatusSelected,
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: child!,
    ),
    home: Scaffold(
      body: ModerationQueueCard(
        moderationCase: moderationCase,
        onStatusSelected: onStatusSelected ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('kart adı gösterir, değişmez kimlik üç noktadan kopyalanır', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_host(_case()));
    expect(find.textContaining('Mehmet'), findsOneWidget);
    expect(find.textContaining('Ayşe'), findsOneWidget);

    await tester.tap(find.byKey(const Key('moderation-secondary-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();

    expect(copied, [_targetId]);
  });

  testWidgets('çözülemeyen hedef boş değil silinmiş kullanıcı olur', (
    tester,
  ) async {
    final unresolved = ModerationCase(
      targetType: ReportTargetType.group,
      targetId: _targetId,
      targetIdentity: const ModerationIdentity.unresolved(_targetId),
      status: ModerationCaseStatus.open,
      reportCount: 1,
      reasons: const ['spam'],
      latestAt: DateTime.now(),
      reporters: const [],
      reportIds: const ['report-1'],
    );
    await tester.pumpWidget(_host(unresolved));
    // Hem hedef hem raporlayan satırı çözülemiyor: ikisi de boş kalmaz.
    expect(find.textContaining('Silinmiş kullanıcı'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('moderation-secondary-actions')));
    await tester.pumpAndSettle();
    final sanctionItem = find.widgetWithText(
      PopupMenuItem<int>,
      'Yaptırım uygula',
    );
    expect(sanctionItem, findsOneWidget);
    expect(tester.widget<PopupMenuItem<int>>(sanctionItem).enabled, isFalse);
    expect(find.textContaining('Kullanıcı bulunamadı'), findsOneWidget);
  });

  group('WP-440 kabul: yerleşim sıçramaz', () {
    testWidgets('kart yüksekliği dört durumda da aynı', (tester) async {
      final heights = <String, double>{};
      for (final status in ModerationCaseStatus.values) {
        await tester.pumpWidget(_host(_case(status: status)));
        await tester.pumpAndSettle();
        heights[status.wire] = tester
            .getSize(find.byType(ModerationQueueCard))
            .height;
      }
      expect(
        heights.values.toSet(),
        hasLength(1),
        reason: 'durum çipi kart yüksekliğini değiştiriyor: $heights',
      );
    });

    testWidgets('320 dp ve metin ölçeği 1.3te uzun ad taşmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          _case(
            targetName: 'Çok Uzun Bir Kullanıcı Adı Buraya Sığmaz Kesinlikle',
            reportCount: 12,
          ),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('600 dp genişlikte ve 1.3 ölçekte taşma yok', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(_case(status: ModerationCaseStatus.resolved), textScale: 1.3),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('WP-440 kabul: durum çipi', () {
    testWidgets('durum seçimi doğrudan çipten yapılır', (tester) async {
      final selected = <ModerationCaseStatus>[];
      await tester.pumpWidget(_host(_case(), onStatusSelected: selected.add));

      await tester.tap(find.byKey(const Key('moderation-status-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İnceleniyor').last);
      await tester.pumpAndSettle();

      expect(selected, [ModerationCaseStatus.inReview]);
    });

    testWidgets('kapatılan vaka çipten geri açılabilir', (tester) async {
      final selected = <ModerationCaseStatus>[];
      await tester.pumpWidget(
        _host(
          _case(status: ModerationCaseStatus.resolved),
          onStatusSelected: selected.add,
        ),
      );

      // Kapalı vakanın çipi hâlâ etkin: yanlışlıkla kapatma geri alınabilir.
      await tester.tap(find.byKey(const Key('moderation-status-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İnceleniyor').last);
      await tester.pumpAndSettle();

      expect(selected, [ModerationCaseStatus.inReview]);
    });

    testWidgets('menü dört durumu da sunar', (tester) async {
      await tester.pumpWidget(_host(_case()));
      await tester.tap(find.byKey(const Key('moderation-status-chip')));
      await tester.pumpAndSettle();

      // WP-441 (`0105`): `open` da yazılabilir; yanlışlıkla kapatılan vaka
      // gerçekten geri açılsın diye menüde durur.
      expect(
        find.widgetWithText(PopupMenuItem<ModerationCaseStatus>, 'Açık'),
        findsOneWidget,
      );
      expect(find.text('İnceleniyor'), findsOneWidget);
      expect(find.text('Çözüldü'), findsOneWidget);
      expect(find.text('Reddedildi'), findsOneWidget);
    });

    testWidgets('durum çipi ekran okuyucuya buton olarak duyurulur', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_case()));

      expect(
        find.bySemanticsLabel('Açık'),
        findsWidgets,
        reason: 'çipin erişilebilirlik etiketi yok',
      );
      handle.dispose();
    });
  });
}
