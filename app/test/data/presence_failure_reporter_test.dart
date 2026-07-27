import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/providers/presence_failure_reporter.dart';

/// WP-364: presence yazma hatası bir daha sessiz kalmasın.
///
/// WP-363 aylarca görünmedi çünkü hata koşulsuz yutuluyordu. Ama yazım 20
/// saniyede bir denendiği için "her hatayı bildir" de körlük üretir (gürültü).
/// Bu testler iki uçtaki hatayı da kilitler: sessizlik yok, sel yok.
void main() {
  late DateTime now;
  PresenceWriteFailureReporter build() => PresenceWriteFailureReporter(
    window: const Duration(minutes: 5),
    clock: () => now,
  );

  setUp(() => now = DateTime.utc(2026, 7, 27, 12));

  test('ilk hata her zaman bildirilir — sessizlik yok', () {
    final reporter = build();
    final report = reporter.onFailure(StateError('bum'));
    expect(report, isNotNull);
    expect(report!.errorType, 'StateError');
    expect(report.consecutiveFailures, 1);
  });

  test('aynı hata pencere dolmadan tekrar bildirilmez — sel yok', () {
    final reporter = build();
    expect(reporter.onFailure(StateError('bum')), isNotNull);

    // 20 sn'lik heartbeat aralığıyla 10 tur: hiçbiri bildirilmemeli.
    for (var i = 0; i < 10; i++) {
      now = now.add(const Duration(seconds: 20));
      expect(reporter.onFailure(StateError('bum')), isNull);
    }
    expect(reporter.consecutiveFailures, 11);
  });

  test('pencere dolunca aynı hata yeniden bildirilir', () {
    final reporter = build();
    reporter.onFailure(StateError('bum'));
    now = now.add(const Duration(minutes: 5));
    final report = reporter.onFailure(StateError('bum'));
    expect(report, isNotNull);
    expect(report!.consecutiveFailures, 2);
  });

  test('hata türü değişirse pencere beklenmeden bildirilir', () {
    final reporter = build();
    reporter.onFailure(StateError('bum'));
    now = now.add(const Duration(seconds: 20));
    // Yeni bir arıza sınıfı gürültü değil sinyaldir.
    final report = reporter.onFailure(const FormatException('bozuk'));
    expect(report, isNotNull);
    expect(report!.errorType, 'FormatException');
  });

  test('başarı serisi sıfırlar; arıza tekrar başlarsa yine bildirilir', () {
    final reporter = build();
    reporter.onFailure(StateError('bum'));
    now = now.add(const Duration(seconds: 20));
    expect(reporter.onFailure(StateError('bum')), isNull);

    reporter.onSuccess();
    expect(reporter.consecutiveFailures, 0);

    now = now.add(const Duration(seconds: 20));
    final report = reporter.onFailure(StateError('bum'));
    expect(report, isNotNull, reason: 'yeni arıza serisi sessiz kalmamalı');
    expect(report!.consecutiveFailures, 1);
  });
}
