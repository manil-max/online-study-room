import 'package:online_study_room/l10n/app_localizations.dart';

/// Kamp ateşi sahnesinde (§2G) kullanıcıyı temsil eden hayvan.
///
/// Şimdilik emoji tabanlı ve basit (kullanıcı kararı). İleride kıyafet/renk gibi
/// katmanlar ve daha zengin (ör. Rive) animasyonlar eklenebilir; o yüzden hayvan
/// kimliği ([id]) kalıcı ve sunucuda saklanır (`profiles.animal`).
class CampAnimal {
  const CampAnimal({required this.id, required this.emoji});

  /// Kalıcı, dile bağımsız kimlik (DB'de saklanan değer).
  final String id;

  /// Sahnede çizilen emoji.
  final String emoji;

  String label(AppLocalizations l10n) => switch (id) {
    'fox' => l10n.coreTilki,
    'rabbit' => l10n.coreTavsan,
    'bear' => l10n.coreAyi,
    'cat' => l10n.coreKedi,
    'dog' => l10n.coreKopek,
    'panda' => l10n.corePanda,
    'owl' => l10n.coreBaykus,
    'frog' => l10n.coreKurbaga,
    'penguin' => l10n.corePenguen,
    'koala' => l10n.coreKoala,
    'tiger' => l10n.coreKaplan,
    'hedgehog' => l10n.coreKirpi,
    _ => id,
  };
}

/// Seçilebilir hayvanlar. Sıra seçim ızgarasındaki sırayı belirler.
const List<CampAnimal> kCampAnimals = [
  CampAnimal(id: 'fox', emoji: '🦊'),
  CampAnimal(id: 'rabbit', emoji: '🐰'),
  CampAnimal(id: 'bear', emoji: '🐻'),
  CampAnimal(id: 'cat', emoji: '🐱'),
  CampAnimal(id: 'dog', emoji: '🐶'),
  CampAnimal(id: 'panda', emoji: '🐼'),
  CampAnimal(id: 'owl', emoji: '🦉'),
  CampAnimal(id: 'frog', emoji: '🐸'),
  CampAnimal(id: 'penguin', emoji: '🐧'),
  CampAnimal(id: 'koala', emoji: '🐨'),
  CampAnimal(id: 'tiger', emoji: '🐯'),
  CampAnimal(id: 'hedgehog', emoji: '🦔'),
];

/// Kimliğe göre hayvanı bulur; bulunamazsa null.
CampAnimal? campAnimalById(String? id) {
  if (id == null) return null;
  for (final a in kCampAnimals) {
    if (a.id == id) return a;
  }
  return null;
}

/// Bir kullanıcının sahnede gösterilecek hayvanı: seçtiği [animalId] geçerliyse
/// o; değilse [userId]'ye göre **deterministik** bir varsayılan (kimse seçmemiş
/// bir grup bile çeşitli görünür, ve aynı kullanıcı her zaman aynı hayvanı alır).
CampAnimal campAnimalFor({required String userId, String? animalId}) {
  final chosen = campAnimalById(animalId);
  if (chosen != null) return chosen;
  var hash = 0;
  for (final code in userId.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return kCampAnimals[hash % kCampAnimals.length];
}
