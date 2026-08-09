import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/istanbul_calendar.dart';
import '../dday_prefs.dart';

/// WP-632 — sınav geri sayımı düzenleyicisi.
///
/// Proje sahibi kararı: düzenleme **kartın kendisinden** açılır, Ayarlar'a
/// gitmek gerekmez. Ekranı tamamen kaplamaz; alttan açılan bir pencere olur.
///
/// 🔴 `Scaffold.bottomSheet` DEĞİL `showModalBottomSheet` kullanılıyor. Kalıcı
/// alt şerit (`Scaffold.bottomSheet`) gövdenin üstünü örter ve yer ayırmaz; bu
/// depoda tam o hata bir kez yapıldı. Buradaki pencere geçicidir ve kendi
/// yüzeyini kurar.
Future<void> showDDayEditorSheet(
  BuildContext context,
) => showModalBottomSheet<void>(
  context: context,
  // Yükseklik içeriğe göre; klavye açıldığında da taşmaması için kaydırılabilir.
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => const _DDayEditorSheet(),
);

class _DDayEditorSheet extends ConsumerWidget {
  const _DDayEditorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = ref.watch(examListProvider);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Ekranı kaplamaz: en fazla yarısı kadar yer alır, taşarsa kendi içinde
        // kayar. Sabit yükseklik verilmiyor — bir kayıtlı pencere kocaman boş
        // bir kutu olmamalı.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  l10n.homeSinavlariDuzenle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Text(
                    l10n.homeSinavTarihiEklemekIcinDokun,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final entry in list.entries)
                _EntryRow(
                  entry: entry,
                  selected: list.priorityId == entry.id,
                  isFirst: entry == list.entries.first,
                  isLast: entry == list.entries.last,
                ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('dday-add-exam'),
                        // Sınır dolduğunda düğme kaybolmaz, **devre dışı**
                        // kalır: kaybolan düğme kullanıcıya neden ekleyemediğini
                        // söylemez.
                        onPressed: list.canAdd
                            ? () => _editEntry(context, ref, null)
                            : null,
                        icon: const Icon(Icons.add),
                        label: Text(
                          l10n.homeSinavEkleSayac(
                            list.entries.length,
                            kMaxExamEntries,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!list.canAdd)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    l10n.homeSinavSiniriDoldu(kMaxExamEntries),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.selected,
    required this.isFirst,
    required this.isLast,
  });

  final ExamEntry entry;
  final bool selected;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = entry.name.trim().isEmpty
        ? l10n.homeSinavVarsayilanAd
        : entry.name.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // 🔴 Seçili satır YALNIZ renkle anlatılmaz: zemin + çerçeve + rozet
        // birlikte çalışır. Tek başına renk, renk görme farkı olan ya da
        // parlak ışıkta bakan kullanıcı için işaret sayılmaz.
        color: selected ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          children: [
            IconButton(
              key: Key('dday-priority-${entry.id}'),
              tooltip: selected
                  ? l10n.homeOneCikarmayiKaldir
                  : l10n.homeOneCikar,
              isSelected: selected,
              onPressed: () =>
                  ref.read(examListProvider.notifier).togglePriority(entry.id),
              icon: Icon(
                selected ? Icons.star : Icons.star_border,
                color: selected ? scheme.onPrimaryContainer : null,
              ),
            ),
            Expanded(
              child: InkWell(
                key: Key('dday-edit-${entry.id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _editEntry(context, ref, entry),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: selected
                                    ? scheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 6),
                            _FeaturedBadge(label: l10n.homeOneCikan),
                          ],
                        ],
                      ),
                      Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatFullDate(entry.day),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: Key('dday-up-${entry.id}'),
              tooltip: l10n.homeYukariTasi,
              onPressed: isFirst
                  ? null
                  : () => ref
                        .read(examListProvider.notifier)
                        .move(entry.id, delta: -1),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              key: Key('dday-down-${entry.id}'),
              tooltip: l10n.homeAsagiTasi,
              onPressed: isLast
                  ? null
                  : () => ref
                        .read(examListProvider.notifier)
                        .move(entry.id, delta: 1),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              key: Key('dday-delete-${entry.id}'),
              tooltip: l10n.homeSinavSil,
              onPressed: () =>
                  ref.read(examListProvider.notifier).remove(entry.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.primary),
      ),
    );
  }
}

/// Ad + tarih düzenleme kutusu. [entry] `null` ise yeni kayıt açılır.
///
/// 🔴 `AlertDialog` KULLANILMIYOR ve sebebi ölçüldü: `AlertDialog` gövdesini
/// `IntrinsicWidth` ile ölçer, `TextField` bu ölçümde patlıyor ve düzen
/// ~99.000 piksel taşıyor. Kendi `Dialog`umuzu kurmak her kısıtı bize bırakır.
///
/// 🔴 Denetleyici de burada tutulmuyor: fonksiyon içinde açıp `showDialog`
/// dönünce `dispose()` etmek "kapanış animasyonu sırasında imha edilmiş
/// denetleyici kullanıldı" hatası veriyordu. Sahibi artık `State`.
Future<void> _editEntry(
  BuildContext context,
  WidgetRef ref,
  ExamEntry? entry,
) async {
  final l10n = AppLocalizations.of(context);
  final today = istanbulDay(ref.read(ddayClockProvider)());

  final result = await showDialog<({String name, DateTime day})>(
    context: context,
    builder: (context) => _ExamEditDialog(entry: entry, today: today),
  );
  if (result == null) return;

  final notifier = ref.read(examListProvider.notifier);
  if (entry == null) {
    final added = await notifier.add(name: result.name, day: result.day);
    // Sınır dolduğunda ekleme sessizce düşmez; kullanıcı nedenini görür.
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.homeSinavSiniriDoldu(kMaxExamEntries))),
      );
    }
  } else {
    await notifier.update(entry.id, name: result.name, day: result.day);
  }
}

class _ExamEditDialog extends StatefulWidget {
  const _ExamEditDialog({required this.entry, required this.today});

  final ExamEntry? entry;
  final DateTime today;

  @override
  State<_ExamEditDialog> createState() => _ExamEditDialogState();
}

class _ExamEditDialogState extends State<_ExamEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.entry?.name ?? '',
  );
  late DateTime _day = widget.entry?.day ?? widget.today;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    // `showDatePicker`, `initialDate` aralığın dışına düşerse assert ile
    // çöker; geçmiş bir sınav tarihi bunu kolayca yapar, o yüzden sınırlar
    // seçili tarihi kapsar.
    var first = DateTime(widget.today.year - 1, 1, 1);
    var last = DateTime(widget.today.year + 10, 12, 31);
    if (_day.isBefore(first)) first = _day;
    if (_day.isAfter(last)) last = _day;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Dialog(
      child: ConstrainedBox(
        // Genişlik dar ekranda taşmasın, geniş ekranda dağılmasın.
        // Yükseklik klavye açıkken de sınırlı kalsın: taşarsa içerik kayar,
        // düzen kırılmaz.
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: media.size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.entry == null
                    ? l10n.homeSinavEkle
                    : l10n.homeSinaviDuzenle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('dday-name-field'),
                controller: _name,
                autofocus: widget.entry == null,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: l10n.homeSinavAdi,
                  // Ad **isteğe bağlıdır** (proje sahibi kararı): boş bırakan
                  // kullanıcı engellenmez, kartta varsayılan başlık görür.
                  helperText: l10n.homeSinavAdiIstegeBagli,
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                key: const Key('dday-date-tile'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  MaterialLocalizations.of(context).formatFullDate(_day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: _pickDay,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.homeVazgec),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('dday-save'),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop((name: _name.text, day: _day)),
                    child: Text(l10n.homeKaydet),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
