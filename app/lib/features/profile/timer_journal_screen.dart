import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/observability/timer_diagnostic_journal.dart';
import '../../l10n/app_localizations.dart';

/// WP-490 önkoşulu: sayaç uçuş kaydını **cihazdan çıkarılabilir** yapar.
///
/// 🔴 Bu ekranın varlık sebebi ölçüldü: `TimerDiagnosticJournal` WP-430'da
/// yazıldı, her sayaç geçişini `reason + outcome` ile kaydediyor ve
/// `exportEntries()` metodu bile var — ama `app/lib` içinde **hiçbir yerden
/// çağrılmıyordu**; tek çağıran kendi birim testiydi. Yani kayıt tutuluyor,
/// kimse okuyamıyordu.
///
/// WP-490 (hayalet koşu) teşhisinin 2. adımı doğrudan bu kayda bağlı:
/// `mirrorStopRequested` olayının `applied` / `stale` / `deferred` sonucu üç
/// ayrı düzeltme yolundan hangisinin doğru olduğunu söylüyor. Okuma yolu
/// olmadan o adım **yapılamazdı**; sahip belirtiyi tekrarlasa bile eline
/// hiçbir kanıt geçmezdi.
///
/// Gizlilik sözleşmesi journal'ın kendisinde yapısal olarak duruyor (kimlikler
/// tuzlanmış kısa özet, serbest metin yok, TTL'li). Bu ekran o sözleşmeyi
/// **genişletmez**: yalnız zaten saklanan kaydı gösterir ve kullanıcı açıkça
/// isterse paylaşır.
class TimerJournalScreen extends ConsumerStatefulWidget {
  const TimerJournalScreen({super.key});

  @override
  ConsumerState<TimerJournalScreen> createState() => _TimerJournalScreenState();
}

class _TimerJournalScreenState extends ConsumerState<TimerJournalScreen> {
  bool _busy = false;

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final journal = ref.read(timerDiagnosticJournalProvider);
    setState(() => _busy = true);
    try {
      final json = journal.exportEntries();
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(text: json, subject: l10n.diagTimerJournalTitle),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/odak-kampi-timer-journal.json');
        await file.writeAsString(json);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            subject: l10n.diagTimerJournalTitle,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // En yeni üstte: teşhis sırasında bakılan şey son geçiştir.
    final entries = ref.watch(timerDiagnosticJournalProvider).entries().reversed
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diagTimerJournalTitle)),
      floatingActionButton: entries.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.diagTimerJournalShare),
            ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.diagTimerJournalEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: entries.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.diagTimerJournalCount(entries.length),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.diagTimerJournalPrivacy,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final entry = entries[index - 1];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.event,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              entry.at.toIso8601String(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Teşhisin cevabı tam olarak bu iki alanda: hangi girdi
                        // geçişi doğurdu ve istek uygulandı mı.
                        Text(
                          '${entry.reason} → ${entry.outcome}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        // 🔴 WP-601: `trigger` WP-599'da yazılmaya başlandı ama
                        // bu ekran onu HİÇ göstermiyordu. Alan tam da "sayacı
                        // parmak mı bir rutin mi başlattı" sorusunu cevaplamak
                        // için eklendi; ekranda görünmezse gerçek bir olayda
                        // yine dışa aktarma + elle JSON okumak gerekirdi.
                        //
                        // `unknown` ÇİZİLMEZ: WP-599 öncesi satırlar bu alanı
                        // taşımıyor ve onlara "bilinmiyor" damgası basmak
                        // gürültüdür — asıl yanlış olan ise onları "kullanıcı"
                        // saymak olurdu, o da hiç yapılmıyor.
                        if (entry.trigger != TimerJournalTriggers.unknown) ...[
                          const SizedBox(height: 2),
                          Text(
                            'kaynak: ${entry.trigger}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  TimerJournalTriggers.isUserButton(
                                    entry.trigger,
                                  )
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.tertiary,
                              fontWeight:
                                  TimerJournalTriggers.isUserButton(
                                    entry.trigger,
                                  )
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
