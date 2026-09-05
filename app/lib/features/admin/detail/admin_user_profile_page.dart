import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/theme/theme_tokens.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/data/models/admin_user_insight.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../sanctions/admin_sanction_actions.dart';
import '../sanctions/sanction_ladder.dart';

/// Panelin govdesi (kaydirilan liste).
const Key kAdminUserProfileKey = Key('admin-user-profile');

/// Oran blogu — **en ustte** durur.
const Key kAdminUserRatiosKey = Key('admin-user-ratios');

/// Hesap blogu: acilis, yas, son gorulme, e-posta, kimlik.
const Key kAdminUserAccountKey = Key('admin-user-account');

/// Ceza gecmisi blogu.
const Key kAdminUserSanctionsKey = Key('admin-user-sanctions');

/// Alttaki tek sabit dugme.
const Key kAdminUserSanctionApplyKey = Key('admin-user-sanction-apply');

/// Olcum cubugunun **yatagi** (tam genislik).
Key adminUserRatioTrackKey(String slot) => Key('admin-user-ratio-track-$slot');

/// Olcum cubugunun **dolusu**. Genisligi yatagin `haklı/toplam` katidir; test
/// oran iddiasini buradan olcer, saglayicidan degil.
Key adminUserRatioFillKey(String slot) => Key('admin-user-ratio-fill-$slot');

/// Hakkinda acilan sikayet yonu.
const String kAdminUserRatioAgainst = 'against';

/// Kendi actigi sikayet yonu.
const String kAdminUserRatioFiled = 'filed';

/// WP-776 — bir kisinin **moderasyon profili**: oranlar, hesap, kullanim, ceza
/// gecmisi ve yaptirim yolu tek panelde.
///
/// Sahip: *"basinca detayli profil ekrani acilsin, hesap acma tarihi vs vs gibi
/// ayri bir panelde her seyi gorebileyim... cok sikayet ettiklerini / sikayet
/// edildiklerini ve en ustte de oranlari, aldigi cezalar tarihler gibi cok
/// detayli bir sey istiyorum."*
///
/// 🔴 Yaptirim artik **yalniz burada**. Ayni yol vaka sayfasinda da duruyordu;
/// iki yuzey ayni isi yapinca hangisinin kaydi yazdigi belirsizlesiyordu.
/// Kisiyi kisitlama karari, oranlarini ve ceza gecmisini goren ekranda verilir.
Future<void> openAdminUserProfile(
  BuildContext context, {
  required String userId,
  String? displayName,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          AdminUserProfilePage(userId: userId, displayName: displayName),
    ),
  );
}

class AdminUserProfilePage extends ConsumerWidget {
  const AdminUserProfilePage({
    super.key,
    required this.userId,
    this.displayName,
  });

  final String userId;

  /// Cagiran yuzeyin bildigi ad (vaka karti gibi). Dosya cozulunce sunucudaki
  /// ad kazanir; boylece baslik yuklenirken de bos kalmaz.
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final insight = ref.watch(adminUserInsightProvider(userId));
    final data = insight.value;

    final name = _firstNonEmpty([
      data?.displayName,
      displayName,
    ], fallback: l10n.adminUserProfileTitle);
    final email = (data?.email ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        // 🔴 Alt serit `Scaffold.bottomSheet` DEGIL: o govdeyi orter, yer
        // ayirmaz. Sabit serit Column + Expanded ile kurulur.
        child: Column(
          children: [
            Expanded(
              child: insight.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                // Hata sessiz yutulmaz: bos panel "veri yok" gibi okunurdu.
                error: (_, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.adminUserProfileLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (value) =>
                    _ProfileBody(insight: value, name: name, userId: userId),
              ),
            ),
            _SanctionBar(
              targetUserId: userId,
              // Kalici yasak teyidi e-postayi yazdirir; e-posta yoksa kimlik.
              confirmationPhrase: email.isEmpty ? userId : email,
              // Silinmis hesaba yaptirim olu anahtardir.
              enabled: !(data?.isDeleted ?? false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.insight,
    required this.name,
    required this.userId,
  });

  final AdminUserInsight insight;
  final String name;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ageDays = insight.accountAgeDays();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // SPEC §3: form sutunu tavani 760.
        constraints: const BoxConstraints(
          maxWidth: DesktopBreakpoints.maxFormWidth,
        ),
        child: ListView(
          key: kAdminUserProfileKey,
          padding: const EdgeInsets.all(16),
          children: [
            // 1) Ad + hesap yasi.
            Row(
              children: [
                CircleAvatar(radius: 23, child: Text(_initials(name))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      if (ageDays != null)
                        Text(
                          l10n.adminUserProfileAccountAge(ageDays),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2) Oranlar — en ustte, cunku ham sayi tek basina karar verdirmez.
            _RatiosBlock(insight: insight),
            const SizedBox(height: 20),

            // 3) Hesap.
            _AccountBlock(insight: insight, userId: userId),
            const SizedBox(height: 20),

            // 4) Kullanim.
            _UsageBlock(insight: insight),
            const SizedBox(height: 20),

            // 5) Ceza gecmisi.
            _SanctionHistoryBlock(userId: userId),
          ],
        ),
      ),
    );
  }
}

class _RatiosBlock extends StatelessWidget {
  const _RatiosBlock({required this.insight});

  final AdminUserInsight insight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Column(
      key: kAdminUserRatiosKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(context, l10n.adminUserProfileRatiosTitle),
        if (insight.isDeleted)
          Text(
            l10n.adminUserProfileDeleted,
            style: theme.textTheme.bodyMedium,
          )
        else ...[
          _RatioMeter(
            slot: kAdminUserRatioAgainst,
            label: l10n.adminUserProfileAgainstLabel,
            upheld: insight.reportsAgainstUpheld,
            total: insight.reportsAgainst,
            ratio: insight.upheldAgainstRatio,
            note: l10n.adminUserProfileAgainstNote(
              insight.reportsAgainstUpheld,
              insight.reportsAgainst,
            ),
            emptyNote: l10n.adminUserProfileNoReportsAgainst,
            // 🔴 Renk ANLAMA gore: bu yonde yuksek oran kotu isarettir.
            barColor: colors.error,
          ),
          _RatioMeter(
            slot: kAdminUserRatioFiled,
            label: l10n.adminUserProfileFiledLabel,
            upheld: insight.reportsFiledUpheld,
            total: insight.reportsFiled,
            ratio: insight.upheldFiledRatio,
            note: l10n.adminUserProfileFiledNote(
              insight.reportsFiledUpheld,
              insight.reportsFiled,
            ),
            emptyNote: l10n.adminUserProfileNoReportsFiled,
            // 🔴 ...bu yonde yuksek oran guvenilir sikayetci demektir. Ikisine
            // ayni rengi vermek iki blogu ayirt edilemez kilar.
            barColor: colors.success,
          ),
        ],
      ],
    );
  }
}

/// Tek olcum cubugu: "hakli / toplam" sayisi, cubuk ve tek cumlelik aciklama.
class _RatioMeter extends StatelessWidget {
  const _RatioMeter({
    required this.slot,
    required this.label,
    required this.upheld,
    required this.total,
    required this.ratio,
    required this.note,
    required this.emptyNote,
    required this.barColor,
  });

  final String slot;
  final String label;
  final int upheld;
  final int total;

  /// `null` = hic sikayet yok. `0.0` ile ayni sey DEGILDIR.
  final double? ratio;

  final String note;
  final String emptyNote;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = ratio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text('$upheld/$total', style: theme.textTheme.titleMedium),
              ],
            ],
          ),
          // 🔴 Oran `null` ise cubuk CIZILMEZ. Sifir genislikte bir cubuk
          // cizmek "hic sikayet edilmemis" ile "bes kez edilmis, hicbiri
          // tutmamis" kullaniciyi ayni gosterirdi.
          if (value != null) ...[
            const SizedBox(height: 6),
            Container(
              key: adminUserRatioTrackKey(slot),
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  key: adminUserRatioFillKey(slot),
                  widthFactor: value.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            value == null ? emptyNote : note,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AccountBlock extends StatelessWidget {
  const _AccountBlock({required this.insight, required this.userId});

  final AdminUserInsight insight;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ageDays = insight.accountAgeDays();
    final email = (insight.email ?? '').trim();

    return Column(
      key: kAdminUserAccountKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(context, l10n.settingsSectionAccount),
        _KeyValueRow(
          label: l10n.adminUserProfileCreatedAt,
          value: _stamp(context, insight.accountCreatedAt),
        ),
        _KeyValueRow(
          label: l10n.adminUserProfileAgeLabel,
          value: ageDays == null
              ? l10n.profileBilinmiyor
              : l10n.adminUserProfileDayCount(ageDays),
        ),
        _KeyValueRow(
          label: l10n.adminUserProfileLastSeen,
          value: _stamp(context, insight.lastSeenAt),
        ),
        _KeyValueRow(
          label: l10n.authEposta,
          value: email.isEmpty ? l10n.profileBilinmiyor : email,
        ),
        _KeyValueRow(
          label: l10n.adminUserProfileIdLabel,
          value: userId,
          trailing: IconButton(
            tooltip: l10n.classroomKopyala,
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final copied = l10n.adminUserProfileIdCopied;
              await Clipboard.setData(ClipboardData(text: userId));
              messenger.showSnackBar(SnackBar(content: Text(copied)));
            },
          ),
        ),
        // Kimlik satiri kendi metnini kisaltir; tam metin panoya gider.
        const SizedBox(height: 4),
        Text(
          l10n.adminIdGroupid(userId),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _UsageBlock extends StatelessWidget {
  const _UsageBlock({required this.insight});

  final AdminUserInsight insight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = insight.groupNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(context, l10n.adminUserProfileUsageTitle),
        _KeyValueRow(
          label: l10n.adminUserProfileTotalStudy,
          value: formatHuman(insight.totalStudySeconds),
        ),
        _KeyValueRow(
          label: l10n.adminUserProfileStreak,
          value: l10n.adminUserProfileDayCount(insight.currentStreakDays),
        ),
        _KeyValueRow(
          label: l10n.adminGruplar,
          value: groups.isEmpty
              ? l10n.adminUserProfileNoGroups
              : groups.join(', '),
        ),
      ],
    );
  }
}

class _SanctionHistoryBlock extends ConsumerWidget {
  const _SanctionHistoryBlock({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sanctions = ref.watch(moderationSanctionsProvider(userId));

    return Column(
      key: kAdminUserSanctionsKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(context, l10n.adminSanctionHistoryTitle),
        sanctions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(
            l10n.adminUserProfileSanctionsFailed,
            style: theme.textTheme.bodySmall,
          ),
          data: (items) => items.isEmpty
              ? Text(
                  l10n.adminSanctionHistoryEmpty,
                  style: theme.textTheme.bodySmall,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final sanction in items)
                      _SanctionRow(sanction: sanction),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Tarih · tur · gerekce **ayri sutunlarda**. Onceki yuzey ucunu tek satirda
/// birlestirip basiyordu; goz de test de sutunu ayirt edemiyordu.
class _SanctionRow extends StatelessWidget {
  const _SanctionRow({required this.sanction});

  final ModerationSanction sanction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final applied = sanction.appliedAt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              applied == null ? '—' : _dayStamp(applied),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 104,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Text(
                  adminSanctionLabel(l10n, sanction.action),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(sanction.reason, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Panelin altindaki tek sabit serit.
class _SanctionBar extends ConsumerWidget {
  const _SanctionBar({
    required this.targetUserId,
    required this.confirmationPhrase,
    required this.enabled,
  });

  final String targetUserId;
  final String confirmationPhrase;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            key: kAdminUserSanctionApplyKey,
            onPressed: enabled
                ? () => AdminSanctionActions.chooseAndApply(
                    context,
                    ref,
                    targetUserId: targetUserId,
                    confirmationPhrase: confirmationPhrase,
                  )
                : null,
            icon: const Icon(Icons.gavel_outlined, size: 20),
            label: Text(l10n.adminUserProfileApplySanction),
          ),
        ),
      ),
    );
  }
}

/// Etiket–deger satiri. Etiket solda, deger sagda; ikisi de sarar, boylece
/// 360 dp'de tasma olmaz.
class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Widget _sectionLabel(BuildContext context, String title) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    title,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
    ),
  ),
);

String _firstNonEmpty(List<String?> candidates, {required String fallback}) {
  for (final candidate in candidates) {
    final trimmed = candidate?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final letters = [
    for (final part in parts)
      if (part.isNotEmpty) part.characters.first,
  ];
  if (letters.isEmpty) return '?';
  return letters.take(2).join().toUpperCase();
}

/// Depoda kayitli desen: tarih bicimi tek satirda, gomulu metin yok.
String _stamp(BuildContext context, DateTime? value) => value == null
    ? AppLocalizations.of(context).profileBilinmiyor
    : value.toLocal().toString().substring(0, 16);

/// Ceza satirinin dar tarih sutunu icin yalniz gun.
String _dayStamp(DateTime value) =>
    value.toLocal().toString().substring(0, 10);
