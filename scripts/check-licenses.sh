#!/usr/bin/env bash
# Vérifie la licence de chaque dépendance Dart (app + lumio_core, transitives
# comprises) : AGPL refusée, licence inconnue ou absente de
# scripts/licenses-allow.txt refusée. Nomme chaque dépendance en cause.
#
# `dart pub deps --json` n'expose pas les licences : on lit le fichier LICENSE
# de chaque paquet dans le cache pub (chemin donné par package_config.json) et
# on le classe d'après son texte.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ALLOW="$ROOT/scripts/licenses-allow.txt"

for dir in "$ROOT/app" "$ROOT/packages/lumio_core"; do
  (cd "$dir" && dart pub get >/dev/null)
done

python3 - "$ROOT" "$ALLOW" <<'PY'
import json, os, re, subprocess, sys
from urllib.parse import unquote, urlparse

root, allow_file = sys.argv[1], sys.argv[2]
allowed = {l.strip().lower() for l in open(allow_file)
           if l.strip() and not l.startswith('#')}

def classify(text):
    t = re.sub(r'\s+', ' ', text).lower()
    found = set()
    if 'gnu affero general public license' in t:
        found.add('AGPL')
    if 'gnu lesser general public license' in t or 'gnu library general public license' in t:
        found.add('LGPL')
    if 'gnu general public license' in t and 'version 3' in t and 'affero' not in t:
        found.add('GPL-3.0')
    if 'apache license' in t and 'version 2.0' in t:
        found.add('Apache-2.0')
    if 'mozilla public license' in t and ('2.0' in t):
        found.add('MPL-2.0')
    if 'permission is hereby granted, free of charge' in t:
        found.add('MIT')
    if 'redistribution and use in source and binary forms' in t:
        found.add('BSD-3-Clause' if 'neither the name' in t or 'the names of' in t
                  else 'BSD-2-Clause')
    if re.search(r'permission to use, copy, modify, and/or distribute this software for any purpose with or without fee', t):
        found.add('ISC')
    if 'altered source versions must be plainly marked' in t:
        found.add('Zlib')
    return found

problems, checked = [], 0
seen = set()
for sub in ('app', 'packages/lumio_core'):
    d = os.path.join(root, sub)
    deps = json.loads(subprocess.check_output(
        ['dart', 'pub', 'deps', '--json'], cwd=d, text=True))
    cfg = json.load(open(os.path.join(d, '.dart_tool', 'package_config.json')))
    roots = {p['name']: p for p in cfg['packages']}
    for pkg in deps['packages']:
        name = pkg['name']
        if name in seen or pkg['source'] in ('root', 'sdk', 'path'):
            continue
        seen.add(name)
        p = roots.get(name)
        if p is None:
            problems.append(f'{name}: introuvable dans package_config.json')
            continue
        uri = p['rootUri']
        base = unquote(urlparse(uri).path) if uri.startswith('file:') else \
            os.path.normpath(os.path.join(d, '.dart_tool', uri))
        lic = None
        for f in sorted(os.listdir(base)):
            if re.match(r'(license|licence|copying|unlicense)', f, re.I):
                lic = os.path.join(base, f)
                break
        if lic is None:
            problems.append(f'{name} {pkg["version"]}: aucun fichier de licence')
            continue
        checked += 1
        kinds = classify(open(lic, errors='replace').read())
        if not kinds:
            problems.append(f'{name} {pkg["version"]}: licence non reconnue ({lic})')
        for k in sorted(kinds):
            if k == 'AGPL':
                problems.append(f'{name} {pkg["version"]}: licence AGPL interdite')
            elif k.lower() not in allowed:
                problems.append(f'{name} {pkg["version"]}: licence {k} absente de licenses-allow.txt')

if problems:
    print('check-licenses : dépendances refusées :', file=sys.stderr)
    for p in problems:
        print('  - ' + p, file=sys.stderr)
    sys.exit(1)
print(f'check-licenses : {checked} dépendances vérifiées, toutes autorisées.')
PY
