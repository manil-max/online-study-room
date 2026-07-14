/// WP-61 paket yolları. pubspec: `assets/campfire/` (+ `2.0x/`).
abstract final class CampfireAssets {
  static const base = 'assets/campfire';

  static const ground = '$base/ground.png';
  static const glow = '$base/glow.png';
  static const stones = '$base/stones.png';
  static const wood = '$base/wood.png';
  static const coals = '$base/coals.png';
  static const flameBack = '$base/flame_back.png';
  static const flameMid = '$base/flame_mid.png';
  static const flameFront = '$base/flame_front.png';
  static const smoke = '$base/smoke.png';
  static const emberSheet = '$base/ember_sheet.png';

  /// Z-order alttan üste (parçacıklar hariç).
  static const stackOrder = <String>[
    ground,
    glow,
    stones,
    wood,
    coals,
    flameBack,
    flameMid,
    flameFront,
    smoke,
  ];
}
