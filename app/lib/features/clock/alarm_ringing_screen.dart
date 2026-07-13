import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/time_engine/alarm_scheduler.dart';
import '../../data/models/alarm_rule.dart';

/// Alarm çalarken tam ekran: crescendo haptic + opsiyonel anti-snooze matematik.
class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({
    super.key,
    required this.alarm,
    this.onDismiss,
    this.onSnooze,
  });

  final AlarmRule alarm;
  final VoidCallback? onDismiss;
  final VoidCallback? onSnooze;

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  late final DateTime _started;
  Timer? _tick;
  double _level = 0;
  late final int _a;
  late final int _b;
  final _answerCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _started = DateTime.now();
    final rng = math.Random();
    _a = 10 + rng.nextInt(40);
    _b = 10 + rng.nextInt(40);
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final elapsed = DateTime.now().difference(_started);
      final level = widget.alarm.crescendo
          ? AlarmScheduler.crescendoLevel(elapsed)
          : 1.0;
      if (widget.alarm.vibrate) {
        // Crescendo: düşük seviyede light, yüksekte heavy.
        if (level > 0.7) {
          HapticFeedback.heavyImpact();
        } else if (level > 0.35) {
          HapticFeedback.mediumImpact();
        } else if (level > 0.05) {
          HapticFeedback.lightImpact();
        }
      }
      if (mounted) setState(() => _level = level);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _answerCtrl.dispose();
    super.dispose();
  }

  void _tryDismiss() {
    if (widget.alarm.antiSnooze) {
      final ans = int.tryParse(_answerCtrl.text.trim());
      if (ans != _a + _b) {
        setState(() => _error = 'Yanlış cevap — tekrar dene');
        HapticFeedback.vibrate();
        return;
      }
    }
    widget.onDismiss?.call();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _snooze() {
    if (widget.alarm.antiSnooze) {
      setState(() => _error = 'Erteleme için de soruyu çöz');
      return;
    }
    widget.onSnooze?.call();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.alarm.label.isNotEmpty ? widget.alarm.label : 'Alarm';
    final glow = Color.lerp(
      const Color(0xFF7F1D1D),
      const Color(0xFFEF4444),
      _level,
    )!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                widget.alarm.timeLabel,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  color: glow,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.alarm.crescendo) ...[
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _level,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    color: glow,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ses seviyesi ${(_level * 100).round()}%',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              if (widget.alarm.antiSnooze) ...[
                const SizedBox(height: 36),
                Text(
                  'Kapatmak için çöz: $_a + $_b = ?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _answerCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _tryDismiss(),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _snooze,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size(0, 52),
                      ),
                      child: Text(
                        'Ertele (${widget.alarm.snoozeMinutes} dk)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _tryDismiss,
                      style: FilledButton.styleFrom(
                        backgroundColor: glow,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('Kapat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
