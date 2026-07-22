import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_build_manifest.dart';
import '../../core/config/firebase_push_config.dart';
import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/notifications/app_push_notification_service.dart';
import '../../core/notifications/notification_preferences.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/time_engine/device_timezone.dart';
import '../models/profile.dart';
import '../models/push_notification.dart';
import '../repositories/in_memory/in_memory_push_registration_repository.dart';
import '../repositories/push_registration_repository.dart';
import '../repositories/supabase/supabase_push_registration_repository.dart';
import 'auth_providers.dart';

const _pushInstallationIdKey = 'push_installation_id_v1';

final pushRegistrationRepositoryProvider = Provider<PushRegistrationRepository>(
  (ref) {
    if (SupabaseConfig.isConfigured) {
      return SupabasePushRegistrationRepository(Supabase.instance.client);
    }
    return InMemoryPushRegistrationRepository();
  },
);

enum PushHealthReadiness {
  unsupported,
  notConfigured,
  incompleteConfiguration,
  permissionRequired,
  registering,
  ready,
  error,
}

@immutable
class PushHealthState {
  const PushHealthState({
    required this.readiness,
    required this.snapshot,
    this.deviceRegistered = false,
    this.syncing = false,
    this.localTestSucceeded = false,
    this.selfTestStatus,
    this.selfTestElapsed,
    this.selfTestReceived = false,
    this.errorCode,
  });

  final PushHealthReadiness readiness;
  final AppPushSnapshot snapshot;
  final bool deviceRegistered;
  final bool syncing;
  final bool localTestSucceeded;
  final PushSelfTestStatus? selfTestStatus;
  final Duration? selfTestElapsed;
  final bool selfTestReceived;
  final String? errorCode;

  PushHealthState copyWith({
    PushHealthReadiness? readiness,
    AppPushSnapshot? snapshot,
    bool? deviceRegistered,
    bool? syncing,
    bool? localTestSucceeded,
    PushSelfTestStatus? selfTestStatus,
    Duration? selfTestElapsed,
    bool? selfTestReceived,
    String? errorCode,
    bool clearSelfTest = false,
    bool clearError = false,
  }) {
    return PushHealthState(
      readiness: readiness ?? this.readiness,
      snapshot: snapshot ?? this.snapshot,
      deviceRegistered: deviceRegistered ?? this.deviceRegistered,
      syncing: syncing ?? this.syncing,
      localTestSucceeded: localTestSucceeded ?? this.localTestSucceeded,
      selfTestStatus: clearSelfTest
          ? null
          : selfTestStatus ?? this.selfTestStatus,
      selfTestElapsed: clearSelfTest
          ? null
          : selfTestElapsed ?? this.selfTestElapsed,
      selfTestReceived: clearSelfTest
          ? false
          : selfTestReceived ?? this.selfTestReceived,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }
}

class PushHealthController extends Notifier<PushHealthState> {
  StreamSubscription<String>? _tokenRefreshSub;
  Future<void>? _syncInFlight;
  Profile? _lastUser;
  NotificationPreferences? _lastPreferences;
  String? _lastFingerprint;

  AppPushNotificationService get _service =>
      AppPushNotificationService.instance;

  @override
  PushHealthState build() {
    _tokenRefreshSub = _service.tokenRefresh.listen((_) {
      unawaited(synchronize(force: true));
    });
    ref.onDispose(() => _tokenRefreshSub?.cancel());
    return PushHealthState(
      readiness: _initialReadiness(),
      snapshot: AppPushSnapshot(
        supported: _service.isSupported,
        configStatus: FirebasePushConfig.status,
        initialized: _service.isInitialized,
        permission: _service.isSupported
            ? AppPushPermission.notDetermined
            : AppPushPermission.unsupported,
        notificationsEnabled: false,
        hasToken: false,
      ),
    );
  }

  void updateContext(Profile? user, NotificationPreferences preferences) {
    _lastUser = user;
    _lastPreferences = preferences;
    unawaited(synchronize());
  }

  Future<void> synchronize({bool force = false}) {
    final existing = _syncInFlight;
    if (existing != null) return existing;
    final future = _synchronizeImpl(force: force);
    _syncInFlight = future;
    return future.whenComplete(() => _syncInFlight = null);
  }

  Future<void> _synchronizeImpl({required bool force}) async {
    final snapshot = await _service.snapshot();
    final user = _lastUser;
    final preferences = _lastPreferences;
    final readiness = _readinessFrom(snapshot);
    state = state.copyWith(
      snapshot: snapshot,
      readiness: readiness,
      syncing: readiness == PushHealthReadiness.ready && user != null,
      deviceRegistered: user == null ? false : state.deviceRegistered,
      errorCode: snapshot.errorCode,
      clearError: snapshot.errorCode == null,
    );

    if (user == null ||
        preferences == null ||
        readiness != PushHealthReadiness.ready) {
      return;
    }
    final token = await _service.token();
    if (token == null || token.trim().isEmpty) {
      state = state.copyWith(
        readiness: PushHealthReadiness.error,
        syncing: false,
        deviceRegistered: false,
        errorCode: 'fcm_token_missing',
      );
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    var installationId = prefs.getString(_pushInstallationIdKey)?.trim();
    if (installationId == null || installationId.length < 16) {
      installationId = const Uuid().v4();
      await prefs.setString(_pushInstallationIdKey, installationId);
    }
    final manifest = AppBuildManifest.currentOrNull;
    final registration = PushDeviceRegistration(
      installationId: installationId,
      fcmToken: token,
      appChannel: manifest?.channelName ?? 'local',
      appVersion: manifest?.versionName ?? '0.0.0-local',
      buildNumber: manifest?.buildNumber ?? 0,
      locale: activeAppLocale.languageCode,
      timeZone: DeviceTimezone.lastId ?? 'UTC',
      nudgeEnabled: preferences.nudgeNotificationsEnabled,
      announcementEnabled: preferences.announcementsEnabled,
      updateEnabled: preferences.updatesEnabled,
      quietHoursEnabled: preferences.quietHoursEnabled,
      quietStartMinutes: preferences.quietStartMinutes,
      quietEndMinutes: preferences.quietEndMinutes,
    );
    final fingerprint = [
      user.id,
      token,
      registration.appChannel,
      registration.appVersion,
      registration.buildNumber,
      registration.locale,
      registration.timeZone,
      registration.nudgeEnabled,
      registration.announcementEnabled,
      registration.updateEnabled,
      registration.quietHoursEnabled,
      registration.quietStartMinutes,
      registration.quietEndMinutes,
    ].join('|');
    if (!force && fingerprint == _lastFingerprint && state.deviceRegistered) {
      state = state.copyWith(syncing: false);
      return;
    }

    try {
      await ref
          .read(pushRegistrationRepositoryProvider)
          .registerDevice(registration);
      _lastFingerprint = fingerprint;
      state = state.copyWith(
        readiness: PushHealthReadiness.ready,
        syncing: false,
        deviceRegistered: true,
        clearError: true,
      );
    } on PushRegistrationException catch (error) {
      state = state.copyWith(
        readiness: PushHealthReadiness.error,
        syncing: false,
        deviceRegistered: false,
        errorCode: error.code,
      );
    }
  }

  Future<void> requestPermissionAndSync() async {
    state = state.copyWith(syncing: true, clearError: true);
    await _service.requestPermission();
    await synchronize(force: true);
  }

  Future<void> runLocalTest() async {
    try {
      await AppNotificationCoordinator.instance.showLocalTest();
      state = state.copyWith(localTestSucceeded: true, clearError: true);
      await refresh();
    } catch (_) {
      state = state.copyWith(errorCode: 'local_notification_test_failed');
    }
  }

  Future<void> runRemoteTest() async {
    if (!state.deviceRegistered) {
      state = state.copyWith(errorCode: 'device_not_registered');
      return;
    }
    state = state.copyWith(
      syncing: true,
      clearSelfTest: true,
      clearError: true,
    );
    final watch = Stopwatch()..start();
    try {
      final repository = ref.read(pushRegistrationRepositoryProvider);
      final request = await repository.requestSelfTest();
      PushSelfTestStatus? status;
      var received = false;
      // DB tetikleyicisi + Edge cold-start + FCM için 10 saniye güvenilir değildi.
      // Bu pencere yalnız test sonucunu bekler; normal bildirim teslimini geciktirmez.
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      do {
        status = await repository.fetchSelfTestStatus(request.outboxId);
        final snapshot = await _service.snapshot();
        received = snapshot.lastEventId == 'self_test:${request.outboxId}';
        if ((status?.state == PushSelfTestDeliveryState.sent && received) ||
            (status?.terminal == true &&
                status?.state != PushSelfTestDeliveryState.sent)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      } while (DateTime.now().isBefore(deadline));
      watch.stop();
      final succeeded =
          status?.state == PushSelfTestDeliveryState.sent && received;
      state = state.copyWith(
        syncing: false,
        selfTestStatus: status,
        selfTestElapsed: watch.elapsed,
        selfTestReceived: received,
        errorCode: succeeded
            ? null
            : status?.state == PushSelfTestDeliveryState.sent
            ? 'push_test_not_received'
            : status == null || !(status.terminal)
            ? 'push_test_timeout'
            : 'push_test_delivery_failed',
        clearError: succeeded,
      );
      await refresh();
    } on PushRegistrationException catch (error) {
      watch.stop();
      state = state.copyWith(
        syncing: false,
        selfTestElapsed: watch.elapsed,
        errorCode: error.code,
      );
    }
  }

  Future<void> refresh() async {
    final snapshot = await _service.snapshot();
    state = state.copyWith(
      snapshot: snapshot,
      readiness: _readinessFrom(snapshot),
      errorCode: snapshot.errorCode,
      clearError: snapshot.errorCode == null && state.errorCode == null,
    );
  }

  PushHealthReadiness _initialReadiness() {
    if (!_service.isSupported) return PushHealthReadiness.unsupported;
    return switch (FirebasePushConfig.status) {
      FirebasePushConfigStatus.notConfigured =>
        PushHealthReadiness.notConfigured,
      FirebasePushConfigStatus.incomplete =>
        PushHealthReadiness.incompleteConfiguration,
      FirebasePushConfigStatus.configured => PushHealthReadiness.registering,
    };
  }

  PushHealthReadiness _readinessFrom(AppPushSnapshot snapshot) {
    if (!snapshot.supported) return PushHealthReadiness.unsupported;
    if (snapshot.configStatus == FirebasePushConfigStatus.notConfigured) {
      return PushHealthReadiness.notConfigured;
    }
    if (snapshot.configStatus == FirebasePushConfigStatus.incomplete) {
      return PushHealthReadiness.incompleteConfiguration;
    }
    if (!snapshot.initialized || snapshot.errorCode != null) {
      return PushHealthReadiness.error;
    }
    if (snapshot.permission != AppPushPermission.authorized ||
        !snapshot.notificationsEnabled) {
      return PushHealthReadiness.permissionRequired;
    }
    return PushHealthReadiness.ready;
  }
}

final pushHealthProvider =
    NotifierProvider<PushHealthController, PushHealthState>(
      PushHealthController.new,
    );

/// Auth veya bildirim tercihleri değiştiğinde cihaz kaydını sunucuyla uzlaştırır.
/// AuthGate boyunca izlenir; yalnız HomeShell'e bağlı değildir.
final pushLifecycleListenerProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).value;
  final preferences = ref.watch(notificationPreferencesProvider);
  ref.read(pushHealthProvider.notifier).updateContext(user, preferences);
});
