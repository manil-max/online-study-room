import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/app_build_manifest.dart';
import 'package:online_study_room/core/notifications/timer_panel_preference.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/profile/developer_mode.dart';
import 'package:online_study_room/features/profile/legal_center_screen.dart';
import 'package:online_study_room/features/profile/timer_journal_screen.dart';
import 'package:online_study_room/features/updater/release_notes_screen.dart';
import 'package:online_study_room/features/updater/release_notes_service.dart';
import 'package:online_study_room/features/updater/updater_dialog.dart';
import 'package:online_study_room/features/updater/updater_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/core/config/build_identity_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-419: "Build diagnostics" kartı sürüm notlarından **silinmedi**, buraya
/// taşındı. Destekte "sürümün ne?" cevaplanabilir kalmalı; ama kanal / backend
/// project-ref / commit / migration başı ilk bakışta görünmemeli.
void main() {
  final manifest = AppBuildManifest.resolve(
    channel: 'beta',
    environment: 'staging',
    supabaseUrl: 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
    supabaseAnonKey: 'sb_publishable_test_key',
    selectedProjectRef: 'aaaaaaaaaaaaaaaaaaaa',
    stagingProjectRef: 'aaaaaaaaaaaaaaaaaaaa',
    productionProjectRef: 'bbbbbbbbbbbbbbbbbbbb',
    gitCommitSha: 'abcdef1234567890',
    migrationHead: '0094',
    versionName: '1.0.44-beta.1',
    buildNumber: 4401,
    allowInMemory: false,
    flutterFlavor: 'beta',
  );

  Future<SharedPreferences> pumpAbout(
    WidgetTester tester, {
    AppBuildManifest? build,
    Future<UpdateCheckResult> Function()? updateCheck,
    bool allowsSideloadUpdates = true,
    ReleaseNotesService? releaseNotesService,
    Map<String, Object> initialPrefs = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(initialPrefs);
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AboutScreen(
            buildManifest: build ?? manifest,
            updateCheck: updateCheck,
            allowsSideloadUpdates: allowsSideloadUpdates,
            releaseNotesService: releaseNotesService,
            releaseNotesChannel: 'stable',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return preferences;
  }

  testWidgets('varsayılan olarak yalnız sürüm adı görünür', (tester) async {
    await pumpAbout(tester);

    expect(find.text('Hakkında ve güncellemeler'), findsNWidgets(2));
    expect(find.text('1.0.44-beta.1'), findsOneWidget);

    // Teknik satırlar kapalı.
    expect(find.text('abcdef12'), findsNothing);
    expect(find.text('0094'), findsNothing);
    expect(find.text('staging · aaaaaa…aaaa'), findsNothing);
    expect(find.text('Backend'), findsNothing);
    expect(find.text('Commit'), findsNothing);
    expect(find.text('Migration başı'), findsNothing);
  });

  testWidgets('sürüme dokununca teknik kimlik açılır ve tekrar kapanır', (
    tester,
  ) async {
    await pumpAbout(tester);

    await tester.tap(find.byKey(const Key('build-identity-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Commit'), findsOneWidget);
    expect(find.text('abcdef12'), findsOneWidget);
    expect(find.text('Migration başı'), findsOneWidget);
    expect(find.text('0094'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('staging · aaaaaa…aaaa'), findsOneWidget);
    expect(find.text('1.0.44-beta.1+4401'), findsOneWidget);

    await tester.tap(find.byKey(const Key('build-identity-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('abcdef12'), findsNothing);
  });

  testWidgets('kimlik çözülemeyen derlemede boş kalmaz', (tester) async {
    // 🔴 Bu test eskiden `AboutScreen()` kuruyor ve "test derlemesinde
    // dart-define yoktur" varsayıyordu. Varsayım yerelde doğru, CI'da yanlış:
    // CI `flutter test --dart-define-from-file=env.json` ile koşar, ekran
    // `buildManifest ?? AppBuildManifest.currentOrNull` kullandığı için kimlik
    // çözülür ve yedek metin hiç basılmaz. v56 sürüm derlemesi tam buradan
    // düştü. Yedek metni üreten sözleşme `BuildIdentityCard`'ın kendisinde
    // olduğu için doğrudan ona bakılır — ortamdan bağımsız.
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BuildIdentityCard(manifest: null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Kanal/backend kimliği bu test derlemesinde tanımlı değil.'),
      findsOneWidget,
    );
  });

  testWidgets('sürüm, güncelleme, notlar ve destek tek hiyerarşidedir', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(find.text('Odak Kampı'), findsOneWidget);
    expect(find.byKey(const Key('about-check-for-updates')), findsOneWidget);
    expect(find.byKey(const Key('about-release-notes')), findsOneWidget);
    expect(find.byKey(const Key('about-legal')), findsOneWidget);
    expect(find.text('Güncellemeleri denetle'), findsOneWidget);
    expect(find.text('Güncelleme notları'), findsOneWidget);
    expect(find.text('Gizlilik ve yasal'), findsOneWidget);

    // WP-514: SSS buradan Ayarlar → Yardım'a taşındı. Bu ekranda kalmamalı,
    // yoksa iki giriş noktası oluşur ve taşımanın anlamı kalmaz.
    expect(find.byKey(const Key('about-faq')), findsNothing);
    expect(find.text('Sık sorulan sorular'), findsNothing);
  });

  testWidgets('manuel denetim güncel ve hata durumlarını ayırır', (
    tester,
  ) async {
    var checkCount = 0;
    await pumpAbout(
      tester,
      updateCheck: () async {
        checkCount++;
        return checkCount == 1
            ? const UpdateCheckResult.failed()
            : const UpdateCheckResult.upToDate();
      },
    );

    final checkTile = find.byKey(const Key('about-check-for-updates'));
    await tester.tap(checkTile);
    await tester.pump();
    expect(
      find.text(
        'Güncelleme denetlenemedi. İnternet bağlantını kontrol edip tekrar dene.',
      ),
      findsOneWidget,
    );

    await tester.tap(checkTile);
    await tester.pump();
    expect(find.text('Uygulaman güncel.'), findsOneWidget);
    expect(checkCount, 2);
  });

  testWidgets('yeni sürüm bulununca güvenli updater penceresi açılır', (
    tester,
  ) async {
    await pumpAbout(
      tester,
      updateCheck: () async => const UpdateCheckResult.updateAvailable(
        UpdateInfo(
          versionCode: 57,
          versionName: '1.0.57',
          releaseNotes: 'Test notu',
          downloadUrl: 'https://example.com/app.apk',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('about-check-for-updates')));
    await tester.pumpAndSettle();

    expect(find.byType(UpdaterDialog), findsOneWidget);
    expect(find.text('Güncelleme var: 1.0.57'), findsOneWidget);
  });

  testWidgets('Play/Store kanalında self-update denetimi açılmaz', (
    tester,
  ) async {
    var called = false;
    await pumpAbout(
      tester,
      allowsSideloadUpdates: false,
      updateCheck: () async {
        called = true;
        return const UpdateCheckResult.upToDate();
      },
    );

    expect(find.text('Güncelleme mağaza üzerinden yönetilir.'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('about-check-for-updates')),
    );
    expect(tile.onTap, isNull);
    expect(called, isFalse);
  });

  testWidgets('sürüm notları ve yasal bağlantılar gerçek ekranları açar', (
    tester,
  ) async {
    final releaseNotesService = ReleaseNotesService(
      assetLoader: (_) async => '''
{"releases":[{"versionName":"1.0.57","buildNumber":57,"channel":"stable",
"date":"2026-07-30","title":"Birleşik ekran","highlights":[],"fixes":[],"notes":[]}]}
''',
    );
    await pumpAbout(tester, releaseNotesService: releaseNotesService);

    await tester.tap(find.byKey(const Key('about-release-notes')));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotesScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ReleaseNotesScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('about-legal')));
    await tester.pumpAndSettle();
    expect(find.byType(LegalCenterScreen), findsOneWidget);
  });

  // ── WP-514: gizli geliştirici kapısı ────────────────────────────────────
  //
  // Sahip kararı: sayaç tanılama kaydı normal kullanıcının önünde durmasın,
  // ama admin-only da olmasın — kayıt her cihazda tutuluyor, admin kapısı
  // yalnız okunmasını engellerdi. Karşılığı: sürüm satırına yedi dokunuş.

  Future<void> tapVersion(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(const Key('build-identity-toggle')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('geliştirici bölümü varsayılan olarak yok', (tester) async {
    await pumpAbout(tester);

    expect(find.byKey(const ValueKey('timer-journal-entry')), findsNothing);
    expect(find.text('Geliştirici'), findsNothing);
  });

  testWidgets('altı dokunuş kapıyı açmaz', (tester) async {
    final prefs = await pumpAbout(tester);

    await tapVersion(tester, kDeveloperModeTapTarget - 1);

    expect(find.byKey(const ValueKey('timer-journal-entry')), findsNothing);
    expect(prefs.getBool(kDeveloperModeKey), isNot(isTrue));
  });

  testWidgets('yedi dokunuş sayaç tanılama kaydını açar ve kalıcıdır', (
    tester,
  ) async {
    final prefs = await pumpAbout(tester);

    await tapVersion(tester, kDeveloperModeTapTarget);

    expect(find.text('Geliştirici modu açıldı.'), findsOneWidget);
    expect(find.text('Geliştirici'), findsOneWidget);

    final journalEntry = find.byKey(const ValueKey('timer-journal-entry'));
    expect(journalEntry, findsOneWidget);
    // Kalıcı: uygulama kapanıp açılınca kapıyı yeniden geçmek gerekmez.
    expect(prefs.getBool(kDeveloperModeKey), isTrue);

    await tester.ensureVisible(journalEntry);
    await tester.tap(journalEntry);
    await tester.pumpAndSettle();
    expect(find.byType(TimerJournalScreen), findsOneWidget);
  });

  testWidgets('açık geliştirici modu kapatılabilir', (tester) async {
    final prefs = await pumpAbout(
      tester,
      initialPrefs: const {kDeveloperModeKey: true},
    );

    // Kalıcı bayrak okunuyor: dokunmadan bölüm açık gelmeli.
    expect(find.byKey(const ValueKey('timer-journal-entry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('developer-mode-disable')));
    await tester.pumpAndSettle();

    expect(find.text('Geliştirici modu kapatıldı.'), findsOneWidget);
    expect(find.byKey(const ValueKey('timer-journal-entry')), findsNothing);
    expect(prefs.getBool(kDeveloperModeKey), isFalse);
  });

  // 🔴 WP-759 KUSUR 4 nobetcisi (kullanici tarafi).
  //
  // `flutter.timer_panel_expanded` native tarafta sayac bildiriminin YUZEYINI
  // seciyordu ama `app/lib` icinde onu yazan hicbir sey yoktu. Anahtar bu
  // yuzden ne kullanicinin ne de bir cihaz testinin acabilecegi olu bir daldi;
  // WP-753 Live Update yolunu tam olarak bu yuzden CIHAZDA HIC GORULMEDEN
  // varsayilan yapip v71 ile yayina cikarabildi.
  //
  // Test "kod var mi"yi degil "dokununca DISKE ne yazildi"yi olcer: native
  // taraf yalniz diski okur.
  testWidgets('panel secimi native tarafin okudugu degeri yazar', (
    tester,
  ) async {
    final prefs = await pumpAbout(
      tester,
      initialPrefs: const {kDeveloperModeKey: true},
    );

    // Varsayilan: anahtar hic yazilmamis = OTOMATIK.
    expect(prefs.getBool(kTimerPanelExpandedKey), isNull);

    final strip = find.byKey(const Key('developer-panel-choice'));
    expect(strip, findsOneWidget);
    await tester.ensureVisible(strip);
    expect(
      tester.widget<SegmentedButton<TimerPanelChoice>>(strip).selected,
      {TimerPanelChoice.auto},
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    // 🔴 Live Update = diskte `false`. Ters yazilirsa secim kullaniciya "acik"
    // gorunur ama native taraf zengin paneli cizmeye devam eder.
    await tester.tap(find.text(l10n.devPanelChoiceLiveUpdate));
    await tester.pumpAndSettle();
    expect(prefs.getBool(kTimerPanelExpandedKey), isFalse);

    await tester.tap(find.text(l10n.devPanelChoiceRichPanel));
    await tester.pumpAndSettle();
    expect(prefs.getBool(kTimerPanelExpandedKey), isTrue);

    // 🔴 IDDIA YON DEGISTIRDI (WP-760). Eskiden bu satir "kapatinca `true`
    // yazilir" diyordu ve o davranis bir TUZAKTI: `true` native tarafta
    // "zengin paneli ZORLA" demektir, yani secimi bir kez acip kapatan
    // kullanici dinamik paneli KALICI kapatiyordu. Ustelik geri donus yoktu --
    // iki durumlu anahtarda "otomatik"i ifade eden bir deger kalmiyordu.
    // Ucuncu durum artik var ve degerin YOKLUGU ile ifade edilir.
    await tester.tap(find.text(l10n.devPanelChoiceAuto));
    await tester.pumpAndSettle();
    expect(prefs.containsKey(kTimerPanelExpandedKey), isFalse);
  });

  group('DeveloperGateCounter', () {
    test('ardışık dokunuşlar sayılır', () {
      final counter = DeveloperGateCounter(window: const Duration(seconds: 3));
      final t0 = DateTime(2026, 8, 8, 12);

      for (var i = 1; i <= kDeveloperModeTapTarget; i++) {
        expect(counter.registerTap(t0.add(Duration(seconds: i))), i);
      }
    });

    test('pencere dışındaki dokunuş diziyi sıfırlar', () {
      // 🔴 Pencere olmadan sayaç sonsuza kadar birikirdi: sürüm satırını aylar
      // içinde yedi kez açıp kapatan normal kullanıcı kapıyı kazara açardı.
      final counter = DeveloperGateCounter(window: const Duration(seconds: 3));
      final t0 = DateTime(2026, 8, 8, 12);

      expect(counter.registerTap(t0), 1);
      expect(counter.registerTap(t0.add(const Duration(seconds: 1))), 2);
      expect(counter.registerTap(t0.add(const Duration(seconds: 30))), 1);
    });
  });
}
