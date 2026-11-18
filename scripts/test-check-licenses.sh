#!/usr/bin/env bash
# Tests du classifieur de licences (fixtures AGPL / GPL-3.0).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT/scripts" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from license_classify import classify

GPL = """                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>

  13. Use with the GNU Affero General Public License.

  Notwithstanding any other provision of this License, you have
permission to link or combine any covered work with a work licensed
under version 3 of the GNU Affero General Public License into a single
combined work.
"""
AGPL = """                    GNU AFFERO GENERAL PUBLIC LICENSE
                       Version 3, 19 November 2007
"""
cases = {
    'gpl3 citant AGPL': (GPL, {'GPL-3.0'}),
    'agpl nu': (AGPL, {'AGPL'}),
    'agpl avec copyright': ('Copyright (c) 2024 Someone\nSPDX-License-Identifier: AGPL-3.0\n\n' + AGPL, {'AGPL'}),
    'agpl titre en milieu de fichier': ('Notice\n' * 40 + AGPL, {'AGPL'}),
}
bad = 0
for name, (text, want) in cases.items():
    got = classify(text)
    if got != want:
        bad += 1
        print(f'ECHEC {name}: obtenu {got}, attendu {want}')
if bad:
    sys.exit(1)
print('test-check-licenses : OK')
PY
