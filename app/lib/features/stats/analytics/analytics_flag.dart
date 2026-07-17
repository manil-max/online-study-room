import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/app_prefs.dart';

/// WP-158: analitik ızgara feature flag. Default **kapalı** → eski ListView.
const kAnalyticsGridV1Key = 'analytics_grid_v1';

class AnalyticsGridFlagNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(kAnalyticsGridV1Key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(kAnalyticsGridV1Key, value);
  }
}

final analyticsGridV1Provider =
    NotifierProvider<AnalyticsGridFlagNotifier, bool>(
      AnalyticsGridFlagNotifier.new,
    );
