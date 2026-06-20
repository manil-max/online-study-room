import 'package:flutter/material.dart';

/// İstatistik sekmesi: kişisel + sınıf (ortak) istatistikler. Bkz. project.md §3.4.
/// Şimdilik yer tutucu — grafikler ve veriler Faz 3'te gelecek.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistik')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('İstatistikler', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Kişisel ve sınıf istatistikleri burada olacak.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
