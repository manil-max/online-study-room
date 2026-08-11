// WP-714 — "grup ayarlarina girince en ustte members kismi olsun, altinda
// informations kismi" (sahip emri).
//
// 🔴 Bu dosya EKRAN sirasini olcer, agac sirasini degil. `ListView` cocuk
// dizisindeki index'e bakan bir iddia yanlis guven verir: kaydirma, ters
// yon (`reverse`), `Spacer`, negatif margin ya da bir bolumun sarmalanmasi
// agac sirasi ile dy sirasini ayirabilir. Bu yuzden her iddia
// `tester.getTopLeft(...).dy` ile GERCEK koordinat karsilastirir.
//
// Iki kol AYRI olculur: yonetici (`isAdmin == true`) ve normal uye. Ekranin
// bilgi bolumunde yalniz yoneticide cizilen satirlar var (kod yenile, engelli
// uyeler); uye kartinda da yalniz yoneticide cizilen moderasyon yuvasi var.
// Tek kolda dogru sira, digerinde dogru sira demek degildir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _kUyeler = 'Üyeler';
const _kBilgiler = 'Bilgiler';
const _kAyarlar = 'Ayarlar';
const _kDavetKodu = 'Davet kodu';

final _owner = Profile(
  id: 'owner-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);
final _peer = Profile(
  id: 'peer-1',
  displayName: 'Arkadas',
  createdAt: DateTime(2026, 1, 1),
);

/// Ekrani GERCEKTEN monte eder (sahte agac degil): `InMemoryGroupRepository`
/// uzerinde iki uyeli gercek bir grup kurulur ve `ClassDetailScreen` pump edilir.
///
/// 🔴 Olculen tuzak (komsu WP-498 dosyasindan devralindi): `MediaQuery(size:)`
/// kok kisiti daraltmaz. Genislik/tasma iddiasi icin pencerenin KENDISI
/// ayarlanmali — bu yuzden `tester.view.physicalSize`.
///
/// Sira iddialarinda pencere bilerek uzun (1600 dp): `ListView` yalniz gorunur
/// alan + cache extent icindeki cocuklari kurar; kisa pencerede alttaki bolum
/// agacta hic olusmaz ve "dy karsilastirmasi" sessizce `findsNothing` hatasina
/// donusur — yani sirayi degil, kaydirma davranisini olcmus oluruz.
Future<StudyGroup> _pumpDetail(
  WidgetTester tester, {
  required bool asAdmin,
  Size surface = const Size(360, 1600),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  final groups = InMemoryGroupRepository();
  final group = await groups.createGroup(name: 'Odak Kampi', creator: _owner);
  await groups.joinGroup(inviteCode: group.inviteCode, member: _peer);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(groups),
        authStateProvider.overrideWith(
          (ref) => Stream.value(asAdmin ? _owner : _peer),
        ),
        groupPresenceProvider.overrideWith(
          (ref) => Stream.value(const <Presence>[]),
        ),
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
  return group;
}

double _dy(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder).dy;

void main() {
  group('WP-714 — uyeler bolumu bilgilerin USTUNDE (gercek koordinat)', () {
    testWidgets('yonetici kolu: "Üyeler" basligi "Bilgiler" basliginin ustunde', (
      tester,
    ) async {
      await _pumpDetail(tester, asAdmin: true);

      final uyeler = _dy(tester, find.text(_kUyeler));
      final bilgiler = _dy(tester, find.text(_kBilgiler));

      expect(
        uyeler,
        lessThan(bilgiler),
        reason:
            'Yoneticide uye bolumu hala altta: Üyeler dy=$uyeler, '
            'Bilgiler dy=$bilgiler.',
      );
    });

    testWidgets('normal uye kolu: "Üyeler" basligi "Bilgiler" basliginin ustunde', (
      tester,
    ) async {
      await _pumpDetail(tester, asAdmin: false);

      final uyeler = _dy(tester, find.text(_kUyeler));
      final bilgiler = _dy(tester, find.text(_kBilgiler));

      expect(
        uyeler,
        lessThan(bilgiler),
        reason:
            'Normal uyede uye bolumu hala altta: Üyeler dy=$uyeler, '
            'Bilgiler dy=$bilgiler.',
      );
    });

    testWidgets('yonetici kolu: uye SATIRI davet kodu satirinin ustunde', (
      tester,
    ) async {
      await _pumpDetail(tester, asAdmin: true);

      // Baslik metni tasinip kart yerinde kalabilirdi; olculen sey icerigin
      // kendisi olmali.
      final uyeSatiri = _dy(tester, find.byKey(memberRowKey(_peer.id)));
      final davetKodu = _dy(tester, find.widgetWithText(ListTile, _kDavetKodu));

      expect(
        uyeSatiri,
        lessThan(davetKodu),
        reason:
            'Uye karti bilgi kartinin altinda kalmis: uye satiri dy=$uyeSatiri, '
            'davet kodu dy=$davetKodu.',
      );
    });

    testWidgets('normal uye kolu: uye SATIRI davet kodu satirinin ustunde', (
      tester,
    ) async {
      await _pumpDetail(tester, asAdmin: false);

      final uyeSatiri = _dy(tester, find.byKey(memberRowKey(_owner.id)));
      final davetKodu = _dy(tester, find.widgetWithText(ListTile, _kDavetKodu));

      expect(
        uyeSatiri,
        lessThan(davetKodu),
        reason:
            'Uye karti bilgi kartinin altinda kalmis: uye satiri dy=$uyeSatiri, '
            'davet kodu dy=$davetKodu.',
      );
    });
  });

  group('WP-714 — sira degisimi baska hicbir seyi bozmadi', () {
    testWidgets('ayarlar bolumu her iki kolda da EN ALTTA kalir', (
      tester,
    ) async {
      for (final asAdmin in [true, false]) {
        await _pumpDetail(tester, asAdmin: asAdmin);

        final ayarlar = _dy(tester, find.text(_kAyarlar));
        expect(
          ayarlar,
          greaterThan(_dy(tester, find.text(_kUyeler))),
          reason: 'Ayarlar uyelerin ustune cikti (isAdmin=$asAdmin).',
        );
        expect(
          ayarlar,
          greaterThan(_dy(tester, find.text(_kBilgiler))),
          reason: 'Ayarlar bilgilerin ustune cikti (isAdmin=$asAdmin).',
        );
      }
    });

    testWidgets('uye listesi hala VERI yukluyor — spinner/hata degil', (
      tester,
    ) async {
      // 🔴 Sira degisiminin sessiz kirilma yolu tam olarak buydu: bir saglayici
      // bilgi bolumunun `build`inde isiniyor olsaydi, uye karti one alininca
      // liste bos/spinner kalirdi ve kusur "uyeler gorunmuyor" diye cikardi.
      // Iki uye de gercekten cizilmis olmali.
      for (final asAdmin in [true, false]) {
        await _pumpDetail(tester, asAdmin: asAdmin);

        expect(
          find.byKey(memberRowKey(_owner.id)),
          findsOneWidget,
          reason: 'Kurucu satiri yok (isAdmin=$asAdmin).',
        );
        expect(
          find.byKey(memberRowKey(_peer.id)),
          findsOneWidget,
          reason: 'Uye satiri yok (isAdmin=$asAdmin).',
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Uye karti spinner\'da kalmis (isAdmin=$asAdmin).',
        );
      }
    });

    testWidgets('yonetici eylemleri (kod yenile / engelli uyeler) duruyor', (
      tester,
    ) async {
      await _pumpDetail(tester, asAdmin: true);

      expect(find.byTooltip('Kodu yenile'), findsOneWidget);
      expect(find.text('Engellenen kullanıcılar'), findsOneWidget);
      // Moderasyon yuvasi yalniz yoneticide, kurucunun kendi satirinda degil.
      expect(find.byKey(ValueKey('moderate-${_peer.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('moderate-${_owner.id}')), findsNothing);
    });

    testWidgets('normal uyede gruptan cikis satiri duruyor', (tester) async {
      await _pumpDetail(tester, asAdmin: false);

      expect(find.byKey(const ValueKey('leave-group-action')), findsOneWidget);
      // Yonetici-only eylemler sizmadi.
      expect(find.byTooltip('Kodu yenile'), findsNothing);
    });

    testWidgets('uye satiri anahtarlari degismedi (test/golden kancasi)', (
      tester,
    ) async {
      await _pumpDetail(tester, asAdmin: true);

      // `memberRowKey` bu ekranin kararli kancasi; sira degisiminde anahtar
      // uretimi bozulursa butun komsu testler tipe gore aramaya duser.
      expect(memberRowKey(_peer.id), const ValueKey('member-row-peer-1'));
      expect(find.byKey(memberRowKey(_peer.id)), findsOneWidget);
    });

    testWidgets('liste hala tek dikey kaydirici — kaydirma konumu tek yerde', (
      tester,
    ) async {
      // Bolumler ayri kaydiricilara bolunmus olsaydi kaydirma konumu ikiye
      // ayrilir ve geri donuste ekran baska yerden acilirdi.
      await _pumpDetail(tester, asAdmin: true, surface: const Size(360, 800));

      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('WP-714 — 360 dp tasma yok', () {
    testWidgets('360x800 telefonda hicbir bolum tasmiyor (iki kol)', (
      tester,
    ) async {
      for (final asAdmin in [true, false]) {
        await _pumpDetail(tester, asAdmin: asAdmin, surface: const Size(360, 800));

        expect(
          tester.takeException(),
          isNull,
          reason: 'Yeni siralamada tasma/duzen hatasi (isAdmin=$asAdmin).',
        );

        // Kaydirilarak da tasma dogmamali: alttaki bolum ancak kaydirinca
        // kurulur, tasma orada da olculmeli.
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Kaydirdiktan sonra tasma/duzen hatasi (isAdmin=$asAdmin).',
        );
      }
    });
  });
}
