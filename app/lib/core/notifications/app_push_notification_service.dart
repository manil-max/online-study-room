import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/nudge.dart';
import '../config/firebase_push_config.dart';
import '../l10n/system_localizations.dart';

const _seenPushEventIdsKey = 'push_seen_event_ids_v1';
const _lastPushEventIdKey = 'push_last_event_id';
const _lastPushTypeKey = 'push_last_type';
const _lastPushReceivedAtKey = 'push_last_received_at';

enum AppPushPermission { authorized, denied, notDetermined, unsupported }

@immutable
class AppPushSnapshot {
  const AppPushSnapshot({
    required this.supported,
    required this.configStatus,
    required this.initialized,
    required this.permission,
    required this.notificationsEnabled,
    required this.hasToken,
    this.lastReceivedAt,
    this.lastEventId,
    this.lastType,
    this.errorCode,
  });

  final bool supported;
  final FirebasePushConfigStatus configStatus;
  final bool initialized;
  final AppPushPermission permission;
  final bool notificationsEnabled;
  final bool hasToken;
  final DateTime? lastReceivedAt;
  final String? lastEventId;
  final String? lastType;
  final String? errorCode;
}

/// Sosyal/remote bildirimlerin tek local presentation koordinatörü.
/// Alarm full-screen ve native timer FGS bilinçli olarak ayrı kalır.
class AppNotificationCoordinator {
  AppNotificationCoordinator._(this._plugin);

  static final instance = AppNotificationCoordinator._(
    FlutterLocalNotificationsPlugin(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !_isAndroid) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final l10n = await loadSystemLocalizations();
    final channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        'social_nudges',
        l10n.coreDurtmeler,
        description: l10n.coreDurtmeler,
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'push_system_test',
        l10n.notificationsHealthTitle,
        description: l10n.notificationsHealthTitle,
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'app_updates',
        l10n.notificationsGuncellemeBildirimleri,
        description: l10n.notificationsGuncellemeBildirimleri,
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'announcements',
        l10n.notificationsDuyurular,
        description: l10n.notificationsDuyurular,
        importance: Importance.high,
      ),
    ];
    for (final channel in channels) {
      await android?.createNotificationChannel(channel);
    }
    _initialized = true;
  }

  Future<bool> notificationsEnabled() async {
    if (!_isAndroid) return false;
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  Future<bool> requestPermission() async {
    if (!_isAndroid) return false;
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
  }

  Future<void> showLocalTest() async {
    if (!_isAndroid) return;
    await initialize();
    final channel = _channelFor('self_test');
    await _plugin.show(
      id: 266001,
      title: 'Odak Kampı',
      body: 'Telefondaki bildirim gösterimi çalışıyor.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: 'notification_center:local_test',
    );
  }

  Future<void> showRemote(RemoteMessage message) async {
    if (!_isAndroid) return;
    final eventId = _eventId(message.data, fallback: message.messageId);
    final type = (message.data['notification_type'] ?? 'announcement').trim();
    final prefs = await SharedPreferences.getInstance();
    if (!await _markReceivedOnce(prefs, eventId: eventId, type: type)) return;

    final notification = message.notification;
    if (notification == null) return;
    await initialize();
    final channel = _channelFor(type);
    await _plugin.show(
      id: eventId.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: type == 'nudge'
              ? AndroidNotificationCategory.message
              : null,
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: '${message.data['route'] ?? 'notification_center'}:$eventId',
    );
  }

  Future<void> showNudge(Nudge nudge) async {
    if (!_isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final eventId = 'nudge:${nudge.id}';
    if (!await _markReceivedOnce(prefs, eventId: eventId, type: 'nudge')) {
      return;
    }
    await initialize();
    final l10n = await loadSystemLocalizations();
    final sender = (nudge.senderDisplayName?.trim().isNotEmpty ?? false)
        ? nudge.senderDisplayName!.trim()
        : l10n.coreBirArkadasin;
    final body = nudge.message?.trim().isNotEmpty == true
        ? nudge.message!.trim()
        : l10n.coreSeniCalismayaCagiriyor;
    final channel = _channelFor('nudge');
    await _plugin.show(
      id: nudge.id.hashCode & 0x7fffffff,
      title: l10n.coreSenderDurttu(sender),
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          l10n.coreDurtmeler,
          channelDescription: l10n.coreDurtmeler,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          ticker: l10n.coreYeniDurtme,
        ),
      ),
      payload: eventId,
    );
  }

  ({String id, String name, String description}) _channelFor(String type) {
    return switch (type) {
      'nudge' => (
        id: 'social_nudges',
        name: 'Dürtmeler',
        description: 'Arkadaşlarından gelen çalışma dürtmeleri',
      ),
      'self_test' => (
        id: 'push_system_test',
        name: 'Bildirim testi',
        description: 'Uzak bildirim bağlantısı testleri',
      ),
      'update' => (
        id: 'app_updates',
        name: 'Uygulama güncellemeleri',
        description: 'Yeni sürüm bildirimleri',
      ),
      _ => (
        id: 'announcements',
        name: 'Duyurular',
        description: 'Odak Kampı ve grup duyuruları',
      ),
    };
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

/// Firebase/FCM platform köprüsü. Config yoksa hiçbir plugin çağrısı yapmaz.
class AppPushNotificationService {
  AppPushNotificationService._();

  static final instance = AppPushNotificationService._();

  SharedPreferences? _prefs;
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _initialized = false;
  String? _errorCode;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isInitialized => _initialized;

  Stream<String> get tokenRefresh =>
      _messaging?.onTokenRefresh ?? const Stream<String>.empty();

  Future<void> bootstrap(SharedPreferences prefs) async {
    _prefs = prefs;
    if (!isSupported || !FirebasePushConfig.isConfigured || _initialized) {
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebasePushConfig.androidOptions,
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
      _messaging = FirebaseMessaging.instance;
      await _messaging!.setAutoInitEnabled(true);
      await AppNotificationCoordinator.instance.initialize();
      _foregroundSub = FirebaseMessaging.onMessage.listen(
        AppNotificationCoordinator.instance.showRemote,
      );
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_markOpened);
      final initial = await _messaging!.getInitialMessage();
      if (initial != null) await _markOpened(initial);
      _initialized = true;
      _errorCode = null;
    } catch (_) {
      _errorCode = 'firebase_initialization_failed';
      _initialized = false;
    }
  }

  Future<AppPushPermission> requestPermission() async {
    if (!isSupported || _messaging == null) {
      return AppPushPermission.unsupported;
    }
    try {
      await AppNotificationCoordinator.instance.requestPermission();
      final settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _permission(settings.authorizationStatus);
    } catch (_) {
      _errorCode = 'notification_permission_failed';
      return AppPushPermission.denied;
    }
  }

  Future<String?> token() async {
    if (!_initialized || _messaging == null) return null;
    try {
      return await _messaging!.getToken();
    } catch (_) {
      _errorCode = 'fcm_token_failed';
      return null;
    }
  }

  Future<AppPushSnapshot> snapshot() async {
    final prefs = _prefs;
    if (!isSupported) {
      return const AppPushSnapshot(
        supported: false,
        configStatus: FirebasePushConfigStatus.notConfigured,
        initialized: false,
        permission: AppPushPermission.unsupported,
        notificationsEnabled: false,
        hasToken: false,
      );
    }
    if (!FirebasePushConfig.isConfigured) {
      final rawReceived = prefs?.getString(_lastPushReceivedAtKey);
      return AppPushSnapshot(
        supported: true,
        configStatus: FirebasePushConfig.status,
        initialized: false,
        permission: AppPushPermission.notDetermined,
        notificationsEnabled: false,
        hasToken: false,
        lastReceivedAt: rawReceived == null
            ? null
            : DateTime.tryParse(rawReceived),
        lastEventId: prefs?.getString(_lastPushEventIdKey),
        lastType: prefs?.getString(_lastPushTypeKey),
      );
    }
    AppPushPermission permission = AppPushPermission.notDetermined;
    if (_messaging != null) {
      try {
        final settings = await _messaging!.getNotificationSettings();
        permission = _permission(settings.authorizationStatus);
      } catch (_) {
        _errorCode ??= 'notification_settings_failed';
      }
    }
    final rawReceived = prefs?.getString(_lastPushReceivedAtKey);
    return AppPushSnapshot(
      supported: true,
      configStatus: FirebasePushConfig.status,
      initialized: _initialized,
      permission: permission,
      notificationsEnabled: await AppNotificationCoordinator.instance
          .notificationsEnabled(),
      hasToken: (await token())?.trim().isNotEmpty ?? false,
      lastReceivedAt: rawReceived == null
          ? null
          : DateTime.tryParse(rawReceived),
      lastEventId: prefs?.getString(_lastPushEventIdKey),
      lastType: prefs?.getString(_lastPushTypeKey),
      errorCode: _errorCode,
    );
  }

  Future<void> _markOpened(RemoteMessage message) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await _markReceivedOnce(
      prefs,
      eventId: _eventId(message.data, fallback: message.messageId),
      type: message.data['notification_type'] ?? 'unknown',
    );
  }

  AppPushPermission _permission(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => AppPushPermission.authorized,
    AuthorizationStatus.denied => AppPushPermission.denied,
    AuthorizationStatus.notDetermined => AppPushPermission.notDetermined,
  };

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
  }
}

@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty && FirebasePushConfig.isConfigured) {
    await Firebase.initializeApp(options: FirebasePushConfig.androidOptions);
  }
  final prefs = await SharedPreferences.getInstance();
  await _markReceivedOnce(
    prefs,
    eventId: _eventId(message.data, fallback: message.messageId),
    type: message.data['notification_type'] ?? 'unknown',
  );
}

String _eventId(Map<String, dynamic> data, {String? fallback}) {
  final type = (data['notification_type'] ?? 'remote').toString();
  final explicit =
      (type == 'self_test'
              ? data['outbox_id'] ?? data['event_id'] ?? fallback
              : data['event_id'] ?? data['outbox_id'] ?? fallback)
          ?.toString()
          .trim();
  return explicit == null || explicit.isEmpty
      ? '$type:${DateTime.now().microsecondsSinceEpoch}'
      : '$type:$explicit';
}

Future<bool> _markReceivedOnce(
  SharedPreferences prefs, {
  required String eventId,
  required String type,
}) async {
  final seen = (prefs.getStringList(_seenPushEventIdsKey) ?? const <String>[])
      .toList();
  if (seen.contains(eventId)) return false;
  seen.add(eventId);
  if (seen.length > 100) seen.removeRange(0, seen.length - 100);
  final now = DateTime.now().toUtc();
  await Future.wait([
    prefs.setStringList(_seenPushEventIdsKey, seen),
    prefs.setString(_lastPushEventIdKey, eventId),
    prefs.setString(_lastPushTypeKey, type),
    prefs.setString(_lastPushReceivedAtKey, now.toIso8601String()),
  ]);
  return true;
}
