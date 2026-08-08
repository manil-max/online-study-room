// WP-530: hesap oluşturma ve grup kurma akışlarında geri bildirim.
//
// Sahip saha notu (2026-08-08): "grup kurarken 'kur' dedim, 5-6 sn boş boş bir
// şey gelmedi… bu arada 2. kez denedim". Bu **kozmetik değil**: düzeltmeden
// önce alınan ölçümde ikinci deneme ikinci `createGroup` çağrısını gerçekten
// gönderiyordu (prob çıktısı: `toplam createGroup çağrısı = 2`) — yani iki
// gerçek grup. Buradaki testler o kapıyı kilitler.
//
// 🔴 Riverpod 3 tuzağı: `authStateProvider` dinleyicisiz okunursa her `read`
// yeniden kurulur ve `.value` sonsuza dek null kalır; `createGroupFlow` sessizce
// hiçbir şey yapmaz ve test "yeşil" görünürdü. Harness bu yüzden provider'ı
// `watch` ile canlı tutar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi flutter_riverpod 3'te bu yardımcı kütüphaneden gelir.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/auth/auth_screen.dart';
import 'package:online_study_room/features/classroom/widgets/class_switcher.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sahadaki 5-6 sn'lik sunucu turunu taklit eder ve çağrıyı sayar.
class _SlowGroupRepository extends InMemoryGroupRepository {
  _SlowGroupRepository(this.delay);

  final Duration delay;
  int createCalls = 0;

  @override
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
    GroupVisibility visibility = GroupVisibility.private,
    int memberLimit = kDefaultGroupMemberLimit,
    String timeZone = kDefaultGroupTimeZone,
  }) async {
    createCalls++;
    await Future<void>.delayed(delay);
    return super.createGroup(
      name: name,
      creator: creator,
      visibility: visibility,
      memberLimit: memberLimit,
      timeZone: timeZone,
    );
  }
}

/// Kayıt sonucu iki uçlu: ya oturum açılır ya da e-posta doğrulaması beklenir.
/// İkinci uç `SupabaseAuthRepository.signUp` içindeki gerçek metinle aynı
/// cümleyi fırlatır — ekran o cümleye göre dallanıyor.
class _SignUpAuthRepository extends InMemoryAuthRepository {
  _SignUpAuthRepository({this.verificationRequired = false});

  final bool verificationRequired;

  @override
  Future<Profile> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (verificationRequired) {
      throw const AuthException(
        'Hesabın oluşturuldu. Giriş yapabilmek için e-postana gönderilen '
        'doğrulama bağlantısına tıkla.',
      );
    }
    return super.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }
}

class _CreateGroupHarness extends ConsumerWidget {
  const _CreateGroupHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider); // Riverpod 3: provider'ı canlı tut.
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => FilledButton(
            onPressed: () => createGroupFlow(ctx, ref),
            child: const Text('harness-create'),
          ),
        ),
      ),
    );
  }
}

void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _app(Widget home, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  group('grup kurma geri bildirimi', () {
    late _SlowGroupRepository repo;
    late InMemoryAuthRepository auth;

    Future<void> pumpFlow(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      auth = InMemoryAuthRepository();
      await auth.signUp(
        email: 'kurucu@ornek.com',
        password: '123456',
        displayName: 'Kurucu',
      );
      repo = _SlowGroupRepository(const Duration(seconds: 5));
      _useTallPhone(tester);

      await tester.pumpWidget(
        _app(const _CreateGroupHarness(), [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(repo),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('harness-create'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Deneme Grubu');
      await tester.pump();
    }

    testWidgets('iki kez basılsa da tek grup kurulur', (tester) async {
      await pumpFlow(tester);

      final submit = find.byKey(const Key('create-group-submit'));
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kullanıcının "1.de sorun mu vardı" anı: aynı düğmeye ikinci basış.
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // İstek hâlâ uçuyor; sonuç henüz gelmedi.
      expect(repo.createCalls, 1, reason: 'İkinci basış ikinci grup kurdu.');

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(
        repo.createCalls,
        1,
        reason: 'İstek bittikten sonra da tek çağrı kalmalı.',
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Grup oluşturuldu.'), findsOneWidget);
    });

    testWidgets('istek sürerken ilerleme göstergesi ekranda', (tester) async {
      await pumpFlow(tester);

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Basmadan önce gösterge olmamalı.',
      );

      await tester.tap(find.byKey(const Key('create-group-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'Diyalog kapanırsa kullanıcı yine boş ekrana bakar.',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Kuruluyor…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('kayıt sonrası onay', () {
    Future<void> fillAndSubmit(WidgetTester tester) async {
      await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Görünen ad'),
        'Yeni Kullanıcı',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'yeni@ornek.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        '123456',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
      await tester.pumpAndSettle();
    }

    testWidgets('oturum açılan kayıtta "hesabın hazır" onayı görünür', (
      tester,
    ) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(const AuthScreen(), [
          authRepositoryProvider.overrideWithValue(_SignUpAuthRepository()),
        ]),
      );
      await tester.pumpAndSettle();
      await fillAndSubmit(tester);

      expect(find.byKey(const Key('signup-confirmation')), findsOneWidget);
      expect(find.text('Hesabın oluşturuldu'), findsOneWidget);
      expect(
        find.text('Hesabın hazır. Hemen başlayabilirsin.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-confirmation')), findsNothing);
    });

    testWidgets('doğrulama gereken kayıtta "e-postana bak" onayı görünür', (
      tester,
    ) async {
      _useTallPhone(tester);
      await tester.pumpWidget(
        _app(const AuthScreen(), [
          authRepositoryProvider.overrideWithValue(
            _SignUpAuthRepository(verificationRequired: true),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await fillAndSubmit(tester);

      expect(find.byKey(const Key('signup-confirmation')), findsOneWidget);
      expect(find.text('Hesabın oluşturuldu'), findsOneWidget);
      expect(
        find.text(
          'Giriş yapabilmek için e-postana gönderdiğimiz doğrulama '
          'bağlantısına tıkla.',
        ),
        findsOneWidget,
      );

      // Onay kapanınca ekran giriş moduna döner (eskiden tek yaptığı buydu).
      await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-confirmation')), findsNothing);
      expect(find.text('Hesabın yok mu? Kayıt ol'), findsOneWidget);
      expect(find.text('E-posta doğrulaması gerekiyor.'), findsOneWidget);
    });
  });
}
