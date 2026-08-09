// WP-601 — WP-599'un yazdığı `trigger` alanı EKRANDA görünmüyordu.
//
// WP-599 sayaç günlüğüne "bu geçişi ne doğurdu" alanını ekledi: parmak mı,
// Samsung rutini/ana ekran kısayolu mu, bildirim düğmesi mi, uygulama
// kapalıyken sıraya girmiş bir komut mu. Alan tam da sahibin "sayacı gerçekten
// kardeşim mi başlattı?" sorusunu cevaplamak için var.
//
// 🔴 Ama `timer_journal_screen` alanı hiç çizmiyordu: yalnız
// `reason → outcome` basıyordu. Yani gerçek bir olayda cevap yine ancak günlüğü
// dışa aktarıp JSON'u elle okuyarak bulunabilirdi — bu depoda tekrarlayan
// "yazıldı ama kullanılmadı" deseninin aynısı (WP-550 `AppPullToRefresh`,
// WP-595 `TimerVerificationNotice`, WP-600 performans aracı).
//
// 🔴 İki yönlü iddia: kaynak BİLİNİYORSA çizilmeli, `unknown` ise
// ÇİZİLMEMELİ. Tek yönlü ölçüm "her satıra kaynak bas" hâlini geçirirdi ve
// WP-599 öncesi kayıtlara "bilinmiyor" damgası basılırdı — asıl tehlike ise
// onları "kullanıcı" saymaktır, o da hiç yapılmıyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/observability/timer_diagnostic_journal.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/timer_journal_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _seed(
  List<({String event, String trigger})> rows,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final journal = TimerDiagnosticJournal(prefs);
  for (final row in rows) {
    await journal.record(
      event: row.event,
      reason: TimerJournalTriggers.reasonFor(row.trigger),
      outcome: TimerJournalOutcomes.applied,
      trigger: row.trigger,
      // Gerçek saate bağlanmamak için an ENJEKTE edilir; TTL penceresi 72 saat
      // olduğundan "şimdi"ye yakın bir değer gerekiyor ama testin kendisi
      // duvar saatinin hangi güne denk geldiğine bakmıyor.
      at: DateTime.now().toUtc(),
    );
  }
  return prefs;
}

Future<void> _pump(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TimerJournalScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cihaz kısayolundan gelen başlatma EKRANDA ayırt edilir', (
    tester,
  ) async {
    final prefs = await _seed([
      (
        event: TimerJournalEvents.startRequested,
        trigger: '${TimerJournalTriggers.devicePrefix}start_timer_warm',
      ),
    ]);
    await _pump(tester, prefs);

    expect(
      find.textContaining('device_start_timer_warm'),
      findsOneWidget,
      reason:
          'Ekran hâlâ yalnız reason/outcome basıyor: gerçek bir olayda '
          '"parmak mı rutin mi" sorusu yine JSON dışa aktarmadan '
          'cevaplanamaz.',
    );
  });

  testWidgets('parmakla başlatma da görünür (kaynak her zaman okunabilir)', (
    tester,
  ) async {
    final prefs = await _seed([
      (
        event: TimerJournalEvents.startRequested,
        trigger: TimerJournalTriggers.userButton,
      ),
    ]);
    await _pump(tester, prefs);

    expect(find.textContaining(TimerJournalTriggers.userButton), findsOneWidget);
  });

  testWidgets('WP-599 ÖNCESİ satırlara kaynak damgası basılmaz', (
    tester,
  ) async {
    final prefs = await _seed([
      (
        event: TimerJournalEvents.startRequested,
        trigger: TimerJournalTriggers.unknown,
      ),
    ]);
    await _pump(tester, prefs);

    // Satırın kendisi görünmeli — gizlenmesi kanıt kaybı olurdu.
    expect(find.textContaining(TimerJournalEvents.startRequested), findsWidgets);
    // Ama kaynak satırı çizilmemeli.
    expect(
      find.textContaining('kaynak:'),
      findsNothing,
      reason:
          'Eski satırlara "bilinmiyor" damgası basmak gürültüdür; bu olmadan '
          '"her satıra kaynak bas" sabotajı sessizce geçerdi.',
    );
  });

  test('kullanıcı düğmesi ile diğer kaynaklar AYIRT EDİLEBİLİR kalır', () {
    // Ekran vurguyu buna göre veriyor; yardımcı bozulursa vurgu sessizce
    // ters döner ve rutinden gelen başlatma parmak gibi görünür.
    expect(
      TimerJournalTriggers.isUserButton(TimerJournalTriggers.userButton),
      isTrue,
    );
    for (final other in [
      '${TimerJournalTriggers.devicePrefix}start_timer_cold',
      TimerJournalTriggers.notificationButton,
      TimerJournalTriggers.externalCommandQueue,
      TimerJournalTriggers.unknown,
    ]) {
      expect(
        TimerJournalTriggers.isUserButton(other),
        isFalse,
        reason: '$other kullanıcı düğmesi sayılıyor.',
      );
    }
  });
}
