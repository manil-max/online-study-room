import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/stats/istanbul_calendar.dart';
import '../../core/stats/study_stats.dart';
import '../../core/theme/subject_colors.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/study_session.dart';
import '../../data/models/subject.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';
import '../desktop/desktop_page_scaffold.dart';
// WP-679: ortak masaustu olculeri (`ProfileDesktopBody`) Ayarlar'da durur.
import 'settings_screen.dart';
import 'widgets/manual_session_dialog.dart';

/// Çalışma kayıtları: kullanıcının oturumları (yeni → eski), güne göre gruplu.
/// Manuel süre ekleme, düzenleme ve silme (project.md §3.5 — esnek manuel giriş).
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key, this.embedded = false});

  /// Desktop master-detail içinde gömülü: AppBar yok (WP-53).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sessionsAsync = ref.watch(userSessionsProvider);

    final body = sessionsAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      // WP-147: error + yeniden dene (boş/loading zaten var).
      error: (_, _) => ProfileDesktopCentered(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.profileBeklenmeyenBirHataOlustu,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(userSessionsProvider),
                  child: Text(l10n.classroomYenile),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (sessions) {
        // WP-555: burada `if (!hasGroup) return "once bir gruba katil"` vardi.
        // Yapay kapiydi: manuel ekleme akisi (`addManualSessionFlow`) grup
        // sarti aramaz ve grupsuz kullanici ayni akisi sayac kartindan zaten
        // calistirabiliyordu. Onboarding grup adimini atlatabildigi icin
        // grupsuz kullanici gercek bir durum; kendi gecmisini goremiyordu.
        if (sessions.isEmpty) {
          return _centerInfo(theme, l10n.profileHenuzKaydinYok);
        }
        return _SessionList(sessions: sessions);
      },
    );

    if (embedded) {
      return Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _addManual(context, ref),
              icon: Icon(Icons.add),
              label: Text(l10n.profileManuelEkle),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).profileCalismaKayitlarim),
      ),
      // WP-679: masaustunde eylem, 1096 px'lik master-detay bandinin yaninda.
      floatingActionButtonLocation: isDesktopWindow
          ? const ProfileContentEndFabLocation(
              kSessionMasterWidth +
                  kSessionPaneSpacing +
                  DesktopBreakpoints.maxFormWidth,
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addManual(context, ref),
        icon: Icon(Icons.add),
        label: Text(l10n.profileManuelEkle),
      ),
      body: body,
    );
  }

  // WP-679: bos/hata durumu da masaustu yuzeyine baglidir (SPEC §6). Aksi
  // halde ekranin en sik gorunen hali (kayit yokken) hicbir masaustu
  // widget'i cizmez ve `desktop_stretch_contract` OLCUM 4 kirmizi kalir.
  Widget _centerInfo(ThemeData theme, String text) => ProfileDesktopCentered(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );

  Future<void> _addManual(BuildContext context, WidgetRef ref) =>
      addManualSessionFlow(context, ref);
}

/// Oturumları güne göre gruplar. **Bugün** ayrı ayrı (saat aralığıyla); **geçmiş
/// günler** tek katlanabilir özet kayıtta toplanır — dokununca oturumlar açılır
/// (§3.10). Liste şişmez, eski günler tek satır.
class _SessionList extends ConsumerStatefulWidget {
  const _SessionList({required this.sessions});

  final List<StudySession> sessions;

  @override
  ConsumerState<_SessionList> createState() => _SessionListState();
}

class _SessionListState extends ConsumerState<_SessionList> {
  /// Yalniz masaustu iki-pane dalinda anlamli: secili gun. `null` = ilk gun.
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final today = dayOf(DateTime.now());

    // Güne göre grupla (sessions zaten yeni → eski sıralı).
    final byDay = <DateTime, List<StudySession>>{};
    for (final s in widget.sessions) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    final singleColumn = ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final day in days)
          if (isSameDay(day, today))
            _TodaySection(
              total: secondsOnDay(byDay[day]!, day),
              sessions: byDay[day]!,
            )
          else
            _PastDayTile(
              day: day,
              total: secondsOnDay(byDay[day]!, day),
              sessions: byDay[day]!,
            ),
      ],
    );

    // 🔴 WP-679 — bu ekran iki ayri yoldan acilir ve OLCUM ikisini de gordu:
    //   · Profil → "Calisma kayitlarim": `showDesktopPanel` → 920 px'lik
    //     `Dialog`. Olcum (`WP679 | KAYITLAR-PANEL`) icerik **868 px**;
    //     1920 px ile 2560 px pencerede AYNI (panel pencereyle buyumez).
    //   · Sayac karti → `MaterialPageRoute` (`classroom/widgets/
    //     study_timer_card.dart:619`): TAM pencere. Olcum (`WP679 | KAYITLAR`)
    //     1920 px'te **1868 px**, 2560 px'te **2508 px** — bir saat araligi ve
    //     bir sure yazan satirlar iki buçuk metre uzuyordu.
    //
    // SPEC §5 bu ekrani **A1 / master-detay** sayar (320 gun listesi + 760
    // oturum detayi, esik `large` = 1200). Uygulandi ve SAHIDEN BAGLI: tam
    // pencere yolunda 1868 px kap esigi asar, panelde asmaz ve bugunku tek
    // sutun agaci **birebir** korunur — yani ikinci dal olu kod degil.
    return LayoutBuilder(
      builder: (context, constraints) {
        // SPEC §7: mobil dal ve dar kap bugunku agaci BIREBIR korur.
        if (!isDesktopWindow ||
            constraints.maxWidth < DesktopBreakpoints.large) {
          // 🔴 WP-679 ikinci olcum: PANEL yolunda (868 px kap) iki pane esigi
          // asilmaz, ama liste yine de 868 px yayiliyordu — SPEC §2.3'un 760
          // px'lik form tavaninin ustu. Dar dalda agacin SEKLI degismez
          // (bugunku `ListView`), yalniz kabi 760'ta durur.
          return ProfileDesktopBody.form(child: singleColumn);
        }
        final selected = days.contains(_selected) ? _selected! : days.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          child: ProfileDesktopBody(
            // 320 (master) + 16 (SPEC §3 A1 boslugu) + 760 (detay) = 1096.
            maxWidth:
                kSessionMasterWidth +
                kSessionPaneSpacing +
                DesktopBreakpoints.maxFormWidth,
            child: DesktopMasterDetail(
              // SPEC §3 A1 tablosu: gun listesi 320 px, boslugu 16 px.
              masterWidth: kSessionMasterWidth,
              spacing: kSessionPaneSpacing,
              // Iki-pane karari YUKARIDA verildi (kap >= 1200). Widget'in
              // kendi esigi burada tekrar olcerse `Padding`ten sonra kalan
              // 1064 px'i gorur ve daima tek pane'e duserdi — yani ikinci
              // sutun yazilir ama HIC cizilmezdi.
              breakpoint: 0,
              master: _DayMasterList(
                days: days,
                today: today,
                byDay: byDay,
                selected: selected,
                onSelected: (day) => setState(() => _selected = day),
              ),
              detail: _DayDetail(
                day: selected,
                today: today,
                total: secondsOnDay(byDay[selected]!, selected),
                sessions: byDay[selected]!,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// SPEC §3 A1: session history master sutunu **320**, pane araligi **16**.
const double kSessionMasterWidth = 320;
const double kSessionPaneSpacing = 16;

/// Masaustu iki-pane dalinin SOL sutunu: gunler.
///
/// Ayni verinin (gun + toplam + oturum sayisi) ayni gosterimi; yalniz kabi
/// degisti. Hicbir gun gizlenmez — `days` listesi tek sutun daliyla aynidir.
class _DayMasterList extends StatelessWidget {
  const _DayMasterList({
    required this.days,
    required this.today,
    required this.byDay,
    required this.selected,
    required this.onSelected,
  });

  final List<DateTime> days;
  final DateTime today;
  final Map<DateTime, List<StudySession>> byDay;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // SPEC §6 "BAGLA, ATMA": master sutunu icin depoda hazir duran, WP-627
    // kontrast duzeltmesi uygulanmis, klavye odakli liste.
    return DesktopSectionList(
      items: [
        for (final day in days)
          DesktopSectionItem(
            id: day.toIso8601String(),
            icon: isSameDay(day, today)
                ? Icons.today_outlined
                : Icons.calendar_month_outlined,
            label: isSameDay(day, today)
                ? l10n.profileBugun
                : _longDate(l10n, day),
            subtitle:
                '${formatHuman(secondsOnDay(byDay[day]!, day))} · '
                '${l10n.profileOturumSayisi(byDay[day]!.length)}',
          ),
      ],
      selectedId: selected.toIso8601String(),
      onSelected: (id) {
        for (final day in days) {
          if (day.toIso8601String() == id) {
            onSelected(day);
            return;
          }
        }
      },
    );
  }
}

/// Masaustu iki-pane dalinin SAG sutunu: secili gunun oturumlari.
///
/// Satirlar tek sutun dalindaki [_SessionTile]'in TA KENDISI — duzenle/sil
/// menusu, ders rengi, saat araligi ve manuel/sayac ikonu degismedi.
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.today,
    required this.total,
    required this.sessions,
  });

  final DateTime day;
  final DateTime today;
  final int total;
  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isSameDay(day, today)
                      ? l10n.profileBugun
                      : _longDate(l10n, day),
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatHuman(total),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        for (final s in sessions) _SessionTile(session: s),
      ],
    );
  }
}

/// Bugünün bölümü: başlık + her oturum ayrı satır (canlı takip).
class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.total, required this.sessions});

  final int total;
  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).profileBugun,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                formatHuman(total),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        for (final s in sessions) _SessionTile(session: s),
        Divider(height: 16),
      ],
    );
  }
}

/// Geçmiş bir gün: katlanabilir tek özet kayıt (gün + toplam + oturum sayısı);
/// açılınca o günün oturumları görünür (düzenleme/silme yine mümkün).
class _PastDayTile extends StatelessWidget {
  const _PastDayTile({
    required this.day,
    required this.total,
    required this.sessions,
  });

  final DateTime day;
  final int total;
  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: Border(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _longDate(AppLocalizations.of(context), day),
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text(
            formatHuman(total),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      subtitle: Text(
        // WP-504: gömülü "oturum" (WP-500 ile aynı sınıf).
        AppLocalizations.of(context).profileOturumSayisi(sessions.length),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [for (final s in sessions) _SessionTile(session: s)],
    );
  }
}

/// Saat:dakika (iki haneli) — oturum saat aralığı için.
///
/// WP-254: `session.start/end` DB'den UTC olarak parse edilir; ham `.hour`
/// yaz saatinde 3 saat geri gösteriyordu. Artık İstanbul duvar saati.
String _hm(DateTime t) => istanbulHm(t);

/// "21 Haziran 2026 Cumartesi" — okunaklı uzun tarih.
String _longDate(AppLocalizations l10n, DateTime d) =>
    DateFormat.yMMMMEEEEd(l10n.localeName).format(d);

/// Tek bir oturum satırı: süre, kaynak rozeti, düzenle/sil menüsü.
class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isManual = session.source == StudySource.manual;

    // Oturumun dersini bul (silinmiş/derssiz olabilir → null).
    final subjects = ref.watch(userSubjectsProvider).value ?? [];
    Subject? subject;
    for (final s in subjects) {
      if (s.id == session.subjectId) subject = s;
    }
    // Hem sayaç hem manuel oturumda gerçek saat aralığı gösterilir; manuel giriş
    // artık eklendiği andaki saate "bitmiş gibi" yerleştiği için saat anlamlıdır
    // (manuel/sayaç ayrımı baştaki ikonla korunur: edit_calendar / timer).
    final sourceLabel = '${_hm(session.start)}–${_hm(session.end)}';

    return ListTile(
      leading: Icon(
        isManual ? Icons.edit_calendar : Icons.timer_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(formatHuman(session.durationSeconds)),
      subtitle: subject == null
          ? Text(sourceLabel)
          : Row(
              children: [
                CircleAvatar(
                  radius: 5,
                  backgroundColor: subjectColor(subject.color),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$sourceLabel · ${subject.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            _edit(context, ref);
          } else if (v == 'delete') {
            _delete(context, ref);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            child: Text(AppLocalizations.of(context).profileDuzenle),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(AppLocalizations.of(context).profileSil),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final subjects = ref.read(userSubjectsProvider).value ?? [];
    final result = await showManualSessionDialog(
      context,
      // WP-254: UTC `start` verilirse gece yarısına yakın oturumlarda tarih
      // seçici YANLIŞ günü açar (ör. IST 01:30 → UTC 22:30, bir önceki gün).
      initialDate: istanbulDay(session.start),
      initialSeconds: session.durationSeconds,
      initialSubjectId: session.subjectId,
      subjects: subjects,
    );
    if (result == null) return;

    final range = manualSessionRange(result.date, result.seconds);
    await ref
        .read(studyRepositoryProvider)
        .updateSession(
          StudySession(
            id: session.id,
            userId: session.userId,
            subjectId: result.subjectId,
            start: range.start,
            end: range.end,
            durationSeconds: result.seconds,
            // Düzenlenen oturum manuel sayılır (kaynak ayrımı istatistiği etkilemez).
            source: StudySource.manual,
          ),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).profileKaydiSil),
        content: Text(
          AppLocalizations.of(context).profileBuCalismaKaydiSilinsin,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).profileVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).profileSil),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(studyRepositoryProvider).deleteSession(session.id);
  }
}
