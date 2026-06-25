import 'dart:async';

import 'package:flutter/widgets.dart';

/// Saniyede bir kendini (yalnızca kendini) yeniden çizen küçük yardımcı.
///
/// Canlı geçen-süre metinlerinde, üst widget'ı her saniye `setState` ile
/// yeniden kurmak (liste sıralama + tüm satırları yeniden inşa) yerine
/// **sadece** süreyi gösteren yaprağı tikletmek için kullanılır. Böylece
/// 1Hz rebuild işi tüm listeden tek bir `Text`'e iner.
class SecondTicker extends StatefulWidget {
  const SecondTicker({super.key, required this.builder});

  /// Her tikte güncel `now` ile çağrılır.
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<SecondTicker> createState() => _SecondTickerState();
}

class _SecondTickerState extends State<SecondTicker> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
