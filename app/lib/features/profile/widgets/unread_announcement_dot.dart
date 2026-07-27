import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// WP-378: okunmamış duyuru işareti.
///
/// Renk `colorScheme.primary`'dendir — duyuru bir **uyarı değil**, yeni
/// içeriktir. (Uyarı yüzeyleri `warning_tokens.dart`'ı kullanır; ikisi
/// karıştırılmamalı.)
///
/// Aynı nokta üç yerde birden çıkar ve hepsi tek kaynaktan beslenir
/// (`unreadAnnouncementCountProvider`): Profil sekmesi · Profil'deki Ayarlar
/// satırı · Ayarlar'daki Duyurular satırı. Zincirin herhangi bir halkası
/// eksikse kullanıcı duyuruyu ancak Ayarlar'ı açınca fark eder — WP-378'den
/// önceki durum tam olarak buydu.
class UnreadAnnouncementDot extends StatelessWidget {
  const UnreadAnnouncementDot({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: AppLocalizations.of(context).notificationsDuyurular,
      value: '$count',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
