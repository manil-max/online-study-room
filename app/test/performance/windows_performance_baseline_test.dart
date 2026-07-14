import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WP-70 ölçüm betiği anonim, tekrarlanabilir şemayı korur', () {
    final script = File(
      '../scripts/windows_performance_baseline.ps1',
    ).readAsStringSync();

    expect(script, contains('[ValidateRange(1, 20)]'));
    expect(script, contains('[ValidateRange(10, 300)]'));
    expect(script, contains(r'$MyInvocation.MyCommand.Path'));
    expect(script, contains("throw \"Ölçümden önce açık"));
    expect(
      script,
      contains("output_directory = 'local build/windows-performance-baseline'"),
    );
    expect(script, contains('window_visible_milliseconds'));
    expect(script, contains('working_set_megabytes'));
    expect(script, contains('private_megabytes'));
    expect(script, contains('idle_cpu_seconds'));
    expect(script, contains('executable_sha256'));
    expect(script, isNot(contains('UserName')));
    expect(script, isNot(contains('Get-ChildItem Env:')));
  });
}
