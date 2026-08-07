// WP-490 önkoşulu: sayaç uçuş kaydı okunabilir olmalı.
//
// 🔴 Ölçülen boşluk: `TimerDiagnosticJournal` WP-430'da yazıldı, her sayaç
// geçişini kaydediyor ve `exportEntries()` metodu bile var — ama `app/lib`
// içinde **hiçbir çağıran yoktu**; tek çağıran kendi birim testiydi
// (`grep -rn exportEntries app/ --include=*.dart`). Yani kart "günlüğü oku"
// diyordu ve okumanın yolu yoktu.
//
// Bu dosya kabloyu ölçer: ayarlarda giriş var, ekran kayıtları çiziyor ve
// `reason → outcome` (teşhisin cevabını taşıyan iki alan) görünüyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/observability/timer_diagnostic_journal.dart';
import 'package:online_study_room/features/profile/timer_journal_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ⚠️ Slug'lar sabitlerden alınıyor, elle yazılmıyor: journal allowlist dışında
// kalan bir `event`/`reason`/`outcome` gördüğünde kaydı **sessizce düşürür**.
// İlk taslak düz string kullandı ve testler "kayıt yok" diye kırıldı — aynı
// tuzak üretimde de yeni bir olay türü eklendiğinde sessiz veri kaybı olur.
typedef _Seed = ({String event, String reason, String outcome, DateTime at});

Future<ProviderContainer> _containerWith(List<_Seed> seed) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final journal = TimerDiagnosticJournal(prefs);
  for (final s in seed) {
    await journal.record(
      event: s.event,
      reason: s.reason,
      outcome: s.outcome,
      at: s.at,
    );
  }
  return ProviderContainer(
    overrides: [timerDiagnosticJournalProvider.overrideWithValue(journal)],
  );
}

_Seed _entry({
  required String event,
  required String reason,
  required String outcome,
  required DateTime at,
}) => (event: event, reason: reason, outcome: outcome, at: at);

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TimerJournalScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kayıt varsa reason → outcome görünür', (tester) async {
    // 🔴 WP-490'ın 2. adımı tam olarak bu satırı arıyor: ayna Durdur isteği
    // uygulandı mı, bayat mı sayıldı, ertelendi mi?
    final container = await _containerWith([
      _entry(
        event: TimerJournalEvents.mirrorStopRequested,
        reason: TimerJournalReasons.userAction,
        outcome: TimerJournalOutcomes.stale,
        at: DateTime.now().toUtc(),
      ),
    ]);
    await _pump(tester, container);

    expect(find.text(TimerJournalEvents.mirrorStopRequested), findsOneWidget);
    expect(find.text('user_action → stale'), findsOneWidget);
    // Kayıt cihazdan ancak kullanıcı isterse çıkar; paylaşım eylemi görünür.
    expect(find.text('Kaydı paylaş'), findsOneWidget);
  });

  testWidgets('en yeni kayıt üstte', (tester) async {
    // Teşhiste bakılan şey **son** geçiştir; liste ters sıralı olmalı.
    final container = await _containerWith([
      _entry(
        event: TimerJournalEvents.startRequested,
        reason: TimerJournalReasons.userAction,
        outcome: TimerJournalOutcomes.applied,
        at: DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
      ),
      _entry(
        event: TimerJournalEvents.mirrorStopRequested,
        reason: TimerJournalReasons.userAction,
        outcome: TimerJournalOutcomes.deferred,
        at: DateTime.now().toUtc(),
      ),
    ]);
    await _pump(tester, container);

    final newest = tester.getRect(find.text(TimerJournalEvents.mirrorStopRequested));
    final oldest = tester.getRect(find.text(TimerJournalEvents.startRequested));
    expect(newest.top, lessThan(oldest.top));
  });

  testWidgets('kayıt yoksa boş durum ve paylaşım yok', (tester) async {
    final container = await _containerWith(const []);
    await _pump(tester, container);

    expect(find.text('Henüz kaydedilmiş sayaç geçişi yok.'), findsOneWidget);
    // Boş kaydı paylaşmak anlamsız; düğme hiç çizilmez.
    expect(find.text('Kaydı paylaş'), findsNothing);
  });
}
