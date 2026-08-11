// WP-715 — "minimal var, seçiyorum kart hâlâ çok büyük".
//
// 🔴 ÖLÇÜLEN KUSUR: `ClockStyle` beş üyesinin **hiçbiri** sayaç kartının
// yüksekliğine dokunmuyordu. `minimal` adı küçüklük vaat ediyor, kodda yaptığı
// iş `ClockPainter`ın `strokeWidth = 2` dalı — yani **kalem inceltiyor**
// (`clock_style.dart`, "Minimal stil - ekstra ince çizgi"). Sahibin "tam
// farklarını anlayamadım" demesi bunun birebir karşılığı.
//
// Bu dosya iddiayı bir izlenimden SAYIYA çevirir: telefon genişliğinde
// (360 dp) kartın **istediği** yükseklik her stil için ölçülür ve tablo
// yazdırılır. Yeni `ClockStyle.compact` mevcut EN KISA stilden ölçülebilir
// biçimde (≥ 200 px) daha kısa olmak zorundadır.
//
// ⚠️ Ölçüm 360 dp'de yapılır. Bu depoda yükseklik/taşma kusurları iki kez geniş
// ekranda test edildiği için kaçtı (`_StatCard` 73 px, `number_stepper` 8 px).
//
// 🔴 İŞLEV KAYBI YOK: küçültme "özellik silme" ile karıştırılamaz. Her stil
// için **ayrı ayrı** ölçülür — süre okunabiliyor mu, Başlat/Durdur basılabilir
// mi (dururken VE çalışırken).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3).
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/classroom/widgets/clock_style.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Telefon içerik genişliği (sahibin şikâyet ettiği yüzey).
const double _kPhoneWidth = 360;

/// Kartın tek satıra inmesi "biraz kısaldı" değil, **ölçülebilir** olmalı.
/// Çıta bir tahmin değil: aşağıdaki tablo koşturulup en kısa mevcut stil
/// görüldükten sonra konmuştur.
const double _kRequiredDrop = 200;

final _me = Profile(
  id: 'u1',
  displayName: 'Ben',
  createdAt: DateTime(2026, 1, 1),
  dailyGoalMinutes: 240,
);

const _subjects = <Subject>[
  Subject(id: 's1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
];

/// Gerçek notifier kanal/dinleyici kurar; sahne hiç durulmaz.
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

class _RunningTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() =>
      StudyTimerState(isRunning: true, startedAt: DateTime.now());
}

/// Günlük hedef yazması BAŞARILI olan depo.
class _OkAuthRepository extends InMemoryAuthRepository {}

/// Günlük hedef yazması ağ/sunucu hatasıyla düşen depo. 🔴 `AuthException`
/// DEĞİL: WP-619 kök nedeni tam olarak buydu — profil yazmaları o türü hiç
/// atmaz.
class _FailingAuthRepository extends InMemoryAuthRepository {
  @override
  Future<void> updateDailyGoal(int minutes) async {
    throw StateError('ağ hatası');
  }
}

List<Override> _overrides(
  SharedPreferences prefs, {
  required bool running,
  InMemoryAuthRepository? auth,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  if (auth != null) authRepositoryProvider.overrideWithValue(auth),
  authStateProvider.overrideWith((ref) => Stream.value(_me)),
  userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
  todayRecordedSecondsProvider.overrideWithValue(7200),
  dailyGoalMinutesProvider.overrideWithValue(240),
  studyTimerProvider.overrideWith(
    running ? _RunningTimerNotifier.new : _IdleTimerNotifier.new,
  ),
];

final _cardKey = GlobalKey();

/// Kartı **serbest yükseklikte** kurar: ölçülen sayı, o stilin kartın kaç
/// piksel yer kaplamasını İSTEDİĞİdir. (Ana Sayfa ızgarasında hücre yüksekliği
/// dışarıdan verilir; kart istediğinden uzun hücrede boşluk, kısa hücrede
/// kart-içi kaydırma/gizleme doğar — ikisinin de girdisi bu sayıdır.)
Future<void> _pump(
  WidgetTester tester,
  ClockStyle style, {
  bool running = false,
  double width = _kPhoneWidth,
  double textScale = 1.0,
  InMemoryAuthRepository? auth,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'clock_style': style.name,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs, running: running, auth: auth),
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: width,
                  child: KeyedSubtree(
                    key: _cardKey,
                    child: const StudyTimerCard(size: DashboardCardSize.medium),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  // `pumpAndSettle` yok: saniyelik ticker'lar sahneyi hiç durdurmaz.
  await tester.pump();
  await tester.pump();
}

/// Kartı Ana Sayfa ızgarasının yaptığı gibi **sabit yükseklikli hücreye**
/// koyar (`home_screen.dart` `heightOf` → `dashboardCardFor` → `SizedBox`).
Future<void> _pumpInCell(
  WidgetTester tester,
  ClockStyle style, {
  required double cellHeight,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'clock_style': style.name,
  });
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs, running: false),
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: _kPhoneWidth,
              height: cellHeight,
              child: KeyedSubtree(
                key: _cardKey,
                child: const StudyTimerCard(size: DashboardCardSize.medium),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

double _height(WidgetTester tester) =>
    tester.getSize(find.byKey(_cardKey)).height;

Finder _byTypeName(String name) => find.descendant(
  of: find.byKey(_cardKey),
  matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == name),
);

/// Ekranda O AN duran şeritlerin metinleri.
Set<String> _visibleSnackTexts(WidgetTester tester) => {
  for (final w in tester.widgetList<Text>(
    find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
  ))
    if (w.data != null) w.data!,
};

/// Şerit KUYRUĞUNU boşaltıp görülen tüm metinleri toplar. `ScaffoldMessenger`
/// şeritleri sıraya dizer: aynı anda yalnız biri ağaçtadır, o yüzden tek
/// kareye bakan bir iddia ikinci şeridi hiç görmez.
Future<Set<String>> _drainSnackBars(WidgetTester tester) async {
  final seen = <String>{..._visibleSnackTexts(tester)};
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    seen.addAll(_visibleSnackTexts(tester));
  }
  return seen;
}

Finder _inCard(Finder matching) =>
    find.descendant(of: find.byKey(_cardKey), matching: matching);

void main() {
  void widen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  final l10n = lookupAppLocalizations(const Locale('tr'));

  group('WP-715 · 360 dp yükseklik tablosu', () {
    testWidgets('compact, mevcut en kısa stilden ölçülebilir kadar kısa', (
      tester,
    ) async {
      widen(tester);
      final measured = <ClockStyle, double>{};
      for (final style in ClockStyle.values) {
        await _pump(tester, style);
        expect(tester.takeException(), isNull, reason: '${style.name} taştı');
        measured[style] = _height(tester);
      }

      final table = measured.entries
          .map(
            (e) => '${e.key.name.padRight(12)} ${e.value.toStringAsFixed(1)}',
          )
          .join('\n');
      // Tablo rapora girer: iddia "izlenim" değil ölçüm olsun.
      // ignore: avoid_print
      print('WP-715 · 360 dp kart yüksekliği (px)\n$table');

      final others = <ClockStyle, double>{...measured}
        ..remove(ClockStyle.compact);
      final smallestOther = others.values.reduce((a, b) => a < b ? a : b);
      final compact = measured[ClockStyle.compact]!;

      expect(
        compact,
        lessThanOrEqualTo(smallestOther - _kRequiredDrop),
        reason:
            'compact ${compact.toStringAsFixed(1)} px; mevcut en kısa stil '
            '${smallestOther.toStringAsFixed(1)} px. Fark '
            '${(smallestOther - compact).toStringAsFixed(1)} px — en az '
            '$_kRequiredDrop px olmalı. Yeni görünüm eskisiyle aynıysa seçenek '
            'yine "küçüklük vaat edip hiçbir şey küçültmüyor" demektir.',
      );
    });

    testWidgets('mevcut beş stil birbirinden ölçülebilir kadar FARKLI DEĞİL', (
      tester,
    ) async {
      // Sahibin "tam farklarını anlayamadım" cümlesinin sayısal karşılığı:
      // beş stilin kart yüksekliği en fazla 120 px bandına sıkışır. Yani
      // seçenekler arasında bir BOYUT seçeneği yoktu; hepsi çizim varyantıydı.
      widen(tester);
      final measured = <double>[];
      for (final style in ClockStyle.values) {
        if (style == ClockStyle.compact) continue;
        await _pump(tester, style);
        measured.add(_height(tester));
      }
      final min = measured.reduce((a, b) => a < b ? a : b);
      final max = measured.reduce((a, b) => a > b ? a : b);
      expect(
        max - min,
        lessThan(120),
        reason:
            'Bu iddia bir FOTOĞRAFTIR: eski beş stil yükseklikte birbirine '
            'yakındı (${min.toStringAsFixed(1)}–${max.toStringAsFixed(1)} px). '
            'Bandı genişleten bir değişiklik geldiyse tablo yeniden ölçülmeli.',
      );
    });
  });

  group('WP-715 · SABİT HÜCREDE boyanan kart yüksekliği', () {
    // 🔴 Asıl kusur burada: Ana Sayfa ızgarası kartı `SizedBox(height: hücre)`
    // içine koyar ve `Card` o kutuyu doldurur. İçeriği kısaltmak tek başına
    // hiçbir şey küçültmez — kullanıcı "Kompakt"ı seçip aynı büyüklükte,
    // artık BOŞ bir kart görürdü. Ölçülen sayı: hücrenin değil KARTIN
    // boyanan yüksekliği.
    const cell = 400.0;

    Future<double> paintedHeight(WidgetTester tester, ClockStyle style) async {
      await _pumpInCell(tester, style, cellHeight: cell);
      expect(tester.takeException(), isNull);
      return tester.getSize(_inCard(find.byType(Card)).first).height;
    }

    testWidgets('compact kart hücreyi DOLDURMAZ, diğerleri doldurur', (
      tester,
    ) async {
      widen(tester);
      final painted = <ClockStyle, double>{};
      for (final style in ClockStyle.values) {
        painted[style] = await paintedHeight(tester, style);
      }
      // ignore: avoid_print
      print(
        'WP-715 · $cell px hücrede BOYANAN kart yüksekliği (px)\n'
        '${painted.entries.map((e) => '${e.key.name.padRight(12)} '
            '${e.value.toStringAsFixed(1)}').join('\n')}',
      );

      for (final style in ClockStyle.values) {
        if (style == ClockStyle.compact) continue;
        expect(
          painted[style],
          cell,
          reason:
              '${style.name} artık hücreyi doldurmuyor — mevcut görünümler '
              'değişmemeliydi',
        );
      }
      expect(
        painted[ClockStyle.compact],
        lessThan(cell / 2),
        reason:
            'Kompakt kart $cell px hücrede ${painted[ClockStyle.compact]} px '
            'boyanıyor. Hücreyi dolduruyorsa kullanıcı yine "kart hâlâ çok '
            'büyük" der; seçenek yalnız içeriği seyreltmiş olur.',
      );
      // Kart daralmamalı: yalnız YÜKSEKLİK düşer.
      expect(
        tester.getSize(_inCard(find.byType(Card)).first).width,
        _kPhoneWidth,
      );
    });
  });

  group('WP-715 · compact NEYİ gizliyor (yazılı karar, ölçülü)', () {
    // Küçültme "özellik silme" değildir: hangi satırın düştüğü BURADA yazılı.
    // Sabotaj (compact'i eskisiyle aynı yapmak) bu grubu topluca düşürür.
    const hiddenTypes = ['_GoalProgress', '_SubjectSelector'];

    testWidgets('compact: ikincil satırlar çizilmez', (tester) async {
      widen(tester);
      await _pump(tester, ClockStyle.compact);
      expect(tester.takeException(), isNull);

      for (final name in hiddenTypes) {
        expect(
          _byTypeName(name),
          findsNothing,
          reason: '$name kompakt kartta hâlâ çiziliyor',
        );
      }
      expect(_inCard(find.text(l10n.classroomBugun)), findsNothing);
      expect(_inCard(find.text(l10n.classroomManuelSureEkle)), findsNothing);
      expect(_inCard(find.text(l10n.classroomGunlukHedef)), findsNothing);
    });

    testWidgets('digits: aynı satırların hepsi DURUYOR (kural taşmadı)', (
      tester,
    ) async {
      widen(tester);
      await _pump(tester, ClockStyle.digits);
      expect(tester.takeException(), isNull);

      for (final name in hiddenTypes) {
        expect(
          _byTypeName(name),
          findsOneWidget,
          reason: '$name kompakt olmayan kartta kayboldu — gizleme taştı',
        );
      }
      expect(_inCard(find.text(l10n.classroomBugun)), findsOneWidget);
      expect(_inCard(find.text(l10n.classroomManuelSureEkle)), findsOneWidget);
      expect(_inCard(find.text(l10n.classroomGunlukHedef)), findsOneWidget);
    });

    testWidgets('compact: süre ve Başlat/Durdur AYNI satırda', (tester) async {
      // "Tek satır" bir iddia; ölçülür: iki öğenin dikey aralıkları çakışır.
      widen(tester);
      await _pump(tester, ClockStyle.compact);
      final clock = tester.getRect(_inCard(find.byType(StudyClock)));
      final action = tester.getRect(
        _inCard(
          find.widgetWithText(FilledButton, l10n.classroomCalismayaBasla),
        ),
      );
      expect(
        clock.top < action.bottom && action.top < clock.bottom,
        isTrue,
        reason:
            'saat ${clock.top}-${clock.bottom}, düğme ${action.top}-'
            '${action.bottom} — alt alta duruyorlar, kart tek satır değil',
      );
    });
  });

  group('WP-715 · işlev kaybı yok — her görünümde ayrı ayrı', () {
    for (final style in ClockStyle.values) {
      testWidgets('${style.name}: dururken süre görünür + Başlat basılabilir', (
        tester,
      ) async {
        widen(tester);
        await _pump(tester, style);
        expect(tester.takeException(), isNull);

        // SÜRE: kullanıcının GÖRDÜĞÜ satır ölçülür, provider değeri değil.
        expect(_inCard(find.text('00:00:00')), findsOneWidget);
        expect(_inCard(find.byType(StudyClock)), findsOneWidget);

        // BAŞLAT: var olması yetmez — düğmenin merkezi gerçekten
        // **vurulabilir** olmalı (`hitTestable`: başka bir şeyin altında ya da
        // kırpılmış değil) ve dokunma hedefi yüksekliğini korumalı.
        final start = _inCard(
          find.widgetWithText(FilledButton, l10n.classroomCalismayaBasla),
        );
        expect(start, findsOneWidget);
        expect(start.hitTestable(), findsOneWidget);
        expect(tester.getSize(start).height, greaterThanOrEqualTo(40));
      });

      testWidgets(
        '${style.name}: çalışırken süre görünür + Durdur basılabilir',
        (tester) async {
          widen(tester);
          await _pump(tester, style, running: true);
          expect(tester.takeException(), isNull);

          expect(_inCard(find.byType(StudyClock)), findsOneWidget);
          final stop = _inCard(
            find.widgetWithText(FilledButton, l10n.classroomDurdur),
          );
          expect(stop, findsOneWidget);
          expect(stop.hitTestable(), findsOneWidget);
          expect(tester.getSize(stop).height, greaterThanOrEqualTo(40));

          // Saat görünümü menüsü her stilde ulaşılabilir kalmalı — yoksa
          // `compact` seçen kullanıcı geri dönemez (tek yönlü kapı).
          expect(
            _inCard(find.byTooltip(l10n.classroomSaatGorunumu)),
            findsOneWidget,
          );
        },
      );
    }
  });

  group('WP-715 · taşma yok (360 dp)', () {
    for (final style in ClockStyle.values) {
      for (final scale in const [1.0, 1.3, 1.6]) {
        testWidgets('${style.name} · yazı ×$scale', (tester) async {
          widen(tester);
          await _pump(tester, style, running: true, textScale: scale);
          expect(tester.takeException(), isNull);
          await _pump(tester, style, textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('WP-715 · seçenekler ANLAŞILIR', () {
    testWidgets('her seçeneğin ayrı bir açıklaması var', (tester) async {
      widen(tester);
      await _pump(tester, ClockStyle.digits);

      await tester.tap(_inCard(find.byTooltip(l10n.classroomSaatGorunumu)));
      await tester.pumpAndSettle();

      final seen = <String>{};
      for (final style in ClockStyle.values) {
        final label = switch (style) {
          ClockStyle.digits => l10n.classroomSadeRakam,
          ClockStyle.ring => l10n.classroomHedefHalkasi,
          ClockStyle.colorShift => l10n.classroomRenkGecisi,
          ClockStyle.slice => l10n.classroomYarisDilimi,
          ClockStyle.minimal => l10n.classroomMinimal,
          ClockStyle.compact => l10n.classroomSaatKompakt,
        };
        final description = switch (style) {
          ClockStyle.digits => l10n.classroomSaatSadeRakamAciklama,
          ClockStyle.ring => l10n.classroomSaatHedefHalkasiAciklama,
          ClockStyle.colorShift => l10n.classroomSaatRenkGecisiAciklama,
          ClockStyle.slice => l10n.classroomSaatYarisDilimiAciklama,
          ClockStyle.minimal => l10n.classroomSaatIncehalkaAciklama,
          ClockStyle.compact => l10n.classroomSaatKompaktAciklama,
        };
        expect(
          find.text(label),
          findsOneWidget,
          reason: '${style.name} adı yok',
        );
        expect(
          find.text(description),
          findsOneWidget,
          reason: '${style.name} menüde ne yaptığını söylemiyor',
        );
        // Açıklamalar kopyala-yapıştır olmamalı: aynı metin iki seçeneği de
        // anlatıyorsa kullanıcı yine farkı göremez.
        expect(
          seen.add(description),
          isTrue,
          reason: '$description tekrar etti',
        );
        expect(seen.add(label), isTrue, reason: '$label tekrar etti');
      }
    });

    testWidgets('"Minimal" adı artık boyut vaat etmiyor', (tester) async {
      // 🔴 Sahip şikâyeti: "minimal var, seçiyorum kart hâlâ çok büyük".
      // Ad, yaptığı işi (çizgi inceltme) anlatmalı.
      expect(l10n.classroomMinimal, isNot('Minimal'));
      expect(
        l10n.classroomSaatIncehalkaAciklama.toLowerCase(),
        contains('küçültmez'),
      );
    });
  });

  group('WP-715 (ek) · günlük hedef kaydı İKİ YÖNLÜ geri bildirim verir', () {
    // 🔴 WP-710 günlük hedef ayarını Ayarlar'dan kaldırdı. O yolda kayıt
    // başarılı olunca onay şeridi çıkıyordu; tek düzenleme yüzeyi bu karta
    // inince onay sessizce kayboldu — geriye yalnız HATA dalı kalmıştı.
    // İddia iki yönlüdür: tek yönlü olsaydı "her durumda onay göster"
    // sabotajı kapıdan geçerdi.
    Future<void> saveGoal(WidgetTester tester) async {
      await tester.tap(_inCard(find.text(l10n.classroomGunlukHedef)));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.profileKaydet),
        findsOneWidget,
        reason: 'hedef düzenleme diyaloğu açılmadı',
      );
      await tester.tap(find.text(l10n.profileKaydet));
      await tester.pumpAndSettle();
    }

    testWidgets('kayıt başarılı → onay görünür, hata görünmez', (tester) async {
      widen(tester);
      await _pump(tester, ClockStyle.digits, auth: _OkAuthRepository());
      await saveGoal(tester);
      final seen = await _drainSnackBars(tester);
      expect(
        seen,
        contains(l10n.profileGunlukHedefGuncellendi),
        reason:
            'hedef kaydedildi ama kullanıcıya hiçbir onay verilmedi '
            '(WP-710 kaldırmasında kaybolan davranış). Görülen: $seen',
      );
      expect(seen, isNot(contains(l10n.authBeklenmeyenBirHataOlustu)));
    });

    testWidgets('kayıt düştü → hata görünür, sahte onay YOK', (tester) async {
      widen(tester);
      await _pump(tester, ClockStyle.digits, auth: _FailingAuthRepository());
      await saveGoal(tester);
      // 🔴 Şerit KUYRUĞU boşaltılır: ilk şerit ekrandayken ikincisi ağaçta
      // olmaz. Yalnız o ana bakan bir iddia, "her durumda onay göster"
      // sabotajını kaçırıyordu — ölçüldü, kapı yeşil kalmıştı.
      final seen = await _drainSnackBars(tester);
      expect(seen, contains(l10n.authBeklenmeyenBirHataOlustu));
      expect(
        seen,
        isNot(contains(l10n.profileGunlukHedefGuncellendi)),
        reason:
            'yazma düşmüşken "güncellendi" demek kullanıcıyı yanıltır. '
            'Görülen: $seen',
      );
    });
  });

  group('WP-715 · masaüstü düzeni bozulmadı', () {
    testWidgets('varsayılan stil hâlâ digits — compact opt-in', (tester) async {
      // Masaüstünde sorun yok (sahip söyledi). Kart varsayılan olarak bugünkü
      // görünümünde kalır; compact yalnız kullanıcı seçerse devreye girer.
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(clockStyleProvider), ClockStyle.digits);
    });

    testWidgets('1280 dp masaüstü bandında tam kart aynen çizilir', (
      tester,
    ) async {
      widen(tester);
      await _pump(tester, ClockStyle.digits, width: 720);
      expect(tester.takeException(), isNull);
      // Masaüstü şikâyeti yok → hiçbir satır kaybolmamalı.
      expect(_inCard(find.text(l10n.classroomBugun)), findsOneWidget);
      expect(_inCard(find.text(l10n.classroomManuelSureEkle)), findsOneWidget);
      expect(_inCard(find.text(l10n.classroomGunlukHedef)), findsOneWidget);
    });
  });
}
