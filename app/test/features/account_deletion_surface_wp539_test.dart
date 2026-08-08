// WP-539: hesap silme yüzeyi — sessiz düğme, yanlış mesaj ve kaybolan iptal
// kapısı.
//
// 🔴 Denetimin bulduğu yalancı yeşil (B11): `account_settings_screen.dart`
// içindeki `AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi` satırı
// silindiğinde 15 test yeşil kaldı. Ekran katmanının **kodu metne çevirdiğini**
// ölçen hiçbir test yoktu. Aşağıdaki hata tablosu tam olarak o boşluğu kapatır:
// her satır bir switch koluna karşılık gelir.
//
// Ölçülen üç somut kayıp (düzeltmeden önce):
//   * boş şifreyle "Silmeyi planla" → `signInCalls=0 requestCalls=0
//     snackBar=0 dialog=0` — düğme sessizce hiçbir şey yapmıyordu;
//   * yanlış şifre → "Beklenmeyen bir hata oluştu.";
//   * durum sorgusu düşünce aktif istek varken
//     `"Silme planlandı — iptal et"=0` — 14 günlük pencerede **tek iptal
//     kapısı** görünmez oluyordu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/account_deletion_status.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/profile/account_settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Çağrıları sayan ve istenen hatayı fırlatan sahte depo.
///
/// Hata **üretim sabitiyle** (`AuthErrorCode`) kurulur; mesaj kasten anlamsız
/// bir teknik dizedir. Ekran metni mesajdan türetirse test kırmızı düşer.
class _DeletionAuthRepository extends InMemoryAuthRepository {
  _DeletionAuthRepository({
    this.signInError,
    this.statusError = false,
    this.status = AccountDeletionStatus.inactive,
  });

  final AuthException? signInError;

  /// `my_account_deletion_status` RPC'si düşerse: aktif bir istek olsa bile
  /// istemci bunu **bilemez**.
  final bool statusError;
  AccountDeletionStatus status;

  int signInCalls = 0;
  int requestCalls = 0;
  int cancelCalls = 0;
  int statusCalls = 0;

  @override
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final error = signInError;
    if (error != null) throw error;
    return super.signIn(email: email, password: password);
  }

  @override
  Future<AccountDeletionStatus> requestAccountDeletion() async {
    requestCalls++;
    status = AccountDeletionStatus(
      active: true,
      purgeAfter: DateTime.utc(2026, 8, 22),
    );
    return status;
  }

  @override
  Future<AccountDeletionStatus> cancelAccountDeletion() async {
    cancelCalls++;
    status = AccountDeletionStatus.inactive;
    return status;
  }

  @override
  Future<AccountDeletionStatus> fetchAccountDeletionStatus() async {
    statusCalls++;
    if (statusError) throw const AuthException('status rpc down');
    return status;
  }
}

Future<_DeletionAuthRepository> _pumpScreen(
  WidgetTester tester, {
  AuthException? signInError,
  bool statusError = false,
  AccountDeletionStatus status = AccountDeletionStatus.inactive,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final repo = _DeletionAuthRepository(
    signInError: signInError,
    statusError: statusError,
    status: status,
  );
  await repo.signUp(
    email: 'ali@ornek.com',
    password: 'guvenli123',
    displayName: 'Ali',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// "Hesabı sil" kartını açar (silme kartı, ikonla bulunur — metin dile bağlı).
Future<void> _openDeleteDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.delete_forever));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('deleteAccountPassword')), findsOneWidget);
}

void main() {
  group('WP-539 silme diyalogu: sessiz dugme kapandi', () {
    testWidgets('bos sifre: istek gonderilmez ama kullanici NEDEN gorur', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);
      await _openDeleteDialog(tester);

      await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Mevcut şifreni gir.'),
        findsOneWidget,
        reason:
            'ölçüm: eskiden hiçbir şey olmuyordu '
            '(signInCalls=0 requestCalls=0 snackBar=0 dialog=0)',
      );
      expect(
        find.byKey(const Key('deleteAccountPassword')),
        findsOneWidget,
        reason: 'diyalog açık kalmalı; kapanırsa kullanıcı yine hiçbir şey '
            'olmadığını sanır',
      );
      expect(repo.signInCalls, 0);
      expect(repo.requestCalls, 0);
    });

    testWidgets('dolu sifre: istek gonderilir ve tarih gosterilir', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);
      await _openDeleteDialog(tester);
      await tester.enterText(
        find.byKey(const Key('deleteAccountPassword')),
        'guvenli123',
      );
      await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
      await tester.pumpAndSettle();

      expect(repo.signInCalls, 1);
      expect(repo.requestCalls, 1);
      expect(find.textContaining('Silme planlandı. Son tarih:'), findsOneWidget);
    });

    // 🔴 Denetleyici üst ekranda kuruluyor ve diyalog kapanma animasyonu
    // sürerken senkron `dispose()` ediliyordu: "A TextEditingController was
    // used after being disposed" atılıyor, asenkron akış kesiliyor ve hata
    // snackbar'ı **hiç** görünmüyordu.
    testWidgets('dispose edilmis denetleyici istisnasi atilmaz', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        signInError: const AuthException(
          'server said invalid_credentials',
          code: AuthErrorCode.invalidCredentials,
        ),
      );
      await _openDeleteDialog(tester);
      await tester.enterText(
        find.byKey(const Key('deleteAccountPassword')),
        'yanlissifre',
      );
      await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Mevcut şifre hatalı.'), findsOneWidget);
    });
  });

  group('WP-539 silme hatalari: her kod dogru cumleye donusur', () {
    const cases = <String, String>{
      AuthErrorCode.invalidCredentials: 'Mevcut şifre hatalı.',
      AuthErrorCode.rateLimited: 'Çok sık denedin. Biraz bekleyip tekrar dene.',
      AuthErrorCode.network:
          'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.',
      AuthErrorCode.noSession: 'Oturum bulunamadı. Yeniden giriş yap.',
    };

    cases.forEach((code, expected) {
      testWidgets('$code -> "$expected"', (tester) async {
        final repo = await _pumpScreen(
          tester,
          signInError: AuthException('server said $code', code: code),
        );
        await _openDeleteDialog(tester);
        await tester.enterText(
          find.byKey(const Key('deleteAccountPassword')),
          'guvenli123',
        );
        await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
        await tester.pumpAndSettle();

        expect(
          find.text(expected),
          findsOneWidget,
          reason: 'ekran $code kodunu katalog cümlesine çevirmedi',
        );
        expect(
          find.text('Beklenmeyen bir hata oluştu.'),
          findsNothing,
          reason: 'bilinen bir neden generic mesaja düşürülmemeli',
        );
        expect(
          repo.requestCalls,
          0,
          reason: 'yeniden doğrulama düştüyse silme isteği açılmamalı',
        );
      });
    });

    testWidgets('bilinmeyen kod generic mesaja duser', (tester) async {
      await _pumpScreen(
        tester,
        signInError: const AuthException('boom', code: 'kim_bilir'),
      );
      await _openDeleteDialog(tester);
      await tester.enterText(
        find.byKey(const Key('deleteAccountPassword')),
        'guvenli123',
      );
      await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
      await tester.pumpAndSettle();

      expect(find.text('Beklenmeyen bir hata oluştu.'), findsOneWidget);
    });
  });

  group('WP-539 iptal kapisi: durum sorgusu dusse de kaybolmaz', () {
    testWidgets('sorgu hata verince iptal kapisi hala ekranda', (tester) async {
      final repo = await _pumpScreen(
        tester,
        statusError: true,
        status: AccountDeletionStatus(
          active: true,
          purgeAfter: DateTime.utc(2026, 8, 22),
        ),
      );

      expect(
        find.text('Silme planlandı — iptal et'),
        findsOneWidget,
        reason:
            'ölçüm: eskiden 0 — bekleyen istek varken kart sessizce '
            '"Hesabı sil"e dönüyor ve 14 günlük pencerede iptal imkânsız '
            'hâle geliyordu',
      );
      expect(
        find.text(
          'Silme durumu okunamadı. Bekleyen bir isteğin varsa buradan '
          'iptal edebilirsin.',
        ),
        findsOneWidget,
        reason: 'kullanıcı durumun bilinmediğini de bilmeli',
      );

      // Kapı ölü anahtar değil: dokununca gerçekten iptal RPC'si gidiyor.
      await tester.tap(find.text('Silme planlandı — iptal et'));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls, 1);
      expect(find.text('Silme isteği iptal edildi.'), findsOneWidget);
    });

    testWidgets('hata halinde sorguyu yeniden denemek mumkun', (tester) async {
      final repo = await _pumpScreen(tester, statusError: true);
      final before = repo.statusCalls;

      await tester.tap(find.byKey(const Key('accountDeletionStatusRetry')));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, greaterThan(before));
    });

    testWidgets('aktif istek varken kart iptal kapisini gosterir', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        status: AccountDeletionStatus(
          active: true,
          purgeAfter: DateTime.utc(2026, 8, 22),
        ),
      );

      expect(find.text('Silme planlandı — iptal et'), findsOneWidget);
      expect(find.text('Hesabı sil'), findsNothing);
    });
  });

  group('WP-539 durum sorgusu her cizimde yeniden acilmaz', () {
    testWidgets('ekran birden cok kez cizilse de tek RPC', (tester) async {
      final repo = await _pumpScreen(tester);
      expect(repo.statusCalls, 1);

      // Ekranı birkaç kez yeniden çizdir (görünüm boyutu değişimi tüm ağacı
      // yeniden kurar — eski kodda her çizim yeni bir RPC demekti).
      for (var i = 0; i < 3; i++) {
        tester.view.physicalSize = Size(1080, 2400 - i.toDouble());
        await tester.pumpAndSettle();
      }

      expect(
        repo.statusCalls,
        1,
        reason:
            '`future:` build içinde kurulursa her çizimde yeni bir RPC açılır '
            've gösterge sıfırdan yüklenir',
      );
    });

    testWidgets('istek ve iptal sonrasi durum bir kez tazelenir', (
      tester,
    ) async {
      final repo = await _pumpScreen(tester);
      expect(repo.statusCalls, 1);

      await _openDeleteDialog(tester);
      await tester.enterText(
        find.byKey(const Key('deleteAccountPassword')),
        'guvenli123',
      );
      await tester.tap(find.byKey(const Key('deleteAccountSubmit')));
      await tester.pumpAndSettle();

      expect(repo.statusCalls, 2, reason: 'istek sonrası bir kez tazelenmeli');
      expect(find.text('Silme planlandı — iptal et'), findsOneWidget);
    });
  });
}
