import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/animals/camp_animal.dart';

void main() {
  group('camp_animal', () {
    test('campAnimalById bilinen kimliği bulur, bilinmeyende null', () {
      expect(campAnimalById('fox')?.emoji, '🦊');
      expect(campAnimalById('yok'), isNull);
      expect(campAnimalById(null), isNull);
    });

    test('seçilen geçerli hayvan varsayılanı ezer', () {
      final a = campAnimalFor(userId: 'u1', animalId: 'bear');
      expect(a.id, 'bear');
    });

    test('seçim yoksa userId ile deterministik ve stabil varsayılan verir', () {
      final a1 = campAnimalFor(userId: 'user-123', animalId: null);
      final a2 = campAnimalFor(userId: 'user-123', animalId: null);
      expect(a1.id, a2.id); // aynı kullanıcı hep aynı hayvan
      expect(kCampAnimals.contains(a1), isTrue);
    });

    test('geçersiz kimlik varsayılana düşer', () {
      final a = campAnimalFor(userId: 'u1', animalId: 'gecersiz');
      expect(kCampAnimals.contains(a), isTrue);
    });

    test('farklı kullanıcılar çeşitlenebilir', () {
      final ids = {
        for (final u in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'])
          campAnimalFor(userId: u, animalId: null).id,
      };
      // Deterministik dağılım en az birkaç farklı hayvan üretmeli.
      expect(ids.length, greaterThan(1));
    });
  });
}
