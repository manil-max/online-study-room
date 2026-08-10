import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';

/// Bugünün özeti: toplam süre + ders bazında oransal dağılım (§3.9 kart).
/// Küçük boyutta yalnızca toplamı, orta/büyükte ders dağılımını gösterir.
class TodaySummaryCard extends ConsumerWidget {
  const TodaySummaryCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(userSessionsProvider);
    final subjectsAsync = ref.watch(userSubjectsProvider);
    // WP-495C: ikisi de gelmeden "0 dk" ya da varsayılan ders renkleri çizilir.
    final gate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeBugunOzeti,
      sources: [sessionsAsync, subjectsAsync],
    );
    if (gate != null) return gate;
    final sessions = sessionsAsync.value!;
    final subjects = subjectsAsync.value!;
    final now = DateTime.now();
    // 🔴 WP-571: eskiden `isSameDay(s.day, now)` idi — İstanbul gün anahtarı
    // cihazın HAM yerel anıyla kıyaslanıyordu. Bkz. [sessionsOnDay]; ürünün
    // geri kalanı (`secondsOnDay`, `inRange`, `session_history_screen`) zaten
    // iki tarafı da İstanbul gününe indirgiyordu, bu kart tek istisnaydı.
    final today = sessionsOnDay(sessions, now);
    final total = totalSeconds(today);
    final breakdown = subjectBreakdown(today);

    Subject? subjectFor(String? id) {
      for (final s in subjects) {
        if (s.id == id) return s;
      }
      return null;
    }

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dar VEYA çok kısa hücrede kaydırma-güvenli özet düzenine düş; böylece
          // tam genişlikte h=1 gibi çok kısa hücrede taşma (RenderFlex) olmaz.
          // 140 eşiği CardScaffold'un doldurma eşiğiyle (minBody 96 + başlık 44)
          // hizalıdır.
          final isCompact =
              constraints.maxWidth < 180 ||
              (constraints.maxHeight.isFinite && constraints.maxHeight < 140);

          if (isCompact) {
            // WP-508: yalnız taşarsa kayar; sığdığında sürükleme dış sayfaya.
            // Sınırsız yükseklikte (dar hücre + Gruplar listesi) kaydırıcı hiç
            // kurulmaz — `goal_card`/`period_summary_card` ile aynı eksik kontrol.
            final compactColumn = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).homeBugun,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatHuman(total),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  breakdown.isEmpty
                      ? AppLocalizations.of(context).homeKayitYok
                      : AppLocalizations.of(
                          context,
                        ).homeDersSayisi(breakdown.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            return Padding(
              padding: const EdgeInsets.all(16),
              child: constraints.maxHeight.isFinite
                  ? cardScrollIfOverflows(child: compactColumn)
                  : compactColumn,
            );
          }

          final maxSeconds = breakdown.isEmpty
              ? 1
              : breakdown.first.value.clamp(1, 1 << 30);

          // 🔴 WP-515: bu dal `Expanded` kuruyor. `isCompact` yükseklik eşiğini
          // yalnız yükseklik **sınırlıyken** uyguluyor (yukarıda), yani
          // "geniş + sınırsız" bir bağlamda (Gruplar listesi gibi) buraya
          // sonsuz `maxHeight` ile giriliyordu — sonsuz yükseklikte flex'li
          // çocuk `RenderFlex` hatası verir ve kart hiç çizilmezdi.
          // Çözüm compact'a düşmek DEĞİL (ders dağılımı kaybolurdu): flex'i
          // yalnız bounded'da kur, sınırsızda içerik kadar yer kapla.
          final bounded = constraints.maxHeight.isFinite;
          final breakdownBody = breakdown.isEmpty
              ? Text(
                  AppLocalizations.of(context).homeBugunHenuzCalismaKaydin,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : ListView.builder(
                  // WP-508: bayrak verilmezse dikey `ListView`
                  // `AlwaysScrollableScrollPhysics`e düşer ve sığan
                  // içerikte bile sürüklemeyi yutar.
                  physics: kCardOverflowScrollPhysics,
                  primary: false,
                  // WP-515: sınırsız yükseklikte kendi yüksekliğini bilemez.
                  shrinkWrap: !bounded,
                  itemCount: breakdown.length,
                  itemBuilder: (context, index) {
                    final entry = breakdown[index];
                    final subject = subjectFor(entry.key);
                    final name =
                        subject?.name ?? AppLocalizations.of(context).homeGenel;
                    final color = subject != null
                        ? subjectColor(subject.color)
                        : theme.colorScheme.onSurfaceVariant;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // WP-676 / SPEC KURAL 2.2: ders adı ↔ süre de bir
                          // etiket–değer satırıdır; masaüstünde 496'da durur.
                          cardLabelValueRow(
                            context,
                            child: Row(
                              children: [
                                CircleAvatar(radius: 5, backgroundColor: color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  formatHuman(entry.value),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: entry.value / maxSeconds,
                              minHeight: 8,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔴 WP-541: bu satır eskiden `Text` + `Spacer()` + `Text` idi
                // ve hiçbiri esnek değildi, yani `Row` iki metnin **doğal**
                // genişliğini istiyordu. Dar telefonda VARSAYILAN yazı
                // ölçüsünde bile taşıyordu (320 dp → 11 px sağa taşma), büyük
                // yazıda ölçü 299 px'e çıkıyordu. Başlık kısalabilir, toplam
                // süre kısalamaz: esneklik başlığa verildi.
                // 🔴 WP-676: bu satır masaüstünde 1408 px'e uzuyordu ("Bugün
                // özeti" solda, "0sn" 1182 px ötede sağda). SPEC KURAL 2.2 →
                // [cardLabelValueRow] 496 px'te bırakır, sola hizalar.
                cardLabelValueRow(
                  context,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).homeBugunOzeti,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Toplam süre esnek DEĞİL: kısaltılırsa kartın tek sayısal
                      // bilgisi ("2s 30dk" → "2s…") yalan söyler. Yer daralınca
                      // kısalan başlıktır.
                      Text(
                        formatHuman(total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (bounded) Expanded(child: breakdownBody) else breakdownBody,
              ],
            ),
          );
        },
      ),
    );
  }
}
