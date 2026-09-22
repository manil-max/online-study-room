// WP-900: iOS proje iskeleti sozlesmesi.
//
// Mac yok; iOS derlemesi yalniz GitHub Actions macOS runner'inda kosar. Bu
// test, Xcode olmadan (Windows'ta) native dosyalarin App Store icin gereken
// sozlesmeyi korudugunu olcer: bundle id, iOS 15 tabani, izin metinleri,
// push arka plan modu, entitlements, gizlilik manifesti, alfasiz 1024 ikon.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  const pbxPath = 'ios/Runner.xcodeproj/project.pbxproj';
  const infoPath = 'ios/Runner/Info.plist';
  const entPath = 'ios/Runner/Runner.entitlements';
  const privacyPath = 'ios/Runner/PrivacyInfo.xcprivacy';
  const iconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

  group('WP-900 iOS proje sozlesmesi', () {
    test('bundle id com.manilmax.focuscamp, alt cizgili id yok', () {
      final pbx = _read(pbxPath);
      final ids = RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
      ).allMatches(pbx).map((m) => m.group(1)!.replaceAll('"', '')).toList();
      expect(
        ids.where((id) => id == 'com.manilmax.focuscamp').length,
        3,
        reason: 'Runner Debug/Release/Profile',
      );
      expect(
        ids.where((id) => id == 'com.manilmax.focuscamp.RunnerTests').length,
        3,
      );
      for (final id in ids) {
        expect(
          id.contains('_'),
          isFalse,
          reason: 'iOS bundle id alt cizgi kabul etmez: $id',
        );
      }
    });

    test('iOS 15.0 tabani pbxproj ve Podfile icinde', () {
      final pbx = _read(pbxPath);
      final targets = RegExp(
        r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);',
      ).allMatches(pbx).map((m) => m.group(1)).toList();
      expect(targets, isNotEmpty);
      expect(targets.every((t) => t == '15.0'), isTrue, reason: '$targets');
      final podfile = _read('ios/Podfile');
      expect(podfile, contains("platform :ios, '15.0'"));
      expect(podfile, contains("['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'"));
    });

    test('yalniz iPhone (TARGETED_DEVICE_FAMILY = 1)', () {
      final pbx = _read(pbxPath);
      final fam = RegExp(
        r'TARGETED_DEVICE_FAMILY = ([^;]+);',
      ).allMatches(pbx).map((m) => m.group(1)).toSet();
      expect(fam, {'1'});
    });

    test('Info.plist: push, sifreleme beyani, foto izni, tr+en', () {
      final info = _read(infoPath);
      expect(
        RegExp(
          r'<key>UIBackgroundModes</key>\s*<array>\s*'
          r'<string>remote-notification</string>\s*</array>',
        ).hasMatch(info),
        isTrue,
        reason: 'yalniz remote-notification',
      );
      expect(
        RegExp(
          r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>',
        ).hasMatch(info),
        isTrue,
      );
      expect(info, contains('<key>NSPhotoLibraryUsageDescription</key>'));
      expect(
        RegExp(
          r'<key>CFBundleLocalizations</key>\s*<array>'
          r'(?=[\s\S]*?<string>en</string>)'
          r'(?=[\s\S]*?<string>tr</string>)',
        ).hasMatch(info),
        isTrue,
      );
      expect(
        RegExp(
          r'<key>CFBundleDevelopmentRegion</key>\s*<string>en</string>',
        ).hasMatch(info),
        isTrue,
      );
      // Kullanilmayan ozellik icin izin metni yok (inceleme reddi sebebi).
      expect(info, isNot(contains('NSCameraUsageDescription')));
      expect(info, isNot(contains('NSLocationWhenInUseUsageDescription')));
      expect(info, isNot(contains('NSUserTrackingUsageDescription')));
    });

    test(
      'InfoPlist.strings tr/en ad + foto metni tasir ve projede kayitli',
      () {
        final en = _read('ios/Runner/en.lproj/InfoPlist.strings');
        final tr = _read('ios/Runner/tr.lproj/InfoPlist.strings');
        expect(en, contains('"CFBundleDisplayName" = "Focus Camp";'));
        expect(tr, contains('"CFBundleDisplayName" = "Odak Kampı";'));
        expect(en, contains('"NSPhotoLibraryUsageDescription"'));
        expect(tr, contains('"NSPhotoLibraryUsageDescription"'));
        final pbx = _read(pbxPath);
        expect(pbx, contains('path = en.lproj/InfoPlist.strings;'));
        expect(pbx, contains('path = tr.lproj/InfoPlist.strings;'));
        expect(pbx, contains('/* InfoPlist.strings in Resources */,'));
      },
    );

    test('entitlements: push + Sign in with Apple, CODE_SIGN_ENTITLEMENTS', () {
      final ent = _read(entPath);
      expect(
        RegExp(
          r'<key>aps-environment</key>\s*<string>production</string>',
        ).hasMatch(ent),
        isTrue,
      );
      expect(
        RegExp(
          r'<key>com.apple.developer.applesignin</key>\s*<array>\s*'
          r'<string>Default</string>',
        ).hasMatch(ent),
        isTrue,
      );
      final pbx = _read(pbxPath);
      expect(
        'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
            .allMatches(pbx)
            .length,
        3,
      );
      expect(pbx, contains('path = Runner.entitlements;'));
    });

    test('PrivacyInfo.xcprivacy var, izleme yok, Resources fazinda', () {
      final privacy = _read(privacyPath);
      expect(
        RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(privacy),
        isTrue,
      );
      expect(privacy, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
      expect(privacy, contains('CA92.1'));
      final pbx = _read(pbxPath);
      final resources = RegExp(
        r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{[\s\S]*?\};',
      ).firstMatch(pbx)!.group(0)!;
      expect(resources, contains('PrivacyInfo.xcprivacy in Resources'));
    });

    test('AppIcon: 1024 marketing ikonu var ve alfa kanali yok', () {
      final contents =
          jsonDecode(_read('$iconDir/Contents.json')) as Map<String, dynamic>;
      final images = (contents['images'] as List).cast<Map<String, dynamic>>();
      final marketing = images.firstWhere(
        (i) => i['idiom'] == 'ios-marketing' && i['size'] == '1024x1024',
      );
      for (final img in images) {
        final bytes = File('$iconDir/${img['filename']}').readAsBytesSync();
        // PNG imzasi + IHDR: genislik 16..19, renk tipi bayt 25.
        expect(bytes.sublist(1, 4), ascii.encode('PNG'));
        final colorType = bytes[25];
        expect(
          colorType,
          2,
          reason: '${img['filename']} RGB olmali (6 = RGBA reddedilir)',
        );
      }
      final big = File('$iconDir/${marketing['filename']}').readAsBytesSync();
      final width =
          (big[16] << 24) | (big[17] << 16) | (big[18] << 8) | big[19];
      expect(width, 1024);
    });
  });

  group('WP-907 AppDelegate', () {
    const appDelegatePath = 'ios/Runner/AppDelegate.swift';

    test('flutter_local_notifications registrant callback kayitli', () {
      final src = _read(appDelegatePath);
      expect(src, contains('import flutter_local_notifications'));
      expect(
        src,
        contains('FlutterLocalNotificationsPlugin.setPluginRegistrantCallback'),
      );
      // UIScene sablonu: kayit didInitializeImplicitFlutterEngine icinde.
      final implicit = src.indexOf('func didInitializeImplicitFlutterEngine');
      expect(implicit, greaterThan(0));
      expect(
        src.indexOf(
          'FlutterLocalNotificationsPlugin.setPluginRegistrantCallback {',
        ),
        greaterThan(implicit),
      );
    });

    test('saat dilimi kanali Dart tarafiyla ayni ad ve metot', () {
      final src = _read(appDelegatePath);
      final dart = _read('lib/core/time_engine/device_timezone.dart');
      const channel = 'com.manilmax.online_study_room/exact_alarm';
      expect(dart, contains(channel));
      expect(dart, contains("'getLocalTimezoneId'"));
      expect(src, contains('"$channel"'));
      expect(src, contains('"getLocalTimezoneId"'));
      expect(src, contains('TimeZone.current.identifier'));
      expect(src, contains('FlutterMethodNotImplemented'));
    });
  });
}
