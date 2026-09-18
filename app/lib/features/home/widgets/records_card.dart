import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/study_providers.dart';
import '../../stats/widgets/study_records.dart';
import '../dashboard_card.dart';
import 'card_data_gate.dart';
import 'card_scaffold.dart';

/// [StudyRecords]'un `Wrap` aralığı (satırlar arası).
const double _kTileGap = 8;

/// [StudyRecords]'un çizdiği döşeme sayısı.
const int _kRecordTileCount = 5;

/// Yazı ölçeğinin 1'den büyük olup olmadığını sormak için örnek punto.
const double _kProbeFont = 14;

/// "Rekorlar" kartı (§3.11): toplam, rekor seri, en verimli gün, aktif gün,
/// en çok çalışılan ders — renkli stat döşemeleri.
///
/// 🔴 WP-858: kart döşemeleri HER ZAMAN yoğun modda çizer ve gövdeye kaç
/// döşeme sığıyorsa o kadarını gösterir (önem sırasıyla: Toplam → Rekor
/// seri → Aktif gün → En verimli gün → En çok ders).
///
/// Ölçüm (WP-836 envanteri, varsayılan 32×26, dar telefon, yazı 1.0): tam
/// döşemeler ~400 px içerik üretiyordu, gövde ~189 px → 211 px KART İÇİ
/// kaydırma. Tam modda 140 px genişliğindeki tek bir döşeme ("En verimli
/// gün") 172 px'e uzuyordu; yani sorun hücre boyu değil döşeme biçimiydi.
/// Yoğun döşemenin boy tavanı hesaplanabilir ([StudyRecords.denseTileHeight])
/// olduğu için "kaç tane sığar" ölçüm yapmadan bilinir.
///
/// ⚠️ Büyütülmüş yazıda (ölçek > 1) döşeme DÜŞÜRÜLMEZ: büyük yazı seçen
/// kullanıcıdan rekor gizlemek yerine kart kendi içinde kayar (WP-497 /
/// WP-541 sözleşmesi — sığmayan içerik kaybolmaz, ulaşılır kalır).
class RecordsCard extends ConsumerWidget {
  const RecordsCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    // 🔴 WP-612: `userSessionsProvider` SICAK PENCEREdir (son 90 gün,
    // `study_providers.dart`). Kart ise "Toplam / Rekor seri / Aktif gün"
    // diyor ve kapsam etiketi taşımıyordu: 400 günlük geçmişi olan kullanıcı
    // ana ekranda kendi toplamının dörtte birini görüyordu. WP-573 aynı yalanı
    // İstatistik ekranında kapatmış, ana ekran kartı atlanmıştı.
    //
    // Özet KAPIYA konmaz (`cardDataGate`): ağ turu beklerken kart iskelete
    // dönerse yükleme yalanının yerine bir başkası geçer. Gelmediyse kart
    // pencere toplamını gösterir ve etiketiyle bunu söyler.
    final summary = ref.watch(userStudySummaryProvider).value;
    // WP-495C: yükleniyorken "Kayıt yok" yazmak kaydı olan kullanıcıya yalandır.
    final gate = cardDataGate(
      context,
      title: AppLocalizations.of(context).homeRekorlar,
      sources: [sessionsAsync],
    );
    if (gate != null) return gate;
    final sessions = sessionsAsync.value!;
    // Kapsam iddiası ÖLÇÜLÜR: her iki sayı da aynı sunucu özetinden gelir,
    // yani "ömür boyu > pencere" ancak gerçekten daha eski veri varsa doğrudur.
    // Özet yoksa hiçbir iddia edilmez (doğru veriye yanlış uyarı da yalandır).
    final windowLimited =
        summary != null && summary.lifetimeSeconds > summary.hotWindowSeconds;

    return CardScaffold(
      header: cardTitle(context, AppLocalizations.of(context).homeRekorlar),
      bodyBuilder: (context, bodyHeight) => SizedBox(
        height: bodyHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 400
                ? 3
                : (constraints.maxWidth > 250 ? 2 : 1);
            // WP-858: gövdeye kaç döşeme satırı sığar? Wrap'in satır aralığı
            // [_kTileGap]; son satırın altında aralık yoktur (+gap payı).
            final tileHeight = StudyRecords.denseTileHeight(context);
            final rows = ((bodyHeight + _kTileGap) / (tileHeight + _kTileGap))
                .floor();
            final enlargedText =
                MediaQuery.textScalerOf(context).scale(_kProbeFont) >
                _kProbeFont;
            // En az bir döşeme her zaman çizilir (sığmıyorsa kart kayar).
            final fit = (rows < 1 ? 1 : rows) * cols;
            final maxTiles = enlargedText || fit >= _kRecordTileCount
                ? null
                : fit;
            // WP-508: yalnız taşarsa kayar; sığdığında dış sayfa akar.
            return cardScrollIfOverflows(
              child: StudyRecords(
                sessions: sessions,
                columns: cols,
                lifetimeSeconds: summary?.lifetimeSeconds,
                windowLimited: windowLimited,
                dense: true,
                maxTiles: maxTiles,
              ),
            );
          },
        ),
      ),
    );
  }
}
