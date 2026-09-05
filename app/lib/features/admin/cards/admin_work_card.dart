/// WP-698 — **tek kart dili**.
///
/// ## Neden
/// Yonetim paneline dusen her is (sikayet, oneri, soru, hata bildirimi,
/// itiraz) ayni soruyu sordurur: *kim, neyi, ne zaman, ben ne yapmaliyim*.
/// Buna ragmen panelde iki ayri kart vardi ve **tek bir widget'i bile
/// paylasmiyorlardi**:
///
///   - `widgets/moderation_queue_card.dart` — `Card > Column`, kendi
///     `_StatusChip`i, kendi `_CaseBadges`i, kendi `_IdentityLine`i.
///   - `tabs/admin_reports_tab.dart` — `_TicketCard`, kendi `Chip` ormani.
///
/// Olculdu (2026-08-11, `admin_card_system_wp698_test.dart` probu):
///
/// | genislik | vaka karti | bilet karti |
/// | --- | --- | --- |
/// | 280 px | 242 px | **610 px** |
/// | 390 px | 216 px | **500 px** |
/// | 1280 px | 216 px | 198 px |
///
/// Ayni isi gosteren iki kart 280 px'te **2,5 kat** farkli yukseklikte;
/// bilet karti tek basina bir telefon ekranini dolduruyordu. Bilet kartinda
/// 7 cip vardi (3'u bilgi, 4'u eylem) ve hepsi **ayni** 34 px'lik pilldi —
/// hangisine basilabilecegi gorunmuyordu; kartin sekiz dokunma hedefinin
/// sekizi de 48 px'in altindaydi.
///
/// ## Karar
/// Tur farki **veriyle** anlatilir, ayri widget'la degil. Her kart bu
/// bilesenden turer ve ayni dort bolgeyi ayni sirada cizer:
///
/// 1. **Ton seridi** (sol kenar, 4 px) — aciliyet. Kuyrukta gozle asagi
///    kayarken renk sutunu "acil / yeni / bekliyor / kapandi"yi tek bakista
///    verir. Renk [AdminWorkTone] ile *durumdan* turer, turden degil.
/// 2. **Baslik satiri** — tur ikonu + konu + **tek** durum hapi + `…` menusu.
/// 3. **Govde** — istege bagli 2 satirlik ozet, ardindan taraflar
///    (kim), ardindan tek satirlik meta (ne zaman).
/// 4. **Isaret seridi** — yalniz *istisnai* durumlar (yuksek risk, sure asimi,
///    karantina, arsiv). Normal bir kartta hic cizilmez.
/// 5. **Eylem seridi** — istege bagli; **en fazla bir tane** vurgulu eylem,
///    kalani duz. Yuksekligi 48 px. Bos birakilabilir: moderasyon karti
///    yaptirim/karantinayi `…` menusunde tutar, cunku **tehlikeli eylem
///    karttan cikmaz** (WP-B/C karar seridi).
///
/// ## Tipografi
/// Kart **tek olcek** kullanir: baslik `titleSmall`, govde/taraf/meta
/// `bodySmall`, hap ve isaretler `labelSmall`. Iki kart ailesi de ayni
/// avatar yaricapini kullanir, boylece cizilen font boyutu **kumesi** birebir
/// esittir — testte olculur.
///
/// ## Genislik
/// Icerik sutunu `docs/design/DESKTOP-UI-SPEC.md` §2.2'deki **sert tavan
/// 600 px** ile sinirlanir; yeni sayi uretilmedi. Kart 1280 px'lik bir listede
/// de etiket-deger satirlarini 600 px'i asacak sekilde germez.
library;

import 'package:flutter/material.dart';

import 'package:online_study_room/core/widgets/user_avatar.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Kartin aciliyet tonu. **Tur degil, durum.**
enum AdminWorkTone {
  /// Simdi bakilmali: sure asildi ya da sunucu yuksek risk dedi.
  urgent,

  /// Yeni geldi, kimse dokunmadi.
  open,

  /// Biri devraldi / kullanicidan yanit bekleniyor.
  waiting,

  /// Kapandi ya da arsivlendi.
  done,
}

/// Icerik sutunu tavani — `DESKTOP-UI-SPEC.md` §2.2 sert tavani.
const double kAdminWorkCardMaxContentWidth = 600;

/// Kart icindeki her dokunma hedefinin en az yuksekligi.
const double kAdminWorkCardTapTarget = 48;

/// Her iki kart ailesinde de ayni: font boyutu kumesi ayrismasin.
const double kAdminWorkCardAvatarRadius = 12;

Color adminWorkToneAccent(ColorScheme scheme, AdminWorkTone tone) =>
    switch (tone) {
      AdminWorkTone.urgent => scheme.error,
      AdminWorkTone.open => scheme.primary,
      AdminWorkTone.waiting => scheme.tertiary,
      AdminWorkTone.done => scheme.outlineVariant,
    };

/// Hap/isaret zemini ve uzerindeki yazi rengi. Cift her zaman M3'un
/// garantiledigi `X` / `onX` esidir; kirmizi temada kaybolan sabit renk yok.
(Color, Color) adminWorkToneContainer(ColorScheme scheme, AdminWorkTone tone) =>
    switch (tone) {
      AdminWorkTone.urgent => (scheme.errorContainer, scheme.onErrorContainer),
      AdminWorkTone.open => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      AdminWorkTone.waiting => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      AdminWorkTone.done => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

/// Istisnai durum isareti (yuksek risk, sure asimi, karantina, arsiv).
@immutable
class AdminWorkFlag {
  const AdminWorkFlag(this.label, {this.tone = AdminWorkTone.waiting});

  final String label;
  final AdminWorkTone tone;
}

/// Isin tarafi: sikayet edilen, sikayet eden, bileti gonderen…
@immutable
class AdminWorkParticipant {
  const AdminWorkParticipant({
    required this.roleLabel,
    required this.name,
    this.avatarUrl,
    this.extraCount = 0,
    this.trailing,
  });

  /// "Sikayet edilen", "Gonderen" gibi rol etiketi.
  final String roleLabel;

  /// Cozulemeyen kimlikte cagri yeri "Silinmis kullanici" gonderir; kart
  /// bosluk cizmez.
  final String name;

  final String? avatarUrl;

  /// Ayni role dusen diger kisi sayisi — tekrar sayaci `(+N)`.
  final int extraCount;

  /// Satirin sag ucundaki tek kopru (ornek: kisi dosyasi).
  final Widget? trailing;
}

/// Kartta **gorunur** duran eylem. Tehlikeli olan buraya konmaz.
@immutable
class AdminWorkAction {
  const AdminWorkAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  /// Serit basina **bir tane**: yoneticinin bu is icin yapmasi beklenen sey.
  final bool primary;
}

/// `…` menusundeki satir.
@immutable
class AdminWorkMenuItem {
  const AdminWorkMenuItem({
    required this.label,
    required this.onSelected,
    this.disabledReason,
  });

  final String label;
  final VoidCallback? onSelected;

  /// Hedef cozulemedigi gibi durumlarda eylem kaybolmaz; neden calismadigi
  /// menu satirinda acikca gorunur ve erisilebilirlik agacina girer.
  final String? disabledReason;
}

/// Durum hapinin ortak atasi.
///
/// [AdminWorkCard.status] bu tipi ister; boylece **derleyici** her kartin ayni
/// hapi kullanmasini zorunlu kilar. Ayri bir cip yazip kartın icine koymak
/// mumkun degildir.
abstract class AdminWorkStatusPillBase extends StatelessWidget {
  const AdminWorkStatusPillBase({super.key});
}

/// WP-768: yalniz **gosteren** durum hapi.
///
/// 🔴 Sahip karari: *"her kartta sadece detayli incele butonu olsun."* Kuyruk
/// kartindaki durum hapi bir `PopupMenuButton`du; ustunde menu oldugunu
/// soyleyen hicbir isaret yoktu ve sahip ona basinca ne olacagini bilmiyordu.
/// Durum artik **detay sayfasinda** degistirilir; kartta yalnizca okunur.
/// Hap gorunumu [AdminWorkStatusPill] ile birebir ayni kalir ki kart
/// yuksekligi ve tipografi olcegi sicramasin.
class AdminWorkStatusLabel extends AdminWorkStatusPillBase {
  const AdminWorkStatusLabel({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final AdminWorkTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = adminWorkToneContainer(
      theme.colorScheme,
      tone,
    );
    return Semantics(
      container: true,
      // Etiket hapin kendisidir; alttaki Text ikinci kez okunmasin.
      excludeSemantics: true,
      label: label,
      child: ConstrainedBox(
        // Dokunma hedefi degil; ama satir yuksekligi hapli kartlarla ayni
        // kalsin diye ayni 48 px'lik kutu icinde ortalanir.
        constraints: const BoxConstraints(
          minHeight: kAdminWorkCardTapTarget,
          maxWidth: 132,
        ),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek durum kontrolu: hem durumu **gosterir** hem degistirir.
///
/// Jenerik, cunku cagri yerleri kendi durum `enum`larini menude tasir
/// (`PopupMenuItem<ModerationCaseStatus>` gibi sozlesmeler korunur).
class AdminWorkStatusPill<T> extends AdminWorkStatusPillBase {
  const AdminWorkStatusPill({
    super.key,
    required this.label,
    required this.tone,
    required this.options,
    required this.optionLabel,
    required this.onSelected,
    this.tooltip,
  });

  final String label;
  final AdminWorkTone tone;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = adminWorkToneContainer(
      theme.colorScheme,
      tone,
    );

    return PopupMenuButton<T>(
      onSelected: onSelected,
      tooltip: tooltip ?? AppLocalizations.of(context).adminDurumuDegistir,
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem<T>(value: option, child: Text(optionLabel(option))),
      ],
      child: Semantics(
        button: true,
        container: true,
        // Etiket hapin kendisidir; alttaki Text ikinci kez okunmasin.
        excludeSemantics: true,
        label: label,
        child: ConstrainedBox(
          // Dokunma hedefi 48; **gorunur** hap 28 kalir, boylece hedefi
          // buyutmek kart yuksekligini sismez (baslik satiri zaten `…`
          // dugmesi yuzunden 48).
          constraints: const BoxConstraints(
            minHeight: kAdminWorkCardTapTarget,
            maxWidth: 132,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                label,
                // Her durumda ayni stil ve tek satir: yukseklik sicramaz.
                style: theme.textTheme.labelSmall?.copyWith(color: foreground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yonetim panelindeki **her** gelen isin karti.
class AdminWorkCard extends StatelessWidget {
  const AdminWorkCard({
    super.key,
    required this.typeIcon,
    required this.title,
    required this.status,
    required this.tone,
    this.excerpt,
    this.participants = const <AdminWorkParticipant>[],
    this.metaLine,
    this.flags = const <AdminWorkFlag>[],
    this.flagsKey,
    this.overflowItems = const <AdminWorkMenuItem>[],
    this.overflowKey,
    this.actions = const <AdminWorkAction>[],
    this.onTap,
    this.selected = false,
  });

  /// Turun **tek** gorsel isareti. Tur yazisi meta satirinda durur.
  final IconData typeIcon;

  /// "Ne hakkinda" — sikayet gerekcesi ya da bilet konusu.
  final String title;

  /// Derleyici zorunlulugu: her kart ayni durum hapini kullanir.
  final AdminWorkStatusPillBase status;

  /// Sol ton seridi ve tarama rengi.
  final AdminWorkTone tone;

  /// Kullanicinin yazdigi metnin ilk iki satiri (bilette mesaj govdesi).
  final String? excerpt;

  final List<AdminWorkParticipant> participants;

  /// "Ne zaman" satiri: tur · sure · sayac.
  final String? metaLine;

  final List<AdminWorkFlag> flags;
  final Key? flagsKey;

  final List<AdminWorkMenuItem> overflowItems;
  final Key? overflowKey;

  /// Gorunur eylemler. Tehlikeli olanlar buraya **konmaz**.
  final List<AdminWorkAction> actions;

  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        hoverColor: scheme.onSurface.withValues(alpha: 0.06),
        focusColor: scheme.primary.withValues(alpha: 0.12),
        child: Container(
          // Ton seridi: kuyrukta tek bakista taranan sey budur. Kenarlik
          // olarak cizilir — `Row(stretch)` liste icinde **sinirsiz yukseklik**
          // aldigi icin cokuyordu; kenarlik cocugun yuksekligini kendiliginden
          // takip eder.
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: adminWorkToneAccent(scheme, tone),
                width: 4,
              ),
            ),
          ),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kAdminWorkCardMaxContentWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _content(context, theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(typeIcon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          status,
          if (overflowItems.isNotEmpty)
            _AdminWorkOverflow(items: overflowItems, menuKey: overflowKey),
        ],
      ),
      if (excerpt != null && excerpt!.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(
          excerpt!,
          style: muted,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      for (final participant in participants) ...[
        const SizedBox(height: 4),
        _ParticipantLine(participant: participant),
      ],
      if (metaLine != null && metaLine!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          metaLine!,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      if (flags.isNotEmpty) ...[
        const SizedBox(height: 4),
        _FlagStrip(flags: flags, stripKey: flagsKey),
      ],
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 2),
        _ActionRail(actions: actions),
      ],
    ];
  }
}

class _ParticipantLine extends StatelessWidget {
  const _ParticipantLine({required this.participant});

  final AdminWorkParticipant participant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = participant.extraCount > 0
        ? '${participant.roleLabel}: ${participant.name} '
              '(+${participant.extraCount})'
        : '${participant.roleLabel}: ${participant.name}';

    return Row(
      children: [
        UserAvatar(
          displayName: participant.name,
          avatarUrl: participant.avatarUrl,
          radius: kAdminWorkCardAvatarRadius,
          enableZoom: false,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?participant.trailing,
      ],
    );
  }
}

class _FlagStrip extends StatelessWidget {
  const _FlagStrip({required this.flags, this.stripKey});

  final List<AdminWorkFlag> flags;
  final Key? stripKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      key: stripKey,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final flag in flags)
          Builder(
            builder: (context) {
              final (background, foreground) = adminWorkToneContainer(
                theme.colorScheme,
                flag.tone,
              );
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  flag.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                  ),
                  maxLines: 1,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Tek ritim: her dugme 48 px, vurgulu olan **bir tane**.
class _ActionRail extends StatelessWidget {
  const _ActionRail({required this.actions});

  final List<AdminWorkAction> actions;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, kAdminWorkCardTapTarget)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    return Wrap(
      spacing: 4,
      runSpacing: 0,
      children: [
        for (final action in actions)
          if (action.primary)
            FilledButton.tonalIcon(
              key: action.buttonKey,
              style: style,
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 18),
              label: Text(action.label),
            )
          else
            TextButton.icon(
              key: action.buttonKey,
              style: style,
              onPressed: action.onPressed,
              icon: Icon(action.icon, size: 18),
              label: Text(action.label),
            ),
      ],
    );
  }
}

class _AdminWorkOverflow extends StatelessWidget {
  const _AdminWorkOverflow({required this.items, this.menuKey});

  final List<AdminWorkMenuItem> items;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      key: menuKey,
      tooltip: AppLocalizations.of(context).adminWorkCardMoreActions,
      onSelected: (index) => items[index].onSelected?.call(),
      itemBuilder: (_) => [
        for (var index = 0; index < items.length; index++)
          PopupMenuItem<int>(
            value: index,
            enabled: items[index].onSelected != null,
            child: Semantics(
              enabled: items[index].onSelected != null,
              hint: items[index].disabledReason,
              child: items[index].disabledReason == null
                  ? Text(items[index].label)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[index].label),
                        Text(
                          items[index].disabledReason!,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
