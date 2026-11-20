#!/usr/bin/env bash
# Télécharge TorrServer (version et SHA-256 épinglés dans scripts/torrserver.pins)
# et le place en app/android/app/src/main/jniLibs/<abi>/libtorrserver.so.
# Cache : ${LUMIO_TORRSERVER_CACHE:-~/.cache/lumio-torrserver}. Un binaire dont la
# somme ne correspond pas est supprimé et le script échoue : rien n'est installé.
# Usage : fetch-torrserver.sh [--verify] [arm7|arm64 ...]   (défaut : les deux)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=torrserver.pins
. "$ROOT/scripts/torrserver.pins"
CACHE="${LUMIO_TORRSERVER_CACHE:-$HOME/.cache/lumio-torrserver}/$VERSION"
JNI="$ROOT/app/android/app/src/main/jniLibs"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

verify_only=0
if [ "${1:-}" = "--verify" ]; then verify_only=1; shift; fi
targets=("$@")
[ ${#targets[@]} -gt 0 ] || targets=(arm7 arm64)

fetch() {
  local asset="$1" want="$2" abi="$3"
  local cached="$CACHE/TorrServer-android-$asset"
  local dest="$JNI/$abi/libtorrserver.so"
  if [ "$verify_only" = 1 ]; then
    [ -f "$dest" ] || { echo "absent : $dest" >&2; return 1; }
    [ "$(sha256 "$dest")" = "$want" ] || { echo "somme incorrecte : $dest" >&2; return 1; }
    echo "ok : $abi ($VERSION)"; return 0
  fi
  mkdir -p "$CACHE" "$JNI/$abi"
  if [ ! -f "$cached" ] || [ "$(sha256 "$cached")" != "$want" ]; then
    rm -f "$cached"
    curl -fL --retry 4 --retry-delay 3 -o "$cached.part" \
      "https://github.com/YouROK/TorrServer/releases/download/$VERSION/TorrServer-android-$asset"
    got="$(sha256 "$cached.part")"
    if [ "$got" != "$want" ]; then
      rm -f "$cached.part"
      echo "SHA-256 incorrect pour $asset : attendu $want, obtenu $got" >&2
      return 1
    fi
    mv "$cached.part" "$cached"
  fi
  cp "$cached" "$dest"
  chmod 755 "$dest"
  [ "$(sha256 "$dest")" = "$want" ] || { rm -f "$dest"; echo "copie corrompue : $abi" >&2; return 1; }
  echo "ok : $abi ($VERSION)"
}

for t in "${targets[@]}"; do
  case "$t" in
    arm7)  fetch arm7  "$SHA256_ARM7"  armeabi-v7a ;;
    arm64) fetch arm64 "$SHA256_ARM64" arm64-v8a ;;
    *) echo "cible inconnue : $t" >&2; exit 2 ;;
  esac
done
