import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/l10n/nudge_error_text.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/nudge_providers.dart';
import '../../../data/repositories/nudge_repository.dart';

/// Dürtme eyleminin görünüm biçimi. Mantık ikisinde de aynıdır.
enum NudgeActionStyle {
  /// Üye satırındaki dar simge yuvası.
  icon,

  /// Alt sayfadaki tek başına duran, yazılı düğme.
  labeled,
}

/// WP-511: **tek** dürtme eylemi — grup üye satırı ve kamp ateşi üye sayfası
/// aynı bileşeni kullanır.
///
/// 🔴 Neden ortak: mantık daha önce `class_detail_screen.dart` içinde
/// `private`di. Kamp ateşine kopyalansaydı iki uygulama zamanla ayrışır ve
/// biri şunlardan birini kaçırırdı:
///   * hata metinleri (`core/l10n/nudge_error_text.dart`),
///   * sunucu tarafı odak koruması (`0116_nudge_focus_guard.sql`) — istemci
///     kapısı onunla **aynı** cümleyi göstermek zorunda,
///   * "kendine dürtme" kapısı.
///
/// WP-484 kazanımı aynen korunur: alıcı çalışıyorken düğme **devre dışı
/// değildir**. Devre dışı `IconButton` dokunmaya hiç tepki vermez ve gerekçe
/// yalnız tooltip'te kalır; kullanıcı dokunuyor, hiçbir şey olmuyordu. Düğme
/// etkin kalır, dokununca açıklamayı gösterir ve **sunucuya çağrı yapmaz** —
/// kapı istemcide durur, aksi hâlde spam koruması boşa çıkar.
class NudgeAction extends ConsumerStatefulWidget {
  const NudgeAction({
    super.key,
    required this.groupId,
    required this.recipient,
    required this.isRecipientStudying,
    this.style = NudgeActionStyle.icon,
    this.onBeforeAction,
  });

  final String groupId;
  final Profile recipient;
  final bool isRecipientStudying;
  final NudgeActionStyle style;

  /// Eylemden (gönderim ya da açıklama) hemen önce çalışır.
  ///
  /// 🔴 Modal alt sayfa gibi bir kabuk içinde **zorunlu**: SnackBar'ı çizen
  /// `Scaffold` modal rotanın altında kalır, yani sayfa kapanmadan gösterilen
  /// mesaj hiç görünmez. Kabuğu kapatmak çağıranın işidir; bu bileşen
  /// içinde bulunduğu kabuğu tanımaz.
  final VoidCallback? onBeforeAction;

  @override
  ConsumerState<NudgeAction> createState() => _NudgeActionState();
}

class _NudgeActionState extends ConsumerState<NudgeAction> {
  /// Ekranda duran açıklama. Art arda dokunuşta SnackBar kuyruğunun şişmemesi
  /// için bastırma penceresi sabit bir süre değil, **uyarının kendi ömrüdür**:
  /// uyarı kapanır kapanmaz aynı üye için yeniden gösterilebilir.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _notice;

  /// 🔴 WP-540: uçmakta olan dürtme isteği.
  ///
  /// Eskiden `_send` hiçbir meşgul durumu tutmuyordu. Ölçüldü: aynı düğmeye
  /// ikinci basış İKİNCİ `sendNudge` çağrısı gönderiyordu (`TOPLAM sendNudge=2`)
  /// ve sunucu ikinciyi `nudge_cooldown` ile reddediyordu — kullanıcı başarılı
  /// dürtmenin hemen ardından "20 dakika bekle" hatası görüyordu. Yani kusur
  /// kozmetik değil: doğru davranış yanlış hataya dönüşüyordu.
  bool _sending = false;

  /// `mounted` ayrı ele alınır: `onBeforeAction` modal alt sayfayı pop
  /// edebiliyor, o durumda bu widget ağaçtan düşer ve `setState` çöker.
  /// Kilidin kendisi yine de doğru kalmalı.
  void _setSending(bool value) {
    _sending = value;
    if (mounted) setState(() {});
  }

  void _handlePressed(Profile sender) {
    // Açıklama zaten ekrandaysa ikinci kez gösterme (kuyruk şişmesin).
    if (widget.isRecipientStudying && _notice != null) return;
    if (_sending) return;

    // 🔴 Messenger ve metin kabuk kapanmadan **önce** okunmalı: `onBeforeAction`
    // alt sayfayı pop ederse bu widget ağaçtan düşer ve `context` ölür.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    widget.onBeforeAction?.call();

    if (!widget.isRecipientStudying) {
      _send(messenger, l10n, sender);
      return;
    }
    final notice = messenger.showSnackBar(
      SnackBar(content: Text(l10n.classroomStudyingNudgeUnavailable)),
    );
    _notice = notice;
    notice.closed.whenComplete(() {
      if (!mounted) return;
      if (identical(_notice, notice)) _notice = null;
    });
  }

  Future<void> _send(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    Profile sender,
  ) async {
    // İkinci kapı: düğme zaten devre dışı, bu guard klavye/erişilebilirlik
    // yollarını ve kabuk kapandığı için `setState` işlemeyen durumu da kapatır.
    if (_sending) return;
    _setSending(true);
    try {
      await ref
          .read(nudgeRepositoryProvider)
          .sendNudge(
            groupId: widget.groupId,
            sender: sender,
            recipient: widget.recipient,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.classroomRecipientdisplaynameDurtuldu(
              widget.recipient.displayName,
            ),
          ),
        ),
      );
    } on NudgeException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.localize(l10n))));
    } finally {
      _setSending(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sender = ref.watch(authStateProvider).value;

    // Kendine dürtme **hiç gösterilmez**. Sunucu da reddediyor
    // (`NudgeErrorCode.cannotNudgeSelf`) ama kullanıcının basıp hata alması
    // bir eylem değil, tuzaktır.
    if (sender != null && sender.id == widget.recipient.id) {
      return const SizedBox.shrink();
    }

    final tooltip = widget.isRecipientStudying
        ? l10n.classroomStudyingNudgeUnavailable
        : l10n.classroomDurt;
    // Oturum yoksa gönderecek kimse yok — düğme gerçekten devre dışıdır.
    // WP-540: uçmakta olan istek sırasında da devre dışı; ikinci basış artık
    // ikinci `sendNudge` üretemez.
    final onPressed = (sender == null || _sending)
        ? null
        : () => _handlePressed(sender);
    // Gönderim görünür olmalı: WP-484 kazanımı (alıcı çalışıyorken düğme
    // **etkin** kalır) korunuyor, kilit yalnız istek uçarken devrede.
    final icon = _sending
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.notifications_active_outlined);

    return switch (widget.style) {
      NudgeActionStyle.icon => IconButton(
        tooltip: tooltip,
        icon: icon,
        onPressed: onPressed,
      ),
      NudgeActionStyle.labeled => FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: icon,
        label: Text(l10n.classroomDurt),
      ),
    };
  }
}
