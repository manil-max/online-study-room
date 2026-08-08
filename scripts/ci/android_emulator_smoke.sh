#!/usr/bin/env bash
# Android emulatorunde sayac smoke testi.
#
# 🔴 WP-572 — BU DOSYA NEDEN VAR (kok neden olculdu, tahmin degil)
#
# Bu blok eskiden `ci.yml` icinde `reactivecircus/android-emulator-runner`
# adiminin `script:` alaninda cok satirli olarak duruyordu. Action o alani TEK
# BIR KABUK BETIGI OLARAK KOSTURMUYOR: her SATIRI ayri ayri `/usr/bin/sh -c`
# ile calistiriyor. Kanit, kosum 31281652153 (job 93163879845) logundan:
#
#     [command]/usr/bin/sh -c echo "GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-...}"
#     GITHUB_WORKSPACE=/home/runner/work/online-study-room/online-study-room
#     ...
#     mkdir: cannot create directory '': No such file or directory
#     ##[error]The process '/usr/bin/sh' failed with exit code 1
#
# Yani `GITHUB_WORKSPACE` TANIMLIYDI; ama `LOG_DIR=...` atamasi bir `sh -c`
# icinde yapilip `mkdir -p "$LOG_DIR"` BASKA bir `sh -c` icinde kosuldugu icin
# degisken ucmustu. Ayni sebeple `set -u` ve `set -e` de sonraki satirlara
# gecmiyordu.
#
# Sonucu tek cumleyle: **Android sayac smoke testi CI'da HIC KOSMADI.** Kapi
# aylardir vardi, olctugu sey yoktu -- v58'de geri sayim/pomodoro acilista
# coktugunda (Dart `setInt` -> native `getInt` ClassCastException) 18 kapinin
# hicbiri kirmizi donmemisti ve bu is tam onu yakalamak icin yazilmisti.
#
# Cozum: butun mantik TEK dosyada; workflow'daki `script:` alani TEK SATIR
# (`bash ../scripts/ci/android_emulator_smoke.sh <api-level>`). Boylece degisken
# kapsami, `set -u` ve hata yayilimi normal bir betikteki gibi calisir.
#
# Kullanim: emulator-runner adiminin `working-directory: app` degeriyle, yani
# `app/` icinden cagrilir. Tek argüman: API seviyesi (log dosyasi adlandirmasi).
#
# 🔴 `set -e` BILEREK YOK: kirmiziyi yutmadan logcat toplanabilsin diye cikis
# kodu elle tasinir. Test dustugunde asil kanit crash tamponundadir; `set -e`
# ile o tampon hic okunmazdi.
set -u

API_LEVEL="${1:?API seviyesi ilk argüman olarak verilmeli}"

echo "PWD=$PWD"
echo "GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-<tanimsiz>}"
echo "ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-<tanimsiz>}"
command -v adb || echo "UYARI: adb PATH'te yok"
command -v flutter || echo "UYARI: flutter PATH'te yok"

# Tanimsizsa calisma dizinine dus: tani ciktisi ucmasin diye LOG_DIR yuzunden
# olmek kabul edilemez.
LOG_DIR="${GITHUB_WORKSPACE:-$PWD}/emulator-logs"
mkdir -p "$LOG_DIR"
CRASH_LOG="$LOG_DIR/crash-api${API_LEVEL}.log"

DEVICE="$(adb devices | awk '/\tdevice$/ {print $1; exit}')"
if [ -z "$DEVICE" ]; then
  echo "::error::adb hicbir hazir cihaz bildirmedi; emulator boot etmemis."
  exit 1
fi
echo "Cihaz: $DEVICE"
adb logcat -c

status=0
# 🔴 APK once derlenip `install -g` (tum runtime izinleri ver) ile kurulur,
# sonra test kosar. Sebebi olculdu: API 33'te ilk `Baslat` POST_NOTIFICATIONS
# diyalogunu acar, kimse dokunmadigi icin diyalog ekranda kalir ve ikinci
# `Baslat` `PlatformException(permissionRequestInProgress)` firlatir — kapi
# sayacla ilgisi olmayan bir sebeple kirmizi duserdi. `flutter test` ayni
# APK'yi yeniden kurar; `-r` runtime izinlerini korur.
flutter build apk --debug --flavor local \
  --dart-define-from-file=env.json || status=$?

if [ $status -eq 0 ]; then
  adb -s "$DEVICE" install -r -t -g \
    build/app/outputs/flutter-apk/app-local-debug.apk || status=$?
fi

if [ $status -eq 0 ]; then
  flutter test -d "$DEVICE" --flavor local \
    integration_test/android_timer_smoke_test.dart \
    --dart-define-from-file=env.json || status=$?
fi

adb logcat -b crash -d > "$CRASH_LOG" || true
adb logcat -d -s flutter:V AndroidRuntime:E \
  > "$LOG_DIR/flutter-api${API_LEVEL}.log" || true

# Sessiz gecme yok: surec cokmusse `flutter test` bazen yalniz "Lost connection"
# der ve kok neden yalniz crash tamponundadir.
if grep -q 'ClassCastException' "$CRASH_LOG"; then
  echo "::error::logcat crash tamponunda ClassCastException var — v58 sinifi Dart↔native prefs tip kaymasi."
  status=1
fi
if grep -q 'com.manilmax.online_study_room' "$CRASH_LOG"; then
  echo "::error::Uygulama sureci logcat crash tamponuna dustu."
  status=1
fi

exit $status
