#!/usr/bin/env bash
# WP-903 — CI'da (yalniz derleme kopyasinda) Info.plist'e derleme-zamani
# degerlerini yazar. Repodaki app/ios/Runner/Info.plist DEGISMEZ; bu betik
# macOS runner'daki checkout uzerinde kosar.
#
# 1) Google ile giris (iOS): GoogleSignIn SDK'si tarayici donusunu ters
#    istemci kimligi semasiyla (com.googleusercontent.apps.<onek>) yakalar.
#    Sema Info.plist'te yoksa SDK girisi baslatirken cokertir (NSException).
#    Bu yuzden sema YALNIZ GOOGLE_IOS_CLIENT_ID verildiginde eklenir; kimlik
#    yoksa uygulama Google dugmesini zaten cizmez (fail-closed, WP-902).
# 2) ITSAppUsesNonExemptEncryption: uygulama yalniz standart sifreleme (HTTPS)
#    kullanir -> muaf. Anahtar yoksa false yazilir; varsa DOKUNULMAZ
#    (WP-900'un karari kazanir). Anahtarsiz her TestFlight derlemesi App Store
#    Connect'te "ihracat uyumlulugu" sorusunda bekler.
#
# Kullanim: inject_info_plist.sh <Info.plist yolu>
#   ortam: GOOGLE_IOS_CLIENT_ID (istege bagli)
# Betik idempotenttir: ikinci kosum ayni semayi ikinci kez eklemez.
set -euo pipefail

plist="${1:?Info.plist yolu gerekli}"
buddy=/usr/libexec/PlistBuddy
[ -f "$plist" ] || { echo "::error::Info.plist yok: $plist (WP-900 app/ios projesi repoda mi?)"; exit 1; }

has_key() { "$buddy" -c "Print :$1" "$plist" >/dev/null 2>&1; }

client_id="${GOOGLE_IOS_CLIENT_ID:-}"
if [ -n "$client_id" ]; then
  case "$client_id" in
    *.apps.googleusercontent.com) ;;
    *) echo "::error::GOOGLE_IOS_CLIENT_ID bicimi beklenmiyor (…apps.googleusercontent.com olmali)"; exit 1 ;;
  esac
  prefix="${client_id%.apps.googleusercontent.com}"
  scheme="com.googleusercontent.apps.${prefix}"

  if plutil -convert xml1 -o - "$plist" | grep -q "<string>${scheme}</string>"; then
    echo "Google URL semasi zaten var; dokunulmadi."
  else
    has_key CFBundleURLTypes || "$buddy" -c "Add :CFBundleURLTypes array" "$plist"
    n=0
    while has_key "CFBundleURLTypes:$n"; do n=$((n + 1)); done
    "$buddy" -c "Add :CFBundleURLTypes:$n dict" "$plist"
    "$buddy" -c "Add :CFBundleURLTypes:$n:CFBundleTypeRole string Editor" "$plist"
    "$buddy" -c "Add :CFBundleURLTypes:$n:CFBundleURLName string google-sign-in" "$plist"
    "$buddy" -c "Add :CFBundleURLTypes:$n:CFBundleURLSchemes array" "$plist"
    "$buddy" -c "Add :CFBundleURLTypes:$n:CFBundleURLSchemes:0 string $scheme" "$plist"
    echo "Google URL semasi eklendi (CFBundleURLTypes:$n)."
  fi
else
  echo "::warning::GOOGLE_IOS_CLIENT_ID bos: Google URL semasi eklenmedi; iOS derlemesinde Google ile giris dugmesi cizilmez."
fi

if has_key ITSAppUsesNonExemptEncryption; then
  echo "ITSAppUsesNonExemptEncryption zaten tanimli: $("$buddy" -c 'Print :ITSAppUsesNonExemptEncryption' "$plist")"
else
  "$buddy" -c "Add :ITSAppUsesNonExemptEncryption bool false" "$plist"
  echo "ITSAppUsesNonExemptEncryption=false eklendi (yalniz standart sifreleme)."
fi

plutil -lint "$plist"
