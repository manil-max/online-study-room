import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/rollout_config.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/repositories/presence_repository.dart';

/// WP-365: çoklu cihaz senkronu rollout anahtarları.
///
/// Bu testin varlık sebebi: anahtarlar sabit kodluyken "çoklu cihaz senkronu
/// çalışmıyor" bir hata sanıldı, oysa özellik hiç açılmamıştı ve denemek için
/// bile yeni build gerekiyordu. Testler hem varsayılanın gerçekten AÇIK
/// olduğunu, hem de yanlış yazılmış bir değerin sessizce açık kalmadığını
/// kilitler.
void main() {
  test('varsayılan presence kademesi shadow — eski sürümdekiler kör kalmasın', () {
    // projection'a doğrudan geçmek, legacy tabloyu okuyan eski istemcileri
    // görünmez yapardı. shadow ikisine de yazar, ikisinden de okur.
    expect(RolloutConfig.presenceMode, PresenceProjectionMode.shadow);
  });

  test('varsayılan global timer kademesi foregroundMirror — gerçekten aynalar', () {
    // shadow yalnız ölçer; kullanıcıya çoklu cihaz senkronu kazandırmaz.
    expect(RolloutConfig.globalTimerMode, GlobalTimerMode.foregroundMirror);
  });

  test('yapılandırılmış adlar gerçekten tanınıyor — sessiz düşüş yok', () {
    // Yanlış yazılmış bir --dart-define güvenli kademeye düşer; bu iyi bir
    // davranış ama sessiz olmamalı. Build'in ne istediğini burada doğruluyoruz.
    expect(
      RolloutConfig.isKnownPresenceMode(
        RolloutConfig.configuredPresenceModeName,
      ),
      isTrue,
      reason:
          'ROLLOUT_PRESENCE_MODE tanınmayan bir değere ayarlanmış: '
          '${RolloutConfig.configuredPresenceModeName}',
    );
    expect(
      RolloutConfig.isKnownGlobalTimerMode(
        RolloutConfig.configuredGlobalTimerModeName,
      ),
      isTrue,
      reason:
          'ROLLOUT_GLOBAL_TIMER_MODE tanınmayan bir değere ayarlanmış: '
          '${RolloutConfig.configuredGlobalTimerModeName}',
    );
  });

  test('tanınmayan değer güvenli kademeye düşer', () {
    expect(RolloutConfig.isKnownPresenceMode('bogus'), isFalse);
    expect(RolloutConfig.isKnownGlobalTimerMode('bogus'), isFalse);
    expect(kSafePresenceMode, PresenceProjectionMode.legacy);
    expect(kSafeGlobalTimerMode, GlobalTimerMode.disabled);
  });

  test('provider\'lar yapılandırmayı okur — ölü anahtar yok', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(presenceProjectionModeProvider),
      RolloutConfig.presenceMode,
    );
    expect(
      container.read(globalTimerModeProvider),
      RolloutConfig.globalTimerMode,
    );
  });

  test('iki kademe bağımsız override edilebilir', () {
    // Biri sorun çıkarırsa diğerini kapatmak zorunda kalmamalıyız.
    final container = ProviderContainer(
      overrides: [
        globalTimerModeProvider.overrideWithValue(GlobalTimerMode.disabled),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(globalTimerModeProvider), GlobalTimerMode.disabled);
    expect(
      container.read(presenceProjectionModeProvider),
      RolloutConfig.presenceMode,
      reason: 'timer kademesini kapatmak presence kademesini etkilememeli',
    );
  });
}
