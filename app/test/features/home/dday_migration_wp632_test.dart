// WP-632 — tek tarihten üç kayda geçişin veri sözleşmesi.
//
// 🔴 Bu dosyanın varlık sebebi tek cümle: **kullanıcının kayıtlı sınav tarihi
// kaybolmayacak.** Bu depoda sessiz veri kaybı tekrarlayan bir hata sınıfıdır
// (WP-613 durdurulan oturum, WP-621 bozuk profil önbelleği, WP-624 sessizce
// düşen profil yazmaları — hepsi aynı gece). Depolama biçimi değiştiğinde
// eski değeri okuyan bir taşıma yoksa kayıp SESSİZ olur: kimse hata görmez,
// yalnız veri gider.
//
// Taşıma bu yüzden saf bir fonksiyondur (`decodeExamList`) ve doğrudan
// sınanır; arayüzden geçmeye gerek yok.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container({String? list, String? legacy}) async {
  SharedPreferences.setMockInitialValues({
    kExamListKey: ?list,
    kExamDateKey: ?legacy,
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  group('taşıma — eski tek tarih KAYBOLMAZ', () {
    test('yalnız v1 varsa tek kayda dönüşür', () {
      final state = decodeExamList(listRaw: null, legacyRaw: '2026-06-20');
      expect(state.entries, hasLength(1));
      expect(state.entries.single.day, DateTime(2026, 6, 20));
      // Ad isteğe bağlı; taşımada uydurulmaz.
      expect(state.entries.single.name, '');
      // Taşınan tek kayıt kendiliğinden öne çıkarılmaz.
      expect(state.priorityId, isNull);
    });

    test('v2 varsa v1 YOK SAYILIR (çift kaynak olmaz)', () {
      final v2 = encodeExamList(
        ExamListState(
          entries: [
            ExamEntry(id: 'a', name: 'AYT', day: DateTime(2027, 1, 1)),
          ],
        ),
      );
      final state = decodeExamList(listRaw: v2, legacyRaw: '2026-06-20');
      expect(state.entries, hasLength(1));
      expect(state.entries.single.name, 'AYT');
    });

    test('v2 BOZUKSA v1e düşülür — sessizce boş dönülmez', () {
      // Sessizce boş dönmek, kullanıcının sınavını yok saymaktır.
      final state = decodeExamList(listRaw: '{bozuk', legacyRaw: '2026-06-20');
      expect(state.entries, hasLength(1));
      expect(state.entries.single.day, DateTime(2026, 6, 20));
    });

    test('v2 boş listeyse v1e DÜŞÜLMEZ (kullanıcı silmiştir)', () {
      // 🔴 Ters iddia. "v2 boşsa v1e bak" deseydik, son sınavını silen
      // kullanıcının kaydı bir sonraki açılışta geri gelirdi.
      final v2 = encodeExamList(const ExamListState());
      final state = decodeExamList(listRaw: v2, legacyRaw: '2026-06-20');
      expect(state.entries, isEmpty);
    });

    test('bozuk tek satır diğerlerini düşürmez', () {
      const raw =
          '{"entries":[{"id":"a","name":"YKS","day":"2026-06-20"},'
          '{"id":"","name":"bozuk","day":"2026-06-21"},'
          '{"id":"c","name":"AYT","day":"gecersiz"},'
          '{"id":"d","name":"Deneme","day":"2026-08-21"}],"priority":null}';
      final state = decodeExamList(listRaw: raw);
      expect(state.entries.map((e) => e.name), ['YKS', 'Deneme']);
    });

    test('listede olmayan öncelik kimliği taşınmaz', () {
      const raw =
          '{"entries":[{"id":"a","name":"YKS","day":"2026-06-20"}],'
          '"priority":"silinmis-kayit"}';
      final state = decodeExamList(listRaw: raw);
      expect(state.priorityId, isNull);
      expect(state.priority, isNull);
    });

    test('üçten fazla kayıt taşınırsa ilk üçü alınır', () {
      final raw = encodeExamList(
        ExamListState(
          entries: [
            for (var i = 0; i < 5; i++)
              ExamEntry(id: '$i', name: 's$i', day: DateTime(2026, 6, 20 + i)),
          ],
        ),
      );
      expect(decodeExamList(listRaw: raw).entries, hasLength(kMaxExamEntries));
    });
  });

  group('davranış', () {
    test('taşınan tarih ilk yazmadan sonra v2ye geçer, v1 SİLİNMEZ', () async {
      final c = await _container(legacy: '2026-06-20');
      addTearDown(c.dispose);
      final sub = c.listen(examListProvider, (_, _) {});
      addTearDown(sub.close);

      expect(c.read(examListProvider).entries, hasLength(1));
      await c.read(examListProvider.notifier).add(
        name: 'AYT',
        day: DateTime(2026, 6, 21),
      );

      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getString(kExamListKey), contains('AYT'));
      // 🔴 v1 fosili bilerek duruyor: yazma başarısız olursa ya da kullanıcı
      // sürümü geri alırsa eski tarih hâlâ yerinde olsun. Bir baytlık fosil,
      // kaybolmuş bir sınav tarihinden ucuzdur.
      expect(prefs.getString(kExamDateKey), '2026-06-20');
    });

    test('en fazla üç kayıt; dördüncü SESSİZCE düşmez, false döner', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final sub = c.listen(examListProvider, (_, _) {});
      addTearDown(sub.close);

      final n = c.read(examListProvider.notifier);
      for (var i = 0; i < kMaxExamEntries; i++) {
        expect(await n.add(name: 's$i', day: DateTime(2026, 6, 20 + i)), isTrue);
      }
      expect(
        await n.add(name: 'fazla', day: DateTime(2026, 7, 1)),
        isFalse,
        reason: 'Sınır aşımı sessizce yutuluyor; çağıran kullanıcıya '
            'söyleyemez.',
      );
      expect(c.read(examListProvider).entries, hasLength(kMaxExamEntries));
    });

    test('öne çıkarma bir ANAHTARdır (aynısına basınca kalkar)', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final sub = c.listen(examListProvider, (_, _) {});
      addTearDown(sub.close);
      final n = c.read(examListProvider.notifier);
      await n.add(name: 'YKS', day: DateTime(2026, 6, 20));
      await n.add(name: 'AYT', day: DateTime(2026, 6, 21));
      final ids = c.read(examListProvider).entries.map((e) => e.id).toList();

      await n.togglePriority(ids[0]);
      expect(c.read(examListProvider).priority?.name, 'YKS');
      // Başkasına basınca öncelik ONA geçer.
      await n.togglePriority(ids[1]);
      expect(c.read(examListProvider).priority?.name, 'AYT');
      // Aynısına basınca işaret kalkar ve kart eşit görünüme döner.
      await n.togglePriority(ids[1]);
      expect(c.read(examListProvider).priority, isNull);
    });

    test('sıralama değişince öncelik KAYMAZ (kimliğe bağlı)', () async {
      // 🔴 Öncelik indeks olarak tutulsaydı, kullanıcı sırayı değiştirince
      // öne çıkan sessizce başka bir sınava atlardı.
      final c = await _container();
      addTearDown(c.dispose);
      final sub = c.listen(examListProvider, (_, _) {});
      addTearDown(sub.close);
      final n = c.read(examListProvider.notifier);
      await n.add(name: 'YKS', day: DateTime(2026, 6, 20));
      await n.add(name: 'AYT', day: DateTime(2026, 6, 21));
      final ids = c.read(examListProvider).entries.map((e) => e.id).toList();
      await n.togglePriority(ids[0]);

      await n.move(ids[0], delta: 1);
      expect(c.read(examListProvider).entries.first.name, 'AYT');
      expect(c.read(examListProvider).priority?.name, 'YKS');
    });

    test('öne çıkan silinince öncelik KALKAR, başkasına atlamaz', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final sub = c.listen(examListProvider, (_, _) {});
      addTearDown(sub.close);
      final n = c.read(examListProvider.notifier);
      await n.add(name: 'YKS', day: DateTime(2026, 6, 20));
      await n.add(name: 'AYT', day: DateTime(2026, 6, 21));
      final ids = c.read(examListProvider).entries.map((e) => e.id).toList();
      await n.togglePriority(ids[0]);

      await n.remove(ids[0]);
      expect(c.read(examListProvider).priority, isNull);
      expect(c.read(examListProvider).entries.single.name, 'AYT');
    });

    test('sıra uçlarda taşmaz', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final sub = c.listen(examListProvider, (_, _) {});
      addTearDown(sub.close);
      final n = c.read(examListProvider.notifier);
      await n.add(name: 'a', day: DateTime(2026, 6, 20));
      await n.add(name: 'b', day: DateTime(2026, 6, 21));
      final ids = c.read(examListProvider).entries.map((e) => e.id).toList();

      await n.move(ids[0], delta: -1);
      await n.move(ids[1], delta: 1);
      expect(c.read(examListProvider).entries.map((e) => e.name), ['a', 'b']);
    });

    test('kaydedilen tarih takvim günüdür, saat taşımaz', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final sub = c.listen(examListProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(examListProvider.notifier).add(
        name: 'YKS',
        day: DateTime(2026, 6, 20, 23, 59),
      );
      expect(c.read(examListProvider).entries.single.day, DateTime(2026, 6, 20));
    });
  });
}
