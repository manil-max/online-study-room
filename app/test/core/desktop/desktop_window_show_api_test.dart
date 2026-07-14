import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_window.dart';

void main() {
  test('showDesktopWindowWhenReady API no-op on non-desktop test host', () async {
    // CI/Linux test host: stub veya gerçek IO — çökmemeli.
    await expectLater(showDesktopWindowWhenReady(), completes);
  });

  test('initDesktopWindow API completes', () async {
    await expectLater(initDesktopWindow(), completes);
  });
}
