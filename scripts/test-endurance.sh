#!/usr/bin/env bash
# Teste scripts/endurance.sh en dry-run avec l'adb factice (aucune box).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d -t lumio-test-endurance.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
fail=0

# check <nom> <code attendu> <scénario> [heures]
check() {
  local name="$1" want="$2" scen="$3" hours="${4:-8}" got
  FAKE_ADB_SCENARIO="$scen" FAKE_ADB_STATE="$TMP/state-$name" \
    LUMIO_ENDURANCE_OUT="$TMP/$name.csv" \
    bash "$ROOT/scripts/endurance.sh" "$hours" --dry-run >"$TMP/$name.out" 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    echo "ok   $name (code $got)"
  else
    echo "FAIL $name : code $got, attendu $want"; sed 's/^/     /' "$TMP/$name.out"
    fail=1
  fi
}

check stable 0 stable
check legacy-format 0 legacy
check leak 1 leak
check crash 1 crash
check stuck 1 stuck
check silent 1 silent
check stale 1 stale
check error 1 error
check blip 0 blip
check noepoch 0 noepoch
check nologcat 2 nologcat
check epochblip 1 epochblip
check logcatflap 0 logcatflap
check freezelog 1 freezelog
check usage 2 stable 0

grep -q "aucune activité du lecteur" "$TMP/silent.out" && echo "ok   silent : message dédié" \
  || { echo "FAIL silent : message"; fail=1; }
grep -q 'dead' "$TMP/blip.csv" && { echo "FAIL blip : faux dead"; fail=1; }
grep -q 'dead'  "$TMP/crash.csv" && echo "ok   crash : ligne dead dans le CSV" \
  || { echo "FAIL crash : pas de ligne dead"; fail=1; }
rows="$(($(wc -l < "$TMP/stable.csv") - 1))"
[ "$rows" = 97 ] && echo "ok   stable : 97 relevés" \
  || { echo "FAIL stable : $rows relevés (attendu 97)"; fail=1; }
awk -F, 'NR>1 && $3 !~ /^[0-9]+$/ {bad=1} END{exit bad}' "$TMP/stable.csv" \
  && echo "ok   stable : PSS lue à chaque relevé" || { echo "FAIL PSS manquante"; fail=1; }

# Argument inconnu et box injoignable (adb qui échoue).
LUMIO_ADB=false LUMIO_ENDURANCE_OUT="$TMP/unreach.csv" \
  bash "$ROOT/scripts/endurance.sh" 1 >/dev/null 2>&1
[ $? = 2 ] && echo "ok   box injoignable (code 2)" || { echo "FAIL box injoignable"; fail=1; }

exit "$fail"
