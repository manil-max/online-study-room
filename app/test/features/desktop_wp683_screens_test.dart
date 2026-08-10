// WP-683 GEDIK 2 — HIC OLCULMEMIS EKRANLAR.
//
// Yedi ekran bugune kadar tek bir masaustu iddiasina baglanmadi:
//   bildirim merkezi · duyurular · bildirim izinleri · SSS ·
//   engellenenler · durtmesi susturulanlar · surum notlari
//
// ============================== DISIPLIN =====================================
//
// 1. Iddia CIZILEN kutudan okunur. Kaynakta `maxWidth: 600` yazmasi kanit
//    degildir (depo dersi: "kullanicinin GORDUGU satiri test et").
// 2. 🔴 Sahte yesil tuzagi: olcum ANAHTARA degil, boyanan `Card` yuzeylerine
//    ve iki gercek metnin glif kutularina bakar. `Align`/`Center` gibi kabi
//    dolduran bir widget'i olcmek tavani degil KABI olcer.
// 3. Etiket-deger mesafesi = etiketin SOL kenari -> degerin SAG kenari
//    (SPEC KURAL 2.2'nin lafzi).
// 4. Masaustu dali `debugDefaultTargetPlatformOverride` ile acilir; bayrak
//    govde bitmeden geri alinir.
//
// ============ HIPOTEZ CURUTULDU (hunter §4) — GERCEK KABUK ==================
//
// Lider notu: "Bunlar masaustunde aciliyor ve muhtemelen ayni kusuru tasiyor:
// tek sutun, PENCERE GENISLIGINE yayilan etiket-deger satirlari."
//
// Yarisi yanlis. Olculdu (`lib/features/profile/profile_screen.dart:210`):
// Ayarlar masaustunde `showDesktopPanel` ile acilir, yani **920 px**'lik bir
// `SizedBox` icinde kendi `Navigator`ini tasir
// (`desktop_surface.dart:94`, `DesktopSurface.panelWidth = 920`). Ayarlar'dan
// push edilen bildirim merkezi / duyurular / engellenenler / susturulanlar /
// SSS o panelin ICINDE cizilir: 2560 px'lik pencerede bile satir 920 px'te
// durur, pencereyle BUYUMEZ.
//
// Ama:
//   (a) 920 px'lik satir da SPEC KURAL 2.2'nin 600 px sert tavanini asar —
//       kusur var, buyume mekanizmasi baska.
//   (b) SSS'in IKINCI cagri yeri panelde DEGIL: `auth_screen.dart:446` onu
//       oturum acmadan, tam pencere rotasi olarak acar. Orada satir gercekten
//       pencere genisligine yayilir (2560'ta 2512 px olculdu).
//   (c) `MediaQuery.sizeOf` panel icinde hala TUM PENCEREYI verir. Bu yuzden
//       buradaki tavanlar `LayoutBuilder`/`ConstrainedBox` ile BANTTAN
//       kurulur; `MediaQuery`den kurulan bir tavan panelde yanlis karar verir.
//
// Bu yuzden her ekran hem dort pencere genisliginde (1008/1200/1920/2560, tam
// pencere rotasi) hem de 920 px'lik panel bandinda olculur.
//
// ==================== WP-683 ONCESI / SONRASI OLCUM ==========================
//
// Ayni harness, `devicePixelRatio = 1`, `WP-683 (0)` tanilama testinin
// ciktisi. "kart" = boyanan en genis `Card` yuzeyi.
//
// | ekran | 1008 | 1200 | 1920 | 2560 | panel(920) |
// |---|---:|---:|---:|---:|---:|
// | bildirim merkezi   ONCE | 976 | 1168 | 1888 | 2528 | 888 |
// | bildirim merkezi   SONRA| 600 |  600 |  600 |  600 | 600 |
// | bildirim izinleri  ONCE | 976 | 1168 | 1888 | 2528 | 888 |
// | bildirim izinleri  SONRA| 600 |  600 |  600 |  600 | 600 |
// | duyurular          ONCE | 976 | 1168 | 1888 | 2528 | 888 |
// | duyurular          SONRA| 600 |  600 |  600 |  600 | 600 |
// | SSS                ONCE | 976 | 1168 | 1888 | 2528 | 888 |
// | SSS                SONRA| 600 |  600 |  600 |  600 | 600 |
// | engellenenler      ONCE | 984 | 1176 | 1896 | 2536 | 896 |
// | engellenenler      SONRA| 608 |  608 |  608 |  608 | 608 |
// | susturulanlar      ONCE | 984 | 1176 | 1896 | 2536 | 896 |
// | susturulanlar      SONRA| 608 |  608 |  608 |  608 | 608 |
// | surum notlari      ONCE | 976 | 1168 | 1888 | 2528 | 888 |
// | surum notlari      SONRA| 600 |  600 |  600 |  600 | 600 |
//
// Etiket–deger satiri (SPEC KURAL 2.2, sert tavan 600):
//
// | satir | 1008 | 1200 | 1920 | 2560 | panel |
// |---|---:|---:|---:|---:|---:|
// | "Aylik calisma raporu" -> "Yakinda"   ONCE | 812 | 1004 | 1724 | 2364 | 724 |
// |                                       SONRA| 436 |  436 |  436 |  436 | 436 |
// | "Engellenen Bora" -> "Engeli kaldir"  ONCE | 864 | 1056 | 1776 | 2416 | 776 |
// |                                       SONRA| 488 |  488 |  488 |  488 | 488 |
// | "Susturulan Deniz" -> "Susturmayi..." ONCE | 864 | 1056 | 1776 | 2416 | 776 |
// |                                       SONRA| 488 |  488 |  488 |  488 | 488 |
//
// En genis TEK paragraf (SPEC §2.3 prose tavani 600) SONRA: 429–570 px.
// Duyuru paragrafi ONCE 2560 px'lik pencerede **2208 px** boyaniyordu
// (~294 karakter/satir; WCAG 1.4.8 tavani 80 karakter).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/faq_entry.dart';
import 'package:online_study_room/data/models/moderation_appeal.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/models/nudge_mute.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/notification_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/providers/support_providers.dart';
import 'package:online_study_room/features/notifications/announcements_screen.dart';
import 'package:online_study_room/features/notifications/notification_center_screen.dart';
import 'package:online_study_room/features/notifications/notification_permissions_screen.dart';
import 'package:online_study_room/features/safety/blocked_users_screen.dart';
import 'package:online_study_room/features/safety/muted_nudges_screen.dart';
import 'package:online_study_room/features/support/faq_screen.dart';
import 'package:online_study_room/features/updater/release_notes_screen.dart';
import 'package:online_study_room/features/updater/release_notes_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SPEC §2.2 — etiket–deger satiri SERT tavani (80 karakter, WCAG 2.1 1.4.8).
const double kLabelValueCap = DesktopBreakpoints.maxLabelValueWidth; // 600

/// SPEC §2.3 — duz metin / prose tavani.
const double kProseCap = DesktopBreakpoints.maxProseWidth; // 600

/// Bir "blok" (kart) tavani: 600 px'lik satir + `Card` yatay ic dolgusu 2x16.
///
/// Kardes masaustu ekranlari AYNI sayiyi ayni turetmeyle kullaniyor
/// (`kClockBlockMaxWidth`, `kGroupBlockMaxWidth` = 632). SPEC §2.3'un form
/// tavani 760'tir; bu ekranlarda satirlarin cogu etiket–DEGER oldugu icin
/// daha sert olan 600 turetmesi uygulandi.
const double kBlockCap = DesktopBreakpoints.maxLabelValueWidth + 32; // 632

/// `showDesktopPanel` govdesinin genisligi (`DesktopSurface.panelWidth`).
/// Ayarlar'dan push edilen her ekran GERCEKTE bu bantta cizilir.
const double kPanelBand = 920;

/// Olculen pencere genislikleri (SPEC §1.2 merdiveninin dort basamagi).
const List<double> kWidths = [1008, 1200, 1920, 2560];

// ============================================================================
// SONDA — karede NE BOYANDIGINA bakar, kaynakta ne yazdigina degil.
// ============================================================================

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

bool _isIconGlyph(String text) {
  final trimmed = text.trim();
  if (trimmed.runes.length != 1) return false;
  final code = trimmed.runes.first;
  return code >= 0xE000 && code <= 0xF8FF; // MaterialIcons ozel kullanim alani
}

/// Paragrafin ekranda BOYANAN glif kutusu.
///
/// 🔴 `RenderParagraph`in KUTUSU degil. `Expanded(child: Text('Ad'))` icindeki
/// kutu tum satiri kaplar; boyanan glifler solda kalir. Kutuyu olcmek
/// etiket–deger mesafesini SIFIR gosterirdi.
Rect? _ink(RenderParagraph p) {
  if (!p.hasSize) return null;
  final text = p.text.toPlainText();
  if (text.trim().isEmpty || _isIconGlyph(text)) return null;
  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  if (boxes.isEmpty) return null;
  var local = boxes.first.toRect();
  for (final b in boxes.skip(1)) {
    local = local.expandToInclude(b.toRect());
  }
  return MatrixUtils.transformRect(p.getTransformTo(null), local);
}

/// Boyanmayan alt agaclari atlayarak gezer (`Offstage`, sifir opaklik,
/// `Overlay`in ortulen girisleri, canli tutulan ama cizilmeyen liste ogeleri).
void _walk(RenderObject node, void Function(RenderParagraph) visit) {
  if (node is RenderParagraph) visit(node);
  node.visitChildren((child) {
    if (node.runtimeType.toString() == '_RenderTheater') {
      var onstage = false;
      node.visitChildrenForSemantics((c) {
        if (identical(c, child)) onstage = true;
      });
      if (!onstage) return;
    } else if (!node.paintsChild(child)) {
      return;
    }
    _walk(child, visit);
  });
}

bool _isPainted(RenderObject node) {
  var child = node;
  var parent = child.parent;
  while (parent != null) {
    if (!parent.paintsChild(child)) return false;
    child = parent;
    parent = parent.parent;
  }
  return true;
}

class Measured {
  const Measured({
    required this.widestText,
    required this.textLabel,
    required this.widestCard,
    required this.widestRow,
    required this.rowLabel,
    required this.cardLabel,
  });

  /// SPEC §2.3 "duz metin / prose" — TEK bir paragrafin boyanan genisligi.
  ///
  /// 🔴 Once "en soldaki gliften en sagdaki glife" birlesim olculuyordu; o
  /// sayi YANLISTI: `AppBar` basligi solda, ortalanmis govde sagda kaliyor ve
  /// birlesim govde tavanlansa bile pencereyle buyumeye devam ediyordu
  /// (2560'ta 1533 px). Satir uzunlugu kurali TEK paragrafi olcer.
  final double widestText;
  final String textLabel;

  /// Boyanan en genis `Card` yuzeyi (kart yoksa 0).
  final double widestCard;

  /// SPEC KURAL 2.2 — en genis etiket→deger mesafesi (satir yoksa 0).
  final double widestRow;
  final String rowLabel;
  final String cardLabel;

  @override
  String toString() =>
      'metin=${widestText.toStringAsFixed(0)}[${_short(textLabel)}] '
      'kart=${widestCard.toStringAsFixed(0)}[${_short(cardLabel)}] '
      'satir=${widestRow.toStringAsFixed(0)}[${_short(rowLabel)}]';

  static String _short(String s) {
    final t = s.trim().replaceAll('\n', ' ');
    return t.length <= 42 ? t : '${t.substring(0, 42)}…';
  }
}

/// En yakin "satir" atasi (yatay `Flex` ya da `ListTile`). Gruplama bunun
/// uzerinden yapilir; yoksa iki AYRI kartta ayni y'de duran metinler
/// yanlislikla "ayni satir" sayilirdi.
RenderObject? _rowAncestor(RenderObject node) {
  var current = node.parent;
  while (current != null) {
    if (current is RenderFlex && current.direction == Axis.horizontal) {
      return current;
    }
    if (current.runtimeType.toString().contains('ListTile')) return current;
    current = current.parent;
  }
  return null;
}

Measured measure(WidgetTester tester, {int maxValueChars = 24}) {
  final root = tester.binding.rootElement!.renderObject!;

  var widestText = 0.0;
  var textLabel = '-';
  final groups = <RenderObject, List<(String, Rect)>>{};
  _walk(root, (p) {
    final rect = _ink(p);
    if (rect == null) return;
    if (rect.width > widestText) {
      widestText = rect.width;
      textLabel = p.text.toPlainText();
    }
    final row = _rowAncestor(p);
    if (row == null) return;
    groups.putIfAbsent(row, () => <(String, Rect)>[]).add((
      p.text.toPlainText(),
      rect,
    ));
  });

  var widestRow = 0.0;
  var rowLabel = '-';
  for (final items in groups.values) {
    if (items.length < 2) continue;
    items.sort((a, b) => a.$2.left.compareTo(b.$2.left));
    for (var i = 0; i + 1 < items.length; i++) {
      final a = items[i];
      final b = items[i + 1];
      final tol = (a.$2.height < b.$2.height ? a.$2.height : b.$2.height) / 2;
      if ((a.$2.center.dy - b.$2.center.dy).abs() > tol) continue;
      if (b.$1.trim().length > maxValueChars) continue;
      final span = b.$2.right - a.$2.left;
      if (span > widestRow) {
        widestRow = span;
        rowLabel = '${a.$1.trim()} -> ${b.$1.trim()}';
      }
    }
  }

  var widestCard = 0.0;
  var cardLabel = '-';
  for (final element in find.byType(Card, skipOffstage: true).evaluate()) {
    final ro = element.renderObject;
    if (ro is! RenderBox || !ro.hasSize || !_isPainted(ro)) continue;
    final rect = _globalRect(ro);
    if (rect.width <= widestCard) continue;
    widestCard = rect.width;
    var widest = 0.0;
    _walk(ro, (p) {
      final r = _ink(p);
      if (r == null || r.width <= widest) return;
      widest = r.width;
      cardLabel = p.text.toPlainText().trim();
    });
  }

  return Measured(
    widestText: widestText,
    textLabel: textLabel,
    widestCard: widestCard,
    widestRow: widestRow,
    rowLabel: rowLabel,
    cardLabel: cardLabel,
  );
}

// ============================================================================
// HARNESS
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Profile me() =>
      Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026, 1, 1));

  List<Override> baseOverrides(SharedPreferences prefs) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authStateProvider.overrideWith((ref) => Stream.value(me())),
    myAnnouncementsProvider.overrideWith(
      (ref) async => [
        Announcement(
          id: 'a1',
          title: 'Yeni surum yayinda',
          message:
              'Bu surumde masaustu duzeni yeniden yazildi; sayac, istatistik '
              've grup ekranlari artik pencere genisligine gore sutunlanir. '
              'Ayrintilar surum notlarinda.',
          targetType: 'all',
          createdAt: DateTime(2026, 8, 9),
        ),
        Announcement(
          id: 'a2',
          title: 'Bakim penceresi',
          message: 'Cumartesi 02:00-03:00 arasi kisa kesinti olabilir.',
          targetType: 'all',
          createdAt: DateTime(2026, 8, 1),
        ),
      ],
    ),
    readAnnouncementIdsProvider.overrideWith((ref) async => <String>{}),
    blockedProfilesProvider.overrideWith(
      (ref) async => [
        Profile(
          id: 'b1',
          displayName: 'Engellenen Bora',
          createdAt: DateTime(2026, 1, 1),
        ),
        Profile(
          id: 'b2',
          displayName: 'Engellenen Cem',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    ),
    mySanctionsProvider.overrideWith(
      (ref) async => [
        ModerationSanction(
          id: 's1',
          targetUserId: 'u1',
          action: ModerationAction.mute24h,
          reason: 'Grup sohbetinde tekrarlanan reklam paylasimi.',
          state: ModerationSanctionState.applied,
          expiresAt: DateTime(2026, 8, 2),
        ),
      ],
    ),
    myAppealsProvider.overrideWith((ref) async => const <ModerationAppeal>[]),
    nudgeMutesProvider.overrideWith(
      (ref) async => [
        NudgeMute(
          mutedUserId: 'm1',
          mutedAt: DateTime(2026, 8, 1),
          displayName: 'Susturulan Deniz',
        ),
        NudgeMute(
          mutedUserId: 'm2',
          mutedAt: DateTime(2026, 8, 2),
          displayName: 'Susturulan Ece',
        ),
      ],
    ),
    faqEntriesProvider.overrideWith(
      (ref) async => const [
        FaqEntry(
          id: 'one',
          locale: 'tr',
          question: 'Masaustu penceresini kucultursem duzen ne olur?',
          answer:
              'Pencere daraldikca sutun sayisi duser; icerik hicbir zaman '
              'kaybolmaz, yalniz yeri degisir. Bu davranis WinUI ve Material '
              '3 kirilim merdiveninden gelir ve her bantta ayri olculur.',
          sortOrder: 1,
        ),
        FaqEntry(
          id: 'two',
          locale: 'tr',
          question: 'Bildirimler nerede?',
          answer: 'Ayarlar altindaki Bildirim Merkezi ekranindan yonetilir.',
          sortOrder: 2,
        ),
      ],
    ),
  ];

  ReleaseNotesService fakeNotes() => ReleaseNotesService(
    assetLoader: (_) async => '''
{"releases":[
 {"versionName":"1.0.64","buildNumber":64,"channel":"stable","date":"2026-08-09",
  "title":"Masaustu duzeni","highlights":["Sayac ekrani yeniden duzenlendi",
  "Istatistik kartlari icerik genisligine gore tavanlandi"],
  "fixes":["Bildirim merkezi satirlari artik okunabilir genislikte"],
  "notes":["Mobil gorunum degismedi"]},
 {"versionName":"1.0.63","buildNumber":63,"channel":"stable","date":"2026-08-01",
  "title":"Kararlilik","highlights":["Grup istatistikleri hizlandi"],
  "fixes":["Sayac senkronu"],"notes":[]}
]}''',
  );

  /// Tam pencere rotasi (SSS'in `auth_screen` yolu ve mobil yol).
  Future<void> pump(
    WidgetTester tester, {
    required Widget screen,
    required Size window,
    double? band,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: baseOverrides(prefs),
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // `band` verilirse `showDesktopPanel`in 920 px'lik govdesi taklit
          // edilir: Ayarlar'dan push edilen ekranlarin GERCEK kabugu budur.
          home: band == null
              ? screen
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: band,
                    height: window.height,
                    child: screen,
                  ),
                ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final screens = <String, Widget Function()>{
    'bildirim-merkezi': () => const NotificationCenterScreen(),
    'bildirim-izinleri': () => const NotificationPermissionsScreen(),
    'duyurular': () => const AnnouncementsScreen(),
    'sss': () => const FaqScreen(),
    'engellenenler': () => const BlockedUsersScreen(),
    'susturulanlar': () => const MutedNudgesScreen(),
    'surum-notlari': () =>
        ReleaseNotesScreen(service: fakeNotes(), channel: 'stable'),
  };

  // ===========================================================================
  // 0) TANILAMA — yedi ekran x dort genislik + panel bandi
  // ===========================================================================

  testWidgets('WP-683 (0) tanilama: yedi ekran, dort genislik + panel', (
    tester,
  ) async {
    final lines = <String>[];
    for (final entry in screens.entries) {
      for (final width in kWidths) {
        await onPlatform(TargetPlatform.windows, () async {
          await pump(tester, screen: entry.value(), window: Size(width, 2000));
          lines.add(
            '${entry.key.padRight(18)} @${width.toStringAsFixed(0).padLeft(4)}'
            ' ${measure(tester)}',
          );
        });
      }
      await onPlatform(TargetPlatform.windows, () async {
        await pump(
          tester,
          screen: entry.value(),
          window: const Size(1920, 2000),
          band: kPanelBand,
        );
        lines.add('${entry.key.padRight(18)} @panel ${measure(tester)}');
      });
    }
    // ignore: avoid_print
    print('--- WP-683 EKRAN OLCUMU ---\n${lines.join('\n')}');
    expect(lines, hasLength(screens.length * (kWidths.length + 1)));
  });

  // ===========================================================================
  // 1) TAVAN — yedi ekran x dort genislik
  // ===========================================================================

  for (final name in screens.keys) {
    for (final width in kWidths) {
      testWidgets(
        'WP-683 (1) $name @${width.toStringAsFixed(0)}: kart <= '
        '${kBlockCap.toStringAsFixed(0)}, prose <= ${kProseCap.toStringAsFixed(0)}, '
        'etiket-deger <= ${kLabelValueCap.toStringAsFixed(0)}',
        (tester) async => onPlatform(TargetPlatform.windows, () async {
          await pump(
            tester,
            screen: screens[name]!(),
            window: Size(width, 2000),
          );
          final m = measure(tester);

          expect(
            m.widestCard,
            greaterThan(0),
            reason: '$name ekraninda hic kart cizilmedi; olcum bos.',
          );
          expect(
            m.widestCard,
            lessThanOrEqualTo(kBlockCap),
            reason:
                '$name @$width: en genis kart '
                '${m.widestCard.toStringAsFixed(0)} px '
                '(icindeki en genis metin "${m.cardLabel}"). SPEC KURAL 2.2 '
                '600 px satir tavani + 2x16 kart dolgusu = '
                '${kBlockCap.toStringAsFixed(0)} px. WP-683 oncesi bu sayi '
                '1008\'de ~976, 2560\'ta ~2528 px idi.',
          );
          expect(
            m.widestText,
            lessThanOrEqualTo(kProseCap),
            reason:
                '$name @$width: en genis paragraf '
                '${m.widestText.toStringAsFixed(0)} px ("${m.textLabel}"). '
                'SPEC §2.3 duz metin tavani ${kProseCap.toStringAsFixed(0)} px '
                '(80 karakter, WCAG 2.1 SC 1.4.8).',
          );
          expect(
            m.widestRow,
            lessThanOrEqualTo(kLabelValueCap),
            reason:
                '$name @$width: en genis etiket-deger satiri '
                '${m.widestRow.toStringAsFixed(0)} px (${m.rowLabel}). '
                'SPEC KURAL 2.2 sert tavani '
                '${kLabelValueCap.toStringAsFixed(0)} px.',
          );
        }),
      );
    }

    // =========================================================================
    // 2) PANEL BANDI — GERCEK kabuk (`showDesktopPanel`, 920 px)
    // =========================================================================

    testWidgets(
      'WP-683 (2) $name @panel(920): ayni tavanlar panel icinde de gecerli',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await pump(
          tester,
          screen: screens[name]!(),
          window: const Size(1920, 2000),
          band: kPanelBand,
        );
        final m = measure(tester);
        expect(
          m.widestCard,
          lessThanOrEqualTo(kBlockCap),
          reason:
              '$name panelde ${m.widestCard.toStringAsFixed(0)} px. '
              'Panel pencereyle BUYUMEZ ama WP-683 oncesi burada da tavan '
              'yoktu: kart 888-896, etiket-deger 776 px idi.',
        );
        expect(m.widestText, lessThanOrEqualTo(kProseCap));
        expect(m.widestRow, lessThanOrEqualTo(kLabelValueCap));
      }),
    );

    // =========================================================================
    // 3) BUYUMEZLIK — 1008 ile 2560 AYNI genisligi cizer
    // =========================================================================

    testWidgets(
      'WP-683 (3) $name: 2560 px pencere 1008 ile AYNI kart genisligini cizer',
      (tester) async {
        var narrow = 0.0;
        var wide = 0.0;
        await onPlatform(TargetPlatform.windows, () async {
          await pump(
            tester,
            screen: screens[name]!(),
            window: const Size(1008, 2000),
          );
          narrow = measure(tester).widestCard;
        });
        await onPlatform(TargetPlatform.windows, () async {
          await pump(
            tester,
            screen: screens[name]!(),
            window: const Size(2560, 2000),
          );
          wide = measure(tester).widestCard;
        });
        expect(
          wide,
          closeTo(narrow, 1),
          reason:
              '$name: 1008 px pencerede ${narrow.toStringAsFixed(0)} px, '
              '2560 px pencerede ${wide.toStringAsFixed(0)} px. Tavan varsa '
              'iki sayi ESIT olmali. WP-683 oncesi fark 1552 px idi '
              '(976 -> 2528): "arayuz buyutuldu, yeniden duzenlenmedi".',
        );
      },
    );
  }

  // ===========================================================================
  // 4) ISLEV KAYBI YOK — SPEC §7
  // ===========================================================================

  testWidgets(
    'WP-683 (4a) bildirim merkezi: her ayar satiri duruyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        screen: const NotificationCenterScreen(),
        window: const Size(1920, 2400),
      );
      for (final label in [
        tr.notificationsCihazIzinleri,
        tr.notificationsBildirimTurleri,
        tr.notificationsDurtmeBildirimleri,
        tr.smartStreakReminder,
        tr.smartWeeklySummary,
        tr.notificationsDuyurular,
        tr.notificationsGuncellemeBildirimleri,
        tr.notificationsSessizSaatler,
        tr.notificationsSessizSaatleriEtkinlestir,
        // 🔴 "Bildirim sagligi" tani karti bu listede YOK ve bu WP-683'un
        // sonucu DEGIL. `AppPushNotificationService.isSupported`
        // (`app_push_notification_service.dart:374`) `defaultTargetPlatform ==
        // android` demektir; Windows'ta `_PushHealthCard` `SizedBox.shrink()`
        // doner. Kart masaustunde ZATEN hic cizilmiyordu. Ayrik bir bulgu
        // olarak lidere bildirildi; asagida mobilde durdugu sinaniyor ki bu
        // WP tavani onu gizlemis olmasin.
      ]) {
        expect(
          find.text(label),
          findsWidgets,
          reason: '"$label" masaustunde cizilmedi — SPEC §7 islev kaybi.',
        );
      }
      expect(
        find.byType(SwitchListTile),
        findsNWidgets(6),
        reason: 'Alti tercih anahtarindan biri kayboldu.',
      );
      // Anahtar GERCEKTEN calisiyor: duyuru tercihi kapatilabiliyor.
      final announcements = find.ancestor(
        of: find.text(tr.notificationsDuyurular),
        matching: find.byType(SwitchListTile),
      );
      expect(tester.widget<SwitchListTile>(announcements).value, isTrue);
      await tester.tap(
        find.descendant(of: announcements, matching: find.byType(Switch)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<SwitchListTile>(announcements).value,
        isFalse,
        reason: 'Tavan eklendikten sonra anahtar dokunusa cevap vermiyor.',
      );
    }),
  );

  testWidgets(
    'WP-683 (4a2) bildirim merkezi MOBILDE: tani karti hala ciziliyor',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      // Tavan mobil dala sizip tani kartini gizlemis olmasin (SPEC §7).
      await pump(
        tester,
        screen: const NotificationCenterScreen(),
        window: const Size(390, 4000),
      );
      for (final label in [
        tr.notificationsHealthTitle,
        tr.notificationsLocalTest,
        tr.notificationsRemoteTest,
        tr.notificationsBildirimIzniniKontrolEt,
      ]) {
        expect(
          find.text(label),
          findsWidgets,
          reason: '"$label" mobilde kayboldu — SPEC §7 mobil regresyon.',
        );
      }
    }),
  );

  testWidgets(
    'WP-683 (4b) duyurular: baslik + mesaj + okuma dokunusu duruyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        screen: const AnnouncementsScreen(),
        window: const Size(2560, 2000),
      );
      expect(find.text('Yeni surum yayinda'), findsOneWidget);
      expect(find.text('Bakim penceresi'), findsOneWidget);
      expect(
        find.textContaining('masaustu duzeni yeniden yazildi'),
        findsOneWidget,
      );
      // Okundu isaretleme dokunusu hala bagli (okunmamis duyuruda `onTap`).
      final tiles = find
          .byType(ListTile)
          .evaluate()
          .map((e) => e.widget as ListTile)
          .where((t) => t.onTap != null)
          .length;
      expect(
        tiles,
        2,
        reason: 'Okunmamis duyurularin okundu-isaretleme dokunusu kayboldu.',
      );
    }),
  );

  testWidgets(
    'WP-683 (4c) SSS: arama filtreliyor, soru sorma dugmesi duruyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        screen: const FaqScreen(),
        window: const Size(2560, 2000),
      );
      expect(find.textContaining('Masaustu penceresini'), findsOneWidget);
      expect(find.text('Bildirimler nerede?'), findsOneWidget);
      expect(find.text(tr.faqAskQuestion), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'Bildirimler');
      await tester.pump();
      expect(
        find.textContaining('Masaustu penceresini'),
        findsNothing,
        reason: 'Arama artik filtrelemiyor — tavan islevi bozdu.',
      );
      expect(find.text('Bildirimler nerede?'), findsOneWidget);

      // Cevap acilabiliyor ve METNI degismedi (SSS icerigine dokunulmadi).
      await tester.tap(find.text('Bildirimler nerede?'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ayarlar altindaki Bildirim Merkezi ekranindan yonetilir.'),
        findsOneWidget,
      );
    }),
  );

  testWidgets('WP-683 (4d) engellenenler + susturulanlar: eylemler duruyor', (
    tester,
  ) async {
    await onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        screen: const BlockedUsersScreen(),
        window: const Size(2560, 2000),
      );
      expect(find.text('Engellenen Bora'), findsOneWidget);
      expect(find.text('Engellenen Cem'), findsOneWidget);
      expect(find.text(tr.safetyUnblock), findsNWidgets(2));
      // WP-442 kisit bolumu ve itiraz yolu da duruyor.
      expect(find.byKey(const Key('my-restrictions-section')), findsOneWidget);
      expect(find.byKey(const Key('appeal-action-s1')), findsOneWidget);
      expect(
        find.textContaining('reklam paylasimi'),
        findsOneWidget,
        reason: 'Yaptirim gerekcesi kayboldu — kullanici itiraz edemez.',
      );
    });
    await onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        screen: const MutedNudgesScreen(),
        window: const Size(2560, 2000),
      );
      expect(find.text('Susturulan Deniz'), findsOneWidget);
      expect(find.text('Susturulan Ece'), findsOneWidget);
      expect(find.text(tr.safetyUnmuteNudges), findsNWidgets(2));
      expect(find.text(tr.safetyMutedNudgesExplainer), findsOneWidget);
    });
  });

  testWidgets(
    'WP-683 (4e) surum notlari: her bolum + "daha fazla" duruyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        screen: ReleaseNotesScreen(service: fakeNotes(), channel: 'stable'),
        window: const Size(2560, 2000),
      );
      expect(find.text('Masaustu duzeni'), findsOneWidget);
      expect(find.text('Kararlilik'), findsOneWidget);
      expect(find.textContaining('1.0.64+64'), findsOneWidget);
      expect(find.text(tr.updaterYenilikler), findsWidgets);
      expect(find.text(tr.updaterDuzeltmeler), findsWidgets);
      expect(find.text(tr.updaterNotlar), findsWidgets);
      expect(
        find.textContaining('Sayac ekrani yeniden duzenlendi'),
        findsOneWidget,
      );
      expect(find.text(tr.updaterStable), findsNWidgets(2));
    }),
  );

  testWidgets(
    'WP-683 (4f) bildirim izinleri: iki sekme de aciliyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        screen: const NotificationPermissionsScreen(),
        window: const Size(2560, 2400),
      );
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(const Key('monthly-report-opt-in')), findsOneWidget);
      expect(
        find.byKey(const Key('monthly-report-coming-soon')),
        findsOneWidget,
      );
      // Sekme serit tavani: iki ikon 600 px'lik banda sigar.
      final strip = tester.getSize(find.byType(TabBar));
      expect(
        strip.width,
        lessThanOrEqualTo(kBlockCap),
        reason:
            'Sekme seridi ${strip.width.toStringAsFixed(0)} px; tavansiz halde '
            '2560 px pencerede iki ikon ~1200 px arayla duruyordu.',
      );
      // Ikinci sekme (widget ayarlari) hala aciliyor.
      await tester.tap(find.byIcon(Icons.security_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(TabBarView), findsOneWidget);
    }),
  );

  // ===========================================================================
  // 5) MOBIL REGRESYON — 390x844'te tavan UYGULANMAZ
  // ===========================================================================

  for (final name in screens.keys) {
    testWidgets(
      'WP-683 (5) $name mobilde 390x844: masaustu tavani ACILMAZ',
      (tester) async => onPlatform(TargetPlatform.android, () async {
        await pump(
          tester,
          screen: screens[name]!(),
          window: const Size(390, 3000),
        );
        final m = measure(tester);
        expect(
          m.widestCard,
          greaterThan(kBlockCap / 2),
          reason:
              '$name mobilde en genis kart ${m.widestCard.toStringAsFixed(0)} '
              'px. Mobil dal ekran genisligini kullanmali; 632 px tavani '
              'mobile SIZDI (SPEC §7: mobil dal degismez).',
        );
        expect(
          m.widestCard,
          lessThanOrEqualTo(390),
          reason: 'Mobil kart ekrandan tasti.',
        );
      }),
    );
  }
}
