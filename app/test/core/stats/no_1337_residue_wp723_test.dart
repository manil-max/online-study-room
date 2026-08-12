import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kaldırılan başarım aktif ürün yüzeylerinde kalıntı bırakmaz', () {
    final forbiddenTokens = <String>[
      String.fromCharCodes([49, 51, 51, 55]),
      String.fromCharCodes([101, 108, 105, 116, 101]),
      String.fromCharCodes([108, 101, 101, 116]),
    ];
    final activeFiles = <File>[
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.arb') || file.path.endsWith('.dart'),
          ),
      ...Directory('test/fixtures')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.json')),
      File('../docs/BASARIM-MIMARISI.md'),
    ];

    for (final file in activeFiles) {
      final content = file.readAsStringSync().toLowerCase();
      for (final token in forbiddenTokens) {
        expect(
          content,
          isNot(contains(token)),
          reason: '${file.path} kaldırılan başarım kalıntısı içeriyor',
        );
      }
    }
  });
}
