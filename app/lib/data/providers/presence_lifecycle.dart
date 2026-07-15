import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/presence.dart';
import '../models/study_group.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'presence_providers.dart';
import 'study_providers.dart';

/// Yerel kullanıcının canlı durumunu (presence) diri tutan yaşam-döngüsü
/// denetleyicisi (§WP-5).
///
/// Sayaç yalnız başlat/faz-geçiş/durdur anlarında presence yazdığı için, uzun
/// bir çalışma oturumu boyunca satır güncellenmez; başka bir cihaz bu satırı
/// "bayat" görürdü. Bu denetleyici çalışma sürerken düzenli **heartbeat** atar
/// (satırı yeniden yazıp sunucu `updated_at`'ini tazeler) ve uygulama öne
/// gelince (`resumed`) hemen bir kez tazeler. Uygulama öldürülür/çökerse
/// heartbeat durur, satır [kPresenceStaleThreshold] sonra bayatlar ve okuma
/// tarafı ([groupPresenceProvider]) onu çevrimdışı gösterir.
///
/// Yazım "yangına-at-unut"tur: presence hatası çalışma akışını hiç etkilemez.
class PresenceLifecycle with WidgetsBindingObserver {
  PresenceLifecycle(this._ref);

  final Ref _ref;
  Timer? _heartbeat;
  bool _started = false;

  ProviderSubscription<AsyncValue<StudyGroup?>>? _groupSub;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _heartbeat = Timer.periodic(kPresenceHeartbeatInterval, (_) => beat());
    // Group sonradan gelince (soğuk açılış / widget start) hemen presence yaz;
    // 20 sn heartbeat bekleme (H3).
    _groupSub = _ref.listen(userGroupProvider, (prev, next) {
      final group = next.asData?.value;
      if (group != null) beat();
    });
    // Group zaten hazır + timer restore edilmişse ilk beat'i kaçırma.
    beat();
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _heartbeat?.cancel();
    _heartbeat = null;
    _groupSub?.close();
    _groupSub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Öne gelince satırı hemen tazele: arka planda kaçmış bir heartbeat sonrası
    // kullanıcı yeniden "canlı" görünsün, eşik dolmadan.
    if (state == AppLifecycleState.resumed) beat();
  }

  /// Çalışma sürüyorsa presence satırını yeniden yazar (updated_at tazelenir).
  /// Başlangıç anı (startedAt) korunur ki geçen süre sıfırlanmasın.
  @visibleForTesting
  void beat() {
    final timer = _ref.read(studyTimerProvider);
    if (!timer.isRunning || timer.startedAt == null) return;

    final user = _ref.read(authStateProvider).value;
    final group = _ref.read(userGroupProvider).value;
    if (user == null || group == null) return;

    final presence = Presence(
      userId: user.id,
      groupId: group.id,
      status: timer.phase == TimerPhase.work
          ? PresenceStatus.studying
          : PresenceStatus.onBreak,
      startedAt: timer.startedAt,
      todaySeconds: _ref.read(todayRecordedSecondsProvider),
    );
    _ref.read(presenceRepositoryProvider).setPresence(presence).catchError(
          (_) {},
        );
  }
}

/// Presence heartbeat/yaşam-döngüsü denetleyicisi. Ana kabuk ([HomeShell]) bunu
/// izleyerek oturum boyunca diri tutar (izlendiği sürece çalışır).
final presenceLifecycleProvider = Provider<PresenceLifecycle>((ref) {
  final lifecycle = PresenceLifecycle(ref)..start();
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
