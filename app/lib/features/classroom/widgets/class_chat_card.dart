import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/widgets/safe_screen_padding.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/report_target.dart';
import '../../../data/models/study_group.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/chat_providers.dart';
import '../../../data/providers/moderation_providers.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../profile/widgets/profile_tap.dart';
import '../../safety/block_user_action.dart';
import '../../safety/report_sheet.dart';

/// Grup sohbeti: mesaj listesi + yazma alanı.
///
/// 🔴 WP-510: bu widget eskiden bir `Card` kabuğu içindeydi ve mesaj
/// listesine `messageListHeight` ile **sabit** yükseklik veriyordu. Tam ekran
/// sohbetin içine konduğunda "pencere içinde pencere" çıkıyor, liste ekranın boş
/// kalan yerini kullanmıyor ve klavye açılınca yazma alanı doğru davranmıyordu.
///
/// Kabuk ve parametre kaldırıldı: widget artık **verilen alanın tamamını**
/// kaplar, yani sınırlı yükseklikli bir ebeveyn ister (`Scaffold.body`).
/// Parametre bırakılsaydı aynı "kart içinde kart" bir gün geri dönerdi.
class ClassChatCard extends ConsumerStatefulWidget {
  const ClassChatCard({super.key, required this.group});

  final StudyGroup group;

  @override
  ConsumerState<ClassChatCard> createState() => _ClassChatCardState();
}

class _ClassChatCardState extends ConsumerState<ClassChatCard> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(classMessagesProvider(widget.group.id));
    final user = ref.watch(authStateProvider).value;
    // WP-495B: engelli kümesi gelmeden mesajlar çizilirse engellenen kişinin
    // mesajı bir kare görünür. Sohbet, roster'ın aksine sunucuda süzülmüyor
    // (`0095` sohbeti kapsamaz) — süzgeç yalnız burada, o yüzden küme beklenir.
    //
    // 🔴 WP-538: hata dalı ESKİDEN süzgeçsiz listeye düşüyordu ("moderasyon
    // hatası sohbeti kullanılamaz hâle getirmesin"). O takas yanlış tarafı
    // seçmiş: ölçüldü, küme çağrısı hata verince engellenen kişinin mesajları
    // GÖRÜNÜR hâle geliyordu. Birini taciz ettiği için engelleyen kullanıcı,
    // tek bir ağ hatasında onun mesajlarını yeniden görüyor — ve Play'e
    // "engelleme var" diye beyan verdiğimiz özellik sessizce kapanıyor.
    //
    // Yeni sözleşme: **küme bilinmiyorsa mesaj çizilmez.** Daha önce yüklenmiş
    // bir küme varsa (AsyncValue hatada önceki değeri taşır) onunla süzülür ve
    // sohbet çalışmaya devam eder; hiç bilinmiyorsa hata durumu gösterilir.
    final blockedAsync = ref.watch(blockedUserIdsProvider);
    final knownBlocked = blockedAsync.value;
    final blockedUnknown = knownBlocked == null;
    final gatedMessages = blockedUnknown
        ? (blockedAsync.hasError
              ? AsyncValue<List<ChatMessage>>.error(
                  blockedAsync.error!,
                  blockedAsync.stackTrace ?? StackTrace.current,
                )
              : const AsyncValue<List<ChatMessage>>.loading())
        : messagesAsync;

    // 🔴 WP-560 — Riverpod 3 tuzağı, ÖLÇÜLDÜ: hiç değer vermemiş bir
    // `StreamProvider` hata aldığında durum `AsyncError` DEĞİL, hatayı taşıyan
    // `AsyncLoading` olur. `AsyncValue.when` varsayılan `skipError: false` ile
    // önce `isLoading`e bakar; yani buradaki eski `error:` kolu bu senaryoda
    // HİÇ çalışmıyordu. Kullanıcıdaki karşılığı: ağ hatasında "Sohbet
    // yüklenemedi." yerine SONSUZ spinner — WP-538 fail-closed sözleşmesiyle
    // birleşince sohbet kalıcı olarak kilitleniyordu. `card_data_gate.dart` da
    // tam bu yüzden `.when` değil `hasError` kullanır. Ayrım burada da elle
    // yapılır; `error_retry_wp560_test.dart` sahte depoda aynı durumu kurar.
    final chatFailed = gatedMessages.hasError && !gatedMessages.hasValue;
    final Widget chatBody;
    if (chatFailed) {
      // Tekrar-dene İKİ kaynağı birden tazeler: hata mesaj akışından da
      // engelli küme çağrısından da gelmiş olabilir (`gatedMessages` ikisini
      // tek [AsyncValue]'ya indirger, hangisinin patladığı burada okunamaz).
      // Yalnız birini tazelemek düğmeyi vakaların yarısında sessizce etkisiz
      // bırakırdı.
      chatBody = Center(
        child: ErrorRetryView(
          message: AppLocalizations.of(context).classroomSohbetYuklenemedi,
          onRetry: () {
            ref.invalidate(blockedUserIdsProvider);
            ref.invalidate(classMessagesProvider(widget.group.id));
          },
        ),
      );
    } else if (gatedMessages.hasValue) {
      // WP-126: engellenen kullanıcı mesajlarını gizle.
      // WP-538: buraya yalnız küme BİLİNİYORKEN gelinir; `?? {}` yedeği
      // artık "hata varsa süzme" anlamına gelmiyor.
      final blocked = knownBlocked ?? const <String>{};
      final messages = gatedMessages.requireValue;
      final visible = blocked.isEmpty
          ? messages
          : messages
                .where((m) => !blocked.contains(m.userId))
                .toList(growable: false);
      chatBody = _MessageList(messages: visible, currentUserId: user?.id);
    } else {
      chatBody = const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mesaj listesi boş kalan alanın **tamamını** alır; klavye açılınca
        // `Scaffold` gövdeyi kısaltır ve daralan yalnız bu parça olur.
        Expanded(child: chatBody),
        Padding(
          // Alt güvenli alan yazma alanına eklenir; klavye açıkken
          // `MediaQuery.paddingOf(...).bottom` zaten 0'a düşer (çift boşluk yok).
          padding: getSafePadding(
            context,
            const EdgeInsets.fromLTRB(12, 8, 12, 10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: kMaxChatMessageLength,
                  enabled: user != null && !_sending,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).classroomMesajYaz,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 🔴 WP-540: gönder düğmesi boş metinde de ETKİNDİ. Basınca
              // `normalizeChatMessageText` (`chat_repository.dart:28`)
              // `ChatException('Mesaj boş olamaz.')` fırlatıyor, `_send` ise
              // onu genel "Beklenmeyen bir hata oluştu." cümlesine çeviriyordu
              // (ölçüldü: boş gönderimde o SnackBar çıkıyor). Kullanıcı hiçbir
              // şey yazmamışken sistem hatası görüyordu. Doğrusu düğmenin
              // etkin olmaması; `ValueListenableBuilder` metin değiştikçe
              // yalnız bu düğmeyi yeniden çizer (her tuşta tüm sohbet değil).
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final canSend =
                      user != null && !_sending && value.text.trim().isNotEmpty;
                  return IconButton.filled(
                    tooltip: AppLocalizations.of(context).classroomGonder,
                    onPressed: canSend ? _send : null,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            groupId: widget.group.id,
            sender: user,
            text: _controller.text,
          );
      _controller.clear();
    } on ChatException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.currentUserId});

  final List<ChatMessage> messages;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (messages.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).classroomIlkMesajiSenGonder,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      reverse: true,
      // Kart kabuğu gidince iç dolgu da gitti; mesajlar ekran kenarına
      // yapışmasın diye dolgu listenin kendisine taşındı (WP-510).
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final mine = message.userId == currentUserId;
        return _MessageBubble(message: message, mine: mine);
      },
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  Future<void> _showPeerActions(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WP-446: iki eylem birbirine benziyor ama kapsamları taban
              // tabana zıt — biri yöneticiye gider, diğeri yalnız bu hesabın
              // görünümünü değiştirir. Alt satır bu ayrımı ekranda söyler.
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.safetyReport),
                subtitle: Text(l10n.safetyReportKapsam),
                isThreeLine: false,
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l10n.safetyBlock),
                subtitle: Text(l10n.safetyBlockKapsam),
                isThreeLine: false,
                onTap: () => Navigator.pop(ctx, 'block'),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted || selected == null) return;

    if (selected == 'report') {
      await showReportSheet(
        context,
        ref,
        // WP-439: mesaj hedefi grup bağlamıyla birlikte gider; sunucu ortak
        // aktif üyelik ve görünürlüğü bu grupla doğrular.
        target: ReportTarget.message(
          messageId: message.id,
          groupId: message.groupId,
          hint: message.body,
        ),
      );
      return;
    }

    if (selected == 'block') {
      await confirmAndBlockUser(context, ref, userId: message.userId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = (message.authorDisplayName?.trim().isNotEmpty ?? false)
        ? message.authorDisplayName!.trim()
        : AppLocalizations.of(context).classroomIsimsiz;
    final bubbleColor = mine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = mine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.78),
                ),
              ),
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatMessageTime(message.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.68),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            GestureDetector(
              onTap: () => openMemberProfileById(
                context,
                userId: message.userId,
                displayName: name,
                avatarUrl: message.authorAvatarUrl,
                animal: message.authorAnimal,
              ),
              onLongPress: () => _showPeerActions(context, ref),
              child: LiveCrownedAvatar(
                userId: message.userId,
                displayName: name,
                avatarUrl: message.authorAvatarUrl,
                radius: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: mine
                  ? bubble
                  : GestureDetector(
                      onLongPress: () => _showPeerActions(context, ref),
                      child: bubble,
                    ),
            ),
          ),
          // 🔴 WP-446: uzun basma TEK keşif yolu olamaz. Raporlama yalnız
          // gizli bir jestin arkasındayken, ihtiyacı olan kullanıcının onu
          // bulacağını varsaymış oluruz. Görünür 48 dp'lik hedef eklendi;
          // uzun basma ikinci yol olarak duruyor (kas hafızası bozulmasın).
          if (!mine)
            IconButton(
              tooltip: AppLocalizations.of(context).classroomMesajSecenekleri,
              icon: const Icon(Icons.more_vert, size: 18),
              // Material'in varsayılan 48 dp dokunma hedefi korunur; yalnız
              // ikon küçültülür ki baloncuk hizası bozulmasın.
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => _showPeerActions(context, ref),
            ),
        ],
      ),
    );
  }
}

/// WP-254: `createdAt` DB'den UTC parse edilir; ham `.hour` mesaj saatlerini
/// 3 saat geri gösteriyordu. İstanbul duvar saati tek doğru kaynak.
String _formatMessageTime(DateTime value) => istanbulHm(value);
