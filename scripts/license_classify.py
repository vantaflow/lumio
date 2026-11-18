import re


def classify(text):
    t = re.sub(r'\s+', ' ', text).lower()
    found = set()
    # Le texte GPL-3.0 cite l'AGPL (article 13) : seul un titre compte, soit
    # dans les ~300 premiers caractères (après un éventuel copyright/SPDX),
    # soit sur une ligne à lui seul.
    head = t.lstrip()[:300]
    is_agpl = bool(
        re.search(r'gnu affero general public license\s+version 3', head)
        or re.search(r'^\s*gnu affero general public license(\s+version 3)?\s*$',
                     text, re.I | re.M))
    if is_agpl:
        found.add('AGPL')
    if 'gnu lesser general public license' in t or 'gnu library general public license' in t:
        found.add('LGPL')
    if 'gnu general public license' in t and 'version 3' in t and not is_agpl:
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
