import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// WP-61: Kamp ateşi PNG seti paket içinde ve sözleşmeye uygun mu?
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const base = 'assets/campfire';
  const layers = <String>[
    'ground.png',
    'glow.png',
    'stones.png',
    'wood.png',
    'coals.png',
    'flame_back.png',
    'flame_mid.png',
    'flame_front.png',
    'smoke.png',
    'ember_sheet.png',
  ];

  bool isPng(ByteData data) {
    if (data.lengthInBytes < 8) return false;
    final b = data.buffer.asUint8List(data.offsetInBytes, 8);
    return b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A;
  }

  test('inventory.json lists layers and license', () async {
    final raw = await rootBundle.loadString('$base/inventory.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['package'], 'campfire_r2');
    expect(map['license'], contains('First-party'));
    expect(map['base_path'], 'assets/campfire/');
    final files = (map['density'] as Map)['1.0x'] as Map;
    final listed = files['files'] as Map;
    for (final name in layers) {
      expect(listed.containsKey(name), isTrue, reason: name);
    }
  });

  test('all 1.0x layer PNGs load with PNG signature', () async {
    for (final name in layers) {
      final data = await rootBundle.load('$base/$name');
      expect(data.lengthInBytes, greaterThan(100), reason: name);
      expect(isPng(data), isTrue, reason: '$name not PNG');
    }
  });

  test('2.0x variants load with PNG signature', () async {
    for (final name in layers) {
      final data = await rootBundle.load('$base/2.0x/$name');
      expect(data.lengthInBytes, greaterThan(100), reason: '2.0x/$name');
      expect(isPng(data), isTrue, reason: '2.0x/$name not PNG');
    }
  });
}
