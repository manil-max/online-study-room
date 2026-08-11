// WP-710 — Ayarlar sadeleşti, kamp hayvanı Gruplar'a taşındı.
//
// Proje sahibi emri: "ayarlarda 'study preferences' kısmından günlük hedef,
// countdown date ve 'your camp animal'ı kaldır, reset kısmını da başka yere
// koy ayarlarda. bu 3 kaldırılıcak şeyde kamp hayvanını gruplar kısmından
// seçebilelim".
//
// 🔴 Bu dosya ÇİFT YÖNLÜ ölçer. "Artık Ayarlar'da yok" tek başına, özelliği
// öldürdüğünü fark etmeyen bir testtir: bu depoda kayıtlı ders tam olarak
// "bitmiş backend + bağlanmamış UI" — kod durur, çağıran yoktur, kimse fark
// etmez. Kaldırma yönünde de aynısı geçerli. O yüzden kaldırılan HER ayar için
// iki iddia var:
//
//   1. Ayarlar'da artık YOK.
//   2. Ayarı gerçekten değiştiren BAŞKA bir yüzey hâlâ var ve yazdığı değer
//      depoya/prefs'e düşüyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/animals/camp_animal.dart';
import 'package:online_study_room/core/navigation/nav_index.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dday_prefs.dart';
import 'package:online_study_room/features/home/widgets/dday_card.dart';
import 'package:online_study_room/features/onboarding/onboarding_prefs.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/features/profile/widgets/camp_animal_picker.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _group = StudyGroup(
  id: 'g1',
  name: 'Odak Kampı',
  inviteCode: 'TEST12',
  createdBy: 'u1',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 120,
);

Future<AppLocalizations> _tr() =>
    AppLocalizations.delegate.load(const Locale('tr'));

Widget _app(List<Override> overrides, Widget home) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// Ayarlar gövdesi lazy bir `ListView`; tüm bölümlerin tek karede kurulması
/// için viewport bolca yüksek tutulur (`settings_screen_test.dart` ile aynı).
Future<InMemoryAuthRepository> _pumpSettings(WidgetTester tester) async {
  final auth = InMemoryAuthRepository();
  addTearDown(auth.dispose);
  await auth.signUp(
    email: 'ben@example.com',
    password: 'gizli123',
    displayName: 'Ben',
  );
  // Anahtar HESAP BASINA (`WP-166`): sabit `...u1` yazmak, sifirlamanin hic
  // calismadigi bir kodda da yesil kalirdi.
  SharedPreferences.setMockInitialValues({
    onboardingCompletedKeyFor(auth.currentUser!.id): true,
  });
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(1080, 12000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    _app([
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
    ], const SettingsScreen()),
  );
  await tester.pumpAndSettle();
  return auth;
}

/// Gruplar sekmesi.
///
/// 🔴 `CampfireScene` sonsuz alev animasyonu barındırır: `pumpAndSettle` asla
/// oturmaz (komşu `group_header_actions_wp509_test.dart` ile aynı gerekçe).
Future<InMemoryAuthRepository> _pumpGroups(
  WidgetTester tester, {
  bool hasGroup = true,
}) async {
  final auth = InMemoryAuthRepository();
  addTearDown(auth.dispose);
  await auth.signUp(
    email: 'ben@example.com',
    password: 'gizli123',
    displayName: 'Ben',
  );
  // Tur anahtari da HESAP BASINA. Sabit bir id yazmak turu "gorulmemis"
  // birakir; tanitim orgusu ekrani kaplar ve her dokunusu YUTAR.
  SharedPreferences.setMockInitialValues({
    tourSeenKey(storageId: 'groups.v1', userId: auth.currentUser!.id): true,
  });
  final prefs = await SharedPreferences.getInstance();

  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 2400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _app([
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      navIndexProvider.overrideWith(_GroupsTabNavIndex.new),
      userGroupProvider.overrideWithValue(
        AsyncData<StudyGroup?>(hasGroup ? _group : null),
      ),
      groupMembersProvider.overrideWith((ref) => Stream.value([])),
      groupPresenceProvider.overrideWith((ref) => Stream.value([])),
      groupDailyStatsProvider.overrideWith((ref) => Stream.value([])),
      userSessionsProvider.overrideWith((ref) => Stream.value([])),
    ], const ClassroomScreen()),
  );
  await _beat(tester);
  addTearDown(() async => tester.pumpWidget(const SizedBox()));
  return auth;
}

/// Sonsuz animasyonlu ağaçta `pumpAndSettle` yerine sınırlı ilerletme.
Future<void> _beat(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

class _GroupsTabNavIndex extends NavIndexNotifier {
  @override
  int build() => AppTab.groups.index;
}

/// Gerçek notifier kanal/dinleyici kurar; burada ölçülen şey hedef yazma yolu.
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

void main() {
  // =========================================================================
  // 1) AYARLAR SADELEŞTİ — üç satır gitti, sıfırlama TAŞINDI
  // =========================================================================
  group('Ayarlar: "Çalışma tercihleri" kalktı', () {
    testWidgets('günlük hedef, sınav tarihi ve kamp hayvanı satırları YOK', (
      tester,
    ) async {
      await _pumpSettings(tester);
      final tr = await _tr();

      expect(
        find.byKey(const Key('settings-daily-goal')),
        findsNothing,
        reason: 'Günlük hedef satırı hâlâ Ayarlar\'da.',
      );
      expect(
        find.byKey(const Key('settings-exam-date')),
        findsNothing,
        reason: 'Sınav tarihi satırı hâlâ Ayarlar\'da.',
      );
      expect(
        find.byKey(kCampAnimalTileKey),
        findsNothing,
        reason: 'Kamp hayvanı satırı Ayarlar\'dan çıkmadı, kopyalandı.',
      );
      expect(
        find.text(tr.profileKampHayvanin),
        findsNothing,
        reason: 'Kamp hayvanı başlığı Ayarlar\'da hâlâ yazıyor.',
      );
      expect(
        find.text(tr.settingsSectionStudyPreferences),
        findsNothing,
        reason: 'Bölüm boşaldı ama başlığı duruyor — boş bir kategori.',
      );
    });

    testWidgets('sıfırlama SİLİNMEDİ: "Yardım" bölümüne taşındı ve çalışıyor', (
      tester,
    ) async {
      final auth = await _pumpSettings(tester);
      final tr = await _tr();
      final prefs = await SharedPreferences.getInstance();
      final tourKey = onboardingCompletedKeyFor(auth.currentUser!.id);
      expect(prefs.getBool(tourKey), isTrue, reason: 'on kosul kurulmadi');

      final reset = find.byKey(const Key('reset-introduction-tours'));
      expect(
        reset,
        findsOneWidget,
        reason:
            'Sahip "başka yere koy" dedi, "kaldır" demedi; satır tamamen '
            'kaybolmuş.',
      );
      // Yeri gerçekten DEĞİŞTİ: artık Yardım başlığının ve SSS satırının
      // altında. Sadece "var mı" diye bakmak taşımayı ölçmez.
      expect(
        tester.getTopLeft(reset).dy,
        greaterThan(tester.getTopLeft(find.text(tr.settingsSectionHelp)).dy),
        reason: 'Sıfırlama satırı "Yardım" bölümünün altında değil.',
      );
      expect(
        tester.getTopLeft(reset).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('settings-faq'))).dy,
        ),
      );

      // Ölü anahtar yasağı: taşınan satır hâlâ gerçek etki üretiyor mu?
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(prefs.getBool(tourKey), isFalse);
    });
  });

  // =========================================================================
  // 2) KAMP HAYVANI ARTIK GRUPLAR'DAN SEÇİLİYOR
  // =========================================================================
  group('Gruplar: kamp hayvanı seçicisi', () {
    testWidgets('satır Gruplar ekranında ÇİZİLİYOR', (tester) async {
      await _pumpGroups(tester);
      final tr = await _tr();

      expect(
        find.byKey(kCampAnimalTileKey),
        findsOneWidget,
        reason:
            'Kamp hayvanı satırı Ayarlar\'dan çıktı ama Gruplar\'a hiç '
            'bağlanmamış — ayar ölmüş olur.',
      );
      expect(find.text(tr.profileKampHayvanin), findsOneWidget);
    });

    testWidgets('satır seçiciyi AÇAR ve seçim depoya YAZILIR', (tester) async {
      final auth = await _pumpGroups(tester);
      final tr = await _tr();

      final shown = campAnimalFor(
        userId: auth.currentUser!.id,
        animalId: auth.currentUser!.animal,
      );
      final target = kCampAnimals.firstWhere((a) => a.id != shown.id);

      await tester.ensureVisible(find.byKey(kCampAnimalTileKey));
      await _beat(tester);
      await tester.tap(find.byKey(kCampAnimalTileKey));
      await _beat(tester);

      // Seçici gerçekten açıldı mı? (Alt sayfanın kendi açıklama satırı.)
      expect(
        find.text(tr.profileKampAtesiEkranindaSeni),
        findsOneWidget,
        reason: 'Satıra dokunmak seçiciyi açmıyor: yol KOPUK.',
      );

      await tester.tap(find.text(target.label(tr)).last);
      await _beat(tester);
      await _beat(tester);

      expect(
        auth.currentUser?.animal,
        target.id,
        reason: 'Seçim yapıldı ama profile yazılmadı.',
      );
      expect(find.text(tr.profileKampHayvaniGuncellendi), findsOneWidget);
    });

    testWidgets('grubu OLMAYAN kullanıcı da hayvanını seçebiliyor', (
      tester,
    ) async {
      // Hayvan hesabın özelliğidir, grubun değil. Yalnız gruplu dala
      // koysaydık henüz gruba katılmamış kullanıcı hayvanını HİÇ seçemezdi.
      await _pumpGroups(tester, hasGroup: false);
      expect(find.byKey(kCampAnimalTileKey), findsOneWidget);
    });
  });

  // =========================================================================
  // 3) ÇİFT YÖNLÜ — kaldırılan iki ayar BAŞKA yüzeyden hâlâ değişiyor
  // =========================================================================
  group('kaldırılan ayarlar başka yerden değiştirilebiliyor', () {
    testWidgets('günlük hedef: sayaç kartındaki hedef satırından', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final auth = InMemoryAuthRepository();
      addTearDown(auth.dispose);
      await auth.signUp(
        email: 'ben@example.com',
        password: 'gizli123',
        displayName: 'Ben',
      );
      final before = auth.currentUser!.dailyGoalMinutes;
      final tr = await _tr();

      // 🔴 800 dp genişlik bilinçli: `goal_editor_dialog.dart` 360 dp'de 8 px
      // taşırıyor (WP-555 notu) ve o dosya bu WP'nin kapsamında değil.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app([
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

      final goalRow = find.text(tr.classroomGunlukHedef);
      expect(
        goalRow,
        findsOneWidget,
        reason:
            'Ayarlar\'daki satır kaldırıldı ve sayaç kartındaki hedef satırı '
            'da yok — günlük hedef HİÇBİR yerden değiştirilemiyor.',
      );
      await tester.tap(goalRow);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Dakika sütununun "+" tuşu.
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

      expect(
        auth.currentUser?.dailyGoalMinutes,
        before + 1,
        reason: 'Diyalog açıldı ama yazma yolu kopuk.',
      );
    });

    testWidgets('sınav tarihi: pano geri sayım kartından (WP-632)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ddayClockProvider.overrideWithValue(() => DateTime(2026, 8, 9, 21)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: defaultCardHeight(DashboardCardSize.large),
                  child: const DDayCard(size: DashboardCardSize.large),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(examListProvider).entries, isEmpty);
      await tester.tap(find.byKey(const Key('dday-card-open-editor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dday-add-exam')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dday-name-field')), 'YKS');
      await tester.tap(find.byKey(const Key('dday-save')));
      await tester.pumpAndSettle();

      expect(
        container.read(examListProvider).entries.single.name,
        'YKS',
        reason:
            'Ayarlar\'daki sınav tarihi satırı kaldırıldı ve kart yolu da '
            'çalışmıyor — geri sayım hiç kurulamaz.',
      );
    });
  });
}
