import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/navigation/nav_index.dart';
import '../../core/validation/name_limits.dart';
import '../../core/widgets/app_pull_to_refresh.dart';
import '../../core/widgets/crowned_avatar.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../desktop/desktop_surface.dart';
import 'session_history_screen.dart';
import 'settings_screen.dart';
import 'widgets/gamification_card.dart';
import '../../data/providers/notification_providers.dart';
import 'widgets/unread_announcement_dot.dart';
import 'widgets/unread_message_badge.dart';
import '../../data/providers/admin_providers.dart';

/// Profil sekmesi: foto, görünen ad, ayarlar. Grup yönetimi → Gruplar sekmesi.
/// Bkz. project.md §3.2.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scrollController = ScrollController();
  final _identityTourAnchor = GlobalKey();
  final _actionsTourAnchor = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Cikis: sonuc **beklenir** ve hata **yakalanir**.
  ///
  /// 🔴 WP-620: burasi `() => ref.read(authRepositoryProvider).signOut()` idi —
  /// ne `await`leniyor ne yakalaniyordu. Cevrimdisiyken gotrue yerel oturumu
  /// silip sunucuya gidiyor, ikinci adim patliyor ve hata **islenmemis** async
  /// hata olarak zone'a dusuyordu: kullanici cikmis oluyor ama ekranda hicbir
  /// sey yazmiyor, testte de "unhandled exception" olarak birikiyordu.
  ///
  /// Kural (Hesabim ekranindaki ikiziyle ayni): cikisi olmus say, ama
  /// kapatilamayan seyi — diger cihazlardaki oturumu — kullaniciya soyle.
  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    var serverNotified = true;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      serverNotified = false;
    }
    if (!serverNotified) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.profileCikisYapildiSunucuyaUlasilamadi),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navReselectProvider, (previous, next) {
      if (next.tabIndex != AppTab.profile.index ||
          next.tick <= (previous?.tick ?? 0) ||
          !_scrollController.hasClients ||
          _scrollController.offset <= 0) {
        return;
      }
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
    final theme = Theme.of(context);
    final profile = ref.watch(authStateProvider).value;
    final unreadAnnouncements = ref.watch(unreadAnnouncementCountProvider);
    // WP-421: zincirin en ust halkasi. Ayarlar satirinda hem duyuru hem
    // okunmamis yonetici yaniti gorunur; alt seviyede olan sey ust seviyede
    // de gorunmek zorunda.
    final unreadReplies =
        ref.watch(unreadFeedbackReplyCountProvider).value ?? 0;

    // Windows: içerik okuma genişliğinde ortalanır (full-bleed mobil liste değil).
    final page = Scaffold(
      // WP-460: "Profil" başlığı alt menüde zaten yazılı; ekranın ilk anlamlı
      // içeriği (avatar kartı) doğrudan yukarı gelir, üst güvenli alan korunur.
      appBar: null,
      // 🔴 WP-550: dört ana sekmenin hiçbirinde aşağı çekerek yenileme yoktu.
      body: AppPullToRefresh(
        child: ListView(
          controller: _scrollController,
          padding: _topSafeListPadding(context),
          children: [
            DesktopReadingBody(
              maxWidth: DesktopSurface.readingWidth,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    key: _identityTourAnchor,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (profile != null)
                          LiveCrownedAvatar(
                            userId: profile.id,
                            displayName: profile.displayName,
                            avatarUrl: profile.avatarUrl,
                            radius: 48,
                            // WP-298: aura yalnız bu iki profil yüzeyinde açık.
                            showAura: true,
                          )
                        else
                          CrownedAvatar(
                            displayName: AppLocalizations.of(
                              context,
                            ).profileMisafir,
                            radius: 48,
                          ),
                        if (profile != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: theme.colorScheme.primary,
                              shape: CircleBorder(),
                              child: InkWell(
                                customBorder: CircleBorder(),
                                onTap: () => _pickAvatar(context, ref),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.photo_camera,
                                    size: 18,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          profile?.displayName.isNotEmpty == true
                              ? profile!.displayName
                              : AppLocalizations.of(context).profileMisafir,
                          style: theme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile != null)
                        IconButton(
                          tooltip: AppLocalizations.of(
                            context,
                          ).profileAdiDuzenle,
                          icon: Icon(Icons.edit, size: 18),
                          onPressed: () =>
                              _editName(context, ref, profile.displayName),
                        ),
                    ],
                  ),
                  SizedBox(height: 24),
                  GamificationCard(),
                  SizedBox(height: 16),
                  Card(
                    key: _actionsTourAnchor,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.history),
                          title: Text(
                            AppLocalizations.of(
                              context,
                            ).profileCalismaKayitlarim,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).profileManuelSureEkleDuzenle,
                          ),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => showDesktopPanel<void>(
                            context: context,
                            builder: (_) => SessionHistoryScreen(),
                          ),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.settings_outlined),
                          title: Text(
                            AppLocalizations.of(context).profileAyarlar,
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).profileGorunumAnaSayfaSayac,
                          ),
                          // WP-378: duyuru zincirinin orta halkası. Nokta
                          // yalnız Ayarlar'ın **içinde** durduğu sürece kullanıcı
                          // yeni duyuruyu ancak oraya girince fark ediyordu.
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (unreadReplies > 0) ...[
                                UnreadMessageBadge(
                                  key: const Key('settings-row-reply-badge'),
                                  count: unreadReplies,
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (unreadAnnouncements > 0) ...[
                                UnreadAnnouncementDot(
                                  key: const Key('settings-row-unread-dot'),
                                  count: unreadAnnouncements,
                                ),
                                const SizedBox(width: 8),
                              ],
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => showDesktopPanel<void>(
                            context: context,
                            builder: (_) => SettingsScreen(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    key: const Key('profile-sign-out'),
                    onPressed: _signOut,
                    icon: Icon(Icons.logout),
                    label: Text(AppLocalizations.of(context).profileCikisYap),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (ref.watch(navIndexProvider) != AppTab.profile.index) return page;

    return page;
  }
}

Future<void> _editName(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: current);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.profileGorunenAdiDuzenle),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        // WP-517: sunucu karşılığı `0122_name_length_limits.sql`.
        maxLength: kDisplayNameMaxLength,
        decoration: InputDecoration(labelText: l10n.profileGorunenAd),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.profileVazgec),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(l10n.profileKaydet),
        ),
      ],
    ),
  );
  if (name == null || name.trim().isEmpty || name.trim() == current) return;
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  // 🔴 WP-610: yalniz `on AuthException` yakalaniyordu. Moderasyon reddi
  // (`public_name_not_allowed`) gercekten o turden gelir, ama ag/sunucu
  // hatasi `PostgrestException` / `ClientException` olarak gelir ve dalin
  // yanindan gecerdi: diyalog kapanir, ad degismez, hicbir uyari cikmazdi.
  // Genis `catch` bu yuzden ikinci dal olarak durur; ozel mesaj korunur.
  try {
    await ref.read(authRepositoryProvider).updateDisplayName(name);
    ref.invalidate(authStateProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.profileGorunenAdGuncellendi)),
    );
  } on AuthException catch (error) {
    final message = error.message == 'public_name_not_allowed'
        ? l10n.moderationPublicNameRejected
        : l10n.profileGorunenAdKaydedilemedi;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.profileGorunenAdKaydedilemedi)),
    );
  }
}

/// Galeriden gorsel secme adimi -- test edilebilir dikis.
///
/// 🔴 WP-610: avatar yuklemesinin hata dali bugune kadar hic olculmemisti,
/// cunku secim adimi dogrudan `ImagePicker`a bagliydi ve widget testinden
/// surulemiyordu. Secim tek satirlik bir saglayiciya alindi: uretimde ayni
/// `image_picker` cagrisi, testte sahte bir secici. Yukleme, geri bildirim ve
/// ekran kablosu boylece gercekten olculur.
final avatarImagePickerProvider = Provider<Future<XFile?> Function()>(
  (ref) => () => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  ),
);

Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final file = await ref.read(avatarImagePickerProvider)();
  if (file == null) return;

  final bytes = await file.readAsBytes();
  final contentType =
      file.mimeType ??
      (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  // 🔴 WP-610: hata dali `on AuthException` idi. Yukleme `Storage` uzerinden
  // gider ve basarisizlik `StorageException` / `ClientException` olarak
  // gelir -- yani o dal HIC calismiyordu: kullanici ne "guncellendi" ne de
  // bir hata goruyor, eski fotograf yerinde kaliyordu.
  try {
    await ref
        .read(authRepositoryProvider)
        .updateAvatar(bytes: bytes, contentType: contentType);
    ref.invalidate(authStateProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.profileProfilFotografiGuncellendi)),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.profileProfilFotografiYuklenemedi)),
    );
  }
}

/// WP-460: Sekmenin AppBar'i kaldirildigi icin durum cubugu payini liste
/// kendisi tasir; guvenli alan kaybolmaz, yalniz tekrar eden baslik gider.
EdgeInsets _topSafeListPadding(BuildContext context) {
  final base = getSafeVerticalPadding(context, horizontal: 24, vertical: 24);
  return base.copyWith(top: base.top + MediaQuery.paddingOf(context).top);
}
