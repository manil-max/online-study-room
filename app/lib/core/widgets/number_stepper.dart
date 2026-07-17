import 'dart:async';

import 'package:flutter/material.dart';

/// Etiketli +/- sayaç (saat/dakika gibi sayısal seçimler için). +/- tuşuna
/// **basılı tutunca** sabit hızda artırıp azaltır (tek tek basmamak için).
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            HoldRepeatButton(
              icon: Icons.remove,
              enabled: value > min,
              onStep: () => onChanged((value - 1).clamp(min, max)),
            ),
            Text('$value', style: theme.textTheme.titleLarge),
            HoldRepeatButton(
              icon: Icons.add,
              enabled: value < max,
              onStep: () => onChanged((value + 1).clamp(min, max)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dolgu-tonlu ikon buton: dokununca bir kez, **basılı tutunca** kısa bir
/// gecikmeden sonra sabit hızda tekrar tekrar [onStep] çağırır.
class HoldRepeatButton extends StatefulWidget {
  const HoldRepeatButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onStep,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onStep;

  @override
  State<HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<HoldRepeatButton> {
  Timer? _delay;
  Timer? _repeat;

  void _start() {
    if (!widget.enabled) return;
    widget.onStep(); // ilk dokunuş hemen
    // Basılı tutulursa kısa gecikmeden sonra sabit hızda tekrarla.
    _delay = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (widget.enabled) {
          widget.onStep();
        } else {
          _stop();
        }
      });
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listener (gesture arena dışı) basışı güvenilir yakalar; IconButton yalnız
    // görsel/erişilebilirlik için (onPressed boş — gerçek artış Listener'da).
    return Listener(
      onPointerDown: widget.enabled ? (_) => _start() : null,
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: IconButton.filledTonal(
        onPressed: widget.enabled ? () {} : null,
        icon: Icon(widget.icon),
      ),
    );
  }
}
