// 🔴 WP-704 — WP-701 KOPRUYU YAZDI, CAGRI YERINI YAZMADI.
//
// `task_widget_wp701_test.dart` gorev widget'inin her parcasini olcuyor ve
// 20/20 yesil. Ama o testlerin HEPSI kopruyu KENDISI baslatiyor:
//
//     await container.read(taskWidgetBridgeProvider).start();
//
// `lib/` icinde o satiri cagiran hicbir yer yoktu. Yani ayna hic yazilmaz,
// bekleyen kuyruk hic bosalmaz: kullanici ana ekranda gorevini isaretler,
// isaret bir sure durur, uygulama acilinca GERI DONER. Yesil bir test takimi
// olu bir ozelligi koruyordu.
//
// Depoda kayitli ders bu: *"bitmis backend + baglanmamis UI"* -- testler yesil
// olabilir ama `lib/` icinde cagri yeri yoksa ozellik YOKTUR. Bu dosyanin tek
// isi o dersi olculur yapmak, o yuzden kopruyu ELIYLE BASLATMAZ: gercek
// `HomeShell`i monte eder ve kuyrugun kendiliginden bosalmasini bekler.
//
// Sabotaj sozlesmesi: `home_shell.dart` icindeki tek `ref.watch` satiri
// silinirse bu dosya kirmizi dusmeli, `wp701` dosyasi ise YESIL kalmali.
// Ikisi ayni anda kirmizi dusuyorsa bu test yeni bir sey olcmuyordur.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/home_shell.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('kabuk monte olunca ana ekrandaki isaret GERCEKTEN uygulanir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 8, 11, 12);

    // Once gorevi olustur: kuyruk gercek bir kaydi hedeflemeli, yoksa
    // "silinmis gorev" yolundan gecer ve hicbir sey kanitlamaz.
    final seed = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userTaskRepositoryProvider.overrideWithValue(
          InMemoryUserTaskRepository(now: () => now),
        ),
        userTaskClockProvider.overrideWithValue(() => now),
      ],
    );
    await seed.read(userTasksProvider.future);
    final task = await seed
        .read(userTaskActionsProvider)
        .add(rawTitle: 'Matematik testi');
    expect(task, isNotNull);
    final repository = seed.read(userTaskRepositoryProvider);
    seed.dispose();

    // Kotlin'in uygulama KAPALIYKEN yazdigi kuyruk.
    await prefs.setString(
      TaskWidgetPrefsKeys.pending,
      jsonEncode({
        'ops': [
          {'id': 'o1', 'taskId': task!.id, 'done': true, 'at': '1'},
        ],
      }),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    // Platform bayragi GOVDE icinde acilir ve GOVDE icinde kapanir.
    // `setUp` + `addTearDown` ikisi de gec kalir: `testWidgets` degismezlik
    // kontrolunu govde biter bitmez kosturur ve "foundation debug degiskeni
    // degistirildi" diye patlayip ASIL iddiayi maskeler. Bu testte bir kez
    // oldu; olcum araci bozuldugunda dusen kirmizi, olcmek istedigin sey degil.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authStateProvider.overrideWith(
              (ref) => Stream<Profile?>.value(null),
            ),
            // Ayni depo ornegi: kabuk tohumlanan gorevi gormeli.
            userTaskRepositoryProvider.overrideWithValue(repository),
            userTaskClockProvider.overrideWithValue(() => now),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeShell(),
          ),
        ),
      );
      // Kopru asenkron: depo okumasi + kuyruk uygulamasi + ayna yazimi.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 🔴 ASIL IDDIA: kimse `start()` cagirmadi. Yalniz kabuk monte oldu.
      expect(
        prefs.getString(TaskWidgetPrefsKeys.pending),
        isNull,
        reason:
            'kuyruk bosalmadi: lib/ icinde kopruyu baslatan cagri yeri yok, '
            'yani kullanicinin ana ekranda koydugu isaret geri doner',
      );

      final raw = prefs.getString(TaskWidgetPrefsKeys.mirror);
      expect(raw, isNotNull, reason: 'ayna hic yazilmadi: widget bos gorunur');
      final rows =
          ((jsonDecode(raw!) as Map<String, dynamic>)['tasks'] as List)
              .cast<Map<String, dynamic>>();
      expect(rows.single['title'], 'Matematik testi');
      // Kuyruk bosalip da toggle sessizce dusseydi ayna done:false yazardi;
      // bu yuzden "kuyruk silindi" tek basina yeterli kanit degil.
      expect(
        rows.single['done'],
        isTrue,
        reason: 'isaret uygulanmadi: gorev hala tamamlanmamis',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
