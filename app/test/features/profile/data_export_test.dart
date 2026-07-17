import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/repositories/data_export_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_data_export_repository.dart';

void main() {
  test('export includes only seeded user data', () async {
    final repo = InMemoryDataExportRepository();
    final now = DateTime.now();
    repo.seed(
      userId: 'u1',
      profile: {'display_name': 'Ali'},
      sessionList: [
        StudySession(
          id: 's1',
          userId: 'u1',
          start: now.subtract(const Duration(hours: 2)),
          end: now.subtract(const Duration(hours: 1)),
          durationSeconds: 3600,
          source: StudySource.manual,
        ),
      ],
      subjectList: const [
        Subject(id: 'sub1', userId: 'u1', name: 'Mat', color: 'chart-1'),
      ],
      summary: const UserStudySummary(
        lifetimeSeconds: 3600,
        yearSeconds: 3600,
        hotWindowSeconds: 3600,
      ),
      xp: 120,
    );
    // Another user — must not appear when exporting u1.
    repo.seed(
      userId: 'u2',
      profile: {'display_name': 'Other'},
      sessionList: [
        StudySession(
          id: 's2',
          userId: 'u2',
          start: now,
          end: now.add(const Duration(minutes: 30)),
          durationSeconds: 1800,
          source: StudySource.manual,
        ),
      ],
    );

    final bundle = await repo.buildExport(
      userId: 'u1',
      range: DataExportRange.hot90,
    );
    expect(bundle.payload['user_id'], 'u1');
    expect(bundle.payload['profile']?['display_name'], 'Ali');
    expect(bundle.sessionCount, 1);
    final sessions = bundle.payload['sessions'] as List;
    expect(sessions.single['user_id'], 'u1');
    expect(bundle.payload['xp'], 120);
    expect(bundle.payload['schema_version'], 1);
  });

  test('unauthorized empty when user never seeded', () async {
    final repo = InMemoryDataExportRepository();
    final bundle = await repo.buildExport(
      userId: 'ghost',
      range: DataExportRange.all,
    );
    expect(bundle.sessionCount, 0);
    expect(bundle.payload['profile'], isNull);
    expect(bundle.payload['sessions'], isEmpty);
  });

  test('export profile strips email and tokens', () async {
    final repo = InMemoryDataExportRepository();
    repo.seed(
      userId: 'u1',
      profile: {
        'display_name': 'Ali',
        'email': 'secret@example.com',
        'access_token': 'tok',
        'refresh_token': 'ref',
        'daily_goal_minutes': 120,
      },
    );
    final bundle = await repo.buildExport(
      userId: 'u1',
      range: DataExportRange.all,
    );
    final profile = bundle.payload['profile'] as Map<String, dynamic>;
    expect(profile.containsKey('email'), isFalse);
    expect(profile.containsKey('access_token'), isFalse);
    expect(profile.containsKey('refresh_token'), isFalse);
    expect(profile['display_name'], 'Ali');
    final encoded = bundle.payload.toString();
    expect(encoded.contains('secret@example.com'), isFalse);
    expect(encoded.contains('tok'), isFalse);
  });

  test('year range filters old sessions', () async {
    final repo = InMemoryDataExportRepository();
    final old = DateTime(DateTime.now().year - 1, 6, 1);
    final recent = DateTime.now().subtract(const Duration(days: 3));
    repo.seed(
      userId: 'u1',
      sessionList: [
        StudySession(
          id: 'old',
          userId: 'u1',
          start: old,
          end: old.add(const Duration(hours: 1)),
          durationSeconds: 3600,
          source: StudySource.manual,
        ),
        StudySession(
          id: 'new',
          userId: 'u1',
          start: recent,
          end: recent.add(const Duration(hours: 1)),
          durationSeconds: 3600,
          source: StudySource.manual,
        ),
      ],
    );
    final year = await repo.buildExport(
      userId: 'u1',
      range: DataExportRange.year,
    );
    expect(year.sessionCount, 1);
    expect((year.payload['sessions'] as List).single['id'], 'new');
  });
}
