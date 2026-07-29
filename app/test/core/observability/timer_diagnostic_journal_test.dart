import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/observability/observability_config.dart';
import 'package:online_study_room/core/observability/observability_service.dart';
import 'package:online_study_room/core/observability/timer_diagnostic_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-430: uçuş kaydının gizlilik ve dayanıklılık sözleşmesi.
///
/// Bu testler "log eklendi mi" diye bakmaz; kaydın **kimlik sızdırmadığını**,
/// serbest metin kabul etmediğini ve sınırsız büyümediğini kanıtlar.
void main() {
  late SharedPreferences prefs;

  Future<TimerDiagnosticJournal> journal([
    Map<String, Object> seed = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(seed);
    prefs = await SharedPreferences.getInstance();
    return TimerDiagnosticJournal(prefs);
  }

  test('geçiş kaydı neden + sonuç + state_version/queue_age taşır', () async {
    final subject = await journal();

    await subject.record(
      event: TimerJournalEvents.mirrorAdopted,
      reason: TimerJournalReasons.remoteSnapshot,
      outcome: TimerJournalOutcomes.applied,
      origin: TimerJournalOrigins.mirror,
      accountId: 'user-1',
      runId: 'run-1',
      deviceId: 'device-1',
      commandId: 'command-1',
      runRevision: 4,
      stateVersion: 12,
      queueAgeMs: 28_800_000,
      elapsedSeconds: 28_800,
    );

    final entry = subject.entries().single;
    expect(entry.event, TimerJournalEvents.mirrorAdopted);
    expect(entry.reason, TimerJournalReasons.remoteSnapshot);
    expect(entry.outcome, TimerJournalOutcomes.applied);
    expect(entry.origin, TimerJournalOrigins.mirror);
    expect(entry.stateVersion, 12);
    expect(entry.queueAgeMs, 28_800_000);
    expect(entry.elapsedSeconds, 28_800);
    expect(entry.runRevision, 4);
  });

  test('ham hesap/koşu/cihaz/komut kimliği diske yazılmaz', () async {
    final subject = await journal();

    await subject.record(
      event: TimerJournalEvents.startRequested,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.applied,
      accountId: '11111111-2222-3333-4444-555555555555',
      runId: 'run-super-secret',
      deviceId: 'device-super-secret',
      commandId: 'command-super-secret',
    );

    final raw = prefs.getString(TimerDiagnosticJournal.storageKey);
    expect(raw, isNotNull);
    for (final secret in const [
      '11111111-2222-3333-4444-555555555555',
      'run-super-secret',
      'device-super-secret',
      'command-super-secret',
    ]) {
      expect(
        raw,
        isNot(contains(secret)),
        reason: 'kimlik yalnız tek yönlü özet olarak saklanabilir',
      );
    }

    final entry = subject.entries().single;
    // Özet 12 hex karakter: aynı koşu izlenebilir, kimlik geri üretilemez.
    expect(entry.accountRef, matches(RegExp(r'^[0-9a-f]{12}$')));
    expect(entry.runRef, matches(RegExp(r'^[0-9a-f]{12}$')));
    expect(entry.accountRef, isNot(entry.runRef));
  });

  test('aynı kimlik aynı özete, farklı kimlik farklı özete düşer', () async {
    final subject = await journal();
    await subject.record(
      event: TimerJournalEvents.startRequested,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.applied,
      runId: 'run-a',
    );
    await subject.record(
      event: TimerJournalEvents.runTerminal,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.applied,
      runId: 'run-a',
    );
    await subject.record(
      event: TimerJournalEvents.startRequested,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.applied,
      runId: 'run-b',
    );

    final refs = subject.entries().map((entry) => entry.runRef).toList();
    expect(refs[0], refs[1], reason: 'aynı koşu zaman çizelgesinde eşlenebilmeli');
    expect(refs[2], isNot(refs[0]));
  });

  test('kimliksiz alan `none` kalır — boş özet üretilmez', () async {
    final subject = await journal();
    await subject.record(
      event: TimerJournalEvents.coldStartRestore,
      reason: TimerJournalReasons.coldStart,
      outcome: TimerJournalOutcomes.dropped,
    );
    final entry = subject.entries().single;
    expect(entry.accountRef, TimerJournalRef.absent);
    expect(entry.runRef, TimerJournalRef.absent);
    expect(entry.deviceRef, TimerJournalRef.absent);
    expect(entry.commandRef, TimerJournalRef.absent);
  });

  test('serbest metin slug kapısından geçemez', () async {
    final subject = await journal();
    await subject.record(
      event: 'stop_requested',
      reason: 'kullanıcı v8-qa@ornek.com mesajı: token=secret',
      outcome: 'APPLIED',
      origin: 'Bildirim Paneli',
    );
    final entry = subject.entries().single;
    expect(entry.reason, TimerJournalSlug.unknown);
    expect(entry.origin, TimerJournalSlug.unknown);
    // Büyük harf tek başına kusur değil; normalize edilir.
    expect(entry.outcome, TimerJournalOutcomes.applied);

    final raw = prefs.getString(TimerDiagnosticJournal.storageKey) ?? '';
    expect(raw, isNot(contains('ornek.com')));
    expect(raw, isNot(contains('secret')));
  });

  test('halka tampon maxEntries üstünde en eskiyi düşürür', () {
    final base = DateTime.utc(2026, 7, 30, 2);
    final entries = [
      for (var index = 0; index < TimerDiagnosticJournal.maxEntries + 40; index++)
        TimerJournalEntry(
          at: base.add(Duration(seconds: index)),
          event: TimerJournalEvents.leaseHeartbeat,
          reason: TimerJournalReasons.periodicPoll,
          outcome: TimerJournalOutcomes.applied,
          stateVersion: index,
        ),
    ];

    final pruned = TimerDiagnosticJournal.prune(
      entries,
      now: base.add(const Duration(minutes: 10)),
    );

    expect(pruned, hasLength(TimerDiagnosticJournal.maxEntries));
    expect(pruned.first.stateVersion, 40, reason: 'en eski 40 kayıt düşmeli');
    expect(pruned.last.stateVersion, entries.length - 1);
  });

  test('TTL dışındaki kayıt okumada da görünmez', () async {
    final now = DateTime.utc(2026, 7, 30, 2);
    final stale = now.subtract(
      TimerDiagnosticJournal.retention + const Duration(minutes: 1),
    );
    final fresh = now.subtract(const Duration(hours: 1));
    final subject = await journal({
      TimerDiagnosticJournal.storageKey: jsonEncode([
        {
          'at': stale.toIso8601String(),
          'event': TimerJournalEvents.startRequested,
          'reason': TimerJournalReasons.userAction,
          'outcome': TimerJournalOutcomes.applied,
        },
        {
          'at': fresh.toIso8601String(),
          'event': TimerJournalEvents.runTerminal,
          'reason': TimerJournalReasons.userAction,
          'outcome': TimerJournalOutcomes.applied,
        },
      ]),
    });

    final visible = subject.entries(now: now);
    expect(visible, hasLength(1));
    expect(visible.single.event, TimerJournalEvents.runTerminal);
  });

  test('diskte ham kimlik bulunursa okumada `none`a düşürülür', () async {
    final subject = await journal({
      TimerDiagnosticJournal.storageKey: jsonEncode([
        {
          'at': DateTime.now().toUtc().toIso8601String(),
          'event': TimerJournalEvents.startRequested,
          'reason': TimerJournalReasons.userAction,
          'outcome': TimerJournalOutcomes.applied,
          // Eski/bozuk bir yazıcı ham kimlik bırakmış olsa bile dışa aktarım
          // bunu taşımaz.
          'account_ref': 'kullanici@ornek.com',
          'run_ref': '11111111-2222-3333-4444-555555555555',
        },
      ]),
    });

    final entry = subject.entries().single;
    expect(entry.accountRef, TimerJournalRef.absent);
    expect(entry.runRef, TimerJournalRef.absent);
    expect(subject.exportEntries(), isNot(contains('ornek.com')));
  });

  test('bozuk JSON kaydı çökertmez, kayıt sıfırlanır', () async {
    final subject = await journal({
      TimerDiagnosticJournal.storageKey: '{bu json değil',
    });
    expect(subject.entries(), isEmpty);
    await subject.record(
      event: TimerJournalEvents.startRequested,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.applied,
    );
    expect(subject.entries(), hasLength(1));
  });

  test('telemetri kapalıyken geçiş özeti cihazdan çıkmaz', () async {
    final transport = _FakeTransport();
    final service = ObservabilityService(
      config: const ObservabilityConfig(
        dsn: 'https://public@example.invalid/1',
        environment: 'beta',
        release: 'odak-kampi@1.0.7+8',
        buildEnabled: true,
      ),
      transport: transport,
    );
    SharedPreferences.setMockInitialValues({
      TelemetryPreference.key: false,
    });
    await service.initialize(await SharedPreferences.getInstance());

    service.timerTransition(
      event: TimerJournalEvents.runTerminal,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.ghostNoSession,
      stateVersion: 3,
    );

    expect(transport.breadcrumbs, isEmpty);

    // Yerel kayıt telemetriden bağımsızdır: tanı için cihazda tutulmaya devam
    // eder, ama hiçbir transport görmez.
    final local = TimerDiagnosticJournal(
      await SharedPreferences.getInstance(),
    );
    await local.record(
      event: TimerJournalEvents.runTerminal,
      reason: TimerJournalReasons.userAction,
      outcome: TimerJournalOutcomes.ghostNoSession,
    );
    expect(local.entries(), hasLength(1));
    expect(transport.breadcrumbs, isEmpty);
  });

  test('telemetri açıkken geçiş özeti yalnız slug + tamsayı taşır', () async {
    final transport = _FakeTransport();
    final service = ObservabilityService(
      config: const ObservabilityConfig(
        dsn: 'https://public@example.invalid/1',
        environment: 'beta',
        release: 'odak-kampi@1.0.7+8',
        buildEnabled: true,
      ),
      transport: transport,
    );
    SharedPreferences.setMockInitialValues({});
    await service.initialize(await SharedPreferences.getInstance());

    service.timerTransition(
      event: TimerJournalEvents.runTerminal,
      reason: 'kullanıcı mesajı: gizli@ornek.com',
      outcome: TimerJournalOutcomes.ghostNoSession,
      origin: TimerJournalOrigins.mirror,
      stateVersion: 9,
      queueAgeMs: 28_800_000,
    );

    final breadcrumb = transport.breadcrumbs.singleWhere(
      (item) => item.message == 'timer_transition',
    );
    expect(breadcrumb.category, 'app.sync');
    expect(breadcrumb.data['reason'], TimerJournalSlug.unknown);
    expect(breadcrumb.data['outcome'], TimerJournalOutcomes.ghostNoSession);
    expect(breadcrumb.data['state_version'], 9);
    expect(breadcrumb.data['queue_age_ms'], 28_800_000);
    for (final value in breadcrumb.data.values) {
      expect(
        value is int || value is bool || value is String,
        isTrue,
        reason: 'karmaşık nesne breadcrumb’a giremez',
      );
      if (value is String) {
        expect(value, matches(RegExp(r'^[a-z0-9_]{1,48}$')));
      }
    }
  });
}

class _FakeTransport implements ObservabilityTransport {
  final breadcrumbs = <ObservabilityBreadcrumb>[];

  @override
  Future<void> initialize(ObservabilityConfig config) async {}

  @override
  void addBreadcrumb(ObservabilityBreadcrumb breadcrumb) {
    breadcrumbs.add(breadcrumb);
  }

  @override
  Future<void> captureException(Object exception, StackTrace stackTrace) async {}
}
