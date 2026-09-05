/// WP-778 — vakanin **iki tarafiyla ayri** yazisma.
///
/// 🔴 Sahip karari: *"yanit ve geri bildirim kismi yenilensin. iki taraflara
/// ayri chat sohbeti olsun, direkt gecmis konusmalarida gorebileyim ben sormak
/// istersem diye. ek olarak bu sohbet ve sikayetlerde foto yuklenebilsin 1
/// tane."*
///
/// Onceki durumda yalniz **sikayet EDENle** kanal vardi (`report_ugc`'nin
/// actigi ayna destek kaydi). Sikayet EDILENe yonetici hicbir sey yazamiyordu;
/// tek yol tek yonlu duyuruydu. Bu sayfa iki kanali tek yerde toplar, gecmis
/// mesajlari balon olarak gosterir ve altta **tek** yazma seridi birakir.
///
/// 🔴 Serit `Scaffold.bottomSheet` ile kurulmaz (depoda kayitli tuzak: govdeyi
/// orter, yer ayirmaz). `Column` + `Expanded` kullanilir.
///
/// Yazma seridi **bir tanedir** ve secili tarafa yazar. Iki serit cizmek hem
/// anahtarlari coklardi hem de yaninda duran ikinci bir taslak birakirdi;
/// taslaklar bunun yerine taraf basina saklanir, sekme degisince degistirilir
/// (A tarafina yazilan yari cumle B tarafina gonderilemez).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:online_study_room/data/models/feedback_ticket_message.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Sayfanin govdesi.
const Key kCaseConversationsKey = Key('case-conversations');

/// Taraf sekmesi. Rol basina tekildir.
Key kCaseConversationTabKey(CasePartyRole role) =>
    Key('case-conversation-tab-${role.name}');

/// Yazma seridindeki gonder dugmesi.
const Key kCaseConversationSendKey = Key('case-conversation-send');

/// Yazma seridindeki atac (tek foto) dugmesi.
const Key kCaseConversationAttachKey = Key('case-conversation-attach');

/// Yazma seridindeki metin alani.
const Key kCaseConversationInputKey = Key('case-conversation-input');

/// Secili tarafa eklenmis fotografin onizlemesi.
const Key kCaseConversationPhotoPreviewKey = Key(
  'case-conversation-photo-preview',
);

/// Vakanin bir tarafi.
enum CasePartyRole { reporter, reported }

/// Yazismanin muhatabi olan kisi.
///
/// [ticketId] `null` ise o tarafla **henuz kanal yoktur**. Bu bos ekran demek
/// degildir: ekran "ilk mesaji siz yazin" der ve yazma seridi acik kalir;
/// kanali [CaseConversationGateway.send] acar.
@immutable
class CaseParty {
  const CaseParty({
    required this.role,
    required this.userId,
    required this.displayName,
    this.ticketId,
  });

  final CasePartyRole role;
  final String userId;
  final String displayName;
  final String? ticketId;
}

/// Sayfaya eklenen tek fotograf (bayt + uzanti).
@immutable
class CaseConversationPhoto {
  const CaseConversationPhoto({required this.bytes, required this.ext});

  final Uint8List bytes;
  final String ext;
}

/// Fotograf secme dikisi. Varsayilani galeridir; test sahte bir secici verir.
typedef CaseConversationPhotoPicker =
    Future<CaseConversationPhoto?> Function(BuildContext context);

/// Yazismanin veri dikisi.
///
/// 🔴 Bu sayfa depoya **dogrudan** bagli degildir, cunku iki islem
/// (`ticket_message_attachments` yuklemesi ve `admin_send_case_message` ile
/// kanalin tembel acilmasi) `AdminRepository`'de henuz yoktur. Dikisi zorunlu
/// parametre yapmak, sayfanin yarim baglanmasini derleme hatasina cevirir:
/// cagiran taraf gecmeden sayfa acilamaz.
abstract class CaseConversationGateway {
  /// Tarafin gecmis mesajlari, eskiden yeniye.
  ///
  /// Kanali olmayan taraf icin **bos liste** doner; hata degildir.
  Future<List<FeedbackTicketMessage>> messages(CaseParty party);

  /// Metin + opsiyonel **tek** fotograf. Taraf kanali yoksa gateway acar.
  Future<void> send({
    required CaseParty party,
    required String message,
    Uint8List? photoBytes,
    String? photoExt,
  });

  /// Mesaja ekli fotografin imzali adresi. `null` = gosterilemiyor.
  Future<String?> photoUrl(String attachmentPath);
}

/// Vaka sayfasindan tek giris. Imza sabittir.
Future<void> openAdminCaseConversations(
  BuildContext context, {
  required List<CaseParty> parties,
  required CaseConversationGateway gateway,
  CaseConversationPhotoPicker? photoPicker,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminCaseConversationsPage(
        parties: parties,
        gateway: gateway,
        photoPicker: photoPicker,
      ),
    ),
  );
}

class AdminCaseConversationsPage extends StatefulWidget {
  const AdminCaseConversationsPage({
    super.key,
    required this.parties,
    required this.gateway,
    this.photoPicker,
  });

  final List<CaseParty> parties;
  final CaseConversationGateway gateway;
  final CaseConversationPhotoPicker? photoPicker;

  @override
  State<AdminCaseConversationsPage> createState() =>
      _AdminCaseConversationsPageState();
}

/// Bir tarafin ekrandaki hali. Okuma hatasi ile "mesaj yok" ayri durumlardir.
class _Channel {
  _Channel();

  List<FeedbackTicketMessage>? messages;
  bool loading = true;
  bool failed = false;

  /// Sekme degisince kaybolmayan taslak.
  String draft = '';
  CaseConversationPhoto? photo;
}

class _AdminCaseConversationsPageState extends State<AdminCaseConversationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.parties.length,
    vsync: this,
  );
  late final Map<CasePartyRole, _Channel> _channels = {
    for (final party in widget.parties) party.role: _Channel(),
  };
  final TextEditingController _input = TextEditingController();

  CasePartyRole _selected = CasePartyRole.reporter;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.parties.first.role;
    _tabs.addListener(_onTabChanged);
    for (final party in widget.parties) {
      _load(party);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _input.dispose();
    super.dispose();
  }

  CaseParty get _party =>
      widget.parties.firstWhere((party) => party.role == _selected);

  _Channel get _channel => _channels[_selected]!;

  /// Sekme degisirken taslak **yerinde kalir**: A tarafina yazilan yari cumle
  /// B tarafina tasinmaz.
  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final next = widget.parties[_tabs.index].role;
    if (next == _selected) return;
    _channels[_selected]!.draft = _input.text;
    setState(() {
      _selected = next;
      _input.text = _channels[next]!.draft;
    });
  }

  Future<void> _load(CaseParty party) async {
    final channel = _channels[party.role]!;
    setState(() {
      channel.loading = true;
      channel.failed = false;
    });
    try {
      final messages = await widget.gateway.messages(party);
      if (!mounted) return;
      setState(() {
        channel.messages = messages;
        channel.loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        channel.messages = null;
        channel.loading = false;
        channel.failed = true;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = widget.photoPicker ?? _pickPhotoFromGallery;
    final photo = await picker(context);
    if (photo == null || !mounted) return;
    setState(() => _channel.photo = photo);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final party = _party;
    final channel = _channel;
    final photo = channel.photo;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await widget.gateway.send(
        party: party,
        message: text,
        photoBytes: photo?.bytes,
        photoExt: photo?.ext,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(_errorText(error))));
      return;
    }
    if (!mounted) return;
    _input.clear();
    setState(() {
      channel.draft = '';
      channel.photo = null;
      _sending = false;
    });
    await _load(party);
  }

  /// 🔴 WP-770 dersi: sunucunun soyledigi sey atilip yerine genel bir cumle
  /// yazilmaz. [AdminException.message] varsa aynen gosterilir.
  String _errorText(Object error) {
    if (error is AdminException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return AppLocalizations.of(context).adminVakaYazismaGonderilemedi;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminVakaYazismalarBaslik),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final party in widget.parties)
              Tab(
                key: kCaseConversationTabKey(party.role),
                child: Text(
                  l10n.adminVakaYazismaSekmesi(
                    _roleLabel(l10n, party.role),
                    party.displayName,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          key: kCaseConversationsKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final party in widget.parties)
                    _ChannelBody(
                      party: party,
                      channel: _channels[party.role]!,
                      gateway: widget.gateway,
                      onRetry: () => _load(party),
                    ),
                ],
              ),
            ),
            _composer(l10n),
          ],
        ),
      ),
    );
  }

  /// Tek yazma seridi — secili tarafa yazar.
  Widget _composer(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final photo = _channel.photo;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photo != null) _photoPreview(l10n, photo),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 🔴 Tek adet: foto eklendikten sonra atac dugmesi cizilmez,
                // yerine onizlemedeki kaldir dugmesi gecer.
                if (photo == null)
                  IconButton(
                    key: kCaseConversationAttachKey,
                    tooltip: l10n.adminVakaYazismaFotoEkle,
                    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.attach_file),
                    onPressed: _sending ? null : _pickPhoto,
                  ),
                Expanded(
                  child: TextField(
                    key: kCaseConversationInputKey,
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1200,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.adminVakaYazismaGirdiIpucu,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: kCaseConversationSendKey,
                  tooltip: l10n.adminGonder,
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: _input.text.trim().isEmpty || _sending
                      ? null
                      : _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPreview(AppLocalizations l10n, CaseConversationPhoto photo) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            key: kCaseConversationPhotoPreviewKey,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
              image: DecorationImage(
                image: MemoryImage(photo.bytes),
                fit: BoxFit.cover,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.coreKapat,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: Icon(Icons.cancel, color: theme.colorScheme.onInverseSurface),
            onPressed: _sending
                ? null
                : () => setState(() => _channel.photo = null),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(AppLocalizations l10n, CasePartyRole role) => switch (role) {
  CasePartyRole.reporter => l10n.adminUgcReporter,
  CasePartyRole.reported => l10n.adminUgcTarget,
};

/// Galeriden tek foto — `features/safety/report_sheet.dart` ile ayni desen.
///
/// Asil sinir sunucudadir (`0138` bucket 5 MB + MIME +
/// `assert_ticket_message_attachment_allowed`); buradaki kontrol yalniz bosa
/// yukleme yapmamak icindir.
Future<CaseConversationPhoto?> _pickPhotoFromGallery(
  BuildContext context,
) async {
  const maxBytes = 5 * 1024 * 1024;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > maxBytes) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileDosyaBoyutu5mbdanKucuk)),
      );
      return null;
    }
    var ext = file.name.split('.').last.toLowerCase();
    if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      ext = 'jpg';
    }
    return CaseConversationPhoto(bytes: bytes, ext: ext);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileResimSecilemedi)));
    return null;
  }
}

/// Bir tarafin gecmis mesajlari.
class _ChannelBody extends StatelessWidget {
  const _ChannelBody({
    required this.party,
    required this.channel,
    required this.gateway,
    required this.onRetry,
  });

  final CaseParty party;
  final _Channel channel;
  final CaseConversationGateway gateway;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (channel.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (channel.failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.adminVakaYazismaOkunamadi,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.updaterTekrarDene),
              ),
            ],
          ),
        ),
      );
    }
    final messages = channel.messages ?? const <FeedbackTicketMessage>[];
    if (messages.isEmpty) {
      // 🔴 Kanali olmayan taraf bos ekran DEGILDIR: yazma seridi acik kalir.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.adminVakaYazismaHenuzYok,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      itemCount: messages.length,
      itemBuilder: (context, index) => _Bubble(
        message: messages[index],
        party: party,
        gateway: gateway,
      ),
    );
  }
}

/// Tek mesaj balonu: yonetici sagda, kullanici solda.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.party,
    required this.gateway,
  });

  final FeedbackTicketMessage message;
  final CaseParty party;
  final CaseConversationGateway gateway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fromAdmin = message.senderRole == FeedbackTicketSenderRole.admin;
    final sender = fromAdmin ? l10n.feedbackYou : party.displayName;
    final attachment = message.attachmentPath;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: fromAdmin
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: fromAdmin
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$sender · '
                    '${feedbackTicketTimestampLabel(l10n, message.createdAt)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(message.message),
                  if (attachment != null) ...[
                    const SizedBox(height: 8),
                    _BubblePhoto(path: attachment, gateway: gateway),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mesaja ekli foto. Adresi sunucu imzalar (bucket private).
class _BubblePhoto extends StatefulWidget {
  const _BubblePhoto({required this.path, required this.gateway});

  final String path;
  final CaseConversationGateway gateway;

  @override
  State<_BubblePhoto> createState() => _BubblePhotoState();
}

class _BubblePhotoState extends State<_BubblePhoto> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _url = null;
    });
    String? url;
    try {
      url = await widget.gateway.photoUrl(widget.path);
    } catch (_) {
      url = null;
    }
    if (!mounted) return;
    setState(() {
      _url = url;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final url = _url;
    if (url == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(l10n.adminGorselYuklenemedi)),
          IconButton(
            tooltip: l10n.updaterTekrarDene,
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: Image.network(
        url,
        key: ValueKey(url),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Text(l10n.adminGorselYuklenemedi),
      ),
    );
  }
}
