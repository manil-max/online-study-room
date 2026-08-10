import 'package:flutter/material.dart';

import '../../../core/desktop/desktop_layout.dart';
import '../../../core/desktop/desktop_window.dart';
import '../../../data/models/study_group.dart';
import '../../desktop/desktop_page_scaffold.dart';
import 'class_chat_card.dart';

/// Grup sohbeti — tam ekran.
///
/// 🔴 WP-510: ekran eskiden `AppBar("Sohbet")` + gövdede bir `ListView`
/// idi; listenin içinde önce grup adı, sonra sabit yükseklikli bir sohbet
/// **kartı** duruyordu. Üç kat: başlık → ad → kutu içinde sohbet. Yan etkisi
/// yalnız görsel değildi: sabit yükseklikli liste ekranın boş kalan yerini
/// kullanmıyor, dıştaki `ListView` yüzünden yazma alanı klavyeyle birlikte
/// doğru davranmıyordu.
///
/// Şimdi tek kat: başlıkta grup adı, gövdede mesaj listesi + yazma alanı.
/// Klavye `Scaffold`un varsayılan `resizeToAvoidBottomInset` davranışıyla
/// gövdeyi kısaltır; daralan yalnız mesaj listesidir.
class ClassChatScreen extends StatelessWidget {
  const ClassChatScreen({super.key, required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      // Uzun grup adı başlığı taşırmasın; adın kanonik yeri artık burası.
      title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    // 🔴 WP-675 (masaüstü): mesaj listesi pencere kadar genişliyordu.
    // Balonlar zaten 320 px'te tavanlı ama biri sola biri sağa yaslandığı için
    // 2560 px'lik pencerede aralarında ~1700 px boşluk kalıyordu — sahibin
    // "mobilin penceresi gibi olmuş" şikâyetinin bu ekrandaki hali.
    //
    // SPEC §2.3 form sütunu (760 px) kullanılıyor, prose (600) değil: sohbette
    // balonun yanında avatar + taşma düğmesi de var, yani satır saf metin değil.
    //
    // ⚠️ SPEC §3 A1 bu ekran için master–detay öneriyor; **uygulanmadı**.
    // Gerekçe: bu uygulamada aynı anda TEK aktif grup vardır
    // (`userGroupProvider`) ve gruplar arası geçişin kanonik yolu
    // `class_switcher.dart`tır. Master sütunu o değiştiriciyi ikinci kez
    // uygulamak olurdu — WP-446'da tam bu (iki kopya, zamanla ayrışan davranış)
    // bir hata olarak kapatılmıştı.
    body: isDesktopWindow
        ? DesktopContent(
            maxWidth: DesktopBreakpoints.maxFormWidth,
            padding: EdgeInsets.zero,
            child: ClassChatCard(group: group),
          )
        : ClassChatCard(group: group),
  );
}
