// WP-748: oturum akisi TEK bir gecici hatada KALICI olarak oluyor.
//
// 🔴 WP-741 cevrimiciyken cikan sahte "Internet yok" seridinin iki kok nedenini
// kapatti (butce dolar dolmaz iddia + geri alma yok). Ayni turda UCUNCU bir yol
// olculdu ve acik birakildi: seridi asan sey her zaman butce degil, tek bir
// ISTEK HATASI da olabiliyor -- ve o hata akisi da OLDURUYOR.
//
// Sahte serit burada yalnizca SEMPTOM. Asil kusur: oturum akisi tek bir gecici
// hatada kalicI olarak oluyor. Olurse o oturum boyunca kullanicinin auth
// durumu bir daha HIC guncellenmez: giris/cikis/token tazeleme olaylarinin
// hicbiri ekrana ulasmaz.
//
// Bu dosya iki ucu olcer:
//
//   (1) IDDIA DISIPLINI (kablo ucu) -- cihaz cevrimiciyken butceden ONCE gelen
//       tek bir istek hatasi "Internet yok" iddiasini KURMAMALI. Bir HATA,
//       cevrimdisiligin kaniti degildir. Cevrimdisiligin olculen imzasi
//       SESSIZLIKTIR: `kAuthColdStartBudget` belgesindeki zincir 10 sn token
//       tazeleme + 10 sn istek tavani, yani ~20 sn SESSIZLIK -- 200 ms'de
//       donen bir hata degil.
//
//   (2) DAYANIKLILIK (depo) -- `SupabaseAuthRepository.authStateChanges()`
//       tek bir hatadan sonra CANLI kalmali: hata iletilir ama akis surer,
//       sonraki oturum olaylari akmaya devam eder. Boylece WP-741'in geri
//       alma mekanizmasi bu yolda da calisabilir.
//
// Zaman ENJEKTE edilir (widget testinde `tester.pump(<sure>)`, depo testinde
// sifir gecikmeli tur bekleme); gercek saate/aga bagli tek bir bekleme yoktur.
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
import 'package:online_study_room/data/repositories/supabase/supabase_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_gate.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../support/supabase_wire_harness.dart';

const _userId = 'user-1';

/// Gercek dunyada gotrue'nun gecici ag/5xx hatasi icin urettigi tip
/// (`GotrueFetch._handleError`: `Response` degilse veya status >= 500).
supa.AuthRetryableFetchException _transientError() =>
    supa.AuthRetryableFetchException(
      message: 'Failed host lookup: odak-kampi.supabase.co',
    );

Profile _profile(String id, {String name = 'Onbellekteki Ad', int goal = 111}) {
  return Profile(
    id: id,
    displayName: name,
    createdAt: DateTime.utc(2026, 1, 1),
    dailyGoalMinutes: goal,
  );
}

/// Oturum akisi konusmadan once tek bir hata dusuren depo.
class _FlakyAuthRepository extends InMemoryAuthRepository {
  final _controller = StreamController<Profile?>.broadcast();

  @override
  Stream<Profile?> authStateChanges() => _controller.stream;

  void emit(Profile? profile) => _controller.add(profile);

  void fail(Object error) => _controller.addError(error);
}

Map<String, dynamic> _authResponse() => {
  'access_token': 'test-access-token',
  'refresh_token': 'test-refresh-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': _userId,
    'email': 'ali@example.com',
    'aud': 'authenticated',
    'created_at': '2026-08-01T10:00:00Z',
    'app_metadata': <String, dynamic>{},
    'user_metadata': {'display_name': 'Ali'},
  },
};

/// Gercek PostgREST/gotrue kablosuyla, oturum acmis bir depo.
class _Wired {
  _Wired(this.wire, this.client, this.repository);

  final SupabaseWireHarness wire;
  final supa.SupabaseClient client;
  final SupabaseAuthRepository repository;
}

Future<_Wired> _signedIn() async {
  final wire = SupabaseWireHarness();
  wire.respond('token', _authResponse());
  wire.respond('profiles', [
    {
      'id': _userId,
      'display_name': 'Ali',
      'avatar_url': null,
      'created_at': '2026-08-01T10:00:00Z',
      'title_achievement_id': null,
    },
  ]);
  final client = wire.client();
  final repository = SupabaseAuthRepository(client);
  await repository.signIn(email: 'ali@example.com', password: 'guvenli123');
  wire.calls.clear();
  return _Wired(wire, client, repository);
}

/// Askidaki mikro gorevlerin akmasi icin birkac tur.
Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  // -------------------------------------------------------------------------
  // (1) KABLO UCU -- iddia disiplini
  // -------------------------------------------------------------------------
  group('WP-748 kablo ucu: hata "internet yok"un kaniti degildir', () {
    testWidgets(
      'cihaz CEVRIMICI, butce HIC dolmadi, tek bir istek hatasi -> '
      'serit HIC gorunmez',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = _FlakyAuthRepository();

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

        // 200 ms: butce (2 sn) HIC dolmadi. Tek bir istek hatasi duser.
        await tester.pump(const Duration(milliseconds: 200));
        repo.fail(_transientError());
        await tester.pump();
        await tester.pump();

        // WP-603 kazanimi korunur: yerel oturumu olan kullanici ICERI girer,
        // cikissiz hata ekraninda kalmaz.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'hata dali kullaniciyi yine iceri almali (WP-603)',
        );

        // Butce + zarif bekleme sonuna kadar bekle.
        await tester.pump(kAuthColdStartBudget);
        await tester.pump();
        await tester.pump(kOfflineNoticeGrace);
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const Key('auth-gate-offline-notice')),
          findsNothing,
          reason:
              'bir HATA cevrimdisiligin kaniti degildir; cevrimdisiligin '
              'olculen imzasi SESSIZLIKTIR (~20 sn), 200 ms\'de donen hata '
              'degil',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // (2) AKIS SOZLESMESI + KALICILIK -- depo
  // -------------------------------------------------------------------------
  group('WP-748 depo: oturum akisi tek hatada OLMEZ', () {
    test('hatadan SONRA yayilan gercek profil tuketiciye ULASIR', () async {
      SharedPreferences.setMockInitialValues({});
      final wired = await _signedIn();
      final emitted = <Profile?>[];
      final errors = <Object>[];
      var closed = false;

      final sub = wired.repository.authStateChanges().listen(
        emitted.add,
        onError: errors.add,
        onDone: () => closed = true,
      );
      addTearDown(sub.cancel);
      await _settle();
      emitted.clear();

      // 🔴 GERCEK uretim yolu: gecici bir ag/5xx hatasinda gotrue
      // `notifyException` cagirir ve hatayi `onAuthStateChange` akisina KOYAR
      // (gotrue_client.dart `_executeRefresh` -> `notifyException`). Oturum
      // SILINMEZ; kullanici hala giris yapmis durumdadir.
      // ignore: invalid_use_of_internal_member
      wired.client.auth.notifyException(_transientError());
      await _settle();

      expect(errors, hasLength(1), reason: 'hata YUTULMAMALI');

      // Cihaz cevrimici: bir sonraki gercek profil yayini gelir.
      await wired.repository.updateDisplayName('Ayse');
      await _settle();

      expect(
        emitted.map((p) => p?.displayName).toList(),
        contains('Ayse'),
        reason:
            'tek gecici hata sonrasi akis olurse kullanicinin auth durumu o '
            'oturum boyunca bir daha HIC guncellenmez',
      );
      expect(closed, isFalse);
    });

    test('hatadan SONRA oturum olaylari akmaya DEVAM eder', () async {
      SharedPreferences.setMockInitialValues({});
      final wired = await _signedIn();
      final emitted = <Profile?>[];
      var closed = false;

      final sub = wired.repository.authStateChanges().listen(
        emitted.add,
        onError: (_) {},
        onDone: () => closed = true,
      );
      addTearDown(sub.cancel);
      await _settle();
      emitted.clear();

      // ignore: invalid_use_of_internal_member
      wired.client.auth.notifyException(_transientError());
      await _settle();

      expect(
        closed,
        isFalse,
        reason: 'tek gecici hata oturum akisini KAPATMAMALI',
      );

      // Gercek bir OTURUM olayi (profil mutasyonu degil): cikis.
      await wired.repository.signOut();
      await _settle();

      expect(
        emitted,
        isNotEmpty,
        reason:
            'akis canli kalmaliydi: cikis olayi ekrana ulasmazsa kullanici '
            'cikis yaptigi halde uygulamada asili kalir',
      );
      expect(emitted.last, isNull, reason: 'cikis -> profil null');
    });

    test('hata SIKI bir yeniden abonelik dongusu baslatmaz', () async {
      SharedPreferences.setMockInitialValues({});
      final wired = await _signedIn();
      final errors = <Object>[];

      final sub = wired.repository.authStateChanges().listen(
        (_) {},
        onError: errors.add,
      );
      addTearDown(sub.cancel);
      await _settle();

      // ignore: invalid_use_of_internal_member
      wired.client.auth.notifyException(_transientError());
      await _settle();
      await _settle();

      // gotrue'nun `onAuthStateChange`i bir `BehaviorSubject`tir: son olayi
      // yeni abonelere TEKRAR OYNATIR. Hatadan sonra kaynaga yeniden abone
      // olan bir duzeltme, ayni hatayi sonsuz dongude okurdu.
      expect(
        errors,
        hasLength(1),
        reason: 'tek hata tek kez iletilmeli, dongu kurmamali',
      );
    });
  });
}
