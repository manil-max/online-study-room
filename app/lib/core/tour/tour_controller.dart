import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/providers/auth_providers.dart';
import '../prefs/app_prefs.dart';
import 'tour_gate.dart';
import 'tour_models.dart';
import 'tour_prefs.dart';

/// WP-323: tanıtım turu motorunun durumu.
///
/// Aynı anda **tek tur** çalışır; ikinci bir ekran başlatmak isterse
/// [TourBlockReason.otherTourRunning] ile geri çevrilir (üst üste binen iki
/// balon katmanı, kullanıcıyı ekrana hapseder).
class TourController extends Notifier<TourState> {
  @override
  TourState build() => const TourState.idle();

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  String? get _userId => ref.read(authStateProvider).asData?.value?.id;

  bool seen(TourDefinition definition) {
    final userId = _userId;
    if (userId == null) return false;
    return tourSeen(_prefs, storageId: definition.storageId, userId: userId);
  }

  /// Turun neden başlayamadığı (başlayabiliyorsa `null`).
  TourBlockReason? blockReason(
    TourDefinition definition, {
    required bool routeIsCurrent,
    required bool appResumed,
  }) {
    final userId = _userId;
    return tourBlockReason(
      seen: userId != null && seen(definition),
      hasUser: userId != null,
      otherTourRunning:
          state.isRunning &&
          state.definition!.storageId != definition.storageId,
      routeIsCurrent: routeIsCurrent,
      appResumed: appResumed,
    );
  }

  /// Başlatılabiliyorsa başlatır ve `true` döner.
  ///
  /// Başlatılamayan tur **görüldü işaretlenmez** — yalnız ertelenir.
  bool maybeStart(
    TourDefinition definition, {
    required bool routeIsCurrent,
    required bool appResumed,
  }) {
    if (state.definition?.storageId == definition.storageId) return false;
    final reason = blockReason(
      definition,
      routeIsCurrent: routeIsCurrent,
      appResumed: appResumed,
    );
    if (reason != null) return false;
    state = TourState(definition: definition, index: 0);
    return true;
  }

  /// Sonraki balon; sondaysa turu bitirir.
  Future<void> next() async {
    final def = state.definition;
    if (def == null) return;
    if (state.index + 1 >= def.steps.length) {
      await _finish(def);
      return;
    }
    state = TourState(definition: def, index: state.index + 1);
  }

  /// "Atla" — turu bitirir ve **bir daha açılmaz** (bitirmekle aynı sonuç:
  /// kullanıcı "görmek istemiyorum" demiştir).
  Future<void> skip() async {
    final def = state.definition;
    if (def == null) return;
    await _finish(def);
  }

  Future<void> _finish(TourDefinition definition) async {
    final userId = _userId;
    if (userId != null) {
      await markTourSeen(
        _prefs,
        storageId: definition.storageId,
        userId: userId,
      );
    }
    state = const TourState.idle();
  }

  /// Ayarlardaki "Tanıtım turlarını sıfırla". Silinen anahtar sayısını döner.
  Future<int> resetAll() async {
    final userId = _userId;
    if (userId == null) return 0;
    final removed = await resetToursForUser(_prefs, userId: userId);
    state = const TourState.idle();
    return removed;
  }
}

final tourControllerProvider = NotifierProvider<TourController, TourState>(
  TourController.new,
);
