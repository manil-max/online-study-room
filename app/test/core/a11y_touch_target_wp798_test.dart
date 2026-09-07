// WP-798 — **DOKUNMA HEDEFİ + SEMANTİK AKSİYON KAPISI**.
//
// Bu depoda erişilebilirlik hep yamayla ilerledi: WP-446 tek bir rapor
// düğmesini 48 dp'ye çıkardı, WP-554 iki yüzeye etiket ekledi, WP-703 sayacın
// taşmasını düzeltti. Üçü de tek tek doğruydu ve hiçbiri BİR SONRAKİNİ
// engellemedi. Kontrast tarafında aynı döngü WP-627'de kapıya bağlanınca
// bitti; burada yapılan da odur.
//
// Kapı iki şeyi ÖLÇER, iddiaya bakmaz:
//
//   1. **Dokunma hedefi** — etkileşimli öğenin kutusu `kMinInteractiveDimension`
//      (48 dp) altına düşemez. "Görsel küçük ama hedef büyüktür" savunması
//      ölçülür: kutuyu büyütmeyen `HitTestBehavior.opaque` bu kapıdan geçmez.
//   2. **Semantik aksiyon** — ekran okuyucunun "etkinleştir" jesti
//      (`SemanticsAction.tap`) GERÇEKTEN durumu değiştirmeli. `NumberStepper`
//      bunu 10 çağrı yerinde birden kaybetmişti: değeri yalnız
//      `Listener.onPointerDown` değiştiriyordu, `IconButton.onPressed` gövdesi
//      boştu. Semantik tap pointer olayı üretmediği için TalkBack kullanıcısı
//      uygulamadaki HİÇBİR sayıyı değiştiremiyordu — düğme var, ses var, etki
//      yok. Bu yüzden burada "Semantics widget'ı var" değil, **değerin
//      değiştiği** iddia edilir.
//
// 🔴 Eşiği düşürerek ya da bir ekranı listeden çıkararak geçirmek yasaktır.
// Yeni bir etkileşimli yüzey eklendiğinde buraya bir satır eklenir.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';
import 'package:online_study_room/core/widgets/number_stepper.dart';
import 'package:online_study_room/data/models/chat_message.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/desktop/compact_focus_view.dart';
import 'package:online_study_room/features/home/widgets/line_chart_card.dart';
import 'package:online_study_room/features/home/widgets/weekly_chart_card.dart';
import 'package:online_study_room/features/stats/widgets/stats_period_bar.dart';
import 'package:online_study_room/features/stats/widgets/study_heatmap.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Material'ın kendi eşiği (48 dp). Yerel sabit yazılmıyor: eşiği düşürmek
/// isteyen bir "düzeltme" burada tek satır değiştirip kapıyı sessizce
/// gevşetemesin diye kaynak framework sabiti.
const double _kTarget = kMinInteractiveDimension;

/// Yoğunluğu `compact` olan Material bileşeninin hedefi.
///
/// 🔴 Bu bir "istisna" değil, framework'ün KENDİ hesabı: `SegmentedButton`
/// `padded` hedefi `kMinInteractiveDimension + visualDensity.dy` olarak kurar
/// (`segmented_button.dart` → `tapTargetVerticalPadding`). Yani compact bir
/// segment düğmesinde Flutter'ın vaat ettiği hedef 40 dp'dir; sabit sayı
/// yazmıyoruz ki yoğunluk değişince eşik de kendiliğinden değişsin.
/// `tapTargetSize: shrinkWrap` ise bu dolguyu tamamen SIFIRLAR (ölçüm: 32 dp)
/// — bu kapının yakaladığı regresyon tam olarak odur.
final double _kCompactTarget =
    kMinInteractiveDimension + VisualDensity.compact.baseSizeAdjustment.dy;

/// Büyük metin ölçeği: sistem ayarında sık kullanılan %130.
const double _kBigText = 1.3;

Widget _app(Widget child, {double textScale = 1.0, Size? size}) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Center(
        child: size == null
            ? child
            : SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  ),
);

/// Bulunan HER öğeyi ölçer ve 48 dp'nin altını isimle raporlar.
///
/// Boş sonuç da hatadır: finder tutmuyorsa kapı yeşil yanan bir hiçliğe döner
/// (`ci-kapisi-yesil-sanilmaz-dogrulanir`).
void _expectTouchTarget(
  WidgetTester tester,
  Finder finder,
  String what, {
  int? expectedCount,
  double? threshold,
}) {
  final limit = threshold ?? _kTarget;
  final boxes = tester.renderObjectList<RenderBox>(finder).toList();
  expect(boxes, isNotEmpty, reason: '$what: ölçülecek öğe bulunamadı');
  if (expectedCount != null) {
    expect(
      boxes.length,
      expectedCount,
      reason: '$what: beklenen öğe sayısı değişti',
    );
  }
  for (var i = 0; i < boxes.length; i++) {
    final s = boxes[i].size;
    expect(
      s.shortestSide,
      greaterThanOrEqualTo(limit),
      reason:
          '$what [#$i] dokunma hedefi ${s.width.toStringAsFixed(1)}×'
          '${s.height.toStringAsFixed(1)} dp — eşik $limit dp',
    );
  }
}

/// Segment düğmesi: hem ölçü hem de o ölçüyü üreten AYAR sınanır.
///
/// Yalnız ölçüye bakmak yetmez — `shrinkWrap` geri gelirse hedef 32 dp'ye
/// düşer; yalnız ayara bakmak da yetmez, ayar doğru kalıp dolgu başka yerden
/// kırpılabilir.
void _expectSegmentedTarget(WidgetTester tester, String what) {
  final finder = find.byType(SegmentedButton<int>);
  _expectTouchTarget(
    tester,
    finder,
    what,
    expectedCount: 1,
    threshold: _kCompactTarget,
  );
  final style = tester.widget<SegmentedButton<int>>(finder).style;
  expect(
    style?.tapTargetSize,
    isNot(MaterialTapTargetSize.shrinkWrap),
    reason: '$what: shrinkWrap dokunma dolgusunu sıfırlar (32 dp)',
  );
}

/// [text]in verilen ölçekte kapladığı gerçek yükseklik.
double _neededHeight(TextStyle? style, String text, double textScale) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(textScale),
    maxLines: 1,
  )..layout();
  final h = painter.height;
  painter.dispose();
  return h;
}

// ---------------------------------------------------------------------------
// Harness'lar
// ---------------------------------------------------------------------------

final _owner = Profile(
  id: 'owner-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Komsu',
  createdAt: DateTime(2026, 1, 1),
);
final _group = StudyGroup(
  id: 'group-1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: _owner.id,
  createdAt: DateTime(2026, 1, 1),
);

/// Sohbet kartı: karşı taraftan gelmiş tek mesaj → avatar çizilir.
Widget _chatHarness() {
  final message = ChatMessage(
    id: 'msg-1',
    groupId: _group.id,
    userId: _peer.id,
    body: 'Merhaba',
    createdAt: DateTime.utc(2026, 1, 1, 9),
    authorDisplayName: _peer.displayName,
  );
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_owner)),
      classMessagesProvider(
        _group.id,
      ).overrideWith((ref) => Stream.value([message])),
      chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
      // Sohbet, engelli kullanıcı kümesi bilinmeden mesaj çizmez (fail-closed).
      moderationRepositoryProvider.overrideWithValue(
        InMemoryModerationRepository(),
      ),
    ],
    child: _app(ClassChatCard(group: _group)),
  );
}

/// Ev ekranı grafik kartları: boş oturum listesi yeterli (ölçülen segment
/// düğmesi, veri değil) ama `cardDataGate` yükleniyorken kartı hiç çizmez.
Widget _homeCardHarness(Widget card) => ProviderScope(
  overrides: [
    userSessionsProvider.overrideWith(
      (ref) => Stream.value(const <StudySession>[]),
    ),
    dailyGoalMinutesProvider.overrideWithValue(240),
  ],
  child: _app(card, size: const Size(420, 320)),
);

/// Gerçek `StudyTimerNotifier` kanal/zamanlayıcı ister; ölçülen yerleşim.
class _StaticStudyTimer extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

Widget _compactFocusHarness({double textScale = 1.0}) => ProviderScope(
  overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(_owner)),
    userSubjectsProvider.overrideWith((ref) => Stream.value(const <Subject>[])),
    studyTimerProvider.overrideWith(_StaticStudyTimer.new),
  ],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: CompactFocusView(
        onToggleCompact: () async {},
        onTogglePin: () async {},
      ),
    ),
  ),
);

/// Sayaç: değeri gerçekten tutan bir kabuk — iddia "değer değişti"dir.
Widget _stepperHarness({
  required String label,
  int start = 10,
  int min = 0,
  int max = 59,
  required void Function(int) onValue,
}) {
  var value = start;
  return _app(
    StatefulBuilder(
      builder: (context, setState) => SizedBox(
        width: 110,
        child: NumberStepper(
          label: label,
          value: value,
          min: min,
          max: max,
          onChanged: (v) {
            onValue(v);
            setState(() => value = v);
          },
        ),
      ),
    ),
  );
}

void main() {
  group('semantik aksiyon kapısı — NumberStepper', () {
    testWidgets('ekran okuyucu tap aksiyonu değeri GERÇEKTEN artırır', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var last = -1;
      await tester.pumpWidget(
        _stepperHarness(label: 'Dakika', onValue: (v) => last = v),
      );

      tester.semantics.performAction(
        find.semantics.byLabel('Dakika değerini 1 artır'),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(
        last,
        11,
        reason:
            'TalkBack "etkinleştir" jesti pointer olayı üretmez; değer '
            'değişmediyse sayaç ekran okuyucuyla çalışmıyor demektir',
      );
      expect(find.text('11'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('ekran okuyucu tap aksiyonu değeri GERÇEKTEN azaltır', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var last = -1;
      await tester.pumpWidget(
        _stepperHarness(label: 'Saat', onValue: (v) => last = v),
      );

      tester.semantics.performAction(
        find.semantics.byLabel('Saat değerini 1 azalt'),
        SemanticsAction.tap,
      );
      await tester.pump();

      expect(last, 9);
      expect(find.text('9'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('düğmelerin okunabilir adı var (ikon tek başına konuşmaz)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _stepperHarness(label: 'Hedef', onValue: (_) {}),
      );

      expect(find.semantics.byLabel('Hedef değerini 1 artır'), findsOne);
      expect(find.semantics.byLabel('Hedef değerini 1 azalt'), findsOne);
      handle.dispose();
    });

    testWidgets('sınıra dayanmış düğme semantikte de devre dışı', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _stepperHarness(label: 'Dakika', start: 59, onValue: (_) {}),
      );

      final node = find.semantics
          .byLabel('Dakika değerini 1 artır')
          .evaluate()
          .single;
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'max değerdeyken artırma aksiyonu duyurulmamalı',
      );
      expect(
        node.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(),
        isFalse,
      );
      handle.dispose();
    });
  });

  group('dokunma hedefi kapısı — 48 dp', () {
    testWidgets('NumberStepper +/- düğmeleri', (tester) async {
      await tester.pumpWidget(_stepperHarness(label: 'Saat', onValue: (_) {}));
      _expectTouchTarget(
        tester,
        find.descendant(
          of: find.byType(NumberStepper),
          matching: find.byType(IconButton),
        ),
        'NumberStepper +/-',
        expectedCount: 2,
      );
    });

    testWidgets('CrownedAvatar: kutunun köşesine dokunmak da profili açar', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          CrownedAvatar(
            displayName: 'Ada',
            radius: 14,
            onTap: () => taps++,
          ),
        ),
      );

      _expectTouchTarget(
        tester,
        find.byType(CrownedAvatar),
        'CrownedAvatar(radius: 14, onTap)',
        expectedCount: 1,
      );

      // Ölçü değil DAVRANIŞ: 28 dp avatarın dışında, 48 dp hedefin içinde
      // kalan bir nokta. `HitTestBehavior.opaque` kutuyu büyütmediği sürece
      // bu dokunuş boşa giderdi.
      final center = tester.getCenter(find.byType(CrownedAvatar));
      await tester.tapAt(center + const Offset(20, 20));
      await tester.pump();
      expect(taps, 1, reason: 'hedefin köşesi ölü alan olmamalı');
    });

    testWidgets('sohbette profili açan avatar', (tester) async {
      await tester.pumpWidget(_chatHarness());
      await tester.pumpAndSettle();

      _expectTouchTarget(
        tester,
        find
            .ancestor(
              of: find.byType(LiveCrownedAvatar),
              matching: find.byType(GestureDetector),
            )
            .first,
        'sohbet mesajı avatarı',
      );
    });

    testWidgets('istatistik dönem şeridi chip’leri', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: _StatsBarHost()));
      await tester.pumpAndSettle();

      _expectTouchTarget(
        tester,
        find.descendant(
          of: find.byType(StatsPeriodBar),
          matching: find.byType(InkWell),
        ),
        'dönem chip’i',
      );
    });

    testWidgets('ev ekranı eğilim kartı segment düğmesi', (tester) async {
      await tester.pumpWidget(_homeCardHarness(const LineChartCard()));
      await tester.pumpAndSettle();

      _expectSegmentedTarget(tester, 'eğilim kartı gün seçici');
    });

    testWidgets('ev ekranı haftalık kart segment düğmesi', (tester) async {
      await tester.pumpWidget(_homeCardHarness(const WeeklyChartCard()));
      await tester.pumpAndSettle();

      _expectSegmentedTarget(tester, 'haftalık kart gün seçici');
    });

    testWidgets('kompakt odak penceresi başlat/durdur düğmesi', (tester) async {
      await tester.pumpWidget(_compactFocusHarness());
      await tester.pumpAndSettle();

      _expectTouchTarget(
        tester,
        find.byKey(const ValueKey('compact-focus-toggle')),
        'kompakt odak düğmesi',
        expectedCount: 1,
      );
    });
  });

  group('metin ölçeği kapısı — %130', () {
    testWidgets('ısı haritası ay etiketi yuvası metni kırpmaz', (tester) async {
      await tester.pumpWidget(
        _app(
          StudyHeatmap(sessions: const [], weeks: 15),
          textScale: _kBigText,
          size: const Size(420, 260),
        ),
      );
      await tester.pumpAndSettle();

      final slots = find.byKey(const ValueKey('heatmapMonthSlot'));
      final labels = find.descendant(of: slots, matching: find.byType(Text));
      expect(
        labels,
        findsWidgets,
        reason: 'ay etiketi hiç çizilmiyorsa iddia boşa döner',
      );

      final label = tester.widget<Text>(labels.first);
      final needed = _neededHeight(label.style, label.data!, _kBigText);
      // Yuva TEK yükseklik: sütunlar birbirinden kaymasın diye ay yazan ve
      // yazmayan sütunlar aynı değeri kullanır.
      final heights = tester
          .renderObjectList<RenderBox>(slots)
          .map((b) => b.size.height)
          .toSet();
      expect(heights.length, 1, reason: 'sütunlar aynı yuva yüksekliğinde olmalı');
      expect(
        heights.single,
        greaterThanOrEqualTo(needed),
        reason:
            'ay etiketi %130 ölçekte ${needed.toStringAsFixed(1)} dp istiyor, '
            'yuva ${heights.single.toStringAsFixed(1)} dp — metin kırpılır',
      );
    });

    testWidgets('kompakt odak düğmesi %130 ölçekte taşmaz', (tester) async {
      await tester.pumpWidget(_compactFocusHarness(textScale: _kBigText));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      _expectTouchTarget(
        tester,
        find.byKey(const ValueKey('compact-focus-toggle')),
        'kompakt odak düğmesi (%130)',
        expectedCount: 1,
      );

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('compact-focus-toggle')),
          matching: find.byType(Text),
        ),
      );
      final needed = _neededHeight(
        Theme.of(
          tester.element(find.byType(CompactFocusView)),
        ).textTheme.labelLarge,
        label.data!,
        _kBigText,
      );
      final box = tester.getSize(
        find.byKey(const ValueKey('compact-focus-toggle')),
      );
      expect(
        box.height,
        greaterThanOrEqualTo(needed),
        reason:
            'düğme ${box.height.toStringAsFixed(1)} dp, etiket '
            '${needed.toStringAsFixed(1)} dp istiyor',
      );
    });
  });
}

/// Dönem şeridi: dinleyicisiz `statsPeriodProvider` Riverpod 3'te her `read`de
/// yeniden kurulur; şeridin kendisi dinlediği için kabuk yeterli.
class _StatsBarHost extends StatelessWidget {
  const _StatsBarHost();

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: StatsPeriodBar()),
  );
}
