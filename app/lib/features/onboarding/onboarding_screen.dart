import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/notifications/reminder_notification_service.dart';
import '../classroom/widgets/class_switcher.dart';
import 'onboarding_prefs.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _actions(context, l10n),
            ),
          ],
        ),
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
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
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
        ],
      ),
    );
  }
}
