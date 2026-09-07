import 'package:flutter/material.dart';

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
