import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/feedback_ticket.dart';
import '../../../data/models/feedback_ticket_message.dart';
import '../../../data/models/feedback_ticket_note.dart';
import '../../../data/models/moderation_case.dart';
import '../../../data/models/report_target.dart';
import '../../../data/providers/admin_moderation_providers.dart';
import '../../../data/providers/admin_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/repositories/admin_moderation_repository.dart';
import '../../../data/repositories/admin_repository.dart';
import '../queue/moderation_attachment_preview.dart';
import 'admin_case_conversations_page.dart';
import 'admin_user_profile_page.dart';
import '../queue/moderation_dialogs.dart';
import '../ticket/admin_ticket_detail_page.dart';

/// WP-769 — sikayetin **kendi tam sayfasi**.
///
/// 🔴 Sahip karari: *"her kartta sadece detayli incele butonu olsun, basinca
/// ayri bir sayfa acilsin o karta ozel ve her sey orada olsun; baska bir
/// ekrani istemiyorum."*
///
/// Bunun oncesinde inceleme, kuyrugun **yanindaki bolmede** aciliyordu
/// (`queue/moderation_review_view.dart`, WP-B). O tasarim kaniti ve karari ayni
/// anda ekranda tutuyordu ama sahip icin hala "parca parca"ydi: kanit dar
/// bolmede, hedefin gecmisi baska bir yuzeyde (Kisiler & Gruplar), sikayet
/// edenle yazisma bambaska bir sekmedeydi.
///
/// Bu sayfa o dagilmayi kapatir. Tek sayfada:
///   1. kanit (icerik, **ek gorsel**, aciklama, gerekce, zaman, baglam),
///   2. taraflar (kim sikayet etti, kim edildi),
///   3. hedefin dosyasi (aktif kisit + ceza gecmisi + kisit uygula/kaldir),
///   4. yazisma (sikayet edene yanit) ve kullaniciya bildirim,
///   5. **karar seridi** — sayfanin altina sabit.
///
/// 🔴 Serit `Scaffold.bottomSheet` ile kurulmaz (depoda kayitli tuzak: govdeyi
/// orter, yer ayirmaz). `Column` + `Expanded` kullanilir.
const Key kAdminCaseDetailKey = Key('admin-case-detail');

/// Kanit listesi — anahtar WP-B'den korunur, testler bunu ariyor.
const Key kModerationEvidenceKey = Key('moderation-evidence');

const Key kModerationDecisionBarKey = Key('moderation-decision-bar');
const Key kModerationDecisionReasonKey = Key('moderation-decision-reason');
const Key kModerationDecisionResolvedKey = Key('moderation-decision-resolved');
const Key kModerationDecisionRejectedKey = Key('moderation-decision-rejected');
const Key kModerationDecisionQuarantineKey = Key(
  'moderation-decision-quarantine',
);
/// Karar seridindeki tasma menusu (karantina buradan cikar).
const Key kModerationDecisionMoreKey = Key('moderation-decision-more');

/// Vaka sayfasindaki **Kullanicilar** bolumu: taraflar ve ceza gecmisi tek
/// yerde. Satira dokununca kisinin profil paneli acilir.
const Key kAdminCaseUsersKey = Key('admin-case-users');

/// Tek bir kullanici satiri; `userId` ile benzersizlesir.
Key adminCaseUserRowKey(String userId) => Key('admin-case-user-$userId');
const Key kModerationUndoBarKey = Key('moderation-undo-bar');
const Key kModerationUndoButtonKey = Key('moderation-undo-button');

/// Hedefin dosyasi — sayfanin **icinde**, ayri ekran degil.
const Key kAdminCaseTargetSummaryKey = Key('admin-case-target-summary');
const Key kAdminCaseSanctionApplyKey = Key('admin-case-sanction-apply');
const Key kAdminCaseSanctionRevokeKey = Key('admin-case-sanction-revoke');

/// Sikayet edenle yazisma (aynali destek kaydi).
const Key kAdminCaseReplyKey = Key('admin-case-reply');

/// WP-795: **Ic notlar** — yalniz yoneticiler gorur. Migration yok: notlar
/// vakanin ayna biletine (`report_ugc`, 0110) yazilir; bilet yoksa bolum
/// bunu soyler ve giris alani cizilmez.
const Key kAdminCaseNotesKey = Key('admin-case-notes');
const Key kAdminCaseNoteFieldKey = Key('admin-case-note-field');
const Key kAdminCaseNoteSendKey = Key('admin-case-note-send');

/// Tek bir not satiri; `noteId` ile benzersizlesir.
Key adminCaseNoteRowKey(String noteId) => Key('admin-case-note-$noteId');

/// Hedefe dogrudan bildirim (kullaniciya ozel duyuru).
const Key kAdminCaseNoticeTitleKey = Key('admin-case-notice-title');
const Key kAdminCaseNoticeBodyKey = Key('admin-case-notice-body');
const Key kAdminCaseNoticeSendKey = Key('admin-case-notice-send');

/// PLAN §4.4.2: geri alinabilir karar teyit istemez, **10 saniyelik** serit
/// acar. Teyit enflasyonu teyidi oldurur.
const Duration kModerationUndoWindow = Duration(seconds: 10);

/// Kuyruk satirindaki tek dugmenin actigi yer.
Future<void> openAdminCaseDetail(
  BuildContext context, {
  required ModerationCase moderationCase,
  FeedbackTicket? mirrorTicket,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminCaseDetailPage(
        moderationCase: moderationCase,
        mirrorTicket: mirrorTicket,
      ),
    ),
  );
}

class AdminCaseDetailPage extends ConsumerStatefulWidget {
  const AdminCaseDetailPage({
    super.key,
    required this.moderationCase,
    this.mirrorTicket,
  });

  final ModerationCase moderationCase;

  /// `report_ugc` her sikayet icin bir destek kaydi da acar. Sikayet edenle
  /// yazismanin tek kanali odur; kuyruk onu listede gizler ve buraya verir.
  final FeedbackTicket? mirrorTicket;

  @override
  ConsumerState<AdminCaseDetailPage> createState() =>
      _AdminCaseDetailPageState();
}

class _UndoEntry {
  const _UndoEntry({
    required this.previousStatus,
    required this.appliedStatus,
  });

  final ModerationCaseStatus previousStatus;
  final ModerationCaseStatus appliedStatus;
}

class _AdminCaseDetailPageState extends ConsumerState<AdminCaseDetailPage> {
  final TextEditingController _noticeTitle = TextEditingController();
  final TextEditingController _noticeBody = TextEditingController();

  late ModerationCase _case = widget.moderationCase;
  _UndoEntry? _undo;
  Timer? _undoTimer;

  /// Ayni sayfa farkli bir vakayla yeniden kurulursa yerel kopya tazelenir.
  /// Her vaka kendi rotasinda acildigi icin uretimde nadirdir; testte ve
  /// gelecekteki bir liste-detay kullaniminda sessiz yanlis vakayi engeller.
  @override
  void didUpdateWidget(AdminCaseDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moderationCase.caseKey != widget.moderationCase.caseKey) {
      _undoTimer?.cancel();
      _undo = null;
      _case = widget.moderationCase;
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _noticeTitle.dispose();
    _noticeBody.dispose();
    super.dispose();
  }

  String? get _reportId =>
      _case.reportIds.isEmpty ? null : _case.reportIds.first;

  String? get _targetUserId {
    final identity = _case.targetIdentity;
    if (identity == null || identity.isDeleted) return null;
    return identity.id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 🔴 Sonuc kullanilmiyor ama bu satir GEREKLI ve silinemez.
    // `authStateProvider`i CANLI tutar. Onsuz, dugmeye basildiginda yapilan
    // `ref.read(authStateProvider...)` dinleyicisiz bir provider yaratir,
    // provider okumadan hemen sonra dusurulur ve `.value` sonsuza kadar
    // `AsyncLoading` kalir -- dugme SESSIZCE hicbir sey yapmaz. Depoda kayitli
    // tuzak: `riverpod3-autodispose-test-trap`. Nobetci testi bunu yakaladi.
    ref.watch(authStateProvider);
    return Scaffold(
      key: kAdminCaseDetailKey,
      appBar: AppBar(title: Text(l10n.adminVakaDetayBaslik)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // SPEC §3: form/okuma sutunu tavani 760.
            constraints: const BoxConstraints(
              maxWidth: DesktopBreakpoints.maxFormWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_undo != null) _undoBar(context),
                Expanded(child: _body(context)),
                _DecisionBar(
                  moderationCase: _case,
                  onStatus: _applyStatus,
                  onQuarantine: _askQuarantineReason,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Govde ------------------------------------------------------------

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reportId = _reportId;
    if (reportId == null) {
      // 🔴 Eskiden bu vakada kart hic acilmiyordu ve NEDEN acilmadigini
      // soylemiyordu (PLAN §2.2 "sessiz olu dokunus").
      return ListView(
        key: kModerationEvidenceKey,
        padding: const EdgeInsets.all(16),
        children: [
          _header(context),
          const SizedBox(height: 12),
          Text(l10n.adminIncelemeDetayYok),
          const SizedBox(height: 24),
          ..._users(context),
          ..._notes(context),
          ..._contactFold(context),
        ],
      );
    }

    final detail = ref.watch(moderationCaseDetailProvider(reportId));
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(l10n.profileBeklenmeyenBirHataOlustu)),
      data: (data) => ListView(
        key: kModerationEvidenceKey,
        padding: const EdgeInsets.all(16),
        children: [
          _header(context),
          const SizedBox(height: 16),
          ..._evidence(context, data),
          const SizedBox(height: 24),
          ..._users(context, detail: data),
          ..._notes(context),
          ..._contactFold(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final identity = _case.targetIdentity;
    final name = identity == null || identity.isDeleted
        ? l10n.adminUgcDeletedUser
        : identity.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.adminUgcTarget}: $name',
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          _targetTypeLabel(l10n, _case.targetType),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _evidence(BuildContext context, ModerationCaseDetail data) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      _section(context, l10n.adminIncelemeIcerik),
      SelectableText(
        data.snapshot.trim().isEmpty
            ? l10n.adminIncelemeIcerikYok
            : data.snapshot,
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      _section(context, l10n.adminIncelemeEk),
      if (data.attachmentPath != null)
        ModerationAttachmentButton(path: data.attachmentPath!)
      else
        Text(l10n.adminIncelemeEkYok, style: theme.textTheme.bodySmall),
      if ((data.details ?? '').isNotEmpty) ...[
        const SizedBox(height: 16),
        _section(context, l10n.adminIncelemeAciklama),
        SelectableText(data.details!),
      ],
      const SizedBox(height: 16),
      _meta(context, data),
      if (data.contextMessages.isNotEmpty) ...[
        const SizedBox(height: 16),
        _section(context, l10n.adminIncelemeBaglam),
        for (final message in data.contextMessages)
          ListTile(
            dense: true,
            title: Text(message.displayName),
            subtitle: Text(message.body),
            selected: message.isTarget,
          ),
      ],
    ];
  }
  /// Yazisma + bildirim: karari **anlatmanin** iki yolu da sayfada.
  /// Gerekce · gelis zamani · rapor sayisi.
  Widget _meta(BuildContext context, ModerationCaseDetail data) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final createdAt = data.createdAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.adminIncelemeGerekce}: '
          '${_reasonLabel(l10n, data.reason ?? '')}',
          style: theme.textTheme.bodyMedium,
        ),
        if (createdAt != null) ...[
          const SizedBox(height: 4),
          Text(
            '${l10n.adminIncelemeGelisZamani}: '
            '${MaterialLocalizations.of(context).formatFullDate(createdAt)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  /// **Kullanicilar** — taraflar ve ceza gecmisi TEK bolumde.
  ///
  /// 🔴 WP-775, sahibin sozleri: *"ceza gecmisi kismi yerine kullanicilar
  /// olsun, oradan olaya dahil iki kisinin de gecmisini goreyim... basinca
  /// detayli profil ekrani acilsin."* Ayrica: *"taraflarla ceza gecmisini
  /// birlestirebilirsin."*
  ///
  /// Eskiden bu bilgi UC ayri bolume dagilmisti: `Taraflar` (isim + ham UUID),
  /// `Kisi dosyasi` (aktif kisit) ve `Hedefin gecmisi` (duz metin satirlar).
  /// Ucu de ayni kisi hakkindaydi ve hicbiri otekine baglanmiyordu; ustelik
  /// gecmis YALNIZ hedef icin vardi, sikayet EDENIN gecmisi hic gorunmuyordu.
  ///
  /// Satirda tek bakislik isaret duruyor, ayrinti dokununca acilir. Boylece
  /// WP-769'un sarti da korunur: cogu vakada panele girmeden karar verilebilir.
  List<Widget> _users(BuildContext context, {ModerationCaseDetail? detail}) {
    final l10n = AppLocalizations.of(context);
    final identity = _case.targetIdentity;
    final count = detail?.reportCount ?? _case.reportCount;
    return [
      _section(context, l10n.adminVakaTaraflar),
      _CaseUserRow(
        key: adminCaseUserRowKey(_case.targetId),
        userId: _targetUserId,
        name: identity == null || identity.isDeleted
            ? l10n.adminUgcDeletedUser
            : identity.displayName,
        role: l10n.adminUgcTarget,
        caseId: _case.caseId,
      ),
      for (final reporter in _case.reporters)
        _CaseUserRow(
          key: adminCaseUserRowKey(reporter.id),
          userId: reporter.isDeleted ? null : reporter.id,
          name: reporter.isDeleted
              ? l10n.adminUgcDeletedUser
              : reporter.displayName,
          role: l10n.adminUgcReporter,
          caseId: _case.caseId,
        ),
      const SizedBox(height: 4),
      Text(
        l10n.adminVakaSikayetSayisi(count),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
    ];
  }

  /// **Ic notlar** — Kullanicilar'dan sonra, yazisma katindan once.
  ///
  /// WP-795, sahibin onayladigi onizleme. Veri katmani yeni degil: her UGC
  /// sikayeti bir ayna destek bileti acar ve bilet notlari zaten var
  /// (`fetchTicketNotes` / `addTicketNote`). Bolum o bilete yazar.
  ///
  /// Ayna bilet yoksa (rapor kimligi cozulmeyen eski vaka) alan cizilmez ve
  /// NEDEN cizilmedigi soylenir — sessiz bosluk degil.
  List<Widget> _notes(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ticket = widget.mirrorTicket;
    return [
      Column(
        key: kAdminCaseNotesKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(context, l10n.adminIcNotlar),
          if (ticket == null)
            Text(
              l10n.adminVakaNotYok,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            _CaseNotes(ticketId: ticket.id),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Yazisma + bildirim — **katlanmis**.
  ///
  /// 🔴 Bildirim yazma alani (iki metin kutusu + dugme) surekli ACIK
  /// duruyordu. Nadiren kullanilan bir sey icin kalici yer; sahip sayfayi
  /// "duvar" diye tarif etti. Icerik ayni, yalniz varsayilan olarak kapali.
  List<Widget> _contactFold(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: const Key('admin-case-contact-fold'),
          title: Text(l10n.adminVakaYanitBaslik),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: _contact(context),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _contact(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ticket = widget.mirrorTicket;
    final targetUserId = _targetUserId;
    return [
      _section(context, l10n.adminVakaYanitBaslik),
      if (_reportId != null)
        // WP-780 DIKIS: iki tarafli yazisma. Sahip "iki taraflara ayri chat
        // sohbeti olsun, direkt gecmis konusmalari da goreyim" dedi; tek
        // aynali bilet bunu karsilamiyordu (yalniz sikayet EDEN tarafi vardi).
        OutlinedButton.icon(
          key: kAdminCaseReplyKey,
          onPressed: _openConversations,
          icon: const Icon(Icons.forum_outlined, size: 20),
          label: Text(l10n.adminVakaYanitBaslik),
        )
      else if (ticket == null)
        Text(l10n.adminVakaYanitYok, style: theme.textTheme.bodySmall)
      else
        // Rapor kimligi cozulemeyen vaka: kanal RPC'si anahtarsiz calisamaz,
        // eski tek-bilet yuzeyi YEDEK olarak durur. Kaldirmak, o vakalarda
        // yoneticiyi yazisamaz birakirdi.
        OutlinedButton.icon(
          key: kAdminCaseReplyKey,
          onPressed: () =>
              openAdminTicketDetail(context: context, ticket: ticket),
          icon: const Icon(Icons.forum_outlined, size: 20),
          label: Text(l10n.adminVakaYanitBaslik),
        ),
      if (targetUserId != null) ...[
        const SizedBox(height: 24),
        _section(context, l10n.adminVakaBildirimBaslik),
        TextField(
          key: kAdminCaseNoticeTitleKey,
          controller: _noticeTitle,
          decoration: InputDecoration(
            labelText: l10n.adminBaslik,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: kAdminCaseNoticeBodyKey,
          controller: _noticeBody,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.adminMesaj,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: kAdminCaseNoticeSendKey,
            onPressed: () => _sendNotice(targetUserId),
            icon: const Icon(Icons.campaign_outlined, size: 20),
            label: Text(l10n.adminGonder),
          ),
        ),
      ],
    ];
  }

  Widget _undoBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: kModerationUndoBarKey,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusText(l10n, _undo!.appliedStatus),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(
            key: kModerationUndoButtonKey,
            onPressed: _undoLastDecision,
            child: Text(l10n.adminIncelemeGeriAl),
          ),
        ],
      ),
    );
  }

  // --- Kararlar ---------------------------------------------------------

  /// Durum degisimi.
  ///
  /// 🔴 WP-769 hata (a): `setCaseStatus` **etkilenen satir sayisini** donuyor
  /// (`admin_set_ugc_report_group_status` `returns bigint`), ekran bu sayiyi
  /// hic okumuyordu. `0104` oncesi kapanmis raporlarin vakasi yok; RPC sifir
  /// satir gunceller ve ekran yine "Cozuldu" yazip geri alma seridi acardi.
  /// Artik sifir satirda **basari iddia edilmez**.
  Future<void> _applyStatus(ModerationCaseStatus status) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final previous = _case.status;
    final int affected;
    try {
      affected = await ref
          .read(adminModerationRepositoryProvider)
          .setCaseStatus(moderationCase: _case, status: status);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    if (affected == 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminVakaDurumBagimsizUyari)),
      );
      return;
    }
    _refresh();
    setState(() => _case = _case.copyWith(status: status));
    _armUndo(_UndoEntry(previousStatus: previous, appliedStatus: status));
    messenger.showSnackBar(SnackBar(content: Text(_statusText(l10n, status))));
  }

  void _armUndo(_UndoEntry entry) {
    _undoTimer?.cancel();
    setState(() => _undo = entry);
    _undoTimer = Timer(kModerationUndoWindow, () {
      if (!mounted) return;
      setState(() => _undo = null);
    });
  }

  Future<void> _undoLastDecision() async {
    final entry = _undo;
    if (entry == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .setCaseStatus(
            moderationCase: _case,
            status: entry.previousStatus,
          );
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _undoTimer?.cancel();
    _refresh();
    if (!mounted) return;
    setState(() {
      _case = _case.copyWith(status: entry.previousStatus);
      _undo = null;
    });
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminIncelemeKararGeriAlindi)),
    );
  }

  /// Gerekceyi **gerektigi anda** sorar.
  ///
  /// 🔴 WP-775: eskiden serit kalici bir gerekce alani tasiyordu ve o alan
  /// yalniz BU eylemde okunuyordu. Dort eylemden ucu icin bosuna ekranda
  /// duruyordu (bkz. [_DecisionBar]). Depoda hazir duran
  /// [askModerationReason] tek kaynaktir: bos gerekce sessizce "gerekce
  /// belirtilmedi"ye cevrilmez, islem hic yapilmaz.
  Future<void> _askQuarantineReason() async {
    final l10n = AppLocalizations.of(context);
    final reason = await askModerationReason(
      context,
      _case.quarantined
          ? l10n.adminModerationQuarantineRelease
          : l10n.adminModerationQuarantine,
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final next = !_case.quarantined;
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .setQuarantine(
            moderationCase: _case,
            quarantined: next,
            reason: reason,
          );
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _refresh();
    if (!mounted) return;
    setState(() => _case = _case.copyWith(quarantined: next));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          next
              ? l10n.adminModerationQuarantined
              : l10n.adminModerationQuarantineRelease,
        ),
      ),
    );
  }
  /// Kullaniciya dogrudan bildirim — hedefe ozel duyuru
  /// (`announcements.target_type = 'user'`).
  /// WP-780 — vaka yazismasini acar.
  ///
  /// 🔴 Kanal listesi RPC'den gelir, `_case`ten TURETILMEZ. Sikayet edilen
  /// tarafin bileti **tembeldir**: yonetici gercekten yazana kadar yoktur.
  /// Kimlikleri burada uydursaydik, ilk mesajdan sonra gecmis okunamazdi.
  Future<void> _openConversations() async {
    final reportId = _reportId;
    if (reportId == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // 🔴 `.value` DEGIL `.future`. `authStateProvider` bir `StreamProvider`;
    // o an baska bir dinleyicisi yoksa `read(...).value` yukleniyor halinde
    // `null` doner ve dugme SESSIZCE hicbir sey yapmaz -- deponun kayitli
    // Riverpod tuzagi. Nobetci testi tam olarak bunu yakaladi.
    final admin = await ref.read(authStateProvider.future);
    if (!mounted || admin == null) return;

    final List<CaseConversationChannel> channels;
    try {
      channels = await ref.read(
        adminCaseConversationChannelsProvider(reportId).future,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileBeklenmeyenBirHataOlustu)),
      );
      return;
    }
    if (!mounted) return;
    if (channels.isEmpty) {
      // Sessiz olu dokunus olmasin: neden acilmadigi soylenir.
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminVakaYanitYok)));
      return;
    }

    final ticketIds = <CasePartyRole, String?>{
      for (final channel in channels) _roleOf(channel.party): channel.ticketId,
    };
    await openAdminCaseConversations(
      context,
      parties: [
        for (final channel in channels)
          CaseParty(
            role: _roleOf(channel.party),
            userId: channel.userId,
            displayName: channel.displayName ?? l10n.adminUgcDeletedUser,
            ticketId: channel.ticketId,
          ),
      ],
      gateway: _CaseGateway(
        repo: ref.read(adminRepositoryProvider),
        adminId: admin.id,
        reportId: reportId,
        ticketIds: ticketIds,
      ),
    );
    if (!mounted) return;
    // Tembel kanal acilmis olabilir; liste bayat kalmasin.
    ref.invalidate(adminCaseConversationChannelsProvider(reportId));
  }

  static CasePartyRole _roleOf(CaseConversationParty party) => switch (party) {
    CaseConversationParty.reporter => CasePartyRole.reporter,
    CaseConversationParty.reported => CasePartyRole.reported,
  };

  Future<void> _sendNotice(String targetUserId) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = _noticeTitle.text.trim();
    final message = _noticeBody.text.trim();
    if (title.isEmpty || message.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminGerekliAlanlarDoldurulmalidir)),
      );
      return;
    }
    final admin = ref.read(authStateProvider).value;
    if (admin == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .createAnnouncement(
            title: title,
            message: message,
            targetType: 'user',
            targetId: targetUserId,
            adminId: admin.id,
          );
    } on AdminException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(adminAnnouncementsProvider);
    if (!mounted) return;
    _noticeTitle.clear();
    _noticeBody.clear();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminVakaBildirimGonderildi)),
    );
  }

  /// 🔴 WP-769 hata (b): kanit panosu **hicbir eylemden sonra tazelenmiyordu**.
  /// `moderationCaseDetailProvider` autoDispose degil ve depoda tek bir
  /// `invalidate` cagrisi yoktu; yaptirim uygulandiktan sonra "Gecmis" blogu
  /// hala yaptirim oncesi listeyi cizip yoneticiyi ikinci kez uygulamaya
  /// itiyordu.
  void _refresh() {
    ref.invalidate(moderationQueueProvider);
    final reportId = _reportId;
    if (reportId != null) {
      ref.invalidate(moderationCaseDetailProvider(reportId));
    }
    final targetUserId = _targetUserId;
    if (targetUserId != null) {
      ref.invalidate(moderationSanctionsProvider(targetUserId));
    }
  }

  static Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

/// Vaka sayfasindaki tek kullanici satiri.
///
/// Satir tek bakislik bir isaret tasir: kisinin hakkindaki sikayetlerin kaci
/// haklı cikmis. Ayrinti dokununca acilan profil panelindedir.
///
/// 🔴 Isaret bir **kolayliktir**, sayfanin isleyisi ona bagli DEGILDIR:
/// oranlar sunucudan gelir ve o sorgu (`admin_user_insight`) henuz
/// uygulanmamis bir migration'a bagli. Veri gelmezse satir adiyla ve roluyle
/// yine cizilir. Ama hata SESSIZCE yutulmaz — "olculemedi" ile "sikayet yok"
/// ayni gorunmez, cunku ikisi ayni sey degildir.
class _CaseUserRow extends ConsumerWidget {
  const _CaseUserRow({
    super.key,
    required this.userId,
    required this.name,
    required this.role,
    this.caseId,
  });

  /// `null` = silinmis hesap; profil acilamaz.
  final String? userId;
  final String name;
  final String role;

  /// Yaptirimi doguran vaka; denetim kaydinda gorunsun diye tasinir.
  final String? caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final id = userId;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            _initials(name),
            style: theme.textTheme.labelLarge,
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(role, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: id == null ? null : _Signal(userId: id),
        onTap: id == null ? null : () => _open(context, id),
      ),
    );
  }

  void _open(BuildContext context, String id) {
    // 🔴 DIKIS: profil paneli ayri bir lane'de yazildi. Bu cagri liderin
    // isidir ve `verified_admin_case_contract_test` ile kilitlenir —
    // "iki ajan birbirinin yoluna saygi gosterip ozelligi baglamadan birakir"
    // tuzagi bu depoda yasandi.
    openAdminUserProfile(
      context,
      userId: id,
      displayName: name,
      caseId: caseId,
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase());
    return letters.join();
  }
}

/// Satirdaki oran rozeti.
class _Signal extends ConsumerWidget {
  const _Signal({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insight = ref.watch(adminUserInsightProvider(userId));
    return insight.when(
      loading: () => const SizedBox.shrink(),
      // Hata YUTULMAZ: rozet yerine olculemedigini soyleyen bir isaret durur.
      error: (_, _) => Tooltip(
        message: AppLocalizations.of(context).profileBeklenmeyenBirHataOlustu,
        child: Icon(
          Icons.report_gmailerrorred_outlined,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      data: (data) {
        final total = data.reportsAgainst;
        if (total <= 0) return const SizedBox.shrink();
        final scheme = theme.colorScheme;
        // Yuksek oran = tekrar eden ve cogunlukla hakli cikan bir oruntu.
        final bad = data.flaggedAsOffender;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bad ? scheme.errorContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${data.reportsAgainstUpheld}/$total',
            style: theme.textTheme.labelMedium?.copyWith(
              color: bad ? scheme.onErrorContainer : scheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

/// Vaka ic notlari — ayna biletin notlari, sayfanin govdesinde.
///
/// `ticket/admin_ticket_detail_page.dart` `_TicketNotes` deseninin kopyasi;
/// iki fark var: satir kimligi anahtarlanir (test satiri arar) ve gonderim
/// `authStateProvider.future` ile bekler (bkz. [_add]).
class _CaseNotes extends ConsumerStatefulWidget {
  const _CaseNotes({required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<_CaseNotes> createState() => _CaseNotesState();
}

class _CaseNotesState extends ConsumerState<_CaseNotes> {
  final _controller = TextEditingController();
  List<FeedbackTicketNote>? _notes;
  bool _loading = true;

  /// Okuma hatasi ile "not yok" ayri durumlardir (WP-770 dersi: hata
  /// yutulunca govde BOS ciziliyordu).
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final notes = await ref
          .read(adminRepositoryProvider)
          .fetchTicketNotes(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notes = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    // Bos not sunucuya gitmez.
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    // 🔴 `.value` DEGIL `.future` — dinleyicisiz anda `.value` null doner ve
    // dugme sessizce hicbir sey yapmaz (depoda kayitli Riverpod tuzagi).
    final admin = await ref.read(authStateProvider.future);
    if (!mounted || admin == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .addTicketNote(
            ticketId: widget.ticketId,
            note: text,
            adminId: admin.id,
          );
    } on AdminException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    _controller.clear();
    await _load();
  }

  Widget _body(AppLocalizations l10n, String? currentAdminId) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_failed) {
      return Row(
        children: [
          Expanded(child: Text(l10n.adminBiletNotOkunamadi)),
          IconButton(
            tooltip: l10n.updaterTekrarDene,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      );
    }
    final notes = _notes ?? const <FeedbackTicketNote>[];
    if (notes.isEmpty) return Text(l10n.adminHenuzNotYok);
    return Column(
      children: [
        for (final note in notes)
          ListTile(
            key: adminCaseNoteRowKey(note.id),
            contentPadding: EdgeInsets.zero,
            title: Text(note.note),
            // "sen" / admin kimligi · tarih. Silinen admin icin `0114` alani
            // NULL'lar (WP-464).
            subtitle: Text(
              '${_author(l10n, note.adminId, currentAdminId)} · '
              '${note.createdAt.toString().substring(0, 16)}',
            ),
          ),
      ],
    );
  }

  static String _author(
    AppLocalizations l10n,
    String? adminId,
    String? currentAdminId,
  ) {
    if (adminId == null) return l10n.adminUgcDeletedUser;
    if (adminId == currentAdminId) return l10n.feedbackYou;
    return adminId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currentAdminId = ref.watch(authStateProvider).value?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminIcNotlarGizli,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _body(l10n, currentAdminId),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: kAdminCaseNoteFieldKey,
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l10n.adminYeniNot,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              key: kAdminCaseNoteSendKey,
              onPressed: _add,
              child: Text(l10n.adminNotEkle),
            ),
          ],
        ),
      ],
    );
  }
}

/// Karar seridi tasma menusundeki eylemler.
enum _CaseMenuAction { quarantine }

/// Karar seridi — **tek satir**.
///
/// 🔴 WP-775, sahibin cihazda gordugu sikayet: *"altta reject vs nin oldugu
/// kisimda kapanip acilabilsin ya da baska bir cozum bul, cok yer kapliyor."*
///
/// Eski serit 196 dp idi ve bunu su parcalardan topluyordu: baslik 20, gerekce
/// alani 48, iki satira saran dort dugme 88, ic bosluk ve aralar 40.
/// Telefonda ekranin dortte biri, sen daha kaniti okurken.
///
/// **Katlanir yapilmadi.** Katlanmak her karara BIR DOKUNUS daha ekler ve
/// gunluk is tam da o iki karardir. Sik olani ucretsiz birakmak, nadiri bir
/// dokunusa gondermekten daha iyi.
///
/// 🔴 GEREKCE ALANI TAMAMEN KALKTI ve sebebi olculdu: dort eylemden yalniz
/// BIRI onu okuyordu. [ModerationCaseStatus] degisimi `setCaseStatus`
/// uzerinden gider ve o imzada gerekce alani **yoktur** -- yani `Coz` ve
/// `Reddet` yazilani hicbir zaman sunucuya tasimadi. Kalici olarak ekranda
/// duran alan, islerin cogunda bosuna yer kapliyordu. Artik gerekcenin
/// GERCEKTEN gerektigi yerde, karantina sayfasinda soruluyor.
///
/// Yaptirim da buradan kalkti: kisiye uygulanan bir karardir ve kisinin
/// profilinde, oranlari ve ceza gecmisi gorunurken verilir
/// ([kAdminCaseUsersKey] satirlarina dokununca acilan panel).
class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.moderationCase,
    required this.onStatus,
    required this.onQuarantine,
  });

  final ModerationCase moderationCase;
  final ValueChanged<ModerationCaseStatus> onStatus;
  final VoidCallback onQuarantine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: kModerationDecisionBarKey,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: kModerationDecisionRejectedKey,
              onPressed: () => onStatus(ModerationCaseStatus.rejected),
              child: Text(
                l10n.adminUgcStatusRejected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              key: kModerationDecisionResolvedKey,
              onPressed: () => onStatus(ModerationCaseStatus.resolved),
              child: Text(
                l10n.adminUgcStatusResolved,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Karantina ICERIGE uygulanir (o mesaji gizler), kisiye degil. Karari
          // verirken kanit onunde oldugu icin serit menusunde durur.
          // 🔴 Deger tipi `void`/`null` OLAMAZ: `PopupMenuButton.onSelected`
          // yalniz null OLMAYAN bir deger secilince cagrilir. `value: null`
          // ile menu acilir, ogeye dokunulur ve HICBIR SEY olmaz -- sessiz
          // olu dokunus. Nobetci bunu yakaladi.
          PopupMenuButton<_CaseMenuAction>(
            key: kModerationDecisionMoreKey,
            tooltip: l10n.adminIncelemeKarar,
            enabled: moderationCase.supportsCaseActions,
            onSelected: (action) => switch (action) {
              _CaseMenuAction.quarantine => onQuarantine(),
            },
            itemBuilder: (context) => [
              PopupMenuItem<_CaseMenuAction>(
                key: kModerationDecisionQuarantineKey,
                value: _CaseMenuAction.quarantine,
                child: Text(
                  moderationCase.quarantined
                      ? l10n.adminModerationQuarantineRelease
                      : l10n.adminModerationQuarantine,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusText(AppLocalizations l10n, ModerationCaseStatus status) =>
    switch (status) {
      ModerationCaseStatus.open => l10n.adminAcik,
      ModerationCaseStatus.inReview => l10n.adminUgcStatusInReview,
      ModerationCaseStatus.resolved => l10n.adminUgcStatusResolved,
      ModerationCaseStatus.rejected => l10n.adminUgcStatusRejected,
    };

String _targetTypeLabel(AppLocalizations l10n, ReportTargetType type) =>
    switch (type) {
      ReportTargetType.message => l10n.classroomSohbet,
      ReportTargetType.profile => l10n.adminUgcTarget,
      ReportTargetType.group => l10n.classroomGrup,
      ReportTargetType.groupName => l10n.classroomGrupAdi,
    };

String _reasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
  'harassment' => l10n.safetyReasonHarassment,
  'spam' => l10n.safetyReasonSpam,
  'hate' => l10n.safetyReasonHate,
  'illegal' => l10n.safetyReasonIllegal,
  'other' => l10n.safetyReasonOther,
  _ => reason.isEmpty ? '—' : reason,
};


/// WP-780 — sayfa ile depo arasindaki adaptor.
///
/// 🔴 Neden `features/` altinda: veri katmani `CaseParty`/`CasePartyRole`
/// tanimaz ve tanimamalidir. Sayfanin sozlesmesi ile deponun sozlesmesi
/// birbirine burada cevrilir.
class _CaseGateway implements CaseConversationGateway {
  _CaseGateway({
    required this.repo,
    required this.adminId,
    required this.reportId,
    required Map<CasePartyRole, String?> ticketIds,
  }) : _ticketIds = {...ticketIds};

  final AdminRepository repo;
  final String adminId;
  final String reportId;

  /// 🔴 Tembel kanalin kimligi. `send` yeni bilet acinca BURADA guncellenir;
  /// guncellenmezse yoneticinin az once yazdigi mesaj `messages()` ile geri
  /// okunamaz ve ekranda kaybolur.
  final Map<CasePartyRole, String?> _ticketIds;

  static CaseConversationParty _party(CasePartyRole role) => switch (role) {
    CasePartyRole.reporter => CaseConversationParty.reporter,
    CasePartyRole.reported => CaseConversationParty.reported,
  };

  @override
  Future<List<FeedbackTicketMessage>> messages(CaseParty party) async {
    final ticketId = _ticketIds[party.role];
    // Kanal henuz yok — hata degil, "ilk mesaji siz yazin" halidir.
    if (ticketId == null) return const [];
    return repo.fetchTicketMessages(userId: adminId, ticketId: ticketId);
  }

  @override
  Future<void> send({
    required CaseParty party,
    required String message,
    Uint8List? photoBytes,
    String? photoExt,
  }) async {
    final sent = await repo.sendCaseMessage(
      userId: adminId,
      reportId: reportId,
      party: _party(party.role),
      message: message,
      attachmentBytes: photoBytes,
      attachmentExt: photoExt,
    );
    _ticketIds[party.role] = sent.ticketId;
  }

  @override
  Future<String?> photoUrl(String attachmentPath) =>
      repo.getTicketMessageAttachmentUrl(attachmentPath);
}
