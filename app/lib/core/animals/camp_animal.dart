/// Kamp ateşi sahnesinde (§2G) kullanıcıyı temsil eden hayvan.
///
/// Şimdilik emoji tabanlı ve basit (kullanıcı kararı). İleride kıyafet/renk gibi
/// katmanlar ve daha zengin (ör. Rive) animasyonlar eklenebilir; o yüzden hayvan
/// kimliği ([id]) kalıcı ve sunucuda saklanır (`profiles.animal`).
class CampAnimal {
  const CampAnimal({
    required this.id,
    required this.emoji,
    required this.label,
  });

  /// Kalıcı, dile bağımsız kimlik (DB'de saklanan değer).
  final String id;

  /// Sahnede çizilen emoji.
  final String emoji;

  /// Seçim ekranındaki Türkçe ad.
  final String label;
}

/// Seçilebilir hayvanlar. Sıra seçim ızgarasındaki sırayı belirler.
const List<CampAnimal> kCampAnimals = [
  CampAnimal(id: 'fox', emoji: '🦊', label: 'Tilki'),
  CampAnimal(id: 'rabbit', emoji: '🐰', label: 'Tavşan'),
  CampAnimal(id: 'bear', emoji: '🐻', label: 'Ayı'),
  CampAnimal(id: 'cat', emoji: '🐱', label: 'Kedi'),
  CampAnimal(id: 'dog', emoji: '🐶', label: 'Köpek'),
  CampAnimal(id: 'panda', emoji: '🐼', label: 'Panda'),
  CampAnimal(id: 'owl', emoji: '🦉', label: 'Baykuş'),
  CampAnimal(id: 'frog', emoji: '🐸', label: 'Kurbağa'),
  CampAnimal(id: 'penguin', emoji: '🐧', label: 'Penguen'),
  CampAnimal(id: 'koala', emoji: '🐨', label: 'Koala'),
  CampAnimal(id: 'tiger', emoji: '🐯', label: 'Kaplan'),
  CampAnimal(id: 'hedgehog', emoji: '🦔', label: 'Kirpi'),
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
