import 'package:flutter/material.dart';

/// WP-460: Alt sekmenin adı zaten alt menüde yazıyor; ekranın tepesinde aynı
/// kelimeyi ikinci kez yazan başlık çubuğu, durum çubuğu payıyla birlikte
/// ~100 px'lik ölü alan üretiyor ve ilk anlamlı içeriği aşağı itiyordu.
///
/// Kural: **başlık tekrar etmez, eylem kaybolmaz.** Sekmede gerçek bir eylem
/// varsa (kart düzenle, grup değiştir) kompakt bir şerit kalır; eylem yoksa
/// çubuk hiç kurulmaz ve gövde üst güvenli alanı kendisi taşır.
const double kTabActionBarHeight = 48;

/// Sekme üstü kompakt eylem şeridi. Eylem yoksa `null` döner; çağıran ekran
/// bu durumda gövdeyi `SafeArea(bottom: false)` ile sarar.
PreferredSizeWidget? buildTabActionBar({
  Widget? leading,
  List<Widget> actions = const [],
  PreferredSizeWidget? bottom,
  double height = kTabActionBarHeight,
}) {
  if (leading == null && actions.isEmpty && bottom == null) return null;
  return AppBar(
    // Başlık yok: sekme adı alt menüde zaten yazılı.
    automaticallyImplyLeading: false,
    toolbarHeight: leading == null && actions.isEmpty ? 0 : height,
    leading: leading,
    actions: actions,
    bottom: bottom,
  );
}
