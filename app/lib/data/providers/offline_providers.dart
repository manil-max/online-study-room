import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';
import '../repositories/offline/offline_cache_store.dart';

/// Offline-first repository'lerin kullandığı ortak cache deposu.
final offlineCacheStoreProvider = Provider<OfflineCacheStore>((ref) {
  return OfflineCacheStore(ref.watch(sharedPreferencesProvider));
});
