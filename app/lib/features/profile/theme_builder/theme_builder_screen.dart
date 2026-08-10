import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/desktop/desktop_layout.dart';
import '../../../core/desktop/desktop_window.dart';
import '../../../core/theme/custom_theme.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../core/widgets/safe_screen_padding.dart';
import '../../desktop/desktop_surface.dart';
import 'theme_builder_steps.dart';
import 'theme_builder_widgets.dart';
import 'theme_draft.dart';
import 'theme_preview.dart';

/// Yan yana düzendeki kenar boşluğu / oluk (WinUI: >640 px pencerede 24, panel
/// içi bölme aralığı 16 — mevcut değer korunur, WP-684 yalnız isimlendirdi).
const double kThemeBuilderPaneGutter = 16;

/// Düzenleyici bölmesinin anahtarı — SPEC §2.3 form sütunu tavanını taşıyan
/// kutu. Testler genişliği buradan okur.
const String kThemeBuilderEditorPaneKey = 'theme-builder-editor-pane';

/// WP-290: "Kendi Temanı Oluştur" sihirbazı.
///
/// Eski `ThemeStudioScreen`'in yerine geçer. Yedi adım + karşı mod; her adımda
/// canlı önizleme. Kalıcı yazma yalnız son adımdaki "Kaydet ve uygula" ile
/// yapılır — sihirbaz içinde hiçbir şey `SharedPreferences`'a sızmaz.
class ThemeBuilderScreen extends ConsumerStatefulWidget {
  const ThemeBuilderScreen({super.key, this.initial});

  /// Düzenleme modunda kayıtlı tema; null → yeni tema.
  final CustomTheme? initial;

  @override
  ConsumerState<ThemeBuilderScreen> createState() => _ThemeBuilderScreenState();
}

class _ThemeBuilderScreenState extends ConsumerState<ThemeBuilderScreen> {
  static const _stepCount = 8;

  late ThemeDraft _draft;
  late final TextEditingController _nameController;
  var _step = 0;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial.isDefined) {
      _draft = ThemeDraft.fromCustomTheme(initial);
    } else {
      final settings = ref.read(themeSettingsProvider);
      _draft = ThemeDraft.fromPreset(
        slotId: initial?.id ?? _firstFreeSlot(settings),
        name: '',
        preset: settings.family,
      );
    }
    _nameController = TextEditingController(text: _draft.name);
    // Ad alanı "Kaydet"in etkinliğini ve hata metnini belirler; her tuşta
    // yeniden çizilmezse buton ölü görünür.
    _nameController.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  String _firstFreeSlot(ThemeSettings settings) {
    for (final theme in settings.customThemes) {
      if (!theme.isDefined) return theme.id;
    }
    return settings.customThemes.isEmpty
        ? 'custom_1'
        : settings.customThemes.first.id;
  }

  void _update(ThemeDraft next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier = ref.read(themeSettingsProvider.notifier);

    final draft = _draft.copyWith(name: _nameController.text.trim());
    final saved = await notifier.saveCustomTheme(draft.toCustomTheme());
    if (saved != ThemeSaveResult.saved) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileTemaKaydedilemedi)),
      );
      return;
    }
    final activated = await notifier.setActiveCustomTheme(draft.slotId);
    if (activated != ThemeSaveResult.saved) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileTemaKaydedilemedi)),
      );
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileTemaKaydedildi)));
    if (navigator.canPop()) navigator.pop();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.profileKaydedilmemisDegisiklik),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileDevamEt),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileCik),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Önizleme, o adımda düzenlenen varyantı gösterir.
  Brightness get _previewBrightness =>
      _step == 6 ? _draft.counterpart : _draft.editing;

  String _stepLabel(AppLocalizations l10n, int step) => switch (step) {
    0 => l10n.profileAdimZemin,
    1 => l10n.profileAdimRenkler,
    2 => l10n.profileAdimYazilar,
    3 => l10n.profileAdimBicim,
    4 => l10n.profileAdimAtmosfer,
    5 => l10n.profileAdimHis,
    6 => l10n.profileAdimKarsiMod,
    _ => l10n.profileAdimOzet,
  };

  Widget _stepContent(int columns) {
    final settings = ref.watch(themeSettingsProvider);
    return switch (_step) {
      0 => BaseStep(draft: _draft, onChanged: _update, columns: columns),
      1 => ColorsStep(draft: _draft, onChanged: _update),
      2 => TypographyStep(draft: _draft, onChanged: _update),
      3 => ShapeStep(draft: _draft, onChanged: _update),
      4 => AtmosphereStep(draft: _draft, onChanged: _update),
      5 => FeelStep(draft: _draft, onChanged: _update),
      6 => CounterpartStep(draft: _draft, onChanged: _update),
      _ => SummaryStep(
        draft: _draft,
        onChanged: _update,
        nameController: _nameController,
        slots: {
          for (final theme in settings.customThemes) theme.id: theme.isDefined,
        },
        canSave: _canSave,
        onSave: _save,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = isDesktopWindow;
    // WP-306: klavye yüksekliği **Scaffold'un üstünden** okunur. Gövdenin
    // içinde `resizeToAvoidBottomInset` bu değeri sildiği için orada hep 0
    // görünür ve klavye açık mı kapalı mı ayırt edilemez.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final preview = ThemePreviewCard(
      theme: _draft.themeFor(_previewBrightness),
      label: _previewBrightness == Brightness.dark
          ? l10n.profileKoyu
          : l10n.profileAcik,
      // WP-311: yazı adımında önizleme mini kartlar yerine etiketli yazı
      // örnekleri gösterir — hangi seçim başlığa/gövdeye/sayaca dokunuyor.
      focus: _step == 2 ? ThemePreviewFocus.typography : ThemePreviewFocus.none,
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Navigator await'ten önce alınır: async boşluk sonrası context'e
        // dokunulmaz (use_build_context_synchronously).
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileKendiTemaniOlustur),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_step + 1}/$_stepCount · ${_stepLabel(l10n, _step)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sideBySide = desktop && constraints.maxWidth >= 720;
            // Yan yana düzenin iç ölçüsü: 2×16 yatay kenar boşluğu + 16 oluk.
            final inner = constraints.maxWidth - kThemeBuilderPaneGutter * 3;
            // 🔴 WP-684 ÖLÇÜMÜ (2026-08-10): düzenleyici bölmesi eskiden
            // `Expanded(flex: 5)` idi, yani kabın 5/9'u — **tavansız**.
            // Bugüne kadar görünmedi çünkü kap sabit 920 px'lik paneldi
            // (5/9 × 872 = 484 px). Panel artık pencereyle büyüyor
            // (`desktopPanelWidthFor`) ve 1472 px'lik bantta aynı oran
            // **791 px** veriyordu: SPEC §2.3'ün 760 px'lik form sütununun
            // üstü. Aynı bantta ölçülen en geniş etiket–değer satırı da
            // **603 px** çıkıyordu — SPEC KURAL 2.2'nin 600 px'lik SERT
            // tavanının (WCAG 2.1 SC 1.4.8, 80 karakter) üstü. Yani panelin
            // büyümesi bu ekranda ölçülebilir bir kusur açıyordu; bölme
            // form sütununda durdurulur.
            final editorWidth = inner * 5 / 9 > DesktopBreakpoints.maxFormWidth
                ? DesktopBreakpoints.maxFormWidth
                : inner * 5 / 9;
            final columns = desktopGridColumns(
              sideBySide ? editorWidth : constraints.maxWidth,
              compact: 1,
              medium: 2,
              expanded: 2,
            );
            final content = _stepContent(columns);

            if (!sideBySide) {
              final padding = getSafeVerticalPadding(
                context,
                horizontal: 16,
                vertical: 12,
              );
              // WP-302: önizleme sabit kalır. Eskiden listenin ilk çocuğuydu;
              // seçenekleri denemek için aşağı kaydırınca ekrandan çıkıyor,
              // yani kullanıcı **tam da değiştirdiği şeyi** göremiyordu.
              // Yatay/kısa ekranlarda sabit önizleme içeriğe yer bırakmaz;
              // orada eski kaydırmalı düzene dönülür.
              //
              // WP-306: karar **klavyeden bağımsız** yükseklikle verilir.
              // Ölçüt doğrudan `constraints.maxHeight` iken klavye açılınca
              // gövde küçülüyor, düzen Column→ListView'a atlıyor, ağaç şekli
              // değiştiği için `TextField` sıfırdan kuruluyor ve odağı
              // düşürüyordu: klavye açılıp hemen kapanıyor, ad yazılamıyordu.
              // (Yatayda yükseklik zaten eşiğin altında olduğu için dal
              // değişmiyor — sahibin "yana çevirince yazabildim" gözlemi.)
              if (constraints.maxHeight + keyboard < 480) {
                return ListView(
                  padding: padding,
                  children: [preview, const SizedBox(height: 16), content],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // WP-306: klavye açıkken önizleme gizlenir — ad alanına yer
                  // kalsın. Yerine `SizedBox.shrink()` konur ki Column'un çocuk
                  // sayısı sabit kalsın: aşağıdaki liste hep 1. sırada durur,
                  // elemanı korunur ve odak düşmez.
                  if (keyboard > 0)
                    const SizedBox.shrink()
                  else
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        padding.top,
                        padding.right,
                        12,
                      ),
                      child: preview,
                    ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        0,
                        padding.right,
                        padding.bottom,
                      ),
                      children: [content],
                    ),
                  ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                kThemeBuilderPaneGutter,
                12,
                kThemeBuilderPaneGutter,
                8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    // 🔴 Anahtar `SizedBox`ta, içindeki `ListView`da değil:
                    // ölçülecek şey tavanı taşıyan kutudur. Kabı dolduran bir
                    // sarmalayıcıyı ölçmek tavanı değil kabı ölçerdi.
                    key: const Key(kThemeBuilderEditorPaneKey),
                    width: editorWidth,
                    child: ListView(children: [content]),
                  ),
                  const SizedBox(width: kThemeBuilderPaneGutter),
                  // Önizleme kalan yeri alır. Tavanı YOK: SPEC §3 A4 —
                  // sabit en-boy oranlı görsel sahne genişledikçe bozulmaz,
                  // iyileşir. Panelin kendi tavanı (1472) zaten üst sınırdır.
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: preview,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepDots(
                  count: _stepCount,
                  current: _step,
                  onSelect: (value) => setState(() => _step = value),
                ),
                Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        child: Text(l10n.profileGeri),
                      ),
                    const Spacer(),
                    if (_step < _stepCount - 1)
                      FilledButton(
                        onPressed: () => setState(() => _step++),
                        child: Text(l10n.profileIleri),
                      )
                    else
                      FilledButton(
                        onPressed: _canSave ? _save : null,
                        child: Text(l10n.profileBitir),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
