import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard_card.dart';
import '../dday_prefs.dart';
import 'card_scaffold.dart';

/// WP-575 — sınav geri sayımı kartı: seçilen sınav tarihine kalan gün.
///
/// Veri tamamen cihaz içidir (`examDateProvider`), yeni izin/veri yoktur.
class DDayCard extends ConsumerWidget {
  const DDayCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final examDay = ref.watch(examDateProvider);

    return CardScaffold(
      header: cardTitle(context, l10n.homeSinavGeriSayimi),
      bodyBuilder: (context, bodyHeight) => SizedBox(
        height: bodyHeight,
        // WP-508: yalnız taşarsa kayar; sığdığında sürükleme dış sayfaya gider.
        child: cardScrollIfOverflows(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            // 🔴 Tarih seçilmemişken kart **boş kutu değildir**: `cardDataGate`
            // ile aynı sözleşme — başlık korunur, gövde ne olduğunu ve çıkış
            // yolunu söyler. (Kapının kendisi çağrılmıyor çünkü burada
            // beklenen bir `AsyncValue` yok; tarih prefs'ten senkron okunur.)
            children: examDay == null
                ? _emptyBody(context, theme, l10n)
                : _countdownBody(context, theme, l10n, ref, examDay),
          ),
        ),
      ),
    );
  }

  List<Widget> _emptyBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) => [
    Text(l10n.homeSinavTarihiSecilmedi, style: theme.textTheme.titleSmall),
    const SizedBox(height: 6),
    Text(
      l10n.homeSinavTarihiniAyarlardanSec,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ];

  List<Widget> _countdownBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    WidgetRef ref,
    DateTime examDay,
  ) {
    final remaining = daysUntilExam(
      examDay: examDay,
      now: ref.watch(ddayClockProvider)(),
    );
    // 🔴 Negatif gün gösterilmez: geçmiş bir sınav "-3 gün kaldı" değil
    // "geçti"dir. Sıfır da "0 gün kaldı" değildir — sınav bugündür.
    final headline = remaining < 0
        ? l10n.homeSinavGecti
        : (remaining == 0
              ? l10n.homeSinavBugun
              : l10n.homeSinavaKalanGun(remaining));

    return [
      // Dar hücrede kırpmak yerine ölçekle (goal_card ile aynı çözüm).
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          headline,
          maxLines: 1,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: remaining < 0
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 6),
      // Hangi tarihe sayıldığı kartta görünmezse sayı doğrulanamaz; tarih
      // biçimi Material kataloğundan gelir (yeni l10n anahtarı gerekmez).
      Text(
        MaterialLocalizations.of(context).formatFullDate(examDay),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}
