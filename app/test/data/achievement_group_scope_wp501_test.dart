// WP-501 (V58-N06 / rapor T06): grup başarımı yalnız **seçili gruptan**
// sayılsın.
//
// 🔴 Kök neden sunucudaydı: `achievement_metric_progress` birincil anahtarı
// `(user_id, achievement_id)` — grup boyutu yok. Üç projeksiyon da rollup
// tablosunu `group by user_id` ile topluyordu, yani iki grupta aynı hafta
// birinci olan kullanıcı Lider Kurt'ta **2** alıyordu. `0121` kırılımı ayrı
// tabloya taşıdı ve düz tabloyu gruplar arası `max`a çevirdi.
//
// 🔴 Bu dosyanın varlık sebebi ayrı bir tuzak: sunucu **hangi grubun seçili
// olduğunu bilemez**. `activeGroupIdProvider` seçimi yalnız cihazdaki
// `SharedPreferences`'a yazar (`group_providers.dart:106`), aynı hesap iki
// cihazda farklı grup seçebilir. Yani sahibin kuralı ancak istemcide
// uygulanabilir. Kırılım tablosu yazılıp da **çağıran olmasaydı** özellik hiç
// var olmazdı (v57'de üç kez yaşandı: bitmiş backend, bağlanmamış UI).
// Aşağıdaki iddialar tam olarak o kabloyu ölçer.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement_metric_progress.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/achievement_provider.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/achievement_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_repository.dart';

final _user = Profile(
  id: 'u1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g-secili',
  name: 'Seçili Grup',
  inviteCode: 'ABC123',
  createdBy: 'u1',
  createdAt: DateTime(2026, 1, 1),
);

AchievementMetricProgress _progress(String id, int value) =>
    AchievementMetricProgress(
      userId: 'u1',
      achievementId: id,
      metricValue: value,
      sourceVersion: 'group_scoped_v1',
      updatedAt: DateTime(2026, 8, 1),
    );

/// Sunucunun iki tablosunu taklit eder.
class _FakeRepository extends InMemoryAchievementRepository {
  _FakeRepository({required this.flat, required this.scoped});

  final List<AchievementMetricProgress> flat;
  final List<AchievementMetricProgress> scoped;

  String? lastScopedGroupId;

  @override
  Stream<List<AchievementMetricProgress>> watchMetricProgress(String userId) =>
      Stream.value(flat);

  @override
  Stream<List<AchievementMetricProgress>> watchGroupScopedMetricProgress(
    String userId,
    String groupId,
  ) {
    lastScopedGroupId = groupId;
    return Stream.value(scoped);
  }
}

ProviderContainer _container({
  required AchievementRepository repo,
  StudyGroup? group,
}) {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
      achievementRepositoryProvider.overrideWithValue(repo),
      userGroupProvider.overrideWithValue(AsyncValue.data(group)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// 🔴 Riverpod 3: dinleyicisi olmayan provider her `read`de yeniden build olur
/// ve akış ilk değerini vermeden `loading` döner. `listen` tutulmazsa bu
/// dosyadaki her iddia sessizce boşa düşerdi.
Future<List<AchievementMetricProgress>> _resolve(
  ProviderContainer container,
) async {
  final sub = container.listen(achievementMetricProgressProvider, (_, _) {});
  addTearDown(sub.close);
  // İki ayrı akış birleşiyor; biri diğerinden bir tur sonra çözülüyor. Tek
  // `pump` ile ölçmek ilk denemede sessizce **eski** değeri okuttu.
  for (var i = 0; i < 5; i++) {
    await container.pump();
    await Future<void>.delayed(Duration.zero);
  }
  return container.read(achievementMetricProgressProvider).value ?? const [];
}

void main() {
  test('seçili grubun değeri düz tablodakini ezer', () async {
    // Sunucu: düz tabloda en iyi grubun değeri 3 (ödül/XP için),
    // seçili grupta ise 1.
    final repo = _FakeRepository(
      flat: [_progress('alpha_wolf_weekly', 3), _progress('perfect_month', 2)],
      scoped: [_progress('alpha_wolf_weekly', 1)],
    );
    final values = await _resolve(_container(repo: repo, group: _group));

    final byId = {for (final v in values) v.achievementId: v.metricValue};
    // Sahibin kuralı: seçili gruptan sayılsın.
    expect(byId['alpha_wolf_weekly'], 1);
    // Grup dışı metrik dokunulmadan geçer.
    expect(byId['perfect_month'], 2);
    // Kırılım gerçekten **seçili** grup için istendi.
    expect(repo.lastScopedGroupId, 'g-secili');
  });

  test('grup seçili değilse düz tablo aynen geçer', () async {
    final repo = _FakeRepository(
      flat: [_progress('alpha_wolf_weekly', 3)],
      scoped: [_progress('alpha_wolf_weekly', 1)],
    );
    final values = await _resolve(_container(repo: repo, group: null));

    expect(values.single.metricValue, 3);
    // Grup yokken kırılım hiç sorulmaz (gereksiz abonelik açılmaz).
    expect(repo.lastScopedGroupId, isNull);
  });

  test('düz tabloda satırı olmayan grup metriği de görünür', () async {
    // Yeni bir grup metriği yalnız kırılım tablosunda olabilir; birleştirme
    // onu düşürmemeli, yoksa rozet hiç çizilmez.
    final repo = _FakeRepository(
      flat: const [],
      scoped: [_progress('campfire_hours', 4)],
    );
    final values = await _resolve(_container(repo: repo, group: _group));

    expect(values.single.achievementId, 'campfire_hours');
    expect(values.single.metricValue, 4);
  });

  test('kırılım boşsa düz tablo bozulmadan geçer', () async {
    // InMemory katmanı boş liste döndürür; sunucusuz koşumda davranış
    // değişmemeli.
    final repo = _FakeRepository(
      flat: [_progress('alpha_wolf_weekly', 3), _progress('locomotive', 7)],
      scoped: const [],
    );
    final values = await _resolve(_container(repo: repo, group: _group));

    expect(values.length, 2);
    expect(
      {for (final v in values) v.achievementId: v.metricValue},
      {'alpha_wolf_weekly': 3, 'locomotive': 7},
    );
  });
}
