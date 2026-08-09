/// WP-594: klavye odak halkası tema paletinden **bağımsız**.
///
/// Sorun `warning_tokens.dart`'taki (WP-358 / "uyarı rozeti tema çakışması")
/// desenin birebir aynısıydı: masaüstü sol panelindeki odak halkası
/// `colorScheme.primary`den besleniyordu. Tema Stüdyosu'nda döşeme zeminine
/// yakın bir palet seçen kullanıcıda halka eriyip kayboluyor ve **klavyeyle
/// gezinen kullanıcı nerede olduğunu göremiyordu**. Kayıp sessiz: fareyle
/// çalışan hiç fark etmez, yalnız klavye kullanıcısı kaybolur.
///
/// Çözüm aynı ilke: renk paletten türetilmez, **zemine göre** türetilir.
/// Uyarı token'ından tek farkı, odak halkasının bir "anlam" rengi olmaması —
/// WinUI'daki `FocusStrokeColorOuter` gibi akromatik bir uçtur: zemin açıksa
/// koyu, koyuysa açık.
///
/// 🔴 Sabit renk yazma (`Colors.white` gibi): açık temada zemine gömülür,
/// koyu temada bağırır. Renk **zeminin fonksiyonudur**, sabit değildir.
///
/// 🔴 Zemin olarak paneli değil halkanın **fiilen üstünde durduğu döşemeyi**
/// geç: seçili döşeme `secondaryContainer`dır ve panel zemininden farklıdır.
library;

import 'dart:ui' show Color;

import 'warning_tokens.dart' show contrastRatio, kMinSurfaceContrast;

/// Akromatik uçlar. Saf siyah/beyaz yerine bir tık yumuşatılmışları: kontrast
/// kaybı ihmal edilebilir (en kötü zeminde bile > 4.1), görüntü daha az sert.
const Color _lightEnd = Color(0xFFF7F7F7);
const Color _darkEnd = Color(0xFF14141A);

/// [background] üstünde görünürlüğü **garanti** odak halkası rengi.
///
/// Saf ve deterministiktir; aynı zemin her zaman aynı sonucu verir — tema
/// ailesi, palet ya da marka rengi sonucu değiştirmez. İki akromatik uçtan
/// kontrastı yüksek olanı seçilir; en kötü durum (orta parlaklıkta zemin)
/// ~4.1'dir, yani WCAG'ın kullanıcı arayüzü bileşeni için istediği
/// [kMinSurfaceContrast] eşiğinin belirgin üstünde kalır.
Color resolveFocusRingColor(Color background) {
  final lightContrast = contrastRatio(_lightEnd, background);
  final darkContrast = contrastRatio(_darkEnd, background);
  final useLight = lightContrast >= darkContrast;
  assert(
    (useLight ? lightContrast : darkContrast) >= kMinSurfaceContrast,
    'odak halkasi zeminde kayboluyor (gelistirici notu): $background',
  );
  return useLight ? _lightEnd : _darkEnd;
}

/// Widget tarafı kısayolu — `warning_tokens.dart`'taki `warningColorsOn` ile
/// aynı sözleşme: zemin **açıkça** geçilir, yanlış zemini vermek sessiz bir
/// hata olmasın.
Color focusRingColorOn(Color surface) => resolveFocusRingColor(surface);
