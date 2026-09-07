import 'package:flutter/material.dart';

import '../../data/models/subject.dart';
import 'container_roles.dart' show accentOn;

/// Ders renk token'larını (`chart-1`..`chart-5`) gerçek renklere çevirir.
/// Değerler tasarım referansındaki paletin (oklch) yaklaşık sRGB karşılıklarıdır
/// (bkz. project.md §3.7). Nihai ton tasarım aşamasında ince ayar edilebilir.
// Kardeşin tasarım referansındaki oklch paletinin sRGB karşılıkları (globals.css).
const Map<String, Color> _subjectColors = <String, Color>{
  'chart-1': Color(0xFF3186E9), // mavi
  'chart-2': Color(0xFF12C281), // yeşil / teal
  'chart-3': Color(0xFFE69825), // sarı / amber
  'chart-4': Color(0xFFC35DD9), // mor
  'chart-5': Color(0xFFF3625D), // mercan / kırmızı
};

/// Token'a karşılık gelen **ham** marka rengi — zeminden tamamen bağımsız
/// (bilinmeyen token → paletin ilk rengi).
///
/// 🔴 Bu kaçış yolu **istisnadır**. Yalnız rengin üstüne çizildiği zemin
/// uygulamanın tema yüzeyi OLMADIĞI yerde kullanılır — kamp ateşi sahnesinin
/// kendi boyalı zemini gibi. Her çağrının yanına NEDEN ham olduğu yazılır.
///
/// Kapı `theme_contrast_gate_wp627_test.dart` `lib/` içindeki ham kullanımların
/// **tam listesini** kilitler; yeni bir kaçış eklenirse kırmızıya düşer.
Color subjectColorRaw(String token) =>
    _subjectColors[token] ?? _subjectColors[kSubjectColorTokens.first]!;

/// Token'a karşılık gelen renk — **[on] zemininin fonksiyonudur** (zorunlu):
/// ton korunur, açıklık [accentOn] ile eşiğe (3.0) kilitlenir.
///
/// 🔴 WP-797: palet zeminden bağımsız sabitti. 15 hazır temada ölçüldüğünde
/// 75 ölçümün 11'i 3.0 altındaydı — `nordic_snow`/`paper_ink`/`pastel_day`/
/// `soft_cream` açık zeminlerinde `chart-2` (yeşil) ve `chart-3` (amber) 2.2–2.4.
/// Bu iki token dolgu değil **ikon ve metin** olarak çiziliyor: günlük hedef
/// tamamlandı ✓ işareti, "şu an çalışanlar" noktası, kamp ateşi durum rozeti.
/// Yani kayıp sessizdi — kullanıcı işaretin olmadığını değil, hedefin
/// tamamlanmadığını sanıyordu.
///
/// 🔴 WP-804: [on] artık **zorunlu**. WP-797 onu opsiyonel bırakınca ~20 çağrı
/// yeri ham renk almaya devam etti ve kapı bunu göremedi (kapı yalnız zemin
/// farkındalı biçimi ölçüyor). Zorunlu parametreyle derleyici kapıya dönüşür.
/// Gerçekten ham renk gereken yer [subjectColorRaw] kullanır.
Color subjectColor(String token, {required Color on}) =>
    accentOn(on, preferred: subjectColorRaw(token));
