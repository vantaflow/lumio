#!/usr/bin/env bash
# Endurance de Lumio sur la box Android TV (story 3.6).
#
#   scripts/endurance.sh <heures> [--dry-run]
#
# L'application doit déjà tourner en mode boucle (build avec
# --dart-define=LUMIO_DEBUG_LOOP=1, voir docs/rapports/2026-11-18-endurance.md).
# Toutes les LUMIO_ENDURANCE_INTERVAL secondes (300 par défaut) : PSS total
# (dumpsys meminfo), application vivante (pidof), dernier état LUMIO_PLAYER /
# LUMIO_TORRENT du logcat. Une ligne CSV par relevé.
#
# Code de sortie : 0 = verdict OK ; 1 = l'application est morte, lecture figée
# ou PSS en hausse de plus de 30 % entre la 1re et la dernière heure ;
# 2 = box injoignable ou usage incorrect.
#
# Détaché : `nohup scripts/endurance.sh 8 > endurance.log 2>&1 &` (Mac), ou
# `setsid nohup …` (Linux). Sur Mac, préfixer par `caffeinate -i` (veille).
#
# Variables : LUMIO_BOX (défaut 192.168.0.43:5555, comme box-smoke.sh),
# LUMIO_ADB (binaire adb, défaut adb), LUMIO_ENDURANCE_INTERVAL (secondes),
# LUMIO_ENDURANCE_OUT (fichier CSV), LUMIO_PSS_MAX_GROWTH (pour cent, 30).
#
# --dry-run : adb factice (scripts/testing/fake-adb.sh), temps simulé, aucun
# sommeil, aucune box ; FAKE_ADB_SCENARIO=stable|leak|crash|stuck choisit le cas.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="dev.lumio.app"
BOX="${LUMIO_BOX:-192.168.0.43:5555}"
INTERVAL="${LUMIO_ENDURANCE_INTERVAL:-300}"
MAX_GROWTH="${LUMIO_PSS_MAX_GROWTH:-30}"
STUCK_LIMIT=3   # relevés consécutifs hors lecture (15 min à 5 min)
UNREACHABLE_LIMIT=3

usage() { echo "usage : $0 <heures> [--dry-run]" >&2; exit 2; }

HOURS=""
DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help) usage ;;
    -*) usage ;;
    *) [ -z "$HOURS" ] || usage; HOURS="$a" ;;
  esac
done
[ -n "$HOURS" ] || usage
case "$INTERVAL" in ''|*[!0-9]*) echo "endurance : intervalle invalide." >&2; exit 2 ;; esac
[ "$INTERVAL" -gt 0 ] || { echo "endurance : intervalle invalide." >&2; exit 2; }
SAMPLES="$(awk -v h="$HOURS" -v i="$INTERVAL" 'BEGIN{ if (h+0 > 0) printf "%d", h*3600/i; else print 0 }')"
if [ "$SAMPLES" -lt 2 ]; then
  echo "endurance : durée trop courte (au moins 2 relevés)." >&2
  exit 2
fi

if [ "$DRY" = 1 ]; then
  ADB="$ROOT/scripts/testing/fake-adb.sh"
  export FAKE_ADB_STATE="${FAKE_ADB_STATE:-$(mktemp -t lumio-fake-adb.XXXXXX)}"
  : > "$FAKE_ADB_STATE"
  OUT="${LUMIO_ENDURANCE_OUT:-$(mktemp -d -t lumio-endurance.XXXXXX)/endurance-dry.csv}"
else
  ADB="${LUMIO_ADB:-adb}"
  OUT="${LUMIO_ENDURANCE_OUT:-$ROOT/docs/rapports/endurance-$(date +%F).csv}"
  if [ -e "$OUT" ] && [ -z "${LUMIO_ENDURANCE_OUT:-}" ]; then
    OUT="${OUT%.csv}-$(date +%H%M%S).csv"
  fi
  "$ADB" connect "$BOX" >/dev/null 2>&1 || true
fi
mkdir -p "$(dirname "$OUT")"

box() { "$ADB" -s "$BOX" "$@"; }

if ! box get-state >/dev/null 2>&1; then
  echo "endurance : box $BOX injoignable." >&2
  exit 2
fi

echo "timestamp,elapsed_s,pss_kb,alive,pid,state,stuck_count" > "$OUT"
echo "endurance : $SAMPLES relevés toutes les ${INTERVAL}s -> $OUT"

# PSS total en Ko : « TOTAL PSS: N » (Android 14), sinon 1re colonne de « TOTAL ».
parse_pss() {
  awk '
    match($0, /TOTAL PSS: *[0-9]+/) { s = substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); print s; exit }
    $1 == "TOTAL" && $2 ~ /^[0-9]+$/ && !legacy { legacy = $2 }
    END { if (legacy != "") print legacy }
  ' | head -n 1
}

# Valeur du champ "state" du dernier battement (tick) LUMIO_PLAYER/TORRENT.
last_state() {
  { box logcat -d -t 4000 2>/dev/null || true; } \
    | grep -E 'LUMIO_(PLAYER|TORRENT) .*"event":"tick"' | tail -n 1 \
    | sed -n 's/.*"state":"\([a-z]*\)".*/\1/p'
}

stuck=0
unreachable=0
stuck_seen=0
status=0
i=0
while [ "$i" -le "$SAMPLES" ]; do
  elapsed=$((i * INTERVAL))
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if ! box get-state >/dev/null 2>&1; then
    unreachable=$((unreachable + 1))
    echo "$ts,$elapsed,,,,unreachable,$stuck" >> "$OUT"
    if [ "$unreachable" -ge "$UNREACHABLE_LIMIT" ]; then
      echo "endurance : box injoignable $UNREACHABLE_LIMIT relevés de suite." >&2
      exit 2
    fi
  else
    unreachable=0
    pid="$(box shell pidof "$PKG" 2>/dev/null | tr -d '\r' | awk '{print $1}' || true)"
    if [ -z "$pid" ]; then
      echo "$ts,$elapsed,,0,,dead,$stuck" >> "$OUT"
      echo "endurance : ÉCHEC, l'application est morte à ${elapsed}s." >&2
      exit 1
    fi
    pss="$(box shell dumpsys meminfo "$PKG" 2>/dev/null | tr -d '\r' | parse_pss || true)"
    state="$(last_state || true)"
    if [ -n "$state" ] && [ "$state" != "playing" ]; then
      stuck=$((stuck + 1))
    else
      stuck=0
    fi
    [ "$stuck" -ge "$STUCK_LIMIT" ] && stuck_seen=1
    echo "$ts,$elapsed,$pss,1,$pid,${state:-none},$stuck" >> "$OUT"
  fi
  i=$((i + 1))
  if [ "$i" -le "$SAMPLES" ] && [ "$DRY" = 0 ]; then sleep "$INTERVAL"; fi
done

# PSS moyenne de la 1re et de la dernière heure (au plus la moitié de la durée).
verdict="$(awk -F, -v max="$MAX_GROWTH" '
  NR == 1 { next }
  $3 ~ /^[0-9]+$/ { t[++n] = $2; p[n] = $3 }
  END {
    if (n < 2) { print "INCONNU 0 0 0"; exit }
    total = t[n]; win = total / 2; if (win > 3600) win = 3600
    for (k = 1; k <= n; k++) {
      if (t[k] <= win) { fs += p[k]; fc++ }
      if (t[k] >= total - win) { ls += p[k]; lc++ }
    }
    if (fc == 0 || lc == 0) { print "INCONNU 0 0 0"; exit }
    f = fs / fc; l = ls / lc; g = (l - f) / f * 100
    printf "%s %.1f %d %d\n", (g > max ? "KO" : "OK"), g, f, l
  }' "$OUT")"
set -- $verdict
echo "endurance : PSS 1re heure ${3} Ko, dernière heure ${4} Ko, croissance ${2} % (max ${MAX_GROWTH} %)."
case "$1" in
  KO) echo "endurance : ÉCHEC, fuite mémoire probable." >&2; status=1 ;;
  INCONNU) echo "endurance : ÉCHEC, PSS illisible." >&2; status=1 ;;
esac
if [ "$stuck_seen" = 1 ]; then
  echo "endurance : ÉCHEC, lecture figée (état hors lecture sur $STUCK_LIMIT relevés de suite)." >&2
  status=1
fi
[ "$status" = 0 ] && echo "endurance : OK."
exit "$status"
