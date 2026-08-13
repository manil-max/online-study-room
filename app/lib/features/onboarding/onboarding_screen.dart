import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../auth/entry_desktop_layout.dart';
import '../desktop/desktop_page_scaffold.dart';
import '../classroom/widgets/class_switcher.dart';
import 'onboarding_prefs.dart';

/// Masaustu olcum tutamaklari (WP-680): kaynakta `maxWidth: 600` yazmasi kanit
/// degildir, test CIZILEN kutuyu bu anahtarlardan okur.
const String kOnboardingProseKey = 'onboarding-step-prose';

/// WP-151: 4 adımlı atlanabilir onboarding (hoş geldin → bildirim → grup → hazır).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;
  String? _error;

  static const _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(onboardingCompletedProvider.notifier).complete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).authBeklenmeyenBirHataOlustu;
          _busy = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  void _next() {
    if (_page >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _requestNotifications() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ReminderNotificationService.instance.requestPermissionIfNeeded();
      if (mounted) _next();
    } catch (_) {
      // İzin reddi / hata → yine de devam (plan: red OK).
      if (mounted) _next();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(appLanguageProvider.notifier).setLanguage(language);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).authBeklenmeyenBirHataOlustu;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = ref.watch(appLanguageProvider);
    final showLanguageChoice = !hasStoredAppLanguagePreference(
      ref.watch(sharedPreferencesProvider),
    );

    // 🔴 WP-680 / SPEC §2.3 — "Atla" dugmesi pencerenin KOSESINE cakiliydi.
    // `Align(centerEnd)` onu her zaman pencerenin en sagina iter; 2560 px
    // pencerede icerigin sol kenari ile "Atla"nin sag kenari arasi **1565 px**
    // olculdu (WP-671 kapisi, OLCUM 1), izgara tavani 1440 px. Govdenin
    // tamami [DesktopContent] bandina alinir; hicbir eleman kaldirilmaz,
    // yalniz bant icine girer (SPEC §6 "BAGLA, ATMA" + §7).
    final body = Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Semantics(
            button: true,
            label: l10n.onboardingSkip,
            child: TextButton(
              onPressed: _busy ? null : _finish,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.onboardingSkip),
            ),
          ),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _Step(
                icon: Icons.local_fire_department_outlined,
                title: l10n.onboardingWelcomeTitle,
                body: l10n.onboardingWelcomeBody,
                extra: showLanguageChoice
                    ? _LanguageChoice(
                        language: language,
                        enabled: !_busy,
                        onSelected: _selectLanguage,
                      )
                    : null,
              ),
              _Step(
                icon: Icons.notifications_active_outlined,
                title: l10n.onboardingNotifyTitle,
                body: l10n.onboardingNotifyBody,
              ),
              _Step(
                icon: Icons.groups_outlined,
                title: l10n.onboardingGroupTitle,
                body: l10n.onboardingGroupBody,
              ),
              _Step(
                icon: Icons.timer_outlined,
                title: l10n.onboardingReadyTitle,
                body: l10n.onboardingReadyBody,
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pageCount; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        ),
        // 🔴 WP-680 / SPEC §2.3 — birincil dugme PENCEREYI kat ediyordu.
        // Sebep `FilledButton.styleFrom(minimumSize: Size.fromHeight(48))`:
        // `Size.fromHeight` genisligi `double.infinity` yapar, yani dugme
        // kabi ne kadar genisse o kadar genisler. OLCUM (WP-680 testi,
        // dpr=1): 1920 px pencerede **1872 px**, 2560 px'te **2512 px**.
        // Tavan: form sutunu 760 px. Mobilde etkisiz (342 px < 760).
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: isDesktopWindow
              ? EntryFormColumn(child: _actions(context, l10n))
              : _actions(context, l10n),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: isDesktopWindow
            ? DesktopContent(
                maxWidth: DesktopBreakpoints.maxContentWidth,
                padding: EdgeInsets.zero,
                child: body,
              )
            : body,
      ),
    );
  }

  Widget _actions(BuildContext context, AppLocalizations l10n) {
    if (_busy) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return switch (_page) {
      0 => Semantics(
          button: true,
          label: l10n.onboardingContinue,
          child: FilledButton(
            onPressed: _next,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(l10n.onboardingContinue),
          ),
        ),
      1 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: l10n.onboardingAllowNotifications,
              child: FilledButton(
                onPressed: _requestNotifications,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.onboardingAllowNotifications),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: l10n.onboardingNotNow,
              child: TextButton(
                onPressed: _next,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.onboardingNotNow),
              ),
            ),
          ],
        ),
      2 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: l10n.classroomGrupOlustur,
              child: FilledButton(
                onPressed: () async {
                  final ok = await createGroupFlow(context, ref);
                  if (ok && mounted) _next();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.classroomGrupOlustur),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: l10n.classroomGrubaKatil,
              child: OutlinedButton(
                onPressed: () async {
                  final ok = await joinGroupFlow(context, ref);
                  if (ok && mounted) _next();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.classroomGrubaKatil),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: l10n.onboardingSkipGroup,
              child: TextButton(
                onPressed: _next,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.onboardingSkipGroup),
              ),
            ),
          ],
        ),
      _ => Semantics(
          button: true,
          label: l10n.onboardingStart,
          child: FilledButton(
            onPressed: _finish,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(l10n.onboardingStart),
          ),
        ),
    };
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    required this.body,
    this.extra,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 🔴 WP-680 / SPEC §2.3 + §3 A3 — tanitim govdesi prose'dur, tavani 600 px
    // (80 karakter, WCAG 2.1 SC 1.4.8; SPEC §2.1 turetimi). OLCUM (WP-680
    // testi, dpr=1): 1920 px pencerede govde metni **1872 px** = 250 karakter,
    // 2560 px'te **2512 px** = 335 karakter -- tavanin uc-dort kati.
    //
    // Bu ekran SPEC §3 A3'tur, A2 ya da bolunmus duzen DEGIL: bir tanitim
    // adimi ikon + baslik + govdeden olusan **tek** nesnedir; A3'un "birden
    // cok bagimsiz blok tasiyan ekranlar A3 degildir" uyarisi burada
    // tetiklenmez. `AuthScreen` iki blok tasidigi icin bolunur, burasi
    // bolunmez.
    final prose = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (extra != null) ...[const SizedBox(height: 24), extra!],
      ],
    );
    final content = isDesktopWindow
        ? Center(
            child: ConstrainedBox(
              key: const ValueKey(kOnboardingProseKey),
              constraints: const BoxConstraints(
                maxWidth: DesktopBreakpoints.maxProseWidth,
              ),
              child: prose,
            ),
          )
        : prose;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: extra == null
          ? content
          : CustomScrollView(
              slivers: [
                SliverFillRemaining(hasScrollBody: false, child: content),
              ],
            ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.language,
    required this.enabled,
    required this.onSelected,
  });

  final AppLanguage language;
  final bool enabled;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = <(AppLanguage, String)>[
      (AppLanguage.system, l10n.profileDilSistemVarsayilani),
      (AppLanguage.turkish, l10n.profileDilTurkce),
      (AppLanguage.english, l10n.profileDilIngilizce),
    ];

    return Semantics(
      container: true,
      label: l10n.profileUygulamaDili,
      child: Column(
        key: const ValueKey('onboarding-language-choice'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.profileUygulamaDili,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.profileDilDegisikligiAnindaUygulanir,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                Semantics(
                  button: true,
                  selected: language == option.$1,
                  label: option.$2,
                  child: ChoiceChip(
                    key: ValueKey('onboarding-language-${option.$1.name}'),
                    label: Text(option.$2),
                    selected: language == option.$1,
                    onSelected: enabled ? (_) => onSelected(option.$1) : null,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
