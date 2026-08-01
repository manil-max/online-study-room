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
      titleAchievementId: 'marathon_total',
    );

    test('toMap/fromMap roundtrip', () {
      expect(Profile.fromMap(profile.toMap()), profile);
    });

    test('copyWith yalnızca verilen alanı değiştirir', () {
      final updated = profile.copyWith(displayName: 'Veli');
      expect(updated.displayName, 'Veli');
      expect(updated.id, profile.id);
      expect(updated.titleAchievementId, 'marathon_total');
    });

    test('copyWith ünvanı açıkça temizler', () {
      expect(profile.copyWith(clearTitle: true).titleAchievementId, isNull);
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
        avatarPath: 'g1/11111111-1111-1111-1111-111111111111.webp',
        avatarUpdatedAt: DateTime.parse('2026-07-19T12:00:00.000Z'),
      );
      expect(StudyGroup.fromMap(group.toMap()), group);
    });

    test('varsayılan erişim private ve 8 kişilik limittir', () {
      final group = StudyGroup(
        id: 'g1',
        name: 'Aile Sınıfı',
        inviteCode: 'ABC123',
        createdBy: 'u1',
        createdAt: DateTime(2026, 6, 21),
      );

      expect(group.visibility, GroupVisibility.private);
      expect(group.memberLimit, kDefaultGroupMemberLimit);
    });

    test('public erişim ve limit map sözleşmesinde korunur', () {
      final group = StudyGroup.fromMap({
        'id': 'g1',
        'name': 'Global Focus',
        'invite_code': 'ABC123',
        'created_by': 'u1',
        'created_at': '2026-06-21T10:00:00.000Z',
        'daily_goal_minutes': 480,
        'visibility': 'public',
        'member_limit': 6,
      });

      expect(group.visibility, GroupVisibility.public);
      expect(group.memberLimit, 6);
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

    test('sunucu damgası start zamanından bağımsız tarih anahtarı olur', () {
      final session = StudySession.fromMap({
        'id': 's-stamped',
        'user_id': 'u1',
        'start_time': '2026-06-21T21:30:00.000Z',
        'end_time': '2026-06-21T22:00:00.000Z',
        'duration_seconds': 1800,
        'source': 'manual',
        'day': '2026-06-21',
      });

      expect(session.day, DateTime(2026, 6, 21));
      expect(
        session.toMap().containsKey('day'),
        isFalse,
        reason: 'istemci sunucunun sahip olduğu gün damgasını yazamaz',
      );
    });
  });
}
