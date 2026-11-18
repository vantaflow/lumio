#!/usr/bin/env bash
# adb factice pour `scripts/endurance.sh --dry-run` et test-endurance.sh.
# FAKE_ADB_SCENARIO : stable (défaut) | leak (+1,5 %/relevé) | crash (l'application
# meurt au relevé 10) | stuck (lecture bloquée en buffering dès le relevé 5)
# | silent (aucun battement dans logcat) | stale (battements vieux) | error (dernier
# évènement en erreur) | blip (un seul pidof raté au relevé 10) | legacy (format meminfo ancien). FAKE_ADB_STATE : fichier compteur de relevés.
set -u
SCEN="${FAKE_ADB_SCENARIO:-stable}"
STATE="${FAKE_ADB_STATE:?FAKE_ADB_STATE requis}"

# Retire « -s <série> ».
if [ "${1:-}" = "-s" ]; then shift 2; fi
cmd="${1:-}"; shift || true

n() { wc -l < "$STATE" | tr -d ' '; }

case "$cmd" in
  connect) echo "connected to fake" ;;
  get-state) echo device ;;
  shell)
    sub="${1:-}"; shift || true
    case "$sub" in
      pidof)
        if [ "$SCEN" = blip ] && [ "$(n)" -ge 10 ] && [ ! -e "$STATE.blip" ]; then
          : > "$STATE.blip"; exit 1
        fi
        if [ "$SCEN" = crash ] && [ "$(n)" -ge 10 ]; then exit 1; fi
        echo 4242 ;;
      date) date +%s ;;
      dumpsys)
        # Un relevé = un appel meminfo.
        echo x >> "$STATE"
        i=$(n)
        case "$SCEN" in
          leak) pss=$((200000 + i * 3000)) ;;
          *) pss=$((200000 + (i % 5) * 1000)) ;;
        esac
        echo "Applications Memory Usage (in Kilobytes):"
        if [ "$SCEN" = legacy ]; then
          echo "           TOTAL   $pss    1000    2000     3000    50000"
        else
          echo "        TOTAL PSS:   $pss            TOTAL RSS:   300000      TOTAL SWAP PSS:        0"
        fi ;;
    esac ;;
  logcat)
    i=$(n)
    st=playing
    ts=$(date +%s)
    if [ "$SCEN" = stuck ] && [ "$i" -ge 5 ]; then st=buffering; fi
    if [ "$SCEN" = stale ] && [ "$i" -ge 5 ]; then ts=$((ts - 100000)); fi
    [ "$SCEN" = silent ] && exit 0
    echo "$ts.000  4242  4242 I flutter: LUMIO_PLAYER {\"event\":\"phase_start\",\"phase\":\"direct\"}"
    echo "$ts.500  4242  4242 I flutter: LUMIO_TORRENT {\"event\":\"tick\",\"phase\":\"torrent\",\"state\":\"$st\",\"pos_s\":$i}"
    if [ "$SCEN" = error ] && [ "$i" -ge 5 ]; then
      echo "$ts.900  4242  4242 I flutter: LUMIO_TORRENT {\"event\":\"error\",\"phase\":\"torrent\",\"error\":\"X\"}"
    fi ;;
esac
exit 0
