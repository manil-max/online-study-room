// 🔴 WP-626 — kullanıcıya GÖNDERİLMEYEN bir e-postanın açık anahtarı.
//
// Denetim (`docs/denetim/DENETIM-sunucu-admin.md`, KANAMA-1) iddiası: aylık
// rapor e-postası hiç gönderilmiyor. Kodda doğrulandı ve iddiadan daha kötü
// çıktı — zincir TEK yerden değil DÖRT yerden kopuk:
//
//   1. `send-report`'u hiçbir cron / iş akışı / istemci çağırmıyor.
//   2. Ne `send-report` ne `collect-reports` HİÇBİR YERDE deploy edilmiyor
//      (`supabase functions deploy` yalnız `purge-accounts` ve `dispatch-push`
//      için var). Yani cron'un POST attığı uç nokta sunucuda yok; denetimin
//      "kuyruk her ay büyüyor" cümlesi de doğru değil, kuyruk hiç dolmuyor.
//   3. `RESEND_API_KEY` hiçbir iş akışında tanımlanmıyor. Anahtar yokken eski
//      `send-report` taklit dalına düşüp işi **`sent` işaretliyordu**: zinciri
//      düzeltmeden cron'a bağlamak, görünür boşluğu görünmez yalana çevirirdi.
//   4. Şablondaki iptal bağlantısı (`app.odakkampi.com/unsubscribe`) hiçbir
//      yerde karşılanmıyor; `email_unsubscribe_tokens.used_at` hiç yazılmıyor.
//
// Bu yüzden yol (B) seçildi: **vaadi geri çek**. Anahtar tercihi kaydetmeye
// devam ediyor ama artık gönderimin başlamadığını söylüyor.
//
// 🔴 Kapı İKİ UÇLU. Bu depoda "iki uç birbirinden habersiz metin olarak
// yaşıyordu" hatası defalarca üretime çıktı; burada uçlar birbirine bağlandı:
//
//   * Zincir bağlı DEĞİLSE  → arayüz vaat etmemeli ("Yakında" görünmeli).
//   * Zincir bağlanIRSA     → bu kapı KIRMIZI düşer ve vaadi geri açmayı
//                             emreder. Yani "yakında" etiketi sonsuza kadar
//                             unutulup kalamaz.
//
// 🔴 Deno bu makinede kurulu değil; `send-report` KOŞTURULARAK ölçülemedi.
// Sunucu ucundaki iddialar bu yüzden kaynak üzerinden yapılıyor ve bilinçli
// olarak dar tutuldu: yorum satırları ayıklanıp yalnız KOŞAN gövde ölçülüyor
// (aksi hâlde tam da kovaladığımız hata — "yorumda geçiyor, kodda yok" —
// kapının kendisini kandırırdı).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/notifications/notification_permissions_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final sendReport = _read('../supabase/functions/send-report/index.ts');
  final workflows = _workflowSources();

  /// Gönderim zinciri gerçekten bağlı mı? İki ucu da ARANIR: fonksiyonun
  /// sunucuya gitmesi (deploy) **ve** onu tetikleyen bir çağıran.
  bool deliveryChainWired() {
    final deployed = workflows.values.any(
      (yml) => _stripComments(yml).contains('functions deploy send-report'),
    );
    final invoked = workflows.values.any(
      (yml) => _stripComments(yml).contains('functions/v1/send-report'),
    );
    return deployed || invoked;
  }

  Future<InMemoryAuthRepository> pump(
    WidgetTester tester, {
    required bool signedIn,
  }) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = InMemoryAuthRepository();
    addTearDown(repo.dispose);
    if (signedIn) {
      await repo.signUp(
        email: 'ali@ornek.com',
        password: 'guvenli123',
        displayName: 'Ali',
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationPermissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(NotificationPermissionsScreen)),
  );

  SwitchListTile reportTile(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(const Key('monthly-report-opt-in')));

  group('WP-626/1 — arayüz ucu: var olmayan özellik vaat edilmiyor', () {
    testWidgets('anahtar gönderimin başlamadığını SÖYLER', (tester) async {
      await pump(tester, signedIn: true);
      final l10n = l10nOf(tester);

      final badge = find.byKey(const Key('monthly-report-coming-soon'));
      await tester.ensureVisible(
        find.byKey(const Key('monthly-report-opt-in')),
      );
      await tester.pumpAndSettle();

      expect(
        badge,
        findsOneWidget,
        reason:
            'ölçüm: eskiden 0 — kullanıcı açık bir anahtar görüyor ve her ay '
            'gelmeyecek bir e-posta bekliyordu.',
      );
      expect(find.text(l10n.notificationsAylikRaporYakinda), findsOneWidget);
      expect(
        find.text(l10n.notificationsAylikRaporHenuzGonderilmiyor),
        findsOneWidget,
        reason: 'Gönderimin başlamadığı kullanıcıya yazıyla söylenmeli.',
      );
    });

    testWidgets('eski yanıltıcı alt satır kaldırıldı', (tester) async {
      await pump(tester, signedIn: true);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.profileOzetlerVeKullaniciRaporlari),
        findsNothing,
        reason:
            'Bu dize aslında YÖNETİM kartının metniydi; buraya kopyalanıp '
            '"özetler sana geliyor" izlenimini pekiştiriyordu.',
      );
    });

    testWidgets('profil bilinmiyorken anahtar KAPALI başlar', (tester) async {
      await pump(tester, signedIn: false);
      expect(
        reportTile(tester).value,
        isFalse,
        reason:
            'ölçüm: eskiden true — profil yokken bile ekran "açık" gösteriyordu. '
            'Bilinmeyen durumun varsayılanı vaat değil sessizlik olmalı.',
      );
      expect(
        reportTile(tester).onChanged,
        isNull,
        reason: 'Profil yokken kaydedilecek bir tercih de yok.',
      );
    });
  });

  group('WP-626/2 — sunucu ucu: sessiz "gönderildi" yalanı kapatıldı', () {
    test('sağlayıcı anahtarı yokken hiçbir kuyruk satırına dokunulmaz', () {
      final body = _stripComments(sendReport);
      expect(
        body,
        contains("RESEND_API_KEY_MISSING"),
        reason:
            'ölçüm: eskiden yok — anahtar tanımlı değilken fonksiyon taklit '
            'dalına düşüp işi `sent` işaretliyordu. Kuyruk boşalıyor, e-posta '
            'gitmiyor, geriye "gönderildi" yazan satır kalıyordu.',
      );
      final guard = body.indexOf('RESEND_API_KEY_MISSING');
      final firstUpdate = body.indexOf("from('email_job_queue')");
      expect(
        guard,
        lessThan(firstUpdate),
        reason:
            'Reddetme kuyruğa dokunmadan ÖNCE olmalı; sonra olursa satırlar '
            'zaten kirlenmiş olur.',
      );
    });

    test('taklit yalnız açıkça `mock` yazıldığında sürer', () {
      final body = _stripComments(sendReport);
      expect(
        body,
        isNot(contains("RESEND_API_KEY && RESEND_API_KEY !== 'mock'")),
        reason:
            'Eski koşul "anahtar yok" ile "mock" durumlarını AYNI dala '
            'sokuyordu; üretimde eksik yapılandırma sessizce taklide düşerdi.',
      );
      expect(body, contains("RESEND_API_KEY !== 'mock'"));
    });
  });

  group('WP-626/3 — iki ucu bağlayan kapı', () {
    test('zincir bağlanırsa arayüzdeki "yakında" geri alınmalı', () {
      // 🔴 Bu bilinçli bir tuzak telidir. Bugün zincir bağlı değil ve kapı
      // yeşil. Biri `send-report`'u deploy eden veya çağıran bir adım
      // eklediği an burası KIRMIZI düşer ve şunu emreder:
      //   * `notification_permissions_screen.dart` içindeki "Yakında" rozetini
      //     ve `notificationsAylikRaporHenuzGonderilmiyor` alt satırını kaldır,
      //   * bu dosyadaki WP-626/1 iddialarını yeni davranışa çevir.
      // Böylece "yakında" etiketi ne yanlışlıkla kalır ne de zincir sessizce
      // bağlanıp arayüz habersiz kalır.
      expect(
        deliveryChainWired(),
        isFalse,
        reason:
            'Aylık rapor gönderim zinciri bağlanmış görünüyor. Arayüz hâlâ '
            '"Yakında" diyorsa kullanıcı bu kez TERS yönde yanıltılıyor: '
            'e-posta gidiyor ama ekran gitmiyor diyor. Vaadi geri aç.',
      );
    });

    test('bugün zincir gerçekten kopuk: ne deploy var ne çağıran', () {
      // Ölçüm ters yönden: yukarıdaki tuzak telinin BOŞ bir iddia olmadığını
      // gösterir. `functions deploy` geçen tüm iş akışlarını sayar.
      final deployedFunctions = <String>{};
      for (final yml in workflows.values) {
        for (final m in RegExp(
          r'functions deploy ([a-z0-9-]+)',
        ).allMatches(_stripComments(yml))) {
          deployedFunctions.add(m.group(1)!);
        }
      }
      expect(
        deployedFunctions,
        isNotEmpty,
        reason:
            'Hiç deploy adımı bulunamadı — düzenli ifade artık tutmuyor, kapı '
            'hiçbir şey ölçmüyor demektir.',
      );
      expect(
        deployedFunctions,
        isNot(contains('send-report')),
        reason: 'Fonksiyon sunucuya hiç gitmiyor.',
      );
      expect(
        deployedFunctions,
        isNot(contains('collect-reports')),
        reason:
            'Kuyruğu dolduran fonksiyon da deploy edilmiyor; `0035` cron\'unun '
            'POST attığı uç nokta sunucuda yok.',
      );
    });
  });
}

/// `.github/workflows` altındaki tüm iş akışları (dosya adı → içerik).
Map<String, String> _workflowSources() {
  final dir = Directory('../.github/workflows');
  if (!dir.existsSync()) {
    // `main()` gövdesinde, yani test dışında çağrılıyor: `fail()` burada
    // `OutsideTestException` fırlatır ve gerçek nedeni gizler.
    throw StateError(
      'İş akışı dizini bulunamadı: ${dir.path} '
      '(çalışma dizini: ${Directory.current.path})',
    );
  }
  final out = <String, String>{};
  for (final entry in dir.listSync()) {
    if (entry is File && entry.path.endsWith('.yml')) {
      out[entry.uri.pathSegments.last] = entry.readAsStringSync();
    }
  }
  if (out.isEmpty) {
    throw StateError('Hiç iş akışı okunamadı: ${dir.path}');
  }
  return out;
}

/// Yorum satırlarını ayıklar. Kapı KOŞAN gövdeyi ölçmeli; bu depoda
/// `send-report` adı yalnız yorumlarda geçtiği için metin araması yanıltıyor.
String _stripComments(String source) => source
    .split('\n')
    .where((line) {
      final t = line.trimLeft();
      return !t.startsWith('#') && !t.startsWith('//') && !t.startsWith('*');
    })
    .join('\n');

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Sözleşme dosyası bulunamadı: $path '
      '(çalışma dizini: ${Directory.current.path})',
    );
  }
  return file.readAsStringSync();
}
