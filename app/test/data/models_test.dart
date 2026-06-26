import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';

void main() {
  group('Profile', () {
    final profile = Profile(
      id: 'u1',
      displayName: 'Ali',
      avatarUrl: null,
      createdAt: DateTime.parse('2026-06-21T10:00:00.000Z'),
    );

    test('toMap/fromMap roundtrip', () {
      expect(Profile.fromMap(profile.toMap()), profile);
    });

    test('copyWith yalnızca verilen alanı değiştirir', () {
      final updated = profile.copyWith(displayName: 'Veli');
      expect(updated.displayName, 'Veli');
      expect(updated.id, profile.id);
    });
  });

  group('StudyGroup', () {
    test('toMap/fromMap roundtrip', () {
      final group = StudyGroup(
        id: 'g1',
        name: 'Aile Sınıfı',
        inviteCode: 'ABC123',
        createdBy: 'u1',
        createdAt: DateTime.parse('2026-06-21T10:00:00.000Z'),
      );
      expect(StudyGroup.fromMap(group.toMap()), group);
    });
  });

  group('StudySession', () {
    test('toMap/fromMap roundtrip ve gün hesabı', () {
      final session = StudySession(
        id: 's1',
        userId: 'u1',
        start: DateTime.parse('2026-06-21T08:30:00.000Z'),
        end: DateTime.parse('2026-06-21T09:30:00.000Z'),
        durationSeconds: 3600,
        source: StudySource.live,
      );
      expect(StudySession.fromMap(session.toMap()), session);
      expect(session.day, DateTime(2026, 6, 21));
    });
  });
}
