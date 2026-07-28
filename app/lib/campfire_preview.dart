import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'data/models/presence.dart';
import 'data/models/profile.dart';
import 'data/providers/group_providers.dart';
import 'data/providers/moderation_providers.dart';
import 'data/providers/presence_providers.dart';
import 'data/providers/study_providers.dart';
import 'features/classroom/widgets/campfire_layout.dart';
import 'features/classroom/widgets/campfire_scene.dart';

/// WP-416 — kamp ateşinin **mobil** parametrik önizlemesi.
///
/// `lib/wp295_preview.dart` masaüstü kompozisyonunu kendi çizimiyle taklit
/// ediyordu; burada ise **gerçek** [CampfireScene] çizilir. Sahip hangi sayıyı
/// seçerse üretimde göreceği kare birebir odur — önizleme ile sahne arasında
/// ayrışacak ikinci bir uygulama yok.
///
/// Çalıştırma (telefon takılıyken):
/// `flutter run -t lib/campfire_preview.dart --dart-define-from-file=env/local.json`
void main() => runApp(buildCampfirePreviewApp());

/// Test ve cihaz önizlemesi için ortak kabuk.
Widget buildCampfirePreviewApp({Locale? locale}) =>
    _CampfirePreviewApp(locale: locale);

class _CampfirePreviewApp extends StatelessWidget {
  const _CampfirePreviewApp({this.locale});

  final Locale? locale;

  static const _names = [
    'Ada',
    'Bora',
    'Cem',
    'Duru',
    'Ece',
    'Kaan',
    'Lale',
    'Hale',
  ];
  static const _animals = ['rabbit', 'fox', 'bear', 'cat'];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Önizlemenin amacı **telefon** kompozisyonu; masaüstünde açılsa bile
      // profil telefon seçilsin diye platform sabitlenir.
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        platform: TargetPlatform.android,
      ),
      home: const _PreviewScreen(),
    );
  }

  static List<Profile> members(int count) => [
    for (var index = 0; index < count; index++)
      Profile(
        id: 'u$index',
        displayName: _names[index % _names.length],
        animal: _animals[index % _animals.length],
        createdAt: DateTime(2026, 1, 1),
      ),
  ];
}

class _PreviewScreen extends StatefulWidget {
  const _PreviewScreen();

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen> {
  static const _canonical = CampfireTuning(
    greenAreaHeight: kCampfirePhoneGreenAreaHeight,
    ringDropPixels: kCampfirePhoneRingDropPixels,
  );

  var _memberCount = 8;
  var _workingCount = 3;
  var _tuning = _canonical;

  double get _greenArea =>
      _tuning.greenAreaHeight ?? kCampfirePhoneGreenAreaHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = _CampfirePreviewApp.members(_memberCount);

    return ProviderScope(
      overrides: [
        groupMembersProvider.overrideWith((ref) => Stream.value(members)),
        groupPresenceProvider.overrideWith(
          (ref) => Stream.value([
            for (var index = 0; index < members.length; index++)
              Presence(
                userId: members[index].id,
                status: index < _workingCount
                    ? PresenceStatus.studying
                    : PresenceStatus.offline,
                todaySeconds: index < _workingCount ? 900 : 0,
                startedAt: index < _workingCount
                    ? DateTime.now().subtract(const Duration(minutes: 7))
                    : null,
              ),
          ]),
        ),
        groupTodaySecondsProvider.overrideWithValue({
          for (final member in members) member.id: 900,
        }),
        blockedUserIdsProvider.overrideWith((ref) async => <String>{}),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.campfirePreviewTitle)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: CampfireScene(tuning: _tuning),
                ),
              ),
            ),
            Expanded(child: _controls(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _controls(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(l10n.wp295PreviewMemberCount),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var count = 1; count <= 8; count++)
                ChoiceChip(
                  key: ValueKey('member-count-$count'),
                  label: Text('$count'),
                  selected: _memberCount == count,
                  onSelected: (_) => setState(() {
                    _memberCount = count;
                    if (_workingCount > count) _workingCount = count;
                  }),
                ),
            ],
          ),
        ),
        _slider(
          key: 'working-count',
          label: l10n.wp295PreviewWorkingMember,
          value: _workingCount.toDouble(),
          min: 0,
          max: _memberCount.toDouble(),
          divisions: _memberCount,
          fractionDigits: 0,
          onChanged: (value) => setState(() => _workingCount = value.round()),
        ),
        const Divider(height: 24),
        _slider(
          key: 'green-area',
          label: l10n.campfirePreviewGreenArea,
          value: _greenArea,
          min: 60,
          max: 200,
          fractionDigits: 0,
          onChanged: (value) => setState(
            () => _tuning = _tuning.copyWith(greenAreaHeight: value),
          ),
        ),
        _slider(
          key: 'ring-drop',
          label: l10n.campfirePreviewRingDrop,
          value: _tuning.ringDropPixels ?? kCampfirePhoneRingDropPixels,
          min: 0,
          max: 70,
          fractionDigits: 0,
          onChanged: (value) =>
              setState(() => _tuning = _tuning.copyWith(ringDropPixels: value)),
        ),
        _slider(
          key: 'label-font',
          label: l10n.campfirePreviewNameFontSize,
          value: _tuning.labelFontSize,
          min: 8,
          max: 18,
          fractionDigits: 1,
          onChanged: (value) =>
              setState(() => _tuning = _tuning.copyWith(labelFontSize: value)),
        ),
        _slider(
          key: 'seat-spread',
          label: l10n.campfirePreviewRowSpacing,
          value: _tuning.seatVerticalSpread,
          min: 0.6,
          max: 2,
          fractionDigits: 2,
          onChanged: (value) => setState(
            () => _tuning = _tuning.copyWith(seatVerticalSpread: value),
          ),
        ),
        _slider(
          key: 'critter-scale',
          label: l10n.campfirePreviewAnimalSize,
          value: _tuning.critterScale,
          min: 0.6,
          max: 1.6,
          fractionDigits: 2,
          onChanged: (value) =>
              setState(() => _tuning = _tuning.copyWith(critterScale: value)),
        ),
        const Divider(height: 24),
        Text(l10n.campfirePreviewHint),
        const SizedBox(height: 8),
        // Sahip bu satırı olduğu gibi kopyalayıp gönderir; sayılar teste
        // buradan sabit değer olarak geçer.
        SelectableText(
          'greenArea=${_greenArea.toStringAsFixed(0)} · '
          'ringDrop=${(_tuning.ringDropPixels ?? kCampfirePhoneRingDropPixels).toStringAsFixed(0)} · '
          'labelFont=${_tuning.labelFontSize.toStringAsFixed(1)} · '
          'seatSpread=${_tuning.seatVerticalSpread.toStringAsFixed(2)} · '
          'critterScale=${_tuning.critterScale.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('reset-tuning'),
          onPressed: () => setState(() => _tuning = _canonical),
          child: Text(l10n.campfirePreviewReset),
        ),
      ],
    );
  }

  Widget _slider({
    required String key,
    required String label,
    required double value,
    required double min,
    required double max,
    required int fractionDigits,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(fractionDigits)}'),
          Slider(
            key: ValueKey(key),
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
