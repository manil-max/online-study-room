// WP-588: 13 test kullanicisi birbirini bulamiyordu.
//
// Uygulamanin cekirdegi birlikte calismak; Play kapali testinde 13 kisi
// kuracak. Duzeltmeden ONCE koddan olculen durum:
//
//   davet kodu  -> tek cikis "kopyala" (`class_detail_screen.dart:158-177`).
//                  Panoya dusen sey baglamsiz bir harf dizisi: karsi taraf
//                  hangi gruba ait oldugunu, ne yapacagini bilmiyor. `share_plus`
//                  ZATEN bagimlilik (`pubspec.yaml:62`) ve iki ekranda kullanimda.
//   kesif ekrani -> bos dal duz `Center(Text('Acik grup bulunamadi'))`
//                  (`group_discovery_screen.dart:267`), `RefreshIndicator` ise
//                  YALNIZ dolu listeye kuruluyordu (`:269-271`). Yani liste
//                  bosken asagi cekmek hicbir sey yapmiyordu ve ekranda
//                  gidilecek hicbir yer yoktu — cikmaz sokak.
//   varsayilan   -> grup olusturma **Ozel** aciliyor (`class_switcher.dart:191`),
//                  yani yeni grup kesif listesinde hic gorunmuyor.
//
// Bu dosyanin sozlesmesi UC ayri sensor:
//   (a) paylasilan metin grup adi + davet kodunu TASIR. Metni kanaldan
//       yakalar; iddia katalogdan degil, gercekten paylasilan string'den
//       okunur. Koddan cikarilirsa KIRMIZI.
//   (b) bos dal kaydirilabilir ve asagi-cekme gercekten yeniden yukler.
//       Eski `Center`a donulurse KIRMIZI.
//   (c) varsayilan gizlilik **Ozel**. Bu bir urun karari ve bu WP onu
//       DEGISTIRMEZ — yalnizca sessizce degisemeyecek sekilde SABITLER.
//       `class_switcher.dart:191` degistirilirse KIRMIZI.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette degil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/features/classroom/widgets/group_discovery_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `share_plus`in platform kanali (`MethodChannelShare.channel`).
///
/// Testte eklenti kaydi calismadigi icin `SharePlatform.instance`
/// `MethodChannelShare` olarak kalir; yani dugmeye basinca gercekten bu kanala
/// bir `share` cagrisi duser. Metni burada yakalamak, uretim kodundaki metin
/// kurgusunu **oldugu gibi** olcer — testte yeniden yazilmaz.
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

final _owner = Profile(
  id: 'owner-1',
  displayName: 'Kurucu',
  createdAt: DateTime(2026, 1, 1),
);

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// Kesif isteklerini sayan + kurulan gruplari kaydeden bellek-ici depo.
class _CountingGroupRepository extends InMemoryGroupRepository {
  int discoverCalls = 0;
  final createdGroups = <StudyGroup>[];

  /// 🔴 Kanarya: burada varsayilan bilerek **public** — uretimin tersi.
  /// Arayuz `visibility:` argumanini hic gondermezse gercek deponun `private`
  /// varsayilani hatayi yutar ve "varsayilan Ozel" iddiasi yalanci yesil doner.
  /// Ters varsayilanla, argumanin dusmesi de gizliligin degismesi kadar
  /// gorunur olur.
  @override
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
    GroupVisibility visibility = GroupVisibility.public,
    int memberLimit = kDefaultGroupMemberLimit,
    String timeZone = kDefaultGroupTimeZone,
  }) async {
    final group = await super.createGroup(
      name: name,
      creator: creator,
      visibility: visibility,
      memberLimit: memberLimit,
      timeZone: timeZone,
    );
    createdGroups.add(group);
    return group;
  }

  @override
  Future<List<PublicGroupSummary>> discoverPublicGroups({
    String query = '',
    String? timeZone,
    String userTimeZone = kDefaultGroupTimeZone,
    bool onlyWithCapacity = false,
    int offset = 0,
    int limit = 20,
  }) async {
    discoverCalls++;
    return super.discoverPublicGroups(
      query: query,
      timeZone: timeZone,
      userTimeZone: userTimeZone,
      onlyWithCapacity: onlyWithCapacity,
      offset: offset,
      limit: limit,
    );
  }
}

/// Paylasim kanalini taklit eder ve gonderilen metinleri toplar.
List<String?> _captureShares() {
  final shared = <String?>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_shareChannel, (call) async {
    if (call.method == 'share') {
      shared.add((call.arguments as Map)['text'] as String?);
    }
    return 'dev.fluttercommunity.plus/share/success';
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_shareChannel, null));
  return shared;
}

/// Detay ekrani **ikinci** rota olarak acilir; gercek kabuk (AppBar + ListView)
/// boylece yerinde olur.
class _DetailHost extends StatelessWidget {
  const _DetailHost({required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Builder(
        builder: (ctx) => FilledButton(
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => ClassDetailScreen(group: group),
            ),
          ),
          child: const Text('kok-rota'),
        ),
      ),
    ),
  );
}

/// Kesif ekrani da **ikinci** rota: uretimde her iki cagri yeri de `push`
/// ediyor (`classroom_screen.dart:220`, `class_switcher.dart:104`) ve basarili
/// kurma/katilma sonrasi ekranin kapanmasi bu kosula bagli.
class _DiscoveryHost extends StatelessWidget {
  const _DiscoveryHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Builder(
        builder: (ctx) => FilledButton(
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => const GroupDiscoveryScreen(),
            ),
          ),
          child: const Text('kok-rota'),
        ),
      ),
    ),
  );
}

Future<(StudyGroup, InMemoryGroupRepository)> _groupWorld() async {
  final repo = InMemoryGroupRepository();
  final group = await repo.createGroup(name: 'Odak Kampi', creator: _owner);
  return (group, repo);
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required StudyGroup group,
  required GroupRepository repo,
}) async {
  await tester.pumpWidget(
    _app(_DetailHost(group: group), [
      groupRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith((ref) => Stream.value(_owner)),
    ]),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('kok-rota'));
  await tester.pumpAndSettle();
}

/// Hic acik grubu olmayan kesif ekranini cizer.
Future<_CountingGroupRepository> _pumpEmptyDiscovery(
  WidgetTester tester, {
  double scale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _CountingGroupRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        groupRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(_owner)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const _DiscoveryHost(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('kok-rota'));
  await tester.pumpAndSettle();
  return repo;
}

/// Hedefin **dikey** kaydirilabilir bir govde icinde durdugunu sayar.
/// (WP-541 dersi: `find.byType(Scrollable)` tek basina yetmez — arama
/// kutusunun `EditableText`i de bir `Scrollable` kurar.)
int _verticalScrollAncestors(WidgetTester tester, Finder of) => find
    .ancestor(of: of, matching: find.byType(Scrollable))
    .evaluate()
    .where((element) {
      final axis = (element.widget as Scrollable).axisDirection;
      return axis == AxisDirection.down || axis == AxisDirection.up;
    })
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP-588/a — davet paylasimi', () {
    testWidgets('paylas dugmesi davet kodu satirinda, kopyalanin yaninda', (
      tester,
    ) async {
      final (group, repo) = await _groupWorld();
      await _pumpDetail(tester, group: group, repo: repo);

      final share = find.byKey(const Key('invite-share-action'));
      expect(share, findsOneWidget, reason: 'Paylas dugmesi hic yok.');
      expect(find.byTooltip('Daveti paylaş'), findsOneWidget);
      // Kopyala kaldirilmadi; paylas onun YANINA eklendi.
      expect(find.byTooltip('Kopyala'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Davet kodu'),
          matching: share,
        ),
        findsOneWidget,
        reason: 'Paylas dugmesi davet kodu satirinda degil.',
      );
    });

    testWidgets('paylasilan metin grup adini VE davet kodunu tasir', (
      tester,
    ) async {
      final shared = _captureShares();
      final (group, repo) = await _groupWorld();
      await _pumpDetail(tester, group: group, repo: repo);

      await tester.tap(find.byKey(const Key('invite-share-action')));
      await tester.pumpAndSettle();

      expect(
        shared,
        hasLength(1),
        reason:
            'Paylasim kanalina hic cagri dusmedi — dugme olu, iddia bossa '
            'test yalanci yesil olurdu.',
      );
      final text = shared.single;
      expect(text, isNotNull);
      expect(
        text,
        contains(group.inviteCode),
        reason:
            'Kodsuz paylasim ise yaramaz: alici hicbir sey yapamaz. '
            'Paylasilan metin: $text',
      );
      expect(
        text,
        contains(group.name),
        reason:
            'Adsiz paylasim baglamsiz: alici hangi gruba katildigini bilmez. '
            'Paylasilan metin: $text',
      );
    });

    testWidgets('kopyala hala yalniz kodu panoya yaziyor', (tester) async {
      // Paylasim eklendi diye kopyalamanin sozlesmesi degismedi: pano tam
      // olarak kodu tasir, cumleyi degil (kullanici kodu bir kutuya yapistirir).
      final clipboard = <String?>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String?);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final (group, repo) = await _groupWorld();
      await _pumpDetail(tester, group: group, repo: repo);

      await tester.tap(find.byTooltip('Kopyala'));
      await tester.pumpAndSettle();

      expect(clipboard, [group.inviteCode]);
    });
  });

  group('WP-588/b — bos kesif ekrani cikmaz sokak degil', () {
    testWidgets('bos dal dikey kaydirilabilir bir govde cizer', (tester) async {
      await _pumpEmptyDiscovery(tester);

      expect(find.text('Açık grup bulunamadı'), findsOneWidget);
      expect(
        _verticalScrollAncestors(tester, find.text('Açık grup bulunamadı')),
        greaterThan(0),
        reason:
            'Eski davranis: duz `Center(Text(...))`. Kaydirici yoksa '
            'asagi-cekme jesti hic dogmaz.',
      );
      expect(
        find.byType(RefreshIndicator),
        findsOneWidget,
        reason:
            'Eski davranis: `RefreshIndicator` yalniz DOLU listeye '
            'kuruluyordu; bos ekranda yenileme yolu yoktu.',
      );
    });

    testWidgets('asagi cekmek gercekten yeniden yukluyor', (tester) async {
      final repo = await _pumpEmptyDiscovery(tester);
      final before = repo.discoverCalls;
      expect(before, greaterThan(0), reason: 'Ilk yukleme hic kosmadi.');

      await tester.fling(
        find.text('Açık grup bulunamadı'),
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        repo.discoverCalls,
        greaterThan(before),
        reason:
            'Asagi-cekme yeni istek uretmedi; kullanici icin ekran hala '
            'cikmaz sokak.',
      );
    });

    testWidgets('"Grup olustur" cikisi gercek diyalogu aciyor', (tester) async {
      await _pumpEmptyDiscovery(tester);

      await tester.tap(find.byKey(const Key('discovery-empty-create-group')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('create-group-submit')),
        findsOneWidget,
        reason: 'Olu anahtar: dugme var ama hicbir sey acmiyor.',
      );
    });

    testWidgets('"Koda katil" cikisi gercek diyalogu aciyor', (tester) async {
      await _pumpEmptyDiscovery(tester);

      await tester.tap(find.byKey(const Key('discovery-empty-join-code')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('join-group-submit')),
        findsOneWidget,
        reason: 'Olu anahtar: dugme var ama hicbir sey acmiyor.',
      );
    });

    testWidgets('grup kurulunca kesif ekrani kapaniyor', (tester) async {
      final repo = await _pumpEmptyDiscovery(tester);

      await tester.tap(find.byKey(const Key('discovery-empty-create-group')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Grup adı'),
        'Yeni Kamp',
      );
      await tester.tap(find.byKey(const Key('create-group-submit')));
      await tester.pumpAndSettle();

      expect(repo.createdGroups, hasLength(1));
      expect(
        find.text('kok-rota'),
        findsOneWidget,
        reason:
            'Kullanici artik bir gruba ait; kurdugu grup Ozel oldugu icin bu '
            'listede zaten hic gorunmeyecek — ekranda birakmak cikmaz sokak.',
      );
    });
  });

  group('WP-588/c — varsayilan gizlilik SABIT (urun karari, bu WP degistirmez)',
      () {
    testWidgets('grup olusturma diyalogu **Ozel** secili aciliyor', (
      tester,
    ) async {
      await _pumpEmptyDiscovery(tester);
      await tester.tap(find.byKey(const Key('discovery-empty-create-group')));
      await tester.pumpAndSettle();

      final radios = find.byType(RadioGroup<GroupVisibility>);
      expect(radios, findsOneWidget);
      expect(
        tester.widget<RadioGroup<GroupVisibility>>(radios).groupValue,
        GroupVisibility.private,
        reason:
            'Varsayilan gizlilik URUN KARARIDIR (`class_switcher.dart:191`). '
            'Bu iddia karari savunmaz, sessizce degismesini engeller: Acik '
            'yapilacaksa bilerek ve bu satirla birlikte yapilmalidir.',
      );
    });

    testWidgets('kesiften kurulan grup **Ozel** olarak kaydediliyor', (
      tester,
    ) async {
      final repo = await _pumpEmptyDiscovery(tester);

      await tester.tap(find.byKey(const Key('discovery-empty-create-group')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Grup adı'),
        'Yeni Kamp',
      );
      await tester.tap(find.byKey(const Key('create-group-submit')));
      await tester.pumpAndSettle();

      final created = repo.createdGroups.single;
      expect(created.name, 'Yeni Kamp');
      expect(
        created.visibility,
        GroupVisibility.private,
        reason:
            'Widget iddiasinin ikizi: radyo dugmesi degil, DEPOYA yazilan '
            'deger olculur.',
      );
      // Ozel grup kesif listesinde gorunmez — sahibin karar vermesi gereken
      // gercek sonuc bu. Iddia bu sonucu da olcer.
      expect(await repo.discoverPublicGroups(), isEmpty);
    });
  });

  group('WP-588/olcum — bos kesif ekrani 360x720 ve buyuk yazida tasmiyor', () {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('360x720 scale=$scale', (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        await _pumpEmptyDiscovery(tester, scale: scale);
        FlutterError.onError = previous;

        expect(
          errors.map((detail) => detail.exceptionAsString()).toList(),
          isEmpty,
          reason: 'bos kesif ekrani tasti',
        );

        // WP-541 dersi: "tasmiyor" ile "ulasiliyor" ayni sey degil. Iki cikis
        // da ya ekranda, ya kaydirarak getirilebilir olmali.
        for (final target in <(String, Finder)>[
          ('Grup olustur', find.byKey(const Key('discovery-empty-create-group'))),
          ('Koda katil', find.byKey(const Key('discovery-empty-join-code'))),
        ]) {
          expect(target.$2, findsOneWidget, reason: '${target.$1} agacta yok');
          var rect = tester.getRect(target.$2);
          if (rect.bottom > 720 || rect.top < 0) {
            await tester.scrollUntilVisible(
              target.$2,
              80,
              scrollable: find
                  .ancestor(
                    of: find.text('Açık grup bulunamadı'),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pump();
            rect = tester.getRect(target.$2);
          }
          expect(
            rect.top >= -0.5 && rect.bottom <= 720.5,
            isTrue,
            reason:
                '${target.$1} kaydirmadan sonra da ekran disinda: '
                '[${rect.top.toStringAsFixed(0)}..'
                '${rect.bottom.toStringAsFixed(0)}] / 720',
          );
        }
      });
    }
  });
}
