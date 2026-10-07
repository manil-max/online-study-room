import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/distribution_channel.dart';
import '../../core/prefs/app_prefs.dart';
import '../../data/models/study_session.dart';
import '../../data/providers/study_providers.dart';
import 'play_in_app_update.dart';

/// WP-941: Play sürümünde uygun anda Google'ın kendi "puan ver" sayfası.
///
/// Google'ın resmî in-app review akışı (`in_app_review` → Play Core review).
/// Sayfanın gerçekten çıkıp çıkmayacağına **Google** karar verir (kota,
/// daha önce puanladı mı…); biz yalnız uygun anda [PlayReviewGateway.requestReview]
/// çağırırız. Kendi "uygulamayı sevdin mi?" ön sorumuz **yok** — Play
/// politikası puan isteğini önceden filtrelemeyi (gating) önermiyor.
///
/// **Yalnız Play + Android.** Kapı [PlayInAppUpdate.appliesTo] ile aynıdır:
/// GitHub sideload (`githubStable` / `githubBeta`), Windows, Microsoft Store,
/// App Store, iOS ve web'de bu dosyadaki hiçbir satır eklentiye dokunmaz.
///
/// Uygun an (hepsi birlikte):
/// - Bu cihazda kaydedilen **en az 20 dakikalık** seans sayısı 5'e ulaştı
///   (sayaç cihaz başına, `SharedPreferences`'ta);
/// - en fazla 120 günde bir, toplamda en fazla 3 kez;
/// - uygulama ön planda ve koşan/duran bir seans yok;
/// - aynı açılışta Play güncelleme akışı (WP-913) sayfa göstermedi;
/// - süreç başına en fazla bir deneme.
///
/// **Asla düşürmez:** her eklenti çağrısı try/catch içindedir; hata yutulur.
class PlayReviewPolicy {
  const PlayReviewPolicy._();

  /// Sayılan seansın alt sınırı.
  static const int minSessionSeconds = 20 * 60;

  /// Kaçıncı uygun seansta ilk kez sorulur.
  static const int sessionThreshold = 5;

  /// İki istek arası en kısa süre.
  static const Duration cooldown = Duration(days: 120);

  /// Ömür boyu (cihaz başına) en fazla istek.
  static const int maxRequests = 3;

  /// Seans kaydı bu kadar eskiyse "şimdi bu cihazda bitti" sayılmaz (başka
  /// cihazdan senkronla gelen / geç yansıyan satır).
  static const Duration freshWindow = Duration(minutes: 15);

  /// Kanal/platform kapısı — WP-913 ile birebir aynı.
  static bool appliesTo({
    required DistributionChannel channel,
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.android,
  }) => PlayInAppUpdate.appliesTo(
    channel: channel,
    isWeb: isWeb,
    platform: platform,
  );
}

/// Kalıcı sayaçlar (cihaz başına).
class PlayReviewStore {
  const PlayReviewStore(this.prefs);

  final SharedPreferences prefs;

  static const String qualifyingSessionsKey =
      'play_review.qualifying_sessions.v1';
  static const String requestCountKey = 'play_review.request_count.v1';
  static const String lastRequestedAtKey = 'play_review.last_requested_ms.v1';
  static const String watermarkKey = 'play_review.session_watermark_ms.v1';

  int get qualifyingSessions => prefs.getInt(qualifyingSessionsKey) ?? 0;
  int get requestCount => prefs.getInt(requestCountKey) ?? 0;

  DateTime? get lastRequestedAt {
    final ms = prefs.getInt(lastRequestedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  int? get watermarkMs => prefs.getInt(watermarkKey);

  Future<void> addQualifyingSessions(int n) =>
      prefs.setInt(qualifyingSessionsKey, qualifyingSessions + n);

  Future<void> markRequested(DateTime now) async {
    await prefs.setInt(requestCountKey, requestCount + 1);
    await prefs.setInt(lastRequestedAtKey, now.millisecondsSinceEpoch);
  }

  Future<void> setWatermarkMs(int ms) => prefs.setInt(watermarkKey, ms);
}

/// Kaydedilen bir seans sayılır mı? (≥ 20 dk, canlı sayaç)
bool isQualifyingPlayReviewSession(StudySession session) =>
    session.source == StudySource.live &&
    session.durationSeconds >= PlayReviewPolicy.minSessionSeconds;

/// Oturum listesinin (yeni → eski) yeni satırlarını sayaca işler; kaç uygun
/// seans eklendiğini döner. Hiç `throw` etmez.
///
/// - İlk çalıştırmada (filigran yok) geçmiş **sayılmaz**: filigran `now`'a
///   konur. Sayaç bu sürümden sonra bu cihazda biten seanslardan başlar.
/// - Filigrandan sonra biten her satır bir kez görülür; liste yeniden yayınlansa
///   (senkron, gün damgası) aynı seans ikinci kez sayılmaz.
/// - [localRunSeen] yanlışsa (bu süreçte bu cihazda yerel sayaç koşmadı) yeni
///   satırlar başka cihazdandır: filigran ilerler, sayaç artmaz.
Future<int> ingestPlayReviewSessions({
  required PlayReviewStore store,
  required List<StudySession> sessions,
  required DateTime now,
  required bool localRunSeen,
}) async {
  try {
    final watermark = store.watermarkMs;
    if (watermark == null) {
      await store.setWatermarkMs(now.millisecondsSinceEpoch);
      return 0;
    }
    var next = watermark;
    var added = 0;
    for (final s in sessions) {
      final endMs = s.end.millisecondsSinceEpoch;
      if (endMs <= watermark) continue;
      if (endMs > next) next = endMs;
      if (!localRunSeen) continue;
      if (!isQualifyingPlayReviewSession(s)) continue;
      if (now.difference(s.end) > PlayReviewPolicy.freshWindow) continue;
      added++;
    }
    if (next != watermark) await store.setWatermarkMs(next);
    if (added > 0) await store.addQualifyingSessions(added);
    return added;
  } catch (_) {
    return 0;
  }
}

/// Eklenti sınırı — testler gerçek `InAppReview`'a hiç dokunmasın diye.
abstract class PlayReviewGateway {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

/// Gerçek eklenti. Yalnız Play + Android derlemesinde çağrılır.
class PlayStoreReviewGateway implements PlayReviewGateway {
  const PlayStoreReviewGateway();

  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

/// Testte sahte geçit verilebilsin diye; varsayılan gerçek eklentidir.
final playReviewGatewayProvider = Provider<PlayReviewGateway>(
  (ref) => const PlayStoreReviewGateway(),
);

/// Süreç (açılış) başına durum.
class PlayReviewLaunchState {
  /// Bu açılışta eklentiye zaten soruldu mu?
  bool attempted = false;

  /// Bu açılışta Play güncelleme akışı sayfa gösterdi/gösterecek mi (önbellek).
  bool? updateFlowShown;
}

/// Tek denemenin sonucu — hepsi sessizdir.
enum PlayReviewOutcome {
  /// Play kanalı / Android değil: eklentiye **hiç** dokunulmadı.
  notApplicable,

  /// Henüz 5 uygun seans yok.
  belowThreshold,

  /// Ömür boyu 3 istek dolu.
  maxReached,

  /// Son istekten bu yana 120 gün geçmedi.
  coolingDown,

  /// Bu açılışta zaten denendi.
  alreadyThisLaunch,

  /// Arka planda ya da seans koşuyor — sonra (seans bitince / ön plana
  /// dönünce) yeniden denenir.
  deferred,

  /// Bu açılışta Play güncelleme sayfası çıktı — bu açılışta sorulmaz.
  updateFlowThisLaunch,

  /// Play "bu cihazda gösterilemez" dedi.
  unavailable,

  /// `requestReview()` çağrıldı (sayfayı Google gösterir ya da göstermez).
  requested,

  /// Eklenti hata attı — yutuldu.
  failed,
}

/// Saf akış: kapı → eşik → sınırlar → an → eklenti. Hiç `throw` etmez.
Future<PlayReviewOutcome> maybeRequestPlayReview({
  required PlayReviewGateway gateway,
  required PlayReviewStore store,
  required PlayReviewLaunchState launch,
  required DistributionChannel channel,
  required DateTime now,
  required bool inForeground,
  required bool midSession,
  required Future<bool> Function() updateFlowThisLaunch,
  bool isWeb = false,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  if (!PlayReviewPolicy.appliesTo(
    channel: channel,
    isWeb: isWeb,
    platform: platform,
  )) {
    return PlayReviewOutcome.notApplicable;
  }
  try {
    if (store.qualifyingSessions < PlayReviewPolicy.sessionThreshold) {
      return PlayReviewOutcome.belowThreshold;
    }
    if (store.requestCount >= PlayReviewPolicy.maxRequests) {
      return PlayReviewOutcome.maxReached;
    }
    final last = store.lastRequestedAt;
    if (last != null && now.difference(last) < PlayReviewPolicy.cooldown) {
      return PlayReviewOutcome.coolingDown;
    }
    if (launch.attempted) return PlayReviewOutcome.alreadyThisLaunch;
    if (!inForeground || midSession) return PlayReviewOutcome.deferred;
    if (await updateFlowThisLaunch()) {
      return PlayReviewOutcome.updateFlowThisLaunch;
    }
    launch.attempted = true;
    if (!await gateway.isAvailable()) return PlayReviewOutcome.unavailable;
    await gateway.requestReview();
    await store.markRequested(now);
    return PlayReviewOutcome.requested;
  } catch (_) {
    launch.attempted = true;
    return PlayReviewOutcome.failed;
  }
}

/// Aynı açılışta Play güncelleme akışı Google'ın sayfasını gösterdi mi?
///
/// WP-913 akışı yalnız "güncelleme var + esnek akış serbest" iken sayfa açar
/// ([runPlayInAppUpdate]). Aynı geçitle aynı soruyu sorarız; sonuç süreç
/// başına önbelleğe alınır. Kurulum şeridi (WP-914) bekliyorsa da evettir.
/// Hata ⇒ güncelleme akışı da sayfa açamamıştır ⇒ hayır.
Future<bool> playUpdateFlowShownThisLaunch({
  required PlayReviewLaunchState launch,
  required PlayInAppUpdateGateway updateGateway,
  required bool restartHintPending,
}) async {
  if (restartHintPending) return true;
  final cached = launch.updateFlowShown;
  if (cached != null) return cached;
  bool shown;
  try {
    final info = await updateGateway.checkForUpdate();
    shown = info.updateAvailable && info.flexibleAllowed;
  } catch (_) {
    shown = false;
  }
  launch.updateFlowShown = shown;
  return shown;
}

/// Sayaç sinyali: seans ortası mı, bu cihazda yerel (ayna olmayan) koşu mu?
typedef PlayReviewTimerSignal = ({bool midSession, bool localRun});

/// Testte ezilebilsin diye sayaç durumundan türetilir.
final playReviewTimerSignalProvider = Provider<PlayReviewTimerSignal>((ref) {
  final s = ref.watch(studyTimerProvider);
  return (
    midSession: s.isRunning || s.isStopping,
    localRun: s.isRunning && !s.isGlobalTimerMirror,
  );
});

PlayReviewLaunchState _launch = PlayReviewLaunchState();
bool _localRunSeenThisProcess = false;

/// Yalnız test: süreç durumunu sıfırlar.
@visibleForTesting
void debugResetPlayReview() {
  _launch = PlayReviewLaunchState();
  _localRunSeenThisProcess = false;
}

/// Yalnız test: kanal derleme zamanında sabittir, testte ezilir.
@visibleForTesting
DistributionChannel? debugPlayReviewChannel;

/// Yalnız test: platform kararını ezmek için.
@visibleForTesting
TargetPlatform? debugPlayReviewPlatform;

/// Yalnız test: ön plan kararını ezmek için. `null` → gerçek yaşam döngüsü.
@visibleForTesting
bool? debugPlayReviewInForeground;

/// Yalnız test: saat.
@visibleForTesting
DateTime Function()? debugPlayReviewClock;

bool _inForeground() {
  final override = debugPlayReviewInForeground;
  if (override != null) return override;
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}

/// WP-941: ana kabuk (`HomeShell`) kurulduğunda izlenir. Seans kaydını
/// (`userSessionsProvider`) ve sayaç durumunu dinler; denemeyi seans kaydında,
/// sayaç durduğunda ve uygulama ön plana döndüğünde yapar.
final playReviewProvider = Provider<void>((ref) {
  // 🔴 Kanal kararı her şeyden ÖNCE: Play dışı derlemede tek satır bile
  // çalışmamalı (WP-614 / WP-913 dersi).
  final channel = debugPlayReviewChannel ?? DistributionConfig.current;
  final platform = debugPlayReviewPlatform ?? defaultTargetPlatform;
  if (!PlayReviewPolicy.appliesTo(
    channel: channel,
    isWeb: kIsWeb,
    platform: platform,
  )) {
    return;
  }
  final store = PlayReviewStore(ref.read(sharedPreferencesProvider));
  DateTime now() => (debugPlayReviewClock ?? DateTime.now)();

  var busy = false;
  void attempt() {
    if (busy || _launch.attempted || !ref.mounted) return;
    busy = true;
    unawaited(() async {
      try {
        await maybeRequestPlayReview(
          gateway: ref.read(playReviewGatewayProvider),
          store: store,
          launch: _launch,
          channel: channel,
          now: now(),
          inForeground: _inForeground(),
          midSession: ref.read(playReviewTimerSignalProvider).midSession,
          updateFlowThisLaunch: () => playUpdateFlowShownThisLaunch(
            launch: _launch,
            updateGateway: ref.read(playInAppUpdateGatewayProvider),
            restartHintPending: ref.read(playUpdateRestartHintProvider),
          ),
          isWeb: kIsWeb,
          platform: platform,
        );
      } catch (_) {
        // Sessiz.
      } finally {
        busy = false;
      }
    }());
  }

  ref.listen<PlayReviewTimerSignal>(playReviewTimerSignalProvider, (
    prev,
    next,
  ) {
    if (next.localRun) _localRunSeenThisProcess = true;
    // Seans bitti (ya da pomodoro tamamen durdu): ertelenmiş istek şimdi.
    if ((prev?.midSession ?? false) && !next.midSession) attempt();
  }, fireImmediately: true);

  ref.listen<AsyncValue<List<StudySession>>>(userSessionsProvider, (_, next) {
    final sessions = next.asData?.value;
    if (sessions == null) return;
    unawaited(() async {
      final added = await ingestPlayReviewSessions(
        store: store,
        sessions: sessions,
        now: now(),
        localRunSeen: _localRunSeenThisProcess,
      );
      if (added > 0) attempt();
    }());
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(onResume: attempt);
  ref.onDispose(lifecycle.dispose);
});
