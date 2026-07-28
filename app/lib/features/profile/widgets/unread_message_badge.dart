import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// WP-421: okunmamis yonetici yaniti rozeti.
///
/// Sahibin istegi: "yeni mesajda WhatsApp/Instagram gibi renkli rozet." Yani
/// sayisiz gri nokta degil, **sayi tasiyan dolu rozet**. Renk `error`den degil
/// `colorScheme.primary`den gelir: yeni mesaj bir uyari degil, yeni icerik
/// (`warning_tokens.dart` uyari yuzeyleri icindir, ikisi karistirilmamalidir).
///
/// Ayni rozet zincirin her halkasinda cikar ve hepsi tek kaynaktan beslenir
/// (`unreadFeedbackReplyCountProvider`): Profil'deki Ayarlar satiri · Ayarlar'
/// daki Geri bildirim satiri · Geri bildirim ekraninin "Geri bildirimlerim"
/// sekmesi. Halkalardan biri eksikse kullanici yaniti ancak ekrani acinca
/// gorur — WP-421 oncesindeki durum tam olarak buydu.
class UnreadMessageBadge extends StatelessWidget {
  const UnreadMessageBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: AppLocalizations.of(context).feedbackTitle,
      value: '$count',
      child: Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
