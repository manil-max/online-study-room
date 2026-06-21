import 'package:flutter/material.dart';

/// Tetikleyici widget'ın konumunda açılan menü — alttan açılan pencere (bottom
/// sheet) yerine **basılan yerde** açılır (Claude Code model seçici gibi).
///
/// Bu, "açılır seçim" gerektiren çoğu yer için tercih edilen kalıptır (§3.12).
/// [context], tetikleyici widget'ın build context'i olmalı (menü ona göre konumlanır).
Future<T?> showAnchoredMenu<T>({
  required BuildContext context,
  required List<PopupMenuEntry<T>> items,
}) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final box = context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );
  return showMenu<T>(context: context, position: position, items: items);
}

/// Belirli bir **küresel noktada** açar (ör. basılı-tut konumu). Sabit küçük bir
/// hedef kutusu kullanır; menü bu noktanın yakınında belirir.
Future<T?> showMenuAtPosition<T>({
  required BuildContext context,
  required Offset globalPosition,
  required List<PopupMenuEntry<T>> items,
}) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    globalPosition & const Size(40, 40),
    Offset.zero & overlay.size,
  );
  return showMenu<T>(context: context, position: position, items: items);
}
