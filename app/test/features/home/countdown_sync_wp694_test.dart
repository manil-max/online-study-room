// WP-694 — sinav geri sayimi cihazlar arasi senkron.
//
// 🔴 Bu dosyanin varlik sebebi olculdu, varsayilmadi. Gercek bir kullanici
// "telefon ve tablette ayri ayri ayarlanmasi gerekiyor, senkronize degil"
// dedi. Duzeltmeden ONCE asagidaki ilk test kirmizi dustu ve sayi soyleydi:
//
//   Expected: ['YKS']
//     Actual: MappedListIterable<ExamEntry, String>:[]
//
// Yani ikinci cihazda SIFIR kayit vardi: `dday_prefs.dart` yalnizca
// `SharedPreferences`'a yaziyordu ve `supabase/migrations/` icinde geri sayim
// tablosu yoktu. Ozellik eksikti, tercih degildi.
//
// Iki cihaz nasil taklit ediliyor: her cihaz KENDI bos `SharedPreferences`
// deposuyla ve KENDI `ProviderContainer`'iyla acilir; paylasilan tek sey
// bellek ici depodur — yani sunucu. Boylece "ayni hesap, iki cihaz" iddiasi
// gercekten olculur, kopyalanan bir prefs haritasi degil.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/exam_countdown.dart';
import 'package:online_study_room/data/providers/exam_countdown_providers.dart';
import 'package:online_study_room/data/repositories/exam_countdown_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_exam_countdown_repository.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = 'user-1';

/// Sunucuya ulasamayan depo — ucak modu.
class _OfflineRepository implements ExamCountdownRepository {
  var offline = true;
  final ExamCountdownRepository inner;

  _OfflineRepository(this.inner);

  @override
  Future<List<ExamCountdown>> load({required String userKey}) {
    if (offline) throw const SocketishFailure();
    return inner.load(userKey: userKey);
  }

  @override
  Future<void> upsert({
    required String userKey,
    required ExamCountdown entry,
  }) {
    if (offline) throw const SocketishFailure();
    return inner.upsert(userKey: userKey, entry: entry);
  }

  @override
  Future<void> delete({required String userKey, required String id}) {
    if (offline) throw const SocketishFailure();
    return inner.delete(userKey: userKey, id: id);
  }
}

class SocketishFailure implements Exception {
  const SocketishFailure();
}

/// Bir cihaz: bos yerel depo + kendi container'i.
Future<ProviderContainer> _device({
  ExamCountdownRepository? server,
  String? userId = _user,
  DateTime? now,
  Map<String, Object> seed = const {},
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      examCountdownRepositoryProvider.overrideWithValue(server),
      examCountdownUserIdProvider.overrideWithValue(userId),
      if (now != null) ddayClockProvider.overrideWithValue(() => now),
    ],
  );
}

/// 🔴 Riverpod 3: dinleyicisi olmayan provider her `read`de yeniden build olur
/// ve acilis turunu bastan baslatir. Her cihaz once dinlenir, sonra okunur.
Future<ProviderSubscription<ExamListState>> _open(ProviderContainer c) async {
  final sub = c.listen(examListProvider, (_, _) {});
  await c.read(examListProvider.notifier).synced;
  return sub;
}

void main() {
  group('ayni hesap, iki cihaz', () {
    test('telefonda girilen sinav tablette GORUNUR', () async {
      final server = InMemoryExamCountdownRepository();

      final phone = await _device(server: server);
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);
      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 6, 20));
      expect(phone.read(examListProvider).entries, hasLength(1));
      expect(
        server.rowsOf(_user),
        hasLength(1),
        reason: 'Yerel yazma sunucuya hic gitmemis.',
      );

      final tablet = await _device(server: server);
      addTearDown(tablet.dispose);
      final tabletSub = await _open(tablet);
      addTearDown(tabletSub.close);

      expect(
        tablet.read(examListProvider).entries.map((e) => e.name),
        ['YKS'],
        reason: 'Telefonda girilen sinav tablette bastan giriliyor.',
      );
      expect(
        tablet.read(examListProvider).entries.single.day,
        DateTime(2026, 6, 20),
      );
    });

    test('bir cihazda SILINEN kayit digerinde de kaybolur', () async {
      final server = InMemoryExamCountdownRepository();

      final phone = await _device(server: server);
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);
      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 6, 20));

      // Tablet once senkron olur (kimlik `synced` kumesine girer)...
      final tablet = await _device(server: server);
      addTearDown(tablet.dispose);
      final tabletSub = await _open(tablet);
      addTearDown(tabletSub.close);
      expect(tablet.read(examListProvider).entries, hasLength(1));
      final saved = tablet.read(examListProvider);

      // ...sonra telefon siler.
      final id = phone.read(examListProvider).entries.single.id;
      await phone.read(examListProvider.notifier).remove(id);
      expect(server.rowsOf(_user), isEmpty);

      // Tablet yeniden acilir: bayat yerel kopya kaydi GERI DOGURMAZ.
      final rebooted = await _device(
        server: server,
        seed: {kExamListKey: encodeExamList(saved)},
      );
      addTearDown(rebooted.dispose);
      final rebootedSub = await _open(rebooted);
      addTearDown(rebootedSub.close);
      expect(
        rebooted.read(examListProvider).entries,
        isEmpty,
        reason: 'Silinen sinav bayat yerel kopyadan zombi gibi geri dogdu.',
      );
      expect(server.rowsOf(_user), isEmpty);
    });

    test('ayni kaydi iki cihaz duzenlerse SON YAZAN kazanir', () async {
      final server = InMemoryExamCountdownRepository();
      final t1 = DateTime.utc(2026, 6, 1, 10);
      final t2 = DateTime.utc(2026, 6, 1, 11);

      final phone = await _device(server: server, now: t1);
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);
      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 6, 20));
      final id = phone.read(examListProvider).entries.single.id;
      final stale = phone.read(examListProvider);

      // Tablet daha YENI bir damgayla adi degistirir.
      final tablet = await _device(server: server, now: t2);
      addTearDown(tablet.dispose);
      final tabletSub = await _open(tablet);
      addTearDown(tabletSub.close);
      await tablet.read(examListProvider.notifier).update(id, name: 'AYT');

      // Telefon bayat kopyasiyla yeniden acilir: sunucudaki yeni ad kazanir.
      final rebooted = await _device(
        server: server,
        now: t1,
        seed: {kExamListKey: encodeExamList(stale)},
      );
      addTearDown(rebooted.dispose);
      final rebootedSub = await _open(rebooted);
      addTearDown(rebootedSub.close);
      expect(rebooted.read(examListProvider).entries.single.name, 'AYT');
    });

    test('yerel damga daha YENIYSE sunucuya tasinir', () async {
      final server = InMemoryExamCountdownRepository();
      final t1 = DateTime.utc(2026, 6, 1, 10);
      final t3 = DateTime.utc(2026, 6, 1, 12);

      final phone = await _device(server: server, now: t1);
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);
      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 6, 20));
      final id = phone.read(examListProvider).entries.single.id;

      // Tablet cevrimdisiyken duzenler (damga t3), sonra aga kavusur.
      final flaky = _OfflineRepository(server);
      final tablet = await _device(server: flaky, now: t3);
      addTearDown(tablet.dispose);
      final tabletSub = await _open(tablet);
      addTearDown(tabletSub.close);
      // Cevrimdisiyken hicbir sey cizilemedigi icin once senkron olalim:
      flaky.offline = false;
      tablet.invalidate(examListProvider);
      await tablet.read(examListProvider.notifier).synced;
      flaky.offline = true;
      await tablet.read(examListProvider.notifier).update(id, name: 'TYT');
      flaky.offline = false;

      tablet.invalidate(examListProvider);
      await tablet.read(examListProvider.notifier).synced;
      expect(server.rowsOf(_user).single.name, 'TYT');
    });
  });

  group('yerelden sunucuya tasima — WP-694 oncesi kayitlar KAYBOLMAZ', () {
    test('damgasiz yerel kayit ilk acilista yukari tasinir', () async {
      final server = InMemoryExamCountdownRepository();
      // WP-694 oncesi bicim: ne `updatedAt`, ne `synced`, ne `deleted`.
      const legacyBlob =
          '{"entries":[{"id":"1723-0","name":"YKS","day":"2026-06-20"}],'
          '"priority":null}';

      final phone = await _device(
        server: server,
        seed: {kExamListKey: legacyBlob},
      );
      addTearDown(phone.dispose);
      final sub = await _open(phone);
      addTearDown(sub.close);

      expect(phone.read(examListProvider).entries.single.name, 'YKS');
      expect(
        server.rowsOf(_user).map((r) => r.name),
        ['YKS'],
        reason: 'Var olan yerel kayit hicbir zaman sunucuya cikmadi.',
      );
      expect(server.rowsOf(_user).single.id, '1723-0');
    });

    test('v1 tek tarih (legacy) da yukari tasinir', () async {
      final server = InMemoryExamCountdownRepository();
      final phone = await _device(
        server: server,
        seed: {kExamDateKey: '2026-06-20'},
      );
      addTearDown(phone.dispose);
      final sub = await _open(phone);
      addTearDown(sub.close);

      expect(server.rowsOf(_user).single.day, DateTime(2026, 6, 20));
      // v1 fosili SILINMEZ.
      expect(
        phone.read(sharedPreferencesProvider).getString(kExamDateKey),
        '2026-06-20',
      );
    });

    test('iki cihazdaki AYNI sinav ilk senkronda tek kayda iner', () async {
      // 🔴 WP-694 oncesi kimlikler cihaz-yereldi: ayni sinav telefonda ve
      // tablette FARKLI kimlik tasiyor. Ikisini de yukari itmek kullaniciya
      // ayni sinavi iki kez gosterirdi.
      final server = InMemoryExamCountdownRepository();
      const phoneBlob =
          '{"entries":[{"id":"phone-1","name":"YKS","day":"2026-06-20"}],'
          '"priority":null}';
      const tabletBlob =
          '{"entries":[{"id":"tablet-9","name":"yks","day":"2026-06-20"}],'
          '"priority":null}';

      final phone = await _device(
        server: server,
        seed: {kExamListKey: phoneBlob},
      );
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);

      final tablet = await _device(
        server: server,
        seed: {kExamListKey: tabletBlob},
      );
      addTearDown(tablet.dispose);
      final tabletSub = await _open(tablet);
      addTearDown(tabletSub.close);

      expect(server.rowsOf(_user), hasLength(1));
      expect(tablet.read(examListProvider).entries, hasLength(1));
    });
  });

  group('cevrimdisi', () {
    test('internetsiz acilista geri sayim GORUNMEYE DEVAM eder', () async {
      final offline = _OfflineRepository(InMemoryExamCountdownRepository());
      const blob =
          '{"entries":[{"id":"a","name":"YKS","day":"2026-06-20"}],'
          '"priority":null,"synced":["a"],"deleted":[]}';

      final phone = await _device(server: offline, seed: {kExamListKey: blob});
      addTearDown(phone.dispose);
      final sub = await _open(phone);
      addTearDown(sub.close);

      expect(
        phone.read(examListProvider).entries.map((e) => e.name),
        ['YKS'],
        reason: 'Ag yokken liste bosaltildi: kullanicinin tarihi silindi.',
      );
      // Yerel kopya da bozulmamis olmali.
      expect(
        phone.read(sharedPreferencesProvider).getString(kExamListKey),
        contains('YKS'),
      );
    });

    test('cevrimdisi eklenen sinav ag gelince yukari cikar', () async {
      final server = InMemoryExamCountdownRepository();
      final flaky = _OfflineRepository(server);
      final phone = await _device(server: flaky);
      addTearDown(phone.dispose);
      final sub = await _open(phone);
      addTearDown(sub.close);

      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 6, 20));
      expect(server.rowsOf(_user), isEmpty);
      expect(phone.read(examListProvider).entries, hasLength(1));

      flaky.offline = false;
      phone.invalidate(examListProvider);
      await phone.read(examListProvider.notifier).synced;
      expect(server.rowsOf(_user).map((r) => r.name), ['YKS']);
    });

    test('cevrimdisi SILINEN sinav ag gelince GERI GELMEZ', () async {
      final server = InMemoryExamCountdownRepository();
      final flaky = _OfflineRepository(server)..offline = false;
      final phone = await _device(server: flaky);
      addTearDown(phone.dispose);
      final sub = await _open(phone);
      addTearDown(sub.close);
      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 6, 20));
      final id = phone.read(examListProvider).entries.single.id;

      flaky.offline = true;
      await phone.read(examListProvider.notifier).remove(id);
      expect(phone.read(examListProvider).entries, isEmpty);
      expect(server.rowsOf(_user), hasLength(1), reason: 'Silme ag ustunden gitti?');
      expect(phone.read(examListProvider).pendingDeletes, contains(id));

      flaky.offline = false;
      phone.invalidate(examListProvider);
      await phone.read(examListProvider.notifier).synced;
      expect(
        phone.read(examListProvider).entries,
        isEmpty,
        reason: 'Ucakta silinen sinav inisde geri geldi.',
      );
      expect(server.rowsOf(_user), isEmpty);
    });
  });

  group('sinir ve oncelik', () {
    test('uc kaydi asan birlesme SESSIZ degildir', () async {
      final server = InMemoryExamCountdownRepository();
      final phone = await _device(server: server);
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);
      for (var i = 0; i < kMaxExamEntries; i++) {
        await phone
            .read(examListProvider.notifier)
            .add(name: 's$i', day: DateTime(2026, 6, 20 + i));
      }
      expect(server.rowsOf(_user), hasLength(kMaxExamEntries));

      // Tablet, sunucudan habersiz kendi dorduncusunu tasiyor.
      const tabletBlob =
          '{"entries":[{"id":"tablet-x","name":"DGS","day":"2026-09-01"}],'
          '"priority":null}';
      final tablet = await _device(
        server: server,
        seed: {kExamListKey: tabletBlob},
      );
      addTearDown(tablet.dispose);
      final tabletSub = await _open(tablet);
      addTearDown(tabletSub.close);

      expect(tablet.read(examListProvider).entries, hasLength(kMaxExamEntries));
      expect(
        tablet.read(examCountdownDropProvider),
        1,
        reason: 'Sinir asimindan dusen kayit hicbir iz birakmadi.',
      );
    });

    test('one cikarma cihazlar arasi tasinir ve TEK kalir', () async {
      final server = InMemoryExamCountdownRepository();
      final phone = await _device(server: server);
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);
      final notifier = phone.read(examListProvider.notifier);
      await notifier.add(name: 'YKS', day: DateTime(2026, 6, 20));
      await notifier.add(name: 'AYT', day: DateTime(2026, 6, 21));
      final ids = phone.read(examListProvider).entries.map((e) => e.id).toList();
      await notifier.togglePriority(ids[1]);

      final tablet = await _device(server: server);
      addTearDown(tablet.dispose);
      final tabletSub = await _open(tablet);
      addTearDown(tabletSub.close);
      expect(tablet.read(examListProvider).priority?.name, 'AYT');
      expect(
        server.rowsOf(_user).where((r) => r.isPriority),
        hasLength(1),
      );
    });
  });

  group('oturum yoksa davranis DEGISMEZ', () {
    test('kullanici kimligi null ise sunucuya hic dokunulmaz', () async {
      final server = InMemoryExamCountdownRepository();
      final phone = await _device(server: server, userId: null);
      addTearDown(phone.dispose);
      final sub = await _open(phone);
      addTearDown(sub.close);
      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 6, 20));

      expect(phone.read(examListProvider).entries, hasLength(1));
      expect(server.loads, 0);
      expect(server.writes, 0);
    });
  });

  group('KULLANICININ GORDUGU SATIR', () {
    testWidgets('ikinci cihazda kart sinavi GERCEKTEN cizer', (tester) async {
      final server = InMemoryExamCountdownRepository();

      final phone = await _device(server: server);
      addTearDown(phone.dispose);
      final phoneSub = await _open(phone);
      addTearDown(phoneSub.close);
      await phone
          .read(examListProvider.notifier)
          .add(name: 'YKS', day: DateTime(2026, 8, 20));

      // Ikinci cihaz: bos yerel depo, ayni hesap, gercek pano karti.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.utc(2026, 8, 10, 9);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            examCountdownRepositoryProvider.overrideWithValue(server),
            examCountdownUserIdProvider.overrideWithValue(_user),
            ddayClockProvider.overrideWithValue(() => now),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 340,
                  child: dashboardCardFor(
                    DashboardCardType.dday,
                    DashboardCardSize.medium,
                    height: 260,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 🔴 Once GOVDENIN GERCEK oldugunu dogrula: hata kabugu da widget tipi
      // esler. Kart cizilirken istisna atmadi ve bos dala DUSMEDI.
      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        find.text(l10n.homeSinavTarihiSecilmedi),
        findsNothing,
        reason: 'Ikinci cihaz hala "tarih secilmedi" diyor.',
      );
      // Kullanicinin GORDUGU satir: sinavin adi ve kalan gun.
      expect(find.text('YKS'), findsOneWidget);
      expect(find.text(l10n.homeSinavaKalanGun(10)), findsOneWidget);
    });
  });
}
