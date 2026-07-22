import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final contracts = <String, String>{
    'lib/features/classroom/classroom_screen.dart': 'AppTab.groups.index',
    'lib/features/profile/profile_screen.dart': 'AppTab.profile.index',
    'lib/features/stats/widgets/personal_stats_view.dart': 'AppTab.stats.index',
    'lib/features/stats/widgets/class_stats_view.dart': 'AppTab.stats.index',
  };

  test(
    'dört gerçek scroll yüzeyi kanonik tab ile 250 ms tap-to-top uygular',
    () {
      for (final entry in contracts.entries) {
        final source = File(entry.key).readAsStringSync();
        expect(source, contains('ScrollController()'), reason: entry.key);
        expect(
          source,
          contains('ref.listen(navReselectProvider'),
          reason: entry.key,
        );
        expect(source, contains(entry.value), reason: entry.key);
        expect(
          source,
          contains('_scrollController.hasClients'),
          reason: entry.key,
        );
        expect(
          source,
          contains('_scrollController.offset <= 0'),
          reason: entry.key,
        );
        expect(
          source,
          contains('controller: _scrollController'),
          reason: entry.key,
        );
        expect(
          source,
          contains('Duration(milliseconds: 250)'),
          reason: entry.key,
        );
        expect(
          source,
          isNot(contains('next.tabIndex == 0')),
          reason: entry.key,
        );
      }
    },
  );
}
