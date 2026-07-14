import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/nudge.dart';
import '../l10n/system_localizations.dart';

final nudgeNotificationServiceProvider = Provider<NudgeNotificationGateway>(
  (ref) => NudgeNotificationService.instance,
);

abstract interface class NudgeNotificationGateway {
  Future<void> requestPermissionIfNeeded();

  Future<void> showNudge(Nudge nudge);
}

class NudgeNotificationService implements NudgeNotificationGateway {
  NudgeNotificationService._(this._plugin);

  static final instance = NudgeNotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  static const _channelId = 'social_nudges';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  @override
  Future<void> requestPermissionIfNeeded() async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> showNudge(Nudge nudge) async {
    if (!_isAndroid) return;
    await initialize();
    final l10n = await loadSystemLocalizations();

    final sender = (nudge.senderDisplayName?.trim().isNotEmpty ?? false)
        ? nudge.senderDisplayName!.trim()
        : l10n.coreBirArkadasin;
    final body = nudge.message?.trim().isNotEmpty == true
        ? nudge.message!.trim()
        : l10n.coreSeniCalismayaCagiriyor;

    final details = AndroidNotificationDetails(
      _channelId,
      l10n.coreDurtmeler,
      channelDescription: l10n.coreDurtmeler,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      ticker: l10n.coreYeniDurtme,
    );

    await _plugin.show(
      id: nudge.id.hashCode & 0x7fffffff,
      title: l10n.coreSenderDurttu(sender),
      body: body,
      notificationDetails: NotificationDetails(android: details),
      payload: 'nudge:${nudge.id}',
    );
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
