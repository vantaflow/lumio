#!/usr/bin/env bash
# adb factice pour `scripts/endurance.sh --dry-run` et test-endurance.sh.
# FAKE_ADB_SCENARIO : stable (défaut) | leak (+1,5 %/relevé) | crash (l'application
# meurt au relevé 10) | stuck (lecture bloquée en buffering dès le relevé 5)
# | legacy (format meminfo ancien). FAKE_ADB_STATE : fichier compteur de relevés.
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
        if [ "$SCEN" = crash ] && [ "$(n)" -ge 10 ]; then exit 1; fi
        echo 4242 ;;
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
    if [ "$SCEN" = stuck ] && [ "$i" -ge 5 ]; then st=buffering; fi
    echo '11-18 10:00:00.000 I/flutter ( 1): LUMIO_PLAYER {"event":"phase_start","phase":"direct"}'
    echo "11-18 10:00:01.000 I/flutter ( 1): LUMIO_TORRENT {\"event\":\"tick\",\"phase\":\"torrent\",\"state\":\"$st\",\"pos_s\":$i}" ;;
esac
exit 0
