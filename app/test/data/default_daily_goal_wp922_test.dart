// WP-922: yeni hesabın kişisel günlük hedefi 2 saattir (120 dk).
//
// 6 saatlik varsayılan yeni kullanıcıya ilk gün "0sn / 6sa" gösteriyor ve
// seriyi daha ilk gün kırıyordu. Sunucu eşi `0145` (pgTAP `071`); grup hedefi
// kapsam dışıdır ve 360 kalır.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';

void main() {
  test('varsayılan kişisel hedef 120 dk; grup hedefi değişmedi', () {
    expect(kDefaultDailyGoalMinutes, 120);
    expect(kDefaultGroupGoalMinutes, 360);
  });

  test('alanı olmayan profil satırı 120 dk hedefle okunur', () {
    final profile = Profile.fromMap({
      'id': 'yeni',
      'display_name': 'Yeni',
      'created_at': '2026-09-24T08:00:00Z',
    });
    expect(profile.dailyGoalMinutes, 120);
  });

  test('sunucunun yazdığı hedef varsayılanla ezilmez', () {
    final profile = Profile.fromMap({
      'id': 'eski',
      'display_name': 'Eski',
      'created_at': '2026-01-01T08:00:00Z',
      'daily_goal_minutes': 360,
    });
    expect(profile.dailyGoalMinutes, 360);
  });

  test('yeni kayıt (InMemory) 2 saatlik hedefle başlar', () async {
    final auth = InMemoryAuthRepository();
    addTearDown(auth.dispose);
    final profile = await auth.signUp(
      email: 'yeni@example.com',
      password: 'gizli123',
      displayName: 'Yeni',
    );
    expect(profile.dailyGoalMinutes, 120);
  });
}
