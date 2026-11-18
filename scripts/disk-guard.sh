#!/usr/bin/env bash
# Échoue si l'espace libre du volume de données est inférieur à 80 Go.
set -euo pipefail

MIN_GB="${LUMIO_MIN_FREE_GB:-80}"
VOLUME="${LUMIO_DISK_VOLUME:-/System/Volumes/Data}"
[ -d "$VOLUME" ] || VOLUME="/"

free_kb=$(df -k "$VOLUME" | awk 'NR==2 {print $4}')
free_gb=$((free_kb / 1024 / 1024))

if [ "$free_gb" -lt "$MIN_GB" ]; then
  echo "disk-guard : ${free_gb} Go libres sur $VOLUME, minimum ${MIN_GB} Go. Build refusé." >&2
  exit 1
fi
echo "disk-guard : ${free_gb} Go libres sur $VOLUME (minimum ${MIN_GB} Go)."
