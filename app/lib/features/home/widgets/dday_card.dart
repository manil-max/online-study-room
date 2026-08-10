import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard_card.dart';
import '../dday_prefs.dart';
import 'card_scaffold.dart';
import 'dday_editor_sheet.dart';

/// WP-575 / WP-632 — sınav geri sayımı kartı.
///
/// Veri tamamen cihaz içidir (`examListProvider`), yeni izin/veri yoktur.
///
/// **Yerleşim sözleşmesi (proje sahibi kararı, `URUN-POLITIKALARI` §8.1):**
/// hiçbir kayıt öne çıkarılmamışsa tüm sınavlar **eşit** satırlar hâlinde
/// listelenir; biri öne çıkarılmışsa o kayıt **büyük** görünür, diğerleri
/// altında yardımcı satır olur. Sıra kullanıcıya aittir.
///
/// 🔴 **Taşma sözleşmesi.** Pano hücresi karta sabit piksel yükseklik verir:
/// küçük kartta gövdeye kalan yer **~92 px**'dir (160 − 32 dolgu − başlık −
/// boşluk). Büyük sayı + ad + tarih + iki satır oraya sığmaz. Bu yüzden
/// yerleşim [_Density] ile **ölçüye göre** seyreltilir; kaydırma yalnız son
/// çare olarak (çok büyük yazı tipi ölçeği, çok kısa hücre) devrededir.
/// "Sığmazsa kaydırır" tek başına yeterli olsaydı kullanıcı küçük kartta
/// sayıyı görmek için kart içinde kaydırmak zorunda kalırdı.
class DDayCard extends ConsumerWidget {
  const DDayCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final list = ref.watch(examListProvider);

    return CardScaffold(
      header: Row(
        children: [
          Expanded(child: cardTitle(context, l10n.homeSinavGeriSayimi)),
          // 🔴 WP-642: bu simge eskiden ciplak bir [Icon] idi. Baslik,
          // [CardScaffold] icinde govdenin DISINDA durur; govdedeki
          // `dday-card-open-editor` dokunma hedefi buraya ulasmaz. Yani simge
          // dugme gibi goruntude durup hicbir sey yapmiyordu (proje sahibi
          // cihaz bildirimi: "basinca bir sey olmuyor, editlemek icin soldan
          // listeye basmak gerekiyor"). Artik gercek dugme ve **govdeyle ayni**
          // pencereyi acar; iki yol da tek kaynaga baglidir.
          cardHeaderAction(
            key: const Key('dday-card-header-edit'),
            icon: Icons.edit_outlined,
            tooltip: l10n.homeSinavlariDuzenle,
            onPressed: () => showDDayEditorSheet(context),
          ),
        ],
      ),
      bodyBuilder: (context, bodyHeight) {
        final density = _Density.forHeight(bodyHeight);
        return SizedBox(
          height: bodyHeight,
          child: InkWell(
            key: const Key('dday-card-open-editor'),
            onTap: () => showDDayEditorSheet(context),
            // Dokunma hedefi tüm gövde; kartın kendisine basmak pencereyi açar.
            child: cardScrollIfOverflows(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: list.isEmpty
                    ? _emptyBody(context, theme, l10n)
                    : _filledBody(context, theme, l10n, ref, list, density),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🔴 Tarih seçilmemişken kart **boş kutu değildir**: `cardDataGate` ile aynı
  /// sözleşme — başlık korunur, gövde ne olduğunu ve çıkış yolunu söyler.
  List<Widget> _emptyBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) => [
    Text(l10n.homeSinavTarihiSecilmedi, style: theme.textTheme.titleSmall),
    const SizedBox(height: 6),
    Text(
      l10n.homeSinavTarihiEklemekIcinDokun,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  ];

  List<Widget> _filledBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    WidgetRef ref,
    ExamListState list,
    _Density density,
  ) {
    final now = ref.watch(ddayClockProvider)();
    final featured = list.priority;
    final others = list.others;

    // 🔴 ÖLÇÜLDÜ, tahmin edilmedi. Küçük kartın gövdesine ~92 px kalıyor ve
    // büyük sayı + ad + İKİ yardımcı satır oraya sığmıyor (`dday_multi_exam`
    // testi tam bu bileşimde kırmızı düşmüştü). O yüzden en küçük boyutta üç
    // kayıt varsa kahraman düzeninden **kibarca geri çekiliyoruz**: kayıtlar
    // eşit satır olur, öne çıkan **başa alınır** ve bir tık büyük yazılır.
    // Alternatif "kaydırsın" olurdu; o zaman kullanıcı kalan günü görmek için
    // kart içinde kaydırmak zorunda kalırdı — kartın varlık sebebi ortadan
    // kalkardı.
    final useHero = featured != null && (density != _Density.tight || others.length <= 1);

    if (!useHero) {
      final ordered = featured == null ? list.entries : [featured, ...others];
      final rows = <Widget>[];
      for (final entry in ordered) {
        if (rows.isNotEmpty) rows.add(SizedBox(height: density.rowGap));
        rows.add(
          _CompactRow(
            entry: entry,
            now: now,
            l10n: l10n,
            theme: theme,
            density: density,
            emphasized: entry.id == featured?.id,
          ),
        );
      }
      return rows;
    }

    // B — öne çıkan büyük, diğerleri altında.
    return [
      _FeaturedBlock(
        entry: featured,
        now: now,
        l10n: l10n,
        theme: theme,
        density: density,
        // Tarih satırı yalnız yer varken gösterilir: küçük kartta sayının
        // kendisi kırpılmadan durmalı, tarih ikincildir.
        showDate: density.showFeaturedDate,
      ),
      if (others.isNotEmpty) SizedBox(height: density.rowGap),
      for (final entry in others) ...[
        _CompactRow(
          entry: entry,
          now: now,
          l10n: l10n,
          theme: theme,
          density: density,
        ),
        if (entry != others.last) SizedBox(height: density.rowGap),
      ],
    ];
  }
}

/// Kartın kendisine verilen piksel yüksekliğine göre seçilen yoğunluk.
///
/// Eşikler ölçülerek seçildi (`defaultCardHeight`: küçük 160 / orta 240 /
/// büyük 320 px; `CardScaffold` 32 px dolgu + başlık + 12 px boşluk düşer).
enum _Density {
  /// Küçük kart (~92 px gövde): tarih satırı yok, sayı küçültülür.
  tight,

  /// Orta kart (~170 px gövde).
  regular,

  /// Büyük kart (~250 px gövde).
  roomy;

  static _Density forHeight(double h) {
    if (!h.isFinite) return _Density.regular;
    if (h < 120) return _Density.tight;
    if (h < 200) return _Density.regular;
    return _Density.roomy;
  }

  double get rowGap => switch (this) {
    _Density.tight => 4,
    _Density.regular => 8,
    _Density.roomy => 10,
  };

  bool get showFeaturedDate => this != _Density.tight;

  /// Öne çıkan sayının hedef punto ölçüsü. Gerçek küçültme [FittedBox] ile
  /// yapılır; bu yalnız başlangıç boyutudur.
  TextStyle? featuredStyle(ThemeData theme) => switch (this) {
    _Density.tight => theme.textTheme.headlineSmall,
    _Density.regular => theme.textTheme.headlineMedium,
    _Density.roomy => theme.textTheme.headlineLarge,
  };

  TextStyle? compactValueStyle(ThemeData theme) => switch (this) {
    _Density.tight => theme.textTheme.titleMedium,
    _Density.regular => theme.textTheme.titleLarge,
    _Density.roomy => theme.textTheme.headlineSmall,
  };

  /// Kahraman düzeni sığmadığında öne çıkan satırın stili — bir tık büyük.
  TextStyle? emphasizedValueStyle(ThemeData theme) => switch (this) {
    _Density.tight => theme.textTheme.titleLarge,
    _Density.regular => theme.textTheme.headlineSmall,
    _Density.roomy => theme.textTheme.headlineMedium,
  };
}

/// Kalan gün metnini üretir.
///
/// 🔴 Negatif gün gösterilmez: geçmiş bir sınav "-3 gün kaldı" değil
/// "geçti"dir. Sıfır da "0 gün kaldı" değildir — sınav bugündür.
String _headlineFor(int remaining, AppLocalizations l10n) => remaining < 0
    ? l10n.homeSinavGecti
    : (remaining == 0 ? l10n.homeSinavBugun : l10n.homeSinavaKalanGun(remaining));

/// Sınav adı boş bırakılabilir (isteğe bağlı); o zaman dile bağlı varsayılan
/// başlık gösterilir. Varsayılan **diske yazılmaz**, yalnız burada üretilir.
String _labelFor(ExamEntry entry, AppLocalizations l10n) =>
    entry.name.trim().isEmpty ? l10n.homeSinavVarsayilanAd : entry.name.trim();

class _FeaturedBlock extends StatelessWidget {
  const _FeaturedBlock({
    required this.entry,
    required this.now,
    required this.l10n,
    required this.theme,
    required this.density,
    required this.showDate,
  });

  final ExamEntry entry;
  final DateTime now;
  final AppLocalizations l10n;
  final ThemeData theme;
  final _Density density;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final remaining = daysUntilExam(examDay: entry.day, now: now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dar hücrede kırpmak yerine ölçekle (goal_card ile aynı çözüm).
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _headlineFor(remaining, l10n),
            maxLines: 1,
            style: density.featuredStyle(theme)?.copyWith(
              color: remaining < 0
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          _labelFor(entry, l10n),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        // Hangi tarihe sayıldığı kartta görünmezse sayı doğrulanamaz; tarih
        // biçimi Material kataloğundan gelir (yeni l10n anahtarı gerekmez).
        if (showDate)
          Text(
            MaterialLocalizations.of(context).formatFullDate(entry.day),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.entry,
    required this.now,
    required this.l10n,
    required this.theme,
    required this.density,
    this.emphasized = false,
  });

  final ExamEntry entry;
  final DateTime now;
  final AppLocalizations l10n;
  final ThemeData theme;
  final _Density density;

  /// Kahraman düzeninin sığmadığı en küçük boyutta, öne çıkan kaydın tek
  /// işareti: başta durur ve bir tık büyük yazılır.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final remaining = daysUntilExam(examDay: entry.day, now: now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // 🔴 Ad `Expanded` içinde: uzun sınav adı (örn. "Deneme sınavı 12")
        // dar kartta yatay taşma üretirdi.
        Expanded(
          child: Text(
            _labelFor(entry, l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        // Sayı da esner: büyük yazı tipi ölçeğinde sabit punto taşardı.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _headlineFor(remaining, l10n),
              maxLines: 1,
              style:
                  (emphasized
                          ? density.emphasizedValueStyle(theme)
                          : density.compactValueStyle(theme))
                      ?.copyWith(
                color: remaining < 0
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
