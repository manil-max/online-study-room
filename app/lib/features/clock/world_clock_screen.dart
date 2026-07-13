import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/time_engine/world_clock_math.dart';
import '../../data/providers/alarm_providers.dart';

class WorldClockScreen extends ConsumerStatefulWidget {
  const WorldClockScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends ConsumerState<WorldClockScreen> {
  Timer? _tick;
  DateTime _now = DateTime.now();
  static bool _tzReady = false;

  @override
  void initState() {
    super.initState();
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(worldCitiesProvider);
    final theme = Theme.of(context);

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Dünya saatleri',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Şehir ekle',
                onPressed: () => _addCity(context),
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: cities.isEmpty
              ? const Center(child: Text('Şehir ekle'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: cities.length,
                  itemBuilder: (context, index) {
                    final c = cities[index];
                    WorldClockReading reading;
                    try {
                      reading = readWorldClock(
                        cityLabel: c.label,
                        timeZoneId: c.tz,
                        homeNow: _now,
                        location: tz.getLocation(c.tz),
                      );
                    } catch (_) {
                      reading = WorldClockReading(
                        cityLabel: c.label,
                        timeZoneId: c.tz,
                        localTime: _now,
                        isDaytime: true,
                        offsetLabel: 'TZ bilinmiyor',
                        dayLabel: '—',
                      );
                    }
                    return _CityCard(
                      reading: reading,
                      onDelete: () => ref
                          .read(worldCitiesProvider.notifier)
                          .remove(c.tz),
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Dünya Saati')),
      body: body,
    );
  }

  Future<void> _addCity(BuildContext context) async {
    final selected = await showModalBottomSheet<({String label, String tz})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, scroll) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Şehir seç',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    itemCount: kWorldCityCatalog.length,
                    itemBuilder: (_, i) {
                      final item = kWorldCityCatalog[i];
                      return ListTile(
                        title: Text(item.label),
                        subtitle: Text(item.tz),
                        onTap: () => Navigator.pop(
                          ctx,
                          (label: item.label, tz: item.tz),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected != null) {
      await ref
          .read(worldCitiesProvider.notifier)
          .add(selected.label, selected.tz);
    }
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.reading, required this.onDelete});

  final WorldClockReading reading;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDay = reading.isDaytime;
    final bg = isDay
        ? const LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFFBAE6FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final fg = isDay ? const Color(0xFF0C4A6E) : Colors.white;

    final timeStr = DateFormat.Hm().format(reading.localTime);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          reading.cityLabel,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          '${reading.offsetLabel} · ${isDay ? 'Gündüz' : 'Gece'}',
          style: TextStyle(color: fg.withValues(alpha: 0.8)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeStr,
              style: TextStyle(
                color: fg,
                fontSize: 28,
                fontWeight: FontWeight.w300,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.close, color: fg.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
