#!/usr/bin/env bash
# Build release armeabi-v7a, installe sur la box Android TV, attend LUMIO_READY.
# Code de sortie 0 si l'application démarre, 1 sinon.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOX="${LUMIO_BOX:-192.168.0.43:5555}"
PKG="dev.lumio.app"
TIMEOUT="${LUMIO_SMOKE_TIMEOUT:-60}"

export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home}"

bash "$ROOT/scripts/disk-guard.sh"

adb connect "$BOX" >/dev/null 2>&1 || true
if ! adb -s "$BOX" get-state >/dev/null 2>&1; then
  echo "box-smoke : box $BOX injoignable." >&2
  exit 1
fi

cd "$ROOT/app"
flutter build apk --release --target-platform android-arm
APK="build/app/outputs/flutter-apk/app-release.apk"

adb -s "$BOX" install -r "$APK"
adb -s "$BOX" shell am force-stop "$PKG" || true
adb -s "$BOX" logcat -c
adb -s "$BOX" shell am start -n "$PKG/.MainActivity"

deadline=$((SECONDS + TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
  if adb -s "$BOX" logcat -d | grep -q "LUMIO_READY"; then
    echo "box-smoke : LUMIO_READY reçu."
    exit 0
  fi
  sleep 2
done
echo "box-smoke : LUMIO_READY absent après ${TIMEOUT} s." >&2
exit 1
