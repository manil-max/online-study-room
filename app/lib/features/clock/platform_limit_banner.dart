import 'package:flutter/material.dart';

/// Bu platformda **çalışmayan** bir yüzeyin başına konan açıklama şeridi.
///
/// 🔴 WP-611: Windows'ta alarm hiç kurulmuyordu (kurulmamış
/// `flutter_local_notifications` eklentisi plan/iptal çağrılarında istisna
/// atıyor). Kod tarafı artık o çağrıları hiç yapmıyor — ama sessizce
/// yapmamak tek başına **daha kötü** olurdu: kullanıcı alarm kuruyor, ekranda
/// duruyor, saati geliyor ve hiçbir şey olmuyor. Sınır görünür olmalı.
///
/// [severe] `true` → özellik bu platformda **hiç yok** (alarm çalmaz).
/// `false` → özellik kısıtlı çalışıyor (sayaç sayar ama bildirim yok).
/// Renk çifti tema paletinden bağımsız değil ama **eşleşmiş** token'lardan
/// alınır (`errorContainer`/`onErrorContainer`), böylece kırmızı temada
/// kaybolan uyarı sorunu tekrarlamaz.
class PlatformLimitBanner extends StatelessWidget {
  const PlatformLimitBanner({
    super.key,
    required this.message,
    this.severe = false,
  });

  final String message;
  final bool severe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = severe
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = severe
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              severe
                  ? Icons.notifications_off_outlined
                  : Icons.info_outline_rounded,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
