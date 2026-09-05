// WP-440 / WP-698 / **WP-768** — icerik sikayeti kartinin sozlesmesi.
//
// WP-768 sahip karari: *"her kartta sadece detayli incele butonu olsun."*
// Karttan kalkan durum menusu, `…` menusu (yaptirim/karantina/kopyala) ve kisi
// dosyasi kopru dugmesi vakanin **kendi sayfasina** tasindi
// (`features/admin/detail/admin_case_detail_page.dart`, `moderation_review_flow_test.dart`).
//
// Bu dosya iki seyi birden olcer: (1) kaldirilanlar gercekten kalkti mi,
// (2) kaldirilirken kartin tasima/erisilebilirlik kabulleri (yukseklik
// sicramamasi, 320 dp + 1.3 olcek, cozulemeyen kimlik) bozuldu mu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/features/admin/cards/admin_work_card.dart';
import 'package:online_study_room/features/admin/widgets/moderation_queue_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _reporterId = '11111111-1111-4111-8111-111111111111';
const _targetId = '22222222-2222-4222-8222-222222222222';
const _openKey = Key('queue-open');

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
  VoidCallback? onOpenDetail,
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
        openKey: _openKey,
        onOpenDetail: onOpenDetail ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('kart kimlikleri gosterir ve TEK dugmesi detayi acar', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(_host(_case(), onOpenDetail: () => opened++));

    expect(find.textContaining('Mehmet'), findsOneWidget);
    expect(find.textContaining('Ayşe'), findsOneWidget);

    expect(find.byKey(_openKey), findsOneWidget);
    expect(find.text('Detaylı incele'), findsOneWidget);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('gizli menuler karttan kalkti', (tester) async {
    await tester.pumpWidget(_host(_case()));

    expect(
      find.byKey(const Key('moderation-secondary-actions')),
      findsNothing,
      reason:
          'Sahip: "tus neyi ne oldugu belli degil". Yaptirim/karantina/kopyala '
          'artik vakanin kendi sayfasinda.',
    );
    expect(
      find.byType(PopupMenuButton<ModerationCaseStatus>),
      findsNothing,
      reason: 'Durum menusu karttan kalkti; durum detay sayfasinda degisir.',
    );
    // Kartin TEK dokunulabilir kontrolu vardir.
    expect(find.byType(PopupMenuButton<Object?>), findsNothing);
  });

  testWidgets('durum bilgisi kaybolmadi, yalniz okunur oldu', (tester) async {
    await tester.pumpWidget(_host(_case()));
    expect(find.byType(AdminWorkStatusLabel), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);

    await tester.pumpWidget(_host(_case(status: ModerationCaseStatus.resolved)));
    await tester.pumpAndSettle();
    expect(find.text('Çözüldü'), findsOneWidget);
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
    // Hedef cozulemese de kart acilabilir: sayfa NEDEN yaptirim
    // uygulanamadigini orada yazar (sessiz olu dokunus yok).
    expect(find.byKey(_openKey), findsOneWidget);
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
        reason: 'durum hapı kart yüksekliğini değiştiriyor: $heights',
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

  testWidgets('durum etiketi ekran okuyucuya okunur', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_case()));

    expect(
      find.bySemanticsLabel('Açık'),
      findsWidgets,
      reason: 'durum etiketinin erişilebilirlik metni yok',
    );
    handle.dispose();
  });
}
