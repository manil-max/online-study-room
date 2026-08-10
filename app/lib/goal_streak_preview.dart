// WP-657 — seri rozeti ÖNİZLEMESİ (sahip onayı bekliyor).
//
// 🔴 Bu depoda kural: görsel işte ilk çıktı kod değil, **önizleme**dir. Sahip
// bakar, sayıyı/rengi seçer, seçilen değer teste bağlanır (`campfire_preview`
// deseni).
//
// Çalıştırma:
//   cd app && flutter run -t lib/goal_streak_preview.dart -d windows
//
// Ekranda dört durum × tüm hazır temalar yan yana durur; üstteki sekmeden tema
// değiştirilir. Görülmesi gereken şey, sahibin V64'te bildirdiği iki madde:
//   * "işaret soluk ama tam belli olmuyor; gri renk daha güzel olur"
//   * "pause modu da var mı bilmiyorum, hiç deneyimleme fırsatım olmadı"
//
// Duraklatma (pause) rozeti burada **görülebilir**: gerçek uygulamada yalnız
// "dün kaçırdın, önceki gün tutturmuştun" gününde belirir, yani sahip onu bir
// yıl kullanıp hiç görmeyebilir.
import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'data/models/goal_streak.dart';
import 'features/stats/widgets/goal_streak_flame.dart';

void main() => runApp(buildGoalStreakPreviewApp());

Widget buildGoalStreakPreviewApp({Locale? locale}) =>
    _GoalStreakPreviewApp(locale: locale);

/// Sahibin gördüğü sırayla: sıfır → duraklatma → bugün bekliyor → tamamlandı.
const _rows = <(String, GoalStreakState, int)>[
  ('1. Seri yok / sıfırlanmış — gri alev + 0', GoalStreakState.empty, 0),
  ('2. DURAKLAMADA — pause işareti (dün kaçtı)', GoalStreakState.atRisk, 12),
  (
    '   Bugün henüz tamamlanmadı — gri, içi boş alev',
    GoalStreakState.pendingToday,
    12,
  ),
  ('3. Bugünün hedefi tamam — canlı ateş', GoalStreakState.completedToday, 13),
];

const _personal = GoalStreakScope.personal('preview-user');
const _group = GoalStreakScope.group(
  groupId: 'preview-group',
  timeZone: 'Europe/Istanbul',
);

GoalStreakProjection _projection(
  GoalStreakState state,
  int streak,
  GoalStreakScope scope,
) => GoalStreakProjection(
  scope: scope,
  asOfDay: DateTime.utc(2026, 8, 10),
  currentStreak: streak,
  completionCount: streak,
  state: state,
  sourceVersion: 'preview',
);

class _GoalStreakPreviewApp extends StatefulWidget {
  const _GoalStreakPreviewApp({this.locale});

  final Locale? locale;

  @override
  State<_GoalStreakPreviewApp> createState() => _GoalStreakPreviewAppState();
}

class _GoalStreakPreviewAppState extends State<_GoalStreakPreviewApp> {
  var _presetIndex = 0;

  @override
  Widget build(BuildContext context) {
    final preset = kThemePresets[_presetIndex];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: widget.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.fromPreset(preset),
      home: _PreviewScreen(
        presetId: preset.id,
        presetIndex: _presetIndex,
        onPreset: (index) => setState(() => _presetIndex = index),
      ),
    );
  }
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen({
    required this.presetId,
    required this.presetIndex,
    required this.onPreset,
  });

  final String presetId;
  final int presetIndex;
  final ValueChanged<int> onPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Seri rozeti — $presetId')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tema seçici: "her temada ayırt edilebilir mi" sorusu tek temaya
          // bakarak cevaplanamaz (v49 dersi: kırmızı rozet kırmızı temada
          // kaybolur).
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < kThemePresets.length; i++)
                ChoiceChip(
                  label: Text(kThemePresets[i].id),
                  selected: i == presetIndex,
                  onSelected: (_) => onPreset(i),
                ),
            ],
          ),
          const SizedBox(height: 24),
          for (final (label, state, streak) in _rows) ...[
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Kişisel (yuvarlak çerçeve) ve grup (köşeli) yan yana:
                    // sahip "grup serisi de günlük serisi de o şekilde olsun"
                    // dedi, ikisi de aynı üç durumu üretiyor.
                    GoalStreakFlame(
                      projection: _projection(state, streak, _personal),
                    ),
                    const SizedBox(width: 16),
                    GoalStreakFlame(
                      projection: _projection(state, streak, _group),
                    ),
                    const SizedBox(width: 24),
                    GoalStreakFlame(
                      projection: _projection(state, streak, _personal),
                      size: GoalStreakFlameSize.compact,
                    ),
                    const SizedBox(width: 8),
                    GoalStreakFlame(
                      projection: _projection(state, streak, _group),
                      size: GoalStreakFlameSize.compact,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 8),
          Text(
            'Soldan sağa: kişisel (yuvarlak) · grup (köşeli) · aynı ikisi '
            'küçük boyda. Kart yüzeyi gerçek uygulamadaki yüzeydir.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
