#!/usr/bin/env python3
"""Basic static completeness checks for this game's NScripter data."""
from collections import Counter
from pathlib import Path
import re
import sys

from unpack_nsa import entries


def audit(root):
    root = Path(root)
    script_file = root / '0.txt'
    arc_file = root / 'arc.nsa'
    font_file = root / 'default.ttf'
    if not all(f.is_file() for f in [script_file, arc_file, font_file]):
        raise SystemExit('Expected 0.txt, arc.nsa, default.ttf in ' + str(root))
    script = script_file.read_bytes().decode('cp932')
    game_paths = {p.relative_to(root).as_posix().lower() for p in root.rglob('*') if p.is_file()}
    items = list(entries(arc_file.read_bytes()))
    archive_paths = {name.lower() for name, _, _, _ in items}
    available = game_paths | archive_paths
    labels = {line.strip().lower() for line in script.splitlines() if line.startswith('*')}
    refs = Counter()
    for line in script.splitlines():
        if not line.strip() or line.lstrip().startswith(';'):
            continue
        for path in re.findall(r'(?:img|sound)\\[^"\s,;:]+', line, re.IGNORECASE):
            refs[path.replace('\\', '/').lower()] += 1
    missing = sorted(set(refs).difference(available))
    compression = Counter(comp for _, comp, _, _ in items)
    print(f'Script: {len(script.splitlines())} lines; {len(labels)} labels; CP932 encoding')
    print(f'NSA archive: {len(items)} resources; compression modes: {dict(compression)}')
    print(f'Referenced media: {len(refs)} paths; {sum(refs.values())} references')
    if missing:
        print('MISSING:', *missing, sep='\n  ')
        return False
    print('OK: all static img/sound references have a matching resource')
    print('NOTE: This is not a runtime compatibility test on Nintendo Switch.')
    return True


if __name__ == '__main__':
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent/'game'
    sys.exit(0 if audit(root) else 1)
