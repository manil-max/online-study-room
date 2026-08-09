import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../data/models/report_target.dart';
import 'block_user_action.dart';
import 'report_sheet.dart';

/// WP-617: "bildir / engelle" ikilisinin **tek** gorunum kaynagi.
///
/// 🔴 Neden ortak: bu iki eylem daha once yalniz sohbet baloncugunda vardi
/// (`class_chat_card.dart` icinde `private`). Sonuc: rahatsiz eden kisiyi
/// engellemek icin onun MESAJ YAZMASINI beklemek gerekiyordu — kamp atesinde
/// ve uye listesinde hicbir yol yoktu. Kopyalanarak cogaltilsaydi WP-446'nin
/// kazanimi (her iki eylemin **kapsami** ekranda yazili; kullanici hangisinin
/// karsi tarafa gittigini tahmin etmek zorunda degil) yalniz bir yuzeyde
/// kalirdi.
///
/// Google Play, kullanici uretimi icerik barindiran uygulamalarda rahatsiz
/// edici kullaniciyi **bildirme ve engelleme** yolu ister; bu yuzden yol
/// sayisi kozmetik degil.
List<Widget> peerSafetyTiles(
  BuildContext context, {
  required VoidCallback onReport,
  required VoidCallback onBlock,
}) {
  final l10n = AppLocalizations.of(context);
  return [
    // WP-446: iki eylem birbirine benziyor ama kapsamlari taban tabana zit —
    // biri yoneticiye gider, digeri yalniz bu hesabin gorunumunu degistirir.
    // Alt satir bu ayrimi ekranda soyler.
    ListTile(
      key: const ValueKey('peer-safety-report'),
      leading: const Icon(Icons.flag_outlined),
      title: Text(l10n.safetyReport),
      subtitle: Text(l10n.safetyReportKapsam),
      isThreeLine: false,
      onTap: onReport,
    ),
    ListTile(
      key: const ValueKey('peer-safety-block'),
      leading: const Icon(Icons.block),
      title: Text(l10n.safetyBlock),
      subtitle: Text(l10n.safetyBlockKapsam),
      isThreeLine: false,
      onTap: onBlock,
    ),
  ];
}

/// Bildir/engelle alt sayfasi.
///
/// 🔴 Alt sayfa secimden **once** kapatilir: SnackBar'i cizen `Scaffold` modal
/// rotanin altinda kalir, yani sayfa kapanmadan gosterilen "kullanici
/// engellendi" mesaji hic gorunmez.
Future<void> showPeerSafetyActions(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required ReportTarget reportTarget,
}) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: peerSafetyTiles(
            ctx,
            onReport: () => Navigator.pop(ctx, 'report'),
            onBlock: () => Navigator.pop(ctx, 'block'),
          ),
        ),
      );
    },
  );
  if (!context.mounted || selected == null) return;

  if (selected == 'report') {
    await showReportSheet(context, ref, target: reportTarget);
    return;
  }

  if (selected == 'block') {
    await confirmAndBlockUser(context, ref, userId: userId);
  }
}
