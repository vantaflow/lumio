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
# 2 = box injoignable, logcat illisible 3 relevés de suite, PSS illisible/nulle
# (INCONNU) ou usage incorrect.
#
# Détaché : `nohup scripts/endurance.sh 8 > endurance.log 2>&1 &` (Mac), ou
# `setsid nohup …` (Linux). Sur Mac, préfixer par `caffeinate -i` (veille).
#
# Variables : LUMIO_BOX (défaut 192.168.0.43:5555, comme box-smoke.sh),
# LUMIO_ADB (binaire adb, défaut adb), LUMIO_ENDURANCE_INTERVAL (secondes),
# LUMIO_ENDURANCE_OUT (fichier CSV), LUMIO_PSS_MAX_GROWTH (pour cent, 30).
#
# --dry-run : adb factice (scripts/testing/fake-adb.sh), temps simulé, aucun
# sommeil, aucune box ; FAKE_ADB_SCENARIO choisit le cas (stable, leak, crash, stuck, silent,
# stale, error, blip, legacy, noepoch, nologcat : voir fake-adb.sh).
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
echo "endurance : $((SAMPLES + 1)) relevés toutes les ${INTERVAL}s -> $OUT"

# PSS total en Ko : « TOTAL PSS: N » (Android 14), sinon 1re colonne de « TOTAL ».
parse_pss() {
  awk '
    match($0, /TOTAL PSS: *[0-9]+/) { s = substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", s); print s; exit }
    $1 == "TOTAL" && $2 ~ /^[0-9]+$/ && !legacy { legacy = $2 }
    END { if (legacy != "") print legacy }
  ' | head -n 1
}

# État du dernier battement LUMIO_PLAYER/TORRENT : "state" du tick, ou `error`
# (dernier évènement en erreur), `stale` (tick plus vieux que 2 intervalles,
# horloge de la box), `none` (aucun battement). Tout sauf `playing` compte.
last_state() {
  local line now ts age
  line="$(printf '%s\n' "$1" \
    | grep -E 'LUMIO_(PLAYER|TORRENT) .*"event":"(tick|error)"' | tail -n 1)"
  [ -n "$line" ] || { echo none; return; }
  case "$line" in *'"event":"error"'*) echo error; return ;; esac
  # Péremption : seulement si l'heure de la box ET celle du tick sont lisibles.
  if [ "$EPOCH" = 1 ]; then
    now="$(box shell date +%s 2>/dev/null | tr -d '\r' || true)"
    ts="$(echo "$line" | awk '{ sub(/\..*/, "", $1); print $1 }')"
    case "$now" in ''|*[!0-9]*) now="" ;; esac
    case "$ts" in ''|*[!0-9]*) ts="" ;; esac
    if [ -n "$now" ] && [ -n "$ts" ]; then
      age=$((now - ts))
      if [ "$age" -gt $((2 * INTERVAL)) ]; then echo stale; return; fi
    fi
  fi
  echo "$line" | sed -n 's/.*"state":"\([a-z]*\)".*/\1/p'
}

# Logcat : `-v epoch` d'abord ; sinon repli sans epoch (péremption ignorée,
# signalé une fois). Rend 1 si logcat est illisible dans les deux cas.
EPOCH=1
fetch_logcat() {
  if [ "$EPOCH" = 1 ]; then
    if LOGS="$(box logcat -d -v epoch -t 4000 2>/dev/null)"; then return 0; fi
    if LOGS="$(box logcat -d -t 4000 2>/dev/null)"; then
      EPOCH=0
      echo "endurance : logcat -v epoch refusé, repli sans péremption des battements." >&2
      return 0
    fi
    return 1
  fi
  LOGS="$(box logcat -d -t 4000 2>/dev/null)"
}
LOGS=""
logcat_fail=0

stuck=0
unreachable=0
stuck_seen=0
none_seen=0
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
    # Trois essais espacés de 5 s : un raté d'adb (Wi-Fi) n'est pas une mort.
    pid=""
    for try in 1 2 3; do
      pid="$(box shell pidof "$PKG" 2>/dev/null | tr -d '\r' | awk '{print $1}' || true)"
      [ -n "$pid" ] && break
      if [ "$try" -lt 3 ] && [ "$DRY" = 0 ]; then sleep 5; fi
    done
    if [ -z "$pid" ]; then
      echo "$ts,$elapsed,,0,,dead,$stuck" >> "$OUT"
      echo "endurance : ÉCHEC, l'application est morte à ${elapsed}s." >&2
      exit 1
    fi
    pss="$(box shell dumpsys meminfo "$PKG" 2>/dev/null | tr -d '\r' | parse_pss || true)"
    if fetch_logcat; then
      logcat_fail=0
      state="$(last_state "$LOGS" || true)"
    else
      logcat_fail=$((logcat_fail + 1))
      if [ "$logcat_fail" -ge 3 ]; then
        echo "$ts,$elapsed,${pss:-},1,$pid,logcat_error,$stuck" >> "$OUT"
        echo "endurance : logcat illisible $logcat_fail relevés de suite (pas un échec du lecteur)." >&2
        exit 2
      fi
      state="logcat_error"
    fi
    # `none` compte aussi : sans battement, le lecteur n'est pas éprouvé.
    # Logcat illisible : relevé neutre (ni figé ni lecture), voir ci-dessus.
    if [ "$state" = logcat_error ]; then
      :
    elif [ "${state:-none}" != "playing" ]; then
      stuck=$((stuck + 1))
    else
      stuck=0
    fi
    if [ "$stuck" -ge "$STUCK_LIMIT" ]; then
      stuck_seen=1
      [ "${state:-none}" = none ] && none_seen=1
    fi
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
    if (fc == 0 || lc == 0 || fs == 0) { print "INCONNU 0 0 0"; exit }
    f = fs / fc; l = ls / lc; g = (l - f) / f * 100
    printf "%s %.1f %d %d\n", (g > max ? "KO" : "OK"), g, f, l
  }' "$OUT")"
# shellcheck disable=SC2086 # découpage voulu : « STATUT croissance 1re dernière »
set -- $verdict
echo "endurance : PSS 1re heure ${3} Ko, dernière heure ${4} Ko, croissance ${2} % (max ${MAX_GROWTH} %)."
case "$1" in
  KO) echo "endurance : ÉCHEC, fuite mémoire probable." >&2; status=1 ;;
  INCONNU) echo "endurance : ÉCHEC, PSS illisible ou nulle." >&2; status=2 ;;
esac
if [ "$stuck_seen" = 1 ]; then
  if [ "$none_seen" = 1 ]; then
    echo "endurance : ÉCHEC, aucune activité du lecteur (aucun battement LUMIO_* sur $STUCK_LIMIT relevés de suite ; boucle LUMIO_DEBUG_LOOP lancée ?)." >&2
  else
    echo "endurance : ÉCHEC, lecture figée (état hors lecture sur $STUCK_LIMIT relevés de suite)." >&2
  fi
  [ "$status" = 2 ] || status=1
fi
[ "$status" = 0 ] && echo "endurance : OK."
exit "$status"
