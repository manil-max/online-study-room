// 🔴 WP-610 — profil yazmalari AG HATASINDA sessizce kayboluyordu.
//
// Duzeltmeden ONCE olculen davranis (denetim: docs/denetim/DENETIM-auth.md
// KANAMA-2). Dort yazma yolu da hatayi YANLIS turden bekliyordu:
//
//   * settings_screen.dart:82  `on AuthException` (gunluk hedef)
//   * settings_screen.dart:60  hic `try` yok        (kamp hayvani)
//   * profile_screen.dart:277  `on AuthException`   (gorunen ad)
//   * profile_screen.dart:309  `on AuthException`   (avatar)
//
// Oysa bu cagrilar `AuthException` ATMAZ: ag/sunucu hatasi PostgREST'ten
// `PostgrestException`, soketten `SocketException`, Storage'dan
// `StorageException` olarak gelir. Yakalama dali gercek hatanin yanindan
// gecip `observability_service.dart` icindeki global yutucuya gidiyordu —
// ekranda ne hata ne onay kaliyordu.
//
// 🔴 Bu dosyanin sahte deposu bilerek **AuthException DISI** hata atar.
// `AuthException` atan bir sahte depo tam da bu kusuru olcemez; kusurun bugune
// kadar gozden kacmasinin sebebi budur (bkz. ilk grup: "on kosul").
//
// Her yol icin IKI YONLU iddia var: hata varken uyari CIKAR, basaride CIKMAZ
// (ve basari mesaji gorunur). Sabotaj: dort `catch` dalindan biri daraltilirsa
// ya da basari SnackBar'i silinirse bu dosya kirmiziya doner.
//
// 🔴 WP-710 (proje sahibi emri) iki yolun YUZEYINI degistirdi; iddialar
// silinmedi, tasindi:
//   * gunluk hedef  -> Ayarlar'dan kaldirildi; kanonik yer sayac kartindaki
//     hedef satiri (`study_timer_card.dart` `_editGoal`, WP-619 ayni kusuru
//     orada da kapatmisti). Ayarlar'a ozel iki mesaj artik hic cizilmedigi
//     icin olculen uyari kartin genel mesajidir.
//   * kamp hayvani  -> Ayarlar'dan Gruplar'a tasindi; satırın kendisi
//     `CampAnimalTile` (`profile/widgets/camp_animal_picker.dart`). Mesajlar
//     aynen korundu. Satirin Gruplar ekranina BAGLI oldugu ayri olculur:
//     `test/features/classroom/camp_animal_moved_wp710_test.dart`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette degil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:online_study_room/core/animals/camp_animal.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/profile/profile_screen.dart';
import 'package:online_study_room/features/profile/widgets/camp_animal_picker.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, StorageException;

/// Ag/sunucu hatasini **gercekci** turlerle taklit eden depo.
///
/// `error` doluyken dort profil yazmasi da onu atar. Turler bilincli secildi:
/// PostgREST guncellemesi `PostgrestException`, Storage yuklemesi
/// `StorageException`, kopuk baglanti `SocketException` uretir. Hicbiri
/// `AuthException` DEGILDIR.
/// Gercek notifier kanal/dinleyici kurar; burada olculen sey yazma geri
/// bildirimi, sayacin kendisi degil.
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

class _NetworkFailingAuthRepository extends InMemoryAuthRepository {
  Object? error;

  /// Moderasyon reddi ayri dal: bu gercekten `AuthException` olarak gelir ve
  /// kullaniciya OZEL mesaj gosterilmelidir (WP-517 davranisi korunmali).
  bool rejectPublicName = false;

  int goalCalls = 0;
  int animalCalls = 0;
  int nameCalls = 0;
  int avatarCalls = 0;
  String? lastAvatarContentType;

  @override
  Future<void> updateDailyGoal(int minutes) async {
    goalCalls++;
    if (error != null) throw error!;
    return super.updateDailyGoal(minutes);
  }

  @override
  Future<void> updateAnimal(String animal) async {
    animalCalls++;
    if (error != null) throw error!;
    return super.updateAnimal(animal);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    nameCalls++;
    if (rejectPublicName) {
      throw const AuthException('public_name_not_allowed');
    }
    if (error != null) throw error!;
    return super.updateDisplayName(displayName);
  }

  @override
  Future<void> updateAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    avatarCalls++;
    lastAvatarContentType = contentType;
    if (error != null) throw error!;
    // Bellek-ici taban sinif burada her zaman atar (gercek depolama yok);
    // basari yolunu olcebilmek icin sessizce basarili sayilir.
  }
}

PostgrestException _postgrestFailure() => const PostgrestException(
  message: 'Failed host lookup: db.supabase.co',
  code: '500',
);

StorageException _storageFailure() =>
    const StorageException('Failed host lookup: storage.supabase.co');

const _socketFailure = SocketException('Connection reset by peer');

/// Bir PNG'nin imza baytlari; yukleme sahte oldugu icin icerik onemsiz.
final _pngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x01, 0x02, 0x03,
]);

void main() {
  Widget app(List<Override> overrides, Widget home) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Future<_NetworkFailingAuthRepository> signedUpRepo() async {
    final auth = _NetworkFailingAuthRepository();
    addTearDown(auth.dispose);
    await auth.signUp(
      email: 'ben@example.com',
      password: 'gizli123',
      displayName: 'Ben',
    );
    return auth;
  }

  Future<SharedPreferences> emptyPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  void wideView(WidgetTester tester) {
    // `goal_editor_dialog.dart` 360dp'de tasiyor (WP-555 notu); bu dosya
    // geri bildirimi olcer, dar ekran yerlesimini degil.
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('on kosul - sahte depo GERCEK ag hatasi atar', () {
    test('dort yazma da AuthException DISI bir hata firlatir', () async {
      final auth = await signedUpRepo();

      auth.error = _postgrestFailure();
      await expectLater(
        auth.updateDailyGoal(240),
        throwsA(
          allOf(isA<PostgrestException>(), isNot(isA<AuthException>())),
        ),
      );
      await expectLater(
        auth.updateAnimal('koala'),
        throwsA(isNot(isA<AuthException>())),
      );

      auth.error = _socketFailure;
      await expectLater(
        auth.updateDisplayName('Yeni Ad'),
        throwsA(
          allOf(isA<SocketException>(), isNot(isA<AuthException>())),
        ),
      );

      auth.error = _storageFailure();
      await expectLater(
        auth.updateAvatar(bytes: _pngBytes, contentType: 'image/png'),
        throwsA(
          allOf(isA<StorageException>(), isNot(isA<AuthException>())),
        ),
      );
    });
  });

  group('1 - gunluk hedef (sayac karti)', () {
    Future<_NetworkFailingAuthRepository> pump(WidgetTester tester) async {
      final prefs = await emptyPrefs();
      final auth = await signedUpRepo();
      wideView(tester);
      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          userSessionsProvider.overrideWith(
            (_) => Stream.value(const <StudySession>[]),
          ),
          userSubjectsProvider.overrideWith(
            (_) => Stream.value(const <Subject>[]),
          ),
          userGroupProvider.overrideWithValue(
            const AsyncData<StudyGroup?>(null),
          ),
          studyTimerProvider.overrideWith(_IdleTimerNotifier.new),
        ], const Scaffold(
          body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
        )),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    Future<void> editGoal(WidgetTester tester) async {
      await tester.tap(find.text('Günlük hedef'));
      await tester.pumpAndSettle();
      // Dakika sutununun "+" tusu.
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byIcon(Icons.add),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
    }

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(StudyTimerCard)));

    testWidgets('ag hatasinda kullaniciya SOYLENIR', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);

      auth.error = _postgrestFailure();
      await editGoal(tester);

      expect(auth.goalCalls, 1);
      expect(
        find.text(l10n.authBeklenmeyenBirHataOlustu),
        findsOneWidget,
        reason:
            'Yazma dustu ama ekran sessiz kaldi: `catch` dali yine gercek '
            'hatanin yanindan geciyor.',
      );
      // Deger gercekten kaydedilmedi.
      expect(auth.currentUser?.dailyGoalMinutes, 360);
    });

    testWidgets('basaride hata CIKMAZ, deger yazilir', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);

      await editGoal(tester);

      expect(auth.goalCalls, 1);
      expect(auth.currentUser?.dailyGoalMinutes, 361);
      expect(find.text(l10n.authBeklenmeyenBirHataOlustu), findsNothing);
    });
  });

  group('2 - kamp hayvani (tasinan satir)', () {
    Future<_NetworkFailingAuthRepository> pump(WidgetTester tester) async {
      final prefs = await emptyPrefs();
      final auth = await signedUpRepo();
      wideView(tester);
      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ], const Scaffold(body: Center(child: CampAnimalTile()))),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    /// Su an gosterilenden FARKLI bir hayvan secer ve id'sini dondurur.
    Future<CampAnimal> pickOther(
      WidgetTester tester,
      _NetworkFailingAuthRepository auth,
    ) async {
      final shown = campAnimalFor(
        userId: auth.currentUser!.id,
        animalId: auth.currentUser!.animal,
      );
      final target = kCampAnimals.firstWhere((a) => a.id != shown.id);
      await tester.tap(find.byKey(kCampAnimalTileKey));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CampAnimalTile)),
      );
      await tester.tap(find.text(target.label(l10n)).last);
      await tester.pumpAndSettle();
      return target;
    }

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(CampAnimalTile)));

    testWidgets('ag hatasinda kullaniciya SOYLENIR', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);
      expect(
        l10n.profileKampHayvaniKaydedilemedi,
        isNot(l10n.profileKampHayvaniGuncellendi),
      );

      auth.error = _postgrestFailure();
      final target = await pickOther(tester, auth);

      expect(auth.animalCalls, 1);
      expect(find.text(l10n.profileKampHayvaniKaydedilemedi), findsOneWidget);
      expect(find.text(l10n.profileKampHayvaniGuncellendi), findsNothing);
      // Kaydedilmeyen secim ekranda da benimsenmez.
      expect(auth.currentUser?.animal, isNot(target.id));
    });

    testWidgets('basaride onay cikar, hata CIKMAZ', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);

      final target = await pickOther(tester, auth);

      expect(auth.animalCalls, 1);
      expect(auth.currentUser?.animal, target.id);
      expect(find.text(l10n.profileKampHayvaniGuncellendi), findsOneWidget);
      expect(find.text(l10n.profileKampHayvaniKaydedilemedi), findsNothing);
    });
  });

  group('3 - gorunen ad (Profil)', () {
    Future<_NetworkFailingAuthRepository> pump(WidgetTester tester) async {
      final prefs = await emptyPrefs();
      final auth = await signedUpRepo();
      wideView(tester);
      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ], const ProfileScreen()),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    Future<void> rename(WidgetTester tester, String value) async {
      await tester.tap(find.byTooltip('Adı düzenle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        value,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();
    }

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(ProfileScreen)));

    testWidgets('ag hatasinda kullaniciya SOYLENIR', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);
      expect(
        l10n.profileGorunenAdKaydedilemedi,
        isNot(l10n.profileGorunenAdGuncellendi),
      );

      auth.error = _socketFailure;
      await rename(tester, 'Yeni Ad');

      expect(auth.nameCalls, 1);
      expect(find.text(l10n.profileGorunenAdKaydedilemedi), findsOneWidget);
      expect(find.text(l10n.profileGorunenAdGuncellendi), findsNothing);
      expect(auth.currentUser?.displayName, 'Ben');
    });

    testWidgets('basaride onay cikar, hata CIKMAZ', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);

      await rename(tester, 'Yeni Ad');

      expect(auth.nameCalls, 1);
      expect(auth.currentUser?.displayName, 'Yeni Ad');
      expect(find.text(l10n.profileGorunenAdGuncellendi), findsOneWidget);
      expect(find.text(l10n.profileGorunenAdKaydedilemedi), findsNothing);
    });

    testWidgets('moderasyon reddi kendi OZEL mesajini korur', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);

      auth.rejectPublicName = true;
      await rename(tester, 'Yeni Ad');

      expect(find.text(l10n.moderationPublicNameRejected), findsOneWidget);
      expect(find.text(l10n.profileGorunenAdKaydedilemedi), findsNothing);
      expect(find.text(l10n.profileGorunenAdGuncellendi), findsNothing);
    });
  });

  group('4 - profil fotografi (Profil)', () {
    Future<_NetworkFailingAuthRepository> pump(WidgetTester tester) async {
      final prefs = await emptyPrefs();
      final auth = await signedUpRepo();
      wideView(tester);
      await tester.pumpWidget(
        app([
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          // Galeri adimi sahte: OS secici yerine bellekten bir PNG doner.
          avatarImagePickerProvider.overrideWithValue(
            () async => XFile.fromData(
              _pngBytes,
              mimeType: 'image/png',
              name: 'avatar.png',
            ),
          ),
        ], const ProfileScreen()),
      );
      await tester.pumpAndSettle();
      return auth;
    }

    Future<void> tapCamera(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.photo_camera));
      await tester.pumpAndSettle();
    }

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(ProfileScreen)));

    testWidgets('yukleme hatasinda kullaniciya SOYLENIR', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);
      expect(
        l10n.profileProfilFotografiYuklenemedi,
        isNot(l10n.profileProfilFotografiGuncellendi),
      );

      auth.error = _storageFailure();
      await tapCamera(tester);

      expect(auth.avatarCalls, 1);
      expect(auth.lastAvatarContentType, 'image/png');
      expect(find.text(l10n.profileProfilFotografiYuklenemedi), findsOneWidget);
      expect(find.text(l10n.profileProfilFotografiGuncellendi), findsNothing);
    });

    testWidgets('basaride onay cikar, hata CIKMAZ', (tester) async {
      final auth = await pump(tester);
      final l10n = l10nOf(tester);

      await tapCamera(tester);

      expect(auth.avatarCalls, 1);
      expect(find.text(l10n.profileProfilFotografiGuncellendi), findsOneWidget);
      expect(find.text(l10n.profileProfilFotografiYuklenemedi), findsNothing);
    });
  });
}
