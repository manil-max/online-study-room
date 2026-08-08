import 'package:flutter/material.dart';

import '../../../data/models/study_group.dart';
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
    body: ClassChatCard(group: group),
  );
}
