#!/usr/bin/env bash
# WP-903 — imzali IPA uret ve (istenirse) App Store Connect / TestFlight'a yukle.
#
# Mac'siz yayin: bu betik YALNIZ GitHub Actions macOS runner'inda kosar
# (.github/workflows/ios-release.yml, mode=testflight). Imza OTOMATIKTIR:
# dagitim sertifikasi ve App Store profili App Store Connect API anahtariyla
# bulutta olusturulur/yenilenir (`-allowProvisioningUpdates` + authenticationKey*).
# Repoda ve runner diskinde kalici sertifika/profil YOKTUR.
#
# On kosul: cagiran `flutter build ios --config-only --build-name --build-number
# --dart-define-from-file=env.json` ile Generated.xcconfig'i ve pod'lari hazirlamis
# olmali (define'lar orada gomulur; xcodebuild onlari oradan okur).
#
# Calisma dizini: app/
# Ortam:
#   APPLE_TEAM_ID             10 karakter Team ID (developer.apple.com -> Membership)
#   ASC_KEY_ID                App Store Connect API Key ID (10 karakter)
#   ASC_ISSUER_ID             Issuer ID (UUID)
#   ASC_KEY_P8                .p8 icerigi: HAM metin (-----BEGIN PRIVATE KEY-----...)
#                             YA DA onun base64'u. Ikisi de kabul edilir.
#   EXPECTED_BUILD_NAME       ornek 1.0.88  (IPA icinde dogrulanir)
#   EXPECTED_BUILD_NUMBER     ornek 88.412  (IPA icinde dogrulanir)
#   OUT_DIR                   IPA + arsivin yazilacagi klasor
#   UPLOAD                    true -> altool ile yukle; baska her deger -> yalniz IPA
set -euo pipefail

: "${APPLE_TEAM_ID:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8:?}"
: "${EXPECTED_BUILD_NAME:?}" "${EXPECTED_BUILD_NUMBER:?}" "${OUT_DIR:?}"
UPLOAD="${UPLOAD:-false}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "::error::APPLE_TEAM_ID 10 karakterlik buyuk harf/rakam olmali."; exit 1; }
[[ "$ASC_KEY_ID" =~ ^[A-Z0-9]{8,12}$ ]] || { echo "::error::APP_STORE_CONNECT_KEY_ID bicimi beklenmiyor."; exit 1; }
[[ "$ASC_ISSUER_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || {
  echo "::error::APP_STORE_CONNECT_ISSUER_ID UUID bicimi olmali."; exit 1; }

# --- API anahtari: altool ve xcodebuild ayni dosyayi okur ---------------------
key_dir="$HOME/.appstoreconnect/private_keys"
key_path="$key_dir/AuthKey_${ASC_KEY_ID}.p8"
mkdir -p "$key_dir"
chmod 700 "$key_dir"
trap 'rm -f "$key_path"' EXIT
if printf '%s' "$ASC_KEY_P8" | grep -q 'BEGIN PRIVATE KEY'; then
  printf '%s\n' "$ASC_KEY_P8" > "$key_path"
else
  printf '%s' "$ASC_KEY_P8" | tr -d ' \r\n' | base64 --decode > "$key_path" 2>/dev/null || {
    echo "::error::APP_STORE_CONNECT_API_KEY_P8 ne ham .p8 ne gecerli base64."; exit 1; }
fi
chmod 600 "$key_path"
grep -q 'BEGIN PRIVATE KEY' "$key_path" || {
  echo "::error::APP_STORE_CONNECT_API_KEY_P8 cozuldu ama bir .p8 ozel anahtari degil."; exit 1; }
echo "API anahtari yazildi: AuthKey_${ASC_KEY_ID}.p8 ($(wc -c < "$key_path" | tr -d ' ') bayt)"

auth=(-allowProvisioningUpdates
      -authenticationKeyPath "$key_path"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

mkdir -p "$OUT_DIR"
archive="$OUT_DIR/Runner.xcarchive"
export_dir="$OUT_DIR/ipa"
options="$OUT_DIR/ExportOptions.plist"
sed "s/__TEAM_ID__/${APPLE_TEAM_ID}/" "$here/ExportOptions.plist.template" > "$options"
plutil -lint "$options"

# --- 1) arsiv ------------------------------------------------------------------
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  "${auth[@]}" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  archive

# --- 2) IPA disa aktar -------------------------------------------------------------
xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportOptionsPlist "$options" \
  -exportPath "$export_dir" \
  "${auth[@]}"

ipa="$(find "$export_dir" -maxdepth 1 -name '*.ipa' -print -quit)"
[ -n "$ipa" ] || { echo "::error::Disa aktarim IPA uretmedi."; exit 1; }

# --- 3) IPA gercekten istenen surumu mu tasiyor? ------------------------------------
# Yukleme 200 dondugunde bile yanlis numarali derleme TestFlight'ta "bu surum
# zaten var" diye reddedilir ya da daha kotusu yanlis surum adiyla yayinlanir.
tmp="$(mktemp -d)"
unzip -q -o "$ipa" 'Payload/*.app/Info.plist' -d "$tmp"
info="$(find "$tmp/Payload" -maxdepth 2 -name Info.plist -print -quit)"
got_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info")"
got_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info")"
got_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info")"
echo "IPA: $got_id $got_name ($got_build)"
[ "$got_name" = "$EXPECTED_BUILD_NAME" ] || { echo "::error::CFBundleShortVersionString $got_name != $EXPECTED_BUILD_NAME"; exit 1; }
[ "$got_build" = "$EXPECTED_BUILD_NUMBER" ] || { echo "::error::CFBundleVersion $got_build != $EXPECTED_BUILD_NUMBER"; exit 1; }
[ "$got_id" = "com.manilmax.focuscamp" ] || { echo "::error::Bundle id $got_id != com.manilmax.focuscamp"; exit 1; }

shasum -a 256 "$ipa" | tee "$ipa.sha256"

# --- 4) yukle -----------------------------------------------------------------------
if [ "$UPLOAD" = "true" ]; then
  xcrun altool --upload-app --type ios --file "$ipa" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "Yuklendi: $got_name ($got_build). App Store Connect islemesi 5-30 dk surer; sonra TestFlight'ta gorunur."
else
  echo "UPLOAD=$UPLOAD: yukleme atlandi, yalniz IPA uretildi."
fi
