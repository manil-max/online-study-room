/// WP-939 — "Seans sonu özeti göster" anahtarı.
///
/// Sayaç uygulama içinden durdurulup oturum kaydedilince açılan kısa özetin
/// kullanıcı tercihi. Varsayılan AÇIK: özet, durdurmanın sessiz geçmemesi için
/// eklendi; istemeyen Bildirim Merkezi > Bildirim türleri'nden kapatır.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';

/// Tercihin `shared_preferences` anahtarı.
const kSessionSummaryEnabledKey = 'session_summary_enabled';

class SessionSummaryPreferenceNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(kSessionSummaryEnabledKey) ??
      true;

  Future<void> setEnabled(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(kSessionSummaryEnabledKey, value);
    state = value;
  }
}

/// Seans sonu özeti açık mı; varsayılan açık.
final sessionSummaryEnabledProvider =
    NotifierProvider<SessionSummaryPreferenceNotifier, bool>(
      SessionSummaryPreferenceNotifier.new,
    );
