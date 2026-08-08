// WP-509 (v59 saha geri bildirimi · madde 3 + 4 + E6): "grup değiştir" düğmesi
// sekmenin üst eylem şeridinde tek başına duruyordu; sohbet ve ayarlar ise
// aşağıda, grup adının yanındaydı. Tek düğme için bir tam şerit + durum çubuğu
// payı harcanıyordu.
//
// Bu dosya taşımanın **üç gizli adımını** kilitler; üçü de atlanırsa yeni hata
// çıkar ve hiçbiri "düğme aşağıda mı" testiyle görünmez:
//
//   1. Şerit boşalınca `buildTabActionBar` `null` döner (`tab_action_bar.dart`).
//      Gövde `SafeArea(bottom: false)` ile sarılmazsa kamp ateşi durum
//      çubuğunun altına girer — ana ekranda aynı yarım iş WP-493'te hataydı.
//   2. Tur çapası düğmeyle birlikte taşınmazsa Gruplar turunun "grup değiştir"
//      adımı hedefsiz balon olarak ekranın ortasında açılır.
//   3. Üç varsayılan `IconButton` yatayda ~144 dp yer yer; uzun grup adı
//      ellipsis'e düşer. Kazanç ancak yuvalar daralırsa gerçekleşir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/nav_index.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_host.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durum çubuğu payı; şerit gittiğinde bunu **gövde** taşımak zorunda.
const double _kStatusBarInset = 48;

final _viewer = Profile(
  id: 'u1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g1',
  name: 'Gerçekten Çok Uzun Bir Grup Adı Buraya',
  inviteCode: 'TEST12',
  createdBy: 'u1',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 120,
);

/// Gruplar sekmesini kurar.
///
/// 🔴 `CampfireScene` sonsuz alev animasyonu barındırır: `pumpAndSettle` asla
/// oturmaz. Sınırlı pump, akışları çözmeye ve `AnimatedPositioned` yerleşimini
/// bitirmeye yeter (komşu `classroom_screen_test.dart` ile aynı gerekçe).
Future<void> _pumpGroups(
  WidgetTester tester, {
  Size surface = const Size(360, 1600),
  bool tourSeen = true,
}) async {
  SharedPreferences.setMockInitialValues(
    tourSeen
        ? {tourSeenKey(storageId: 'groups.v1', userId: _viewer.id): true}
        : <String, Object>{},
  );
  final prefs = await SharedPreferences.getInstance();

  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = surface;
  // Şeridin devrettiği üst güvenli alan; iddianın ölçülebilir olması için
  // sıfırdan farklı olmak zorunda.
  tester.view.padding = const FakeViewPadding(top: _kStatusBarInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        navIndexProvider.overrideWith(_GroupsTabNavIndex.new),
        userGroupProvider.overrideWithValue(AsyncData(_group)),
        groupMembersProvider.overrideWith((ref) => Stream.value([])),
        groupPresenceProvider.overrideWith((ref) => Stream.value([])),
        groupDailyStatsProvider.overrideWith((ref) => Stream.value([])),
        authStateProvider.overrideWith((ref) => Stream.value(_viewer)),
        userSessionsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClassroomScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
}

/// Ekranı Gruplar sekmesinde açar (tur ancak o zaman kurulur).
class _GroupsTabNavIndex extends NavIndexNotifier {
  @override
  int build() => AppTab.groups.index;
}

Finder _headerAction(IconData icon) => find.ancestor(
  of: find.byIcon(icon),
  matching: find.byType(IconButton),
);

/// Grup adı ekranda iki kere geçer (kompakt başlık + `GroupGoalCard`).
/// Başlıktaki, `ListView` çocuk sırasına göre **ilk** olandır.
Finder _headerName() => find.text(_group.name).first;

void main() {
  group('üst eylem şeridi tamamen kalktı', () {
    testWidgets('Gruplar sekmesinde AppBar hiç kurulmuyor', (tester) async {
      await _pumpGroups(tester);

      // E6: tek ikon için harcanan şerit + durum çubuğu payı ölü alandı.
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('gövde durum çubuğu payını kendisi taşıyor', (tester) async {
      await _pumpGroups(tester);

      // 🔴 Asıl iddia bu: şerit `null` döndüğünde üst inset'i kimse devralmazsa
      // ilk içerik saat/pil simgelerinin altına girer.
      final bodyTop = tester.getTopLeft(find.byType(ListView)).dy;
      expect(
        bodyTop,
        greaterThanOrEqualTo(_kStatusBarInset),
        reason: 'gövde $bodyTop dp\'den başlıyor, durum çubuğu $_kStatusBarInset dp',
      );
    });
  });

  group('üç eylem grup adının yanında', () {
    testWidgets('sıra soldan sağa: değiştir → sohbet → ayarlar', (tester) async {
      await _pumpGroups(tester);

      final x = [
        for (final icon in [
          Icons.swap_horiz,
          Icons.forum_outlined,
          Icons.settings_outlined,
        ])
          tester.getCenter(_headerAction(icon)).dx,
      ];

      expect(x[0], lessThan(x[1]));
      expect(x[1], lessThan(x[2]));
    });

    testWidgets('üçü de grup adıyla aynı satırda', (tester) async {
      await _pumpGroups(tester);

      // Aynı satırda olmaları taşımanın kendisi: düğme yukarıda kalsaydı
      // dikey merkezi grup adınınkinden ayrışırdı.
      final nameY = tester.getCenter(_headerName()).dy;
      for (final icon in [
        Icons.swap_horiz,
        Icons.forum_outlined,
        Icons.settings_outlined,
      ]) {
        expect(tester.getCenter(_headerAction(icon)).dy, closeTo(nameY, 1));
      }
    });

    testWidgets('düğmeye basınca grup değiştirici açılıyor', (tester) async {
      await _pumpGroups(tester);

      // Ölü anahtar yasağı: düğme taşındı ama işlevi de taşındı mı?
      await tester.tap(_headerAction(Icons.swap_horiz));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Gruplarım'), findsOneWidget);
    });
  });

  group('ada yer kalıyor', () {
    testWidgets('üç yuva toplamı 144 dp değil, 3 × 40 dp', (tester) async {
      await _pumpGroups(tester);

      for (final icon in [
        Icons.swap_horiz,
        Icons.forum_outlined,
        Icons.settings_outlined,
      ]) {
        final size = tester.getSize(_headerAction(icon));
        expect(
          size.width,
          lessThanOrEqualTo(kHeaderActionWidth),
          reason: '$icon yuvası ${size.width} dp',
        );
        // Erişilebilirlik: daralan yalnız yatay ayak izi; dokunma hedefinin
        // dikey boyutu 48 dp'nin altına inemez.
        expect(
          size.height,
          greaterThanOrEqualTo(kHeaderActionHeight),
          reason: '$icon dokunma hedefi ${size.height} dp',
        );
      }
    });

    testWidgets('uzun grup adı tek satırda kırpılarak kalır', (tester) async {
      await _pumpGroups(tester);

      final name = tester.widget<Text>(_headerName());
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
    });
  });

  group('tanıtım turu çapası düğmeyle birlikte taşındı', () {
    testWidgets('"switch" adımının çapası grup değiştir düğmesi', (
      tester,
    ) async {
      await _pumpGroups(tester);

      final host = tester.widget<TourHost>(find.byType(TourHost));
      final step = host.definition.steps.firstWhere((s) => s.id == 'switch');

      // Çapa `null` ise balon ekranın ortasında hedefsiz açılır — turun
      // "şuraya bas" cümlesi hiçbir şeyi göstermez.
      expect(step.anchor, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(step.anchor!),
          matching: find.byIcon(Icons.swap_horiz),
        ),
        findsOneWidget,
      );
    });
  });

  group('sohbet kartının ikinci kopyası kalktı', () {
    testWidgets('grup ayarlarında ClassChatCard yok', (tester) async {
      final groups = InMemoryGroupRepository();
      final group = await groups.createGroup(name: 'Odak', creator: _viewer);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            groupRepositoryProvider.overrideWithValue(groups),
            authStateProvider.overrideWith((ref) => Stream.value(_viewer)),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ClassDetailScreen(group: group),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // WP-446'nın dersi (davet kodunun iki kopyası) sohbette tekrar etmişti:
      // aynı kart hem tam ekranda hem ayarlarda yaşıyordu. Sohbetin kanonik
      // yeri başlıktaki simge → `ClassChatScreen`.
      expect(find.byType(ClassChatCard), findsNothing);
    });
  });
}
