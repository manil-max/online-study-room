import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_case_timeline_event.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';

/// WP-796 — zaman çizelgesi modeli: `moderation_audit_events` satırından
/// ekranın çizeceği olay türüne. Saf; ekran yok.
void main() {
  AdminCaseTimelineEvent wire({
    String entity = 'case',
    String action = 'updated',
    Map<String, dynamic>? old,
    Map<String, dynamic>? next,
    String? reason,
    String at = '2026-09-05T18:00:00Z',
    String id = '1',
  }) => AdminCaseTimelineEvent.fromWire({
    'id': id,
    'occurred_at': at,
    'actor_id': 'admin-1',
    'entity_type': entity,
    'entity_id': 'case-1',
    'action': action,
    'old_value': old,
    'new_value': next,
    'reason': reason,
  });

  test('vaka guncellemesi hangi alanin degistigine gore siniflanir', () {
    expect(
      wire(old: {'status': 'open'}, next: {'status': 'resolved'}).kind,
      AdminCaseTimelineKind.statusChanged,
    );
    expect(
      wire(
        old: {'status': 'open', 'quarantined': false},
        next: {'status': 'open', 'quarantined': true},
      ).kind,
      AdminCaseTimelineKind.quarantineChanged,
    );
    expect(
      wire(old: {'severity': 'normal'}, next: {'severity': 'high'}).kind,
      AdminCaseTimelineKind.severityChanged,
    );
    expect(wire(action: 'opened').kind, AdminCaseTimelineKind.caseOpened);
  });

  test('yaptirim ve itiraz olaylari kendi turune duser', () {
    expect(
      wire(entity: 'sanction', action: 'opened', reason: 'hakaret').kind,
      AdminCaseTimelineKind.sanctionApplied,
    );
    expect(
      wire(entity: 'sanction', action: 'state_changed').kind,
      AdminCaseTimelineKind.sanctionStateChanged,
    );
    expect(
      wire(entity: 'appeal', action: 'submitted').kind,
      AdminCaseTimelineKind.appealSubmitted,
    );
    expect(
      wire(entity: 'appeal', action: 'decided').kind,
      AdminCaseTimelineKind.appealDecided,
    );
  });

  /// 🔴 Sunucu bir eylemi yeniden adlandirirsa ekran YANLIS bir dala
  /// yuvarlamaz; ham `action` gosterilir. Sessizce "cozuldu" yazan bir
  /// cizelge, hic cizelge olmamasindan kotudur.
  test('tanimadigi eylem `other`, yuvarlama yok', () {
    expect(wire(action: 'escalated').kind, AdminCaseTimelineKind.other);
    expect(
      wire(entity: 'case', action: 'updated', old: {'x': 1}, next: {'x': 1}).kind,
      AdminCaseTimelineKind.other,
    );
  });

  test('bos gerekce null olur, eskiden yeniye siralanir', () {
    expect(wire(reason: '   ').reason, isNull);
    expect(wire(reason: ' tekrar ').reason, 'tekrar');
    final sorted = sortCaseTimeline([
      wire(id: 'b', at: '2026-09-05T19:00:00Z'),
      wire(id: 'a', at: '2026-09-05T18:00:00Z'),
      wire(id: 'c', at: '2026-09-05T19:00:00Z'),
    ]);
    expect(sorted.map((e) => e.id), ['a', 'b', 'c']);
  });

  test('bellek ici depo tohumsuz BOS doner, uydurmaz', () async {
    final repo = InMemoryAdminModerationRepository();
    expect(await repo.fetchCaseTimeline('case-1'), isEmpty);
    repo.caseTimelines['case-1'] = [
      wire(id: 'b', at: '2026-09-05T19:00:00Z'),
      wire(id: 'a', at: '2026-09-05T18:00:00Z'),
    ];
    final events = await repo.fetchCaseTimeline('case-1');
    expect(events.map((e) => e.id), ['a', 'b']);
  });
}
