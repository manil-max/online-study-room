import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'account_purge_health_providers.dart';

/// WP-E (`docs/design/ADMIN-PANEL-PLAN.md` §5 WP-E) — hesap silme kuyrugunun
/// saglik karti.
///
/// 🔴 Varlik sebebi: `get_account_purge_health` `0113`ten beri sunucuda
/// duruyordu ama `app/lib/` icinde adi HIC gecmiyordu. Kuyruk tikansa
/// (kilitli lease, tukenmis deneme sayaci, hic yazilmamis runtime config)
/// kimsenin haberi olmuyordu ve kullanicinin "hesabimi sil" istegi sessizce
/// oluyordu.
///
/// 🔴 Kartin en onemli karari [AccountPurgeHealth.level] icindedir:
/// **yapilandirilmamis bir kuyruk sifir hata uretir ve "saglikli" gorunur**
/// (`0113:295`, `production-purge-activation.yml:15`). Bu yuzden kart once
/// "yapilandirma yazili mi" sorusunu sorar, sonra sayaclara bakar. Okunamayan
/// saglik da bos durum degil ARIZA olarak cizilir: "sorulamadi" ile "sorun
/// yok" ayni sey degildir.
const Key kAdminPurgeHealthPanelKey = Key('admin-purge-health-panel');

/// Kartin tek cumlelik durum satiri — renginin kaynagi budur.
const Key kAdminPurgeHealthStatusKey = Key('admin-purge-health-status');

/// Bir saatin altindaki bekleme dakika, ustundeki saat olarak yazilir.
const int kAccountPurgeMinuteCeilingSeconds = 3600;

class AccountPurgeHealthPanel extends ConsumerWidget {
  const AccountPurgeHealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final health = ref.watch(accountPurgeHealthProvider);

    return Card(
      key: kAdminPurgeHealthPanelKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.adminPurgeKuyrukBasligi,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.adminPurgeYenile,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(accountPurgeHealthProvider),
                ),
              ],
            ),
            const SizedBox(height: 8),
            health.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              // 🔴 Okunamayan saglik SAGLIKLI DEGILDIR. Hata dali da ayni
              // durum satirini cizer ki renk iddiasi tek yerden olculsun.
              error: (error, _) => _StatusBlock(
                color: theme.colorScheme.error,
                icon: Icons.help_outline,
                title: l10n.adminPurgeSaglikOkunamadi,
                detail: error is AdminException
                    ? error.message
                    : error.toString(),
              ),
              data: (value) => _HealthBody(health: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthBody extends StatelessWidget {
  const _HealthBody({required this.health});

  final AccountPurgeHealth health;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (color, icon, title, detail) = switch (health.level) {
      AccountPurgeHealthLevel.healthy => (
        scheme.primary,
        Icons.check_circle_outline,
        l10n.adminPurgeDurumSaglikli,
        l10n.adminPurgeSaglikliAciklama,
      ),
      // Yapilandirilmamis kuyruk hic silmiyor demektir; ciddiyeti arizayla
      // aynidir, ama metni AYRIDIR: sebep farkli, cozum farkli.
      AccountPurgeHealthLevel.notConfigured => (
        scheme.error,
        Icons.settings_suggest_outlined,
        l10n.adminPurgeDurumYapilandirilmamis,
        l10n.adminPurgeYapilandirilmamisAciklama,
      ),
      AccountPurgeHealthLevel.failing => (
        scheme.error,
        Icons.error_outline,
        l10n.adminPurgeDurumBozuk,
        l10n.adminPurgeBozukAciklama,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusBlock(color: color, icon: icon, title: title, detail: detail),
        const SizedBox(height: 12),
        _MetricRow(
          label: l10n.adminPurgeBekleyen,
          value: health.dueCount.toString(),
        ),
        _MetricRow(
          label: l10n.adminPurgeIsleniyor,
          value: health.processingCount.toString(),
        ),
        _MetricRow(
          label: l10n.adminPurgeKilitliKalan,
          value: health.staleLeaseCount.toString(),
          alert: health.staleLeaseCount > 0,
        ),
        _MetricRow(
          label: l10n.adminPurgeKaliciHata,
          value: health.terminalFailedCount.toString(),
          alert: health.terminalFailedCount > 0,
        ),
        _MetricRow(
          label: l10n.adminPurgeEnEskiBekleme,
          value: formatPurgeWait(l10n, health.oldestDueAgeSeconds),
          alert:
              health.oldestDueAgeSeconds >
              AccountPurgeHealth.backlogToleranceSeconds,
        ),
        _MetricRow(
          label: l10n.adminPurgeSonOtuzGun,
          value: health.purgedLast30d.toString(),
        ),
      ],
    );
  }
}

/// Bekleme suresinin okunur hali. Bir saatin altinda dakika, ustunde saat.
String formatPurgeWait(AppLocalizations l10n, int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  if (safe < kAccountPurgeMinuteCeilingSeconds) {
    return l10n.adminPurgeDakika(safe ~/ 60);
  }
  return l10n.adminPurgeSaat(safe ~/ kAccountPurgeMinuteCeilingSeconds);
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                key: kAdminPurgeHealthStatusKey,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(detail, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.alert = false,
  });

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = alert ? theme.colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
