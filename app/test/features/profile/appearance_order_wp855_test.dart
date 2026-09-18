import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/theme_presets.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/features/profile/appearance_screen.dart';

/// 🔴 WP-855 — karşılama teması Görünüm ekranında İLK sırada durur.
///
/// WP-841 onu listenin sonuna eklemişti; yeni kullanıcı kendi seçili temasını
/// ilk ekranda göremiyordu. Sıra yalnız ekranda değişir: `kThemePresets` ve
/// onun `first`ine düşen `themePresetById` yedeği dokunulmadan kalır.
void main() {
  test('karşılama teması görünüm sırasında birinci', () {
    expect(kAppearancePresetOrder.first.id, kFirstRunFamilyId);
  });

  test('görünüm sırası hiçbir temayı düşürmez ya da çoğaltmaz', () {
    expect(kAppearancePresetOrder.length, kThemePresets.length);
    expect(
      kAppearancePresetOrder.map((p) => p.id).toSet(),
      kThemePresets.map((p) => p.id).toSet(),
    );
  });

  test('kimlik yedeği değişmedi: bilinmeyen kimlik eski ilk temaya düşer', () {
    expect(themePresetById('yok_boyle_tema').id, kThemePresets.first.id);
    expect(kThemePresets.first.id, isNot(kFirstRunFamilyId));
  });
}
