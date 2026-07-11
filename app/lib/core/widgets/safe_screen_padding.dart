import 'package:flutter/material.dart';

/// Ekranların alt kısmındaki liste veya içeriklerin, Android 3 tuşlu navigasyon
/// (system navigation bar) altında kalmasını önlemek için güvenli alt boşluk hesaplar.
/// 
/// Klavye açıkken `MediaQuery.paddingOf(context).bottom` 0'a düşer (çünkü
/// viewInsets devreye girer), böylece Scaffold'un `resizeToAvoidBottomInset` 
/// özelliğiyle çakışmadan çift boşluk (double padding) oluşumunu engeller.
EdgeInsets getSafeBottomPadding(BuildContext context, {double base = 16.0}) {
  final bottomSafe = MediaQuery.paddingOf(context).bottom;
  return EdgeInsets.fromLTRB(base, base, base, base + bottomSafe);
}

/// Yalnızca dikey eksende alt padding'e safe area ekler.
EdgeInsets getSafeVerticalPadding(BuildContext context, {double horizontal = 16.0, double vertical = 16.0}) {
  final bottomSafe = MediaQuery.paddingOf(context).bottom;
  return EdgeInsets.fromLTRB(horizontal, vertical, horizontal, vertical + bottomSafe);
}

/// Verilen `base` padding'in altına güvenli alanı ekler.
EdgeInsets getSafePadding(BuildContext context, EdgeInsets base) {
  final bottomSafe = MediaQuery.paddingOf(context).bottom;
  return base.copyWith(bottom: base.bottom + bottomSafe);
}
