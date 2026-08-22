// WP-603: internet yokken uygulama acilmiyordu.
//
// 🔴 Gercek kullanici (proje sahibi, 2026-08-09, metroda): "internete sahip
// olmadigimda uygulama 20 saniye boyunca 'yukleniyor' diye durdu, acilmadi."
//
// Olculen zincir (`docs/analiz/WP-603-cevrimdisi-acilis.md`):
//   `authStateProvider` ilk olayini `SupabaseAuthRepository._sessionProfiles`
//   uretir; o da ilk `yield`den ONCE `profiles` satirini ceker. Istek
//   `AuthHttpClient.send` icinden gecer, bu sarmalayici ISTEKTEN ONCE
//   `_getAccessToken()` bekler ve suresi dolmus oturumda gotrue'nun yeniden
//   deneme dongusune girer (~10 sn). Ancak ONDAN SONRA govde WP-542'nin 10
//   saniyelik `TimeoutHttpClient` tavanina ulasir. 10 + 10 = kullanicinin
//   saydigi 20 saniye. WP-542 tavani zincirin yalniz ikinci yarisini kapsar.
//
// Bu dosya sozlesmeyi iki uctan olcer:
//   (1) SAF UC — `authStateWithOfflineFallback`: kaynak susarsa yerel oturum
//       yayinlanir; kaynak konusursa yedek HIC calismaz.
//   (2) KABLO UCU — gercek `authStateProvider` + gercek `AuthGate`: yedegin
//       uretimde gercekten bagli oldugu. (Bu deponun tekrar eden hatasi
//       "yazilmis ama cagiran yok"; saf uc tek basina onu yakalamaz.)
//
// Zaman ENJEKTE edilir (`budget` parametresi), gercek saate/aga bagli tek bir
// bekleme yoktur.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/push_notification_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/offline/offline_cache_store.dart';
import 'package:online_study_room/features/auth/auth_gate.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _budget = Duration(milliseconds: 40);

Profile _profile(String id, {String name = 'Onbellekteki Ad', int goal = 111}) {
  return Profile(
    id: id,
    displayName: name,
    createdAt: DateTime.utc(2026, 1, 1),
    dailyGoalMinutes: goal,
  );
}

/// Oturum akisi hic cevap vermeyen depo (ag yok).
class _SilentAuthRepository extends InMemoryAuthRepository {
  final _controller = StreamController<Profile?>.broadcast();

  @override
  Stream<Profile?> authStateChanges() => _controller.stream;

  void emit(Profile? profile) => _controller.add(profile);

  void fail(Object error) => _controller.addError(error);
}

void main() {
  // -------------------------------------------------------------------------
  // (1) SAF UC — akis sozlesmesi
  // -------------------------------------------------------------------------
  group('WP-603 saf uc: authStateWithOfflineFallback', () {
    test('ag yokken butce dolunca yerel oturum yayinlanir', () async {
      final source = StreamController<Profile?>();
      addTearDown(source.close);
      var offlineOpens = 0;

      final events = <Profile?>[];
      final sub = authStateWithOfflineFallback(
        source: source.stream,
        localProfile: () async => _profile('u1'),
        budget: _budget,
        onOfflineOpen: () => offlineOpens++,
      ).listen(events.add);
      addTearDown(sub.cancel);

      // Butce dolmadan once HICBIR sey yayinlanmaz: cevrimici acilis bir kare
      // erken bayat profil gostermemeli.
      await Future<void>.delayed(_budget ~/ 2);
      expect(events, isEmpty);

      await Future<void>.delayed(_budget * 3);
      expect(events, hasLength(1));
      expect(events.single?.id, 'u1');
      expect(
        events.single?.dailyGoalMinutes,
        111,
        reason:
            'yedek onbellekteki GERCEK profili tasimali; metadata yedegi gunluk '
            'hedefi varsayilana dusurur',
      );
      expect(offlineOpens, 1);
    });

    test('ag varken yedek HIC calismaz (cevrimici davranis bozulmaz)', () async {
      final source = StreamController<Profile?>();
      addTearDown(source.close);
      var localReads = 0;
      var offlineOpens = 0;
      final remote = <Profile>[];

      final events = <Profile?>[];
      final sub = authStateWithOfflineFallback(
        source: source.stream,
        localProfile: () async {
          localReads++;
          return _profile('u1');
        },
        budget: _budget,
        onRemoteProfile: remote.add,
        onOfflineOpen: () => offlineOpens++,
      ).listen(events.add);
      addTearDown(sub.cancel);

      source.add(_profile('u1', name: 'Sunucudan', goal: 222));
      await Future<void>.delayed(_budget * 3);

      expect(events, hasLength(1));
      expect(events.single?.displayName, 'Sunucudan');
      expect(offlineOpens, 0);
      expect(localReads, 0, reason: 'butce zamanlayicisi iptal edilmeliydi');
      expect(
        remote.single.dailyGoalMinutes,
        222,
        reason: 'sunucudan gelen profil bir sonraki acilis icin onbellege gider',
      );
    });

    test('gec gelen gercek profil yedegin ustune yazar, tersi olmaz', () async {
      final source = StreamController<Profile?>();
      addTearDown(source.close);

      final events = <Profile?>[];
      final sub = authStateWithOfflineFallback(
        source: source.stream,
        localProfile: () async => _profile('u1', name: 'Yedek'),
        budget: _budget,
      ).listen(events.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(_budget * 3);
      source.add(_profile('u1', name: 'Sunucudan'));
      await Future<void>.delayed(_budget);

      expect(events.map((p) => p?.displayName), ['Yedek', 'Sunucudan']);
    });

    test('kaynak hatasi yerel oturum varsa aciliş ile karsilanir', () async {
      final source = StreamController<Profile?>();
      addTearDown(source.close);
      final errors = <Object>[];

      final events = <Profile?>[];
      final sub = authStateWithOfflineFallback(
        source: source.stream,
        localProfile: () async => _profile('u1'),
        budget: const Duration(days: 1),
      ).listen(events.add, onError: errors.add);
      addTearDown(sub.cancel);

      source.addError(StateError('offline'));
      await Future<void>.delayed(_budget);

      expect(events.single?.id, 'u1');
      expect(
        errors,
        isEmpty,
        reason:
            'hata ekraninin "Tekrar dene"/"Cikis yap" cikislari cevrimdisi '
            'kullaniciya kapali kapidir',
      );
    });

    test('yerel oturum YOKKEN hata gizlenmez', () async {
      final source = StreamController<Profile?>();
      addTearDown(source.close);
      final errors = <Object>[];

      final events = <Profile?>[];
      final sub = authStateWithOfflineFallback(
        source: source.stream,
        localProfile: () async => null,
        budget: _budget,
      ).listen(events.add, onError: errors.add);
      addTearDown(sub.cancel);

      source.addError(StateError('gercek ariza'));
      await Future<void>.delayed(_budget * 3);

      expect(events, isEmpty);
      expect(errors, hasLength(1));
    });

    test('oturumu olmayan kullanici yedek beklemez, null aynen gecer', () async {
      final source = StreamController<Profile?>();
      addTearDown(source.close);

      final events = <Profile?>[];
      final sub = authStateWithOfflineFallback(
        source: source.stream,
        localProfile: () async => null,
        budget: _budget,
      ).listen(events.add);
      addTearDown(sub.cancel);

      source.add(null);
      await Future<void>.delayed(_budget * 3);

      expect(events, [null]);
    });
  });

  // -------------------------------------------------------------------------
  // (2) ONBELLEK — son bilinen iyi profil
  // -------------------------------------------------------------------------
  group('WP-603 onbellek: OfflineCacheStore profil', () {
    test('yazilan profil aynen geri okunur', () async {
      SharedPreferences.setMockInitialValues({});
      final store = OfflineCacheStore(await SharedPreferences.getInstance());

      expect(store.readProfile(), isNull);
      await store.saveProfile(_profile('u1', name: 'Muhlis', goal: 90));
      final read = store.readProfile();
      expect(read?.id, 'u1');
      expect(read?.displayName, 'Muhlis');
      expect(read?.dailyGoalMinutes, 90);
    });

    test('bozuk kayit acilisi dusurmez, null doner', () async {
      SharedPreferences.setMockInitialValues({
        'offline_cache_v1:profile': 'bu json degil',
      });
      final store = OfflineCacheStore(await SharedPreferences.getInstance());
      expect(store.readProfile(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // (3) KABLO UCU — gercek authStateProvider + gercek AuthGate
  // -------------------------------------------------------------------------
  group('WP-603 kablo ucu: acilis yolu', () {
    testWidgets('ag susarken AuthGate cemberden cikip uygulamayi acar', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _SilentAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(repo),
            pushLifecycleListenerProvider.overrideWithValue(null),
            // Cihazda kalici oturum var: `Supabase.initialize` bunu `runApp`
            // oncesi bellege koyar, ag gerekmez.
            localSessionProfileProvider.overrideWithValue(
              () async => _profile('u1'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AuthGate(),
          ),
        ),
      );
      await tester.pump();

      // Once cember: yedek aninda degil, butce dolunca devreye girer.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(kAuthColdStartBudget);
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason:
            'oturumu olan kullanici ag olmadan da iceri girmeli; onceki davranis '
            '~20 sn donen cember + cikissiz hata ekraniydi',
      );
      // 🔴 WP-741: ACILIS ile IDDIA ayrildi. Uygulama yine 2 sn'de acilir
      // ama "internet yok" cumlesi butce dolar dolmaz kurulmaz; butce bir
      // GECIKME olcusudur, baglanti olcusu degil.
      expect(
        find.byKey(const Key('auth-gate-offline-notice')),
        findsNothing,
        reason: 'iddia zarif bekleme dolmadan kurulmamali',
      );

      await tester.pump(kOfflineNoticeGrace);
      await tester.pump();

      // Ag GERCEKTEN sessiz kaldi: bekleme dolunca WP-603'un kazanimi aynen
      // durur, cevrimdisi acilis SESSIZ olmaz.
      expect(
        find.byKey(const Key('auth-gate-offline-notice')),
        findsOneWidget,
        reason: 'cevrimdisi acilis SESSIZ olmamali',
      );
    });

    testWidgets('ag saglikliyken cevrimdisi seridi HIC gorunmez', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _SilentAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(repo),
            pushLifecycleListenerProvider.overrideWithValue(null),
            localSessionProfileProvider.overrideWithValue(
              () async => _profile('u1'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AuthGate(),
          ),
        ),
      );
      await tester.pump();

      repo.emit(null); // sunucu bicimli cevap: oturum yok -> giris ekrani
      await tester.pump();
      await tester.pump(kAuthColdStartBudget * 2);
      await tester.pump();

      expect(find.byKey(const Key('auth-gate-offline-notice')), findsNothing);
    });

    // -----------------------------------------------------------------------
    // 🔴 WP-741 — ARADAKI durum: ag YAVAS ama VAR.
    //
    // Sahip (2026-08-22, gercek cihaz): "internet bagli olmasina ragmen bazen
    // uygulamayi acinca altta 'internet yok' uyarisi geciyor, ama internet var
    // ve uygulamayi normal kullaniyorum."
    //
    // Yukaridaki iki test agin yalniz IKI UCUNU olcuyor: tamamen sessiz ag ve
    // tamamen saglikli ag. Sahibin gordugu durum ORTADA: butceyi dolduracak
    // kadar yavas ama VAR olan ag. `kAuthColdStartBudget` bir GECIKME
    // olcusudur, baglanti olcusu degil — soguk acilista saglikli agda da
    // dolar. Bu yuzden bayrak kalkar kalkmaz "internet yok" demek SAHTE bir
    // iddiadir; once zarif bir bekleme, sonra gerekiyorsa konusma.
    // -----------------------------------------------------------------------
    testWidgets(
      'ag yavas ama VAR: butce dolar ama akis hemen ardindan konusur -> '
      'serit HIC gorunmez',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = _SilentAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(repo),
              pushLifecycleListenerProvider.overrideWithValue(null),
              localSessionProfileProvider.overrideWithValue(
                () async => _profile('u1'),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AuthGate(),
            ),
          ),
        );
        await tester.pump();

        // Butce dolar -> yerel oturum yayinlanir -> `authOpenedOfflineProvider`
        // TRUE olur. Uygulamanin ACILMASI degismez (WP-603 kazanimi).
        await tester.pump(kAuthColdStartBudget);
        await tester.pump();

        // Iddia HENUZ kurulmadi: bu satir zarif beklemeyi TEK BASINA olcer.
        // (Olmazsa test yalniz "geri alma"yi olcerdi ve kullanicinin gordugu
        // ANLIK PARLAMAYI kacirirdi.)
        expect(
          find.byKey(const Key('auth-gate-offline-notice')),
          findsNothing,
          reason: 'butce dolar dolmaz "internet yok" denmemeli',
        );

        // ...ama ag VARDI, sadece yavasti: gercek profil butcenin hemen
        // ardindan gelir ve `onRemoteProfile` bayragi FALSE'a cevirir.
        repo.emit(_profile('u1', name: 'Sunucudan'));
        await tester.pump();

        // Zarif bekleme dolar. Iddia geri alindigi icin serit HIC asilmamali.
        await tester.pump(kOfflineNoticeGrace);
        await tester.pump();

        expect(
          find.byKey(const Key('auth-gate-offline-notice')),
          findsNothing,
          reason:
              'akis butcenin hemen ardindan konustuysa cihaz CEVRIMICIDIR; '
              'kullaniciya "internet yok" denmemeli',
        );
      },
    );

    // 🔴 WP-741 — geri alma. Serit asildiktan sonra gercek profil
    // gelirse `onRemoteProfile` -> `clear()` bayragi FALSE yapiyordu, ama
    // asilmis SnackBar kendi 6 saniyesini doldurmaya devam ediyordu: kullanici
    // cevrimiciyken ekranda "Internet yok" yazisini okumaya devam ediyordu.
    testWidgets('serit asildiktan sonra gercek profil gelirse serit INDIRILIR', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = _SilentAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(repo),
            pushLifecycleListenerProvider.overrideWithValue(null),
            localSessionProfileProvider.overrideWithValue(
              () async => _profile('u1'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AuthGate(),
          ),
        ),
      );
      await tester.pump();

      // Ag GERCEKTEN sessiz: butce + zarif bekleme dolar, serit asilir.
      await tester.pump(kAuthColdStartBudget);
      await tester.pump();
      await tester.pump(kOfflineNoticeGrace);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('auth-gate-offline-notice')),
        findsOneWidget,
        reason: 'gercekten sessiz agda serit hala asilmali (WP-603 kazanimi)',
      );

      // Ag geri geldi: gec de olsa gercek profil dustu.
      repo.emit(_profile('u1', name: 'Sunucudan'));
      await tester.pump();
      // Serit kendi 6 sn'sini DOLDURMADAN inmeli; asagidaki pump'lar yalniz
      // cikis animasyonunu kapsar (toplam < 1 sn), zaman asimini DEGIL.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('auth-gate-offline-notice')),
        findsNothing,
        reason:
            'iddia geri alinmali: kullanici cevrimiciyken ekranda "Internet '
            'yok" yazisi durmamali',
      );
    });

  });
}
