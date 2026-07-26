import 'package:flutter/widgets.dart';

/// WP-323: tanıtım turunun tek adımı (bir balon).
///
/// Metinler burada **taşınır, üretilmez** — motor dil bilmez, çağıran ekran
/// yerelleştirilmiş metni verir (içerikler WP-324).
@immutable
class TourStep {
  const TourStep({
    required this.id,
    required this.text,
    this.title,
    this.anchor,
  });

  /// Adım kimliği (log/test için okunur olsun diye zorunlu).
  final String id;

  /// Balonun işaret ettiği öğe. `null` ise balon ekranın ortasında, hedefsiz
  /// gösterilir — "genel karşılama" adımları için.
  final GlobalKey? anchor;

  final String? title;
  final String text;
}

/// Bir ekranın tanıtım turu.
@immutable
class TourDefinition {
  const TourDefinition({
    required this.id,
    required this.version,
    required this.steps,
  }) : assert(steps.length > 0, 'A tour needs at least one step.');

  /// Ekran kimliği: `home`, `timer`, `groups`...
  final String id;

  /// 🔴 Sürüm, **ekran ciddi değişince** elle artırılır. Anahtar sürümsüz
  /// olsaydı tek seçenek kalırdı: ya turu bir daha hiç göstermemek, ya da her
  /// güncellemede herkese yeniden açmak.
  final int version;

  final List<TourStep> steps;

  /// Kalıcı anahtarın tur tarafı: `home.v1`.
  String get storageId => '$id.v$version';
}

/// Turun o anki durumu.
@immutable
class TourState {
  const TourState({this.definition, this.index = 0});

  const TourState.idle() : definition = null, index = 0;

  final TourDefinition? definition;
  final int index;

  bool get isRunning => definition != null;

  TourStep? get step {
    final def = definition;
    if (def == null || index < 0 || index >= def.steps.length) return null;
    return def.steps[index];
  }

  int get total => definition?.steps.length ?? 0;
  bool get isLast =>
      definition != null && index == definition!.steps.length - 1;
}
