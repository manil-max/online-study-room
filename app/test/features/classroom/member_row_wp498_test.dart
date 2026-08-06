@Tags(['golden'])
library;

// WP-498 (V58-N04 / rapor T07): "Grup üye satırında ad tek harfe düşüyor."
//
// 🔴 Kök neden yerleşim önceliğiydi. Satır `ListTile` idi ve `trailing`e dört
// `IconButton` diziliyordu (dürt · sustur · çıkar · yasakla). `ListTile` önce
// `trailing`e istediği genişliği verir, `title`a **kalanı** bırakır.
//
// Eski koda karşı ölçüldü (tahmin değil), uzun adlı üye satırında ada kalan
// genişlik:
//     320 dp ekran →   0.0 dp  (ad hiç çizilmiyor, %0)
//     360 dp ekran →  12.7 dp  (%4 — sahibin gördüğü "tek harf")
//     411 dp ekran →  63.7 dp  (%17)
// Aynı ölçüm yeni yerleşimde 108 / 148 / 192 dp veriyor.
//
// Şikâyetin kanıtı ekrandaki tek istisnaydı: eylem simgesi **olmayan** satır
// (yöneticinin kendi satırı) adı tam gösteriyordu. Yani hata ada değil,
// eylemlerin aldığı yere bağlıydı.
//
// ⚠️ Test yazarken ölçülen tuzak: kabul "ada en az 12 karakter" diyor, ama
// `flutter test` gerçek yazı tipini yüklemez — Ahem'de **her** glif fontSize
// kadar geniştir (16 sp → 16 dp), 12 karakter 192 dp eder. Karakter saymak bu
// yüzden testte anlamsız; ölçülen şey **ada ayrılan dp** ve karşılığı
// açıkça yazıldı (Roboto 16 sp ortalama ilerleme ~8 dp → 12 karakter ≈ 96 dp).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Kabulün dp karşılığı: 12 karakter × ~8 dp (Roboto 16 sp ortalama ilerleme).
const double _kMinNameWidth = 96;

/// Ünvan sözlüğündeki gerçek bir başarım kimliği (TR adı uzun olanlardan).
const _longTitleId = 'secret_last_second';

const _longName =
    'Abdurrahman Muhammed Kemalettin Serdaroglu Buyukcekmeceli Ogrenci';

Profile _member(String id, String name, {String? titleId}) => Profile(
  id: id,
  displayName: name,
  createdAt: DateTime(2026, 1, 1),
  titleAchievementId: titleId,
);

final _owner = _member('owner-1', 'Sahip', titleId: _longTitleId);
final _shortMember = _member('peer-1', 'Ada');
final _longMember = _member('peer-2', _longName, titleId: _longTitleId);

/// Detay ekranını **gerçekten** verilen genişlikte kurar ve pump eder.
///
/// 🔴 Ölçülen tuzak: bu dosyanın ilk hâli komşusu gibi `MediaQuery(size: ...)`
/// kullanıyordu. `MediaQuery` yalnız onu **okuyan** widget'ları etkiler; kök
/// kısıt test penceresinden gelir (varsayılan 800×600). "320 dp'de ölçtük"
/// diyen her iddia aslında 800 dp'de sınanıyordu — ada kalan alan 570 dp
/// çıkıyordu ve test hiçbir şey kanıtlamıyordu. Genişlik iddiası için
/// pencerenin kendisi daraltılmalı.
///
/// İzleyici varsayılan olarak **yönetici**: dar durum odur, çünkü moderasyon
/// yuvası yalnız yöneticide çizilir.
Future<void> _pumpDetail(
  WidgetTester tester, {
  Profile? viewer,
  Size surface = const Size(320, 900),
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  final groups = InMemoryGroupRepository();
  final group = await groups.createGroup(name: 'Odak Grubu', creator: _owner);
  await groups.joinGroup(inviteCode: group.inviteCode, member: _shortMember);
  await groups.joinGroup(inviteCode: group.inviteCode, member: _longMember);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        authStateProvider.overrideWith((ref) => Stream.value(viewer ?? _owner)),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            // Yalnız yazı ölçeği eziliyor; boyut pencereden gelmeye devam eder.
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: ClassDetailScreen(group: group),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Üye bölümünü görünür hâle getirir.
///
/// 🔴 `scrollUntilVisible` tek başına yetmiyor: finder widget **ağaçta**
/// belirir belirmez duruyor, ama `ListView` cache extent yüzünden satırı
/// görünür alanın altında da kurar. Dokunma o durumda ıskalıyor
/// (`warnIfMissed`) ve "menüde iki eylem var" iddiası sessizce boşa düşüyordu.
Future<void> _revealMembers(WidgetTester tester) async {
  final row = find.byKey(memberRowKey(_longMember.id));
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
}

void main() {
  group('ada gerçek bir alan kalıyor', () {
    testWidgets('320 dp ekranda ad için en az 12 karakterlik yer var', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      // Uzun ad kırpılacağı için `Text` kutusu ada ayrılan alanın tamamıdır.
      final nameWidth = tester.getSize(find.text(_longName)).width;

      // Eski yerleşimde bu değer bu ekranda **0.0 dp** idi: dört yuva
      // (4 × 48 = 192 dp) + avatar + dolgular 280 dp'lik satırı bitiriyordu.
      expect(
        nameWidth,
        greaterThanOrEqualTo(_kMinNameWidth),
        reason: 'ada yalnız $nameWidth dp kalıyor',
      );
    });

    testWidgets('ad alanı satırın en geniş parçası', (tester) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      final row = tester.getSize(find.byKey(memberRowKey(_longMember.id)));
      final nameWidth = tester.getSize(find.text(_longName)).width;

      // 🔴 Salt dp sınırı yetmez: yarın avatar büyürse ya da dördüncü bir
      // yuva geri gelirse sayı hâlâ tutabilir. Asıl kural oranda: ad,
      // satırın **üçte birinden** az yer alamaz. Eskiden %0'dı.
      expect(
        nameWidth / row.width,
        greaterThan(1 / 3),
        reason: 'ad satırın ${(nameWidth / row.width * 100).round()}%\'ini alıyor',
      );
    });

    testWidgets('ad tek satırda ve kırpılarak kalır', (tester) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
    });
  });

  group('hiçbir eylem kaybolmadı', () {
    testWidgets('dürtme ve susturma satırda kalır', (tester) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      // Kart tuzağı: dürtme birincil eylem, menüye gömülemez.
      expect(find.byKey(const ValueKey('nudge-peer-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('mute-peer-2')), findsOneWidget);
    });

    testWidgets('çıkarma ve yasaklama taşma menüsünde, adlarıyla', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      await tester.tap(find.byKey(const ValueKey('moderate-peer-2')));
      await tester.pumpAndSettle();

      // WP-446 kazanımı: iki eylem ayrı adlarla ve "Engelle" metni olmadan.
      expect(find.text('Üyeyi çıkar'), findsOneWidget);
      expect(find.text('Üyeyi yasakla'), findsOneWidget);
      expect(find.text('Engelle'), findsNothing);
    });

    testWidgets('menüden çıkarma seçilince onay diyaloğu açılır', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      await tester.tap(find.byKey(const ValueKey('moderate-peer-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Üyeyi çıkar'));
      await tester.pumpAndSettle();

      // 🔴 Menü kalemi eylemi gerçekten **bağlamalı**; boş bir menü de
      // yukarıdaki metin testini geçerdi. Kapsam cümlesi WP-446'nın.
      expect(find.textContaining('gruptan çıkarılsın mı'), findsOneWidget);
      expect(find.text('Çıkar'), findsOneWidget);
    });
  });

  group('görünürlük koşulu aynen korunuyor', () {
    testWidgets('yönetici olmayan üye moderasyon yuvasını hiç görmez', (
      tester,
    ) async {
      await _pumpDetail(tester, viewer: _shortMember);
      await _revealMembers(tester);

      // Boş menü de açılmamalı: düğmenin kendisi çizilmez.
      expect(find.byKey(const ValueKey('moderate-peer-2')), findsNothing);
      expect(find.byKey(const ValueKey('moderate-owner-1')), findsNothing);
      // Dürtme herkeste durur.
      expect(find.byKey(const ValueKey('nudge-peer-2')), findsOneWidget);
    });

    testWidgets('kurucunun satırında moderasyon yok, kendi satırında eylem yok', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      // Kurucu = izleyici: kendi satırında dürtme/sustur/moderasyon olmaz.
      expect(find.byKey(const ValueKey('moderate-owner-1')), findsNothing);
      expect(find.byKey(const ValueKey('nudge-owner-1')), findsNothing);
      expect(find.byKey(const ValueKey('mute-owner-1')), findsNothing);
    });
  });

  group('WP-487 kazanımı geri gitmedi', () {
    testWidgets('satır yüksekliği ad/ünvan/eylem varlığından bağımsız', (
      tester,
    ) async {
      await _pumpDetail(tester);
      await _revealMembers(tester);

      // 🔴 `ListTile` gidince iki satırlık taban yükseklik de gitmişti:
      // eylemi olan satır 64 dp, olmayan ~46 dp olurdu. Taban artık
      // `minHeight` olarak açıkça duruyor; bu iddia onu sabitler.
      final heights = [
        for (final m in [_owner, _shortMember, _longMember])
          tester.getSize(find.byKey(memberRowKey(m.id))).height,
      ];
      expect(
        heights.toSet(),
        hasLength(1),
        reason: 'liste satırları farklı yükseklikte: $heights',
      );
    });

    testWidgets('yazı ölçeği 1.6 ve 320 dp ekranda taşma yok', (tester) async {
      await _pumpDetail(tester, textScale: 1.6);
      await _revealMembers(tester);

      expect(find.byKey(memberRowKey(_longMember.id)), findsOneWidget);
    });

    testWidgets('yazı ölçeği 1.3\'te de ad alanı korunur', (tester) async {
      await _pumpDetail(tester, textScale: 1.3);
      await _revealMembers(tester);

      // Eylem yuvaları yazı ölçeğiyle büyümez; ad alanı daralmamalı.
      expect(
        tester.getSize(find.text(_longName)).width,
        greaterThanOrEqualTo(_kMinNameWidth),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('golden: 320 dp · uzun ad · ünvan · yönetici', (tester) async {
    await _pumpDetail(tester);
    await _revealMembers(tester);

    // ⚠️ Golden yalnız **yerleşimi** kanıtlar: `flutter test` gerçek
    // MaterialIcons fontunu yüklemez, simgeler boş kutu çizilir. Kabulün
    // ölçülebilir kısmı yukarıdaki dp/oran iddialarındadır.
    await expectLater(
      find.ancestor(
        of: find.byKey(memberRowKey(_longMember.id)),
        matching: find.byType(Card),
      ).first,
      matchesGoldenFile('goldens/member_row_wp498.png'),
    );
  });
}
