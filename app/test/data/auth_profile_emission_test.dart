// WP-478 (V57-N02 birinci yarısı): "Ünvan seçiliyor, grup listesinde doğru
// görünüyor, ama Başarımlar ekranına tekrar girince 'No title selected' yazıyor."
//
// Kök neden: ünvan sunucuya **yazılıyordu**, istemci önbelleği tazelenmiyordu.
// `authStateChanges()` yalnız iki olayda yayın yapıyordu — açılıştaki ilk okuma
// ve auth durumu değişimi. Profil mutasyonlarının hiçbiri yeni değer yaymıyordu,
// yani `authStateProvider` bayat profili sunuyordu.
//
// 🔴 Mevcut testler bunu yakalayamıyordu çünkü `InMemoryAuthRepository` her
// mutasyonda zaten `_controller.add` yapıyor. Boşluk **yalnız** Supabase
// uygulamasındaydı; bu yüzden bu dosya gerçek PostgREST kablosunu sürüyor.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';

import '../support/supabase_wire_harness.dart';

const _userId = 'user-1';

Map<String, dynamic> _authResponse() => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': _userId,
    'email': 'ali@example.com',
    'aud': 'authenticated',
    'created_at': '2026-08-01T10:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': {'display_name': 'Ali'},
  },
};

Future<SupabaseAuthRepository> _signedIn(SupabaseWireHarness wire) async {
  wire.respond('token', _authResponse());
  wire.respond('profiles', [
    {
      'id': _userId,
      'display_name': 'Ali',
      'avatar_url': null,
      'created_at': '2026-08-01T10:00:00Z',
      'title_achievement_id': null,
    },
  ]);
  final repository = SupabaseAuthRepository(wire.client());
  await repository.signIn(email: 'ali@example.com', password: 'guvenli123');
  wire.calls.clear();
  return repository;
}

void main() {
  late SupabaseWireHarness wire;
  late SupabaseAuthRepository repository;
  late List<Profile?> emitted;

  setUp(() async {
    wire = SupabaseWireHarness();
    repository = await _signedIn(wire);
    emitted = [];
    final sub = repository.authStateChanges().listen(emitted.add);
    addTearDown(sub.cancel);
    // Açılış yayınının akması için bir tur bekle; sonrasındaki her kayıt
    // mutasyondan gelmiş olur.
    await Future<void>.delayed(Duration.zero);
    emitted.clear();
  });

  test('updateTitle yeni profili yayar', () async {
    await repository.updateTitle('marathon_total');
    await Future<void>.delayed(Duration.zero);

    expect(emitted, hasLength(1));
    expect(emitted.single?.titleAchievementId, 'marathon_total');
  });

  test('ünvanın kaldırılması da yayılır', () async {
    await repository.updateTitle('marathon_total');
    await repository.updateTitle(null);
    await Future<void>.delayed(Duration.zero);

    expect(emitted, hasLength(2));
    expect(emitted.last?.titleAchievementId, isNull);
  });

  // 🔴 Kart notu: bu tek bir alanın hatası değil. Aynı yayınsız desen altı
  // mutasyonun hepsinde vardı; diğerleri bugün görünmüyordu çünkü ilgili
  // ekranlar yerel `setState` tutuyor. Altısı da ayrı ayrı iddia ediliyor.
  test('altı profil mutasyonunun her biri yayın yapar', () async {
    await repository.updateDisplayName('Ayse');
    await Future<void>.delayed(Duration.zero);
    expect(emitted.last?.displayName, 'Ayse', reason: 'updateDisplayName');

    await repository.updateDailyGoal(120);
    await Future<void>.delayed(Duration.zero);
    expect(emitted.last?.dailyGoalMinutes, 120, reason: 'updateDailyGoal');

    await repository.updateAnimal('fox');
    await Future<void>.delayed(Duration.zero);
    expect(emitted.last?.animal, 'fox', reason: 'updateAnimal');

    await repository.updateTitle('marathon_total');
    await Future<void>.delayed(Duration.zero);
    expect(
      emitted.last?.titleAchievementId,
      'marathon_total',
      reason: 'updateTitle',
    );

    await repository.updateMonthlyReportOptIn(true);
    await Future<void>.delayed(Duration.zero);
    expect(
      emitted.last?.monthlyReportOptIn,
      isTrue,
      reason: 'updateMonthlyReportOptIn',
    );

    // Avatar yolu depolama yüklemesinden geçer; kablo yanıtı `object` uç
    // noktasına verilir (`/storage/v1/object/avatars/<uid>/avatar`).
    wire.respond('object', {'Key': 'avatars/$_userId/avatar'});
    await repository.updateAvatar(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      contentType: 'image/png',
    );
    await Future<void>.delayed(Duration.zero);
    expect(emitted.last?.avatarUrl, isNotNull, reason: 'updateAvatar');

    expect(emitted, hasLength(6));
  });

  test('başarısız mutasyon yayın yapmaz', () async {
    wire.failWith('profiles', status: 400, message: 'title_not_earned');

    await expectLater(
      repository.updateTitle('unearned_title'),
      throwsA(isA<Object>()),
    );
    await Future<void>.delayed(Duration.zero);

    // Yayın, yazma başarılı olduktan **sonra** yapılır; aksi hâlde ekran
    // sunucunun reddettiği değeri gösterirdi.
    expect(emitted, isEmpty);
  });
}
