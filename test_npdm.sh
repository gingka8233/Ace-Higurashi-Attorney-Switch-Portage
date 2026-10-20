#!/usr/bin/env bash
# Test rapide du NPDM avant la compilation complete du NSP.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON="$ROOT/npdm_template.json"
[[ -s "$JSON" ]] || { echo 'ERREUR: npdm_template.json absent du meme dossier.' >&2; exit 1; }
export PATH="/opt/devkitpro/tools/bin:/c/devkitPro/tools/bin:$PATH"
NPDMTOOL=''
for candidate in \
  /opt/devkitpro/tools/bin/npdmtool.exe \
  /opt/devkitpro/tools/bin/npdmtool \
  /c/devkitPro/tools/bin/npdmtool.exe \
  /c/devkitPro/tools/bin/npdmtool; do
  if [[ -f "$candidate" ]]; then NPDMTOOL="$candidate"; break; fi
done
if [[ -z "$NPDMTOOL" ]]; then
  for candidate in npdmtool.exe npdmtool; do
    if command -v "$candidate" >/dev/null 2>&1; then NPDMTOOL="$(command -v "$candidate")"; break; fi
  done
fi
[[ -n "$NPDMTOOL" ]] || { echo 'ERREUR: npdmtool non trouve dans devkitPro.' >&2; exit 1; }
python3 - "$JSON" <<'PY'
import json, pathlib, sys
obj=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
flags=[x['value'] for x in obj.get('kernel_capabilities', []) if x.get('type')=='debug_flags']
assert len(flags)==1, 'Il faut exactement une section debug_flags'
keys=('allow_debug','force_debug','force_debug_prod')
assert sum(flags[0].get(k) is True for k in keys) <= 1, 'Debug flags mutuellement exclusifs'
assert flags[0]['allow_debug'] is True and flags[0]['force_debug'] is False and flags[0]['force_debug_prod'] is False
print('JSON et debug_flags : OK')
PY
DIR="$(mktemp -d)"
trap 'rm -rf -- "$DIR"' EXIT
"$NPDMTOOL" "$JSON" "$DIR/main.npdm"
python3 - "$DIR/main.npdm" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); assert p.is_file() and p.stat().st_size > 4, 'Le fichier NPDM n a pas ete cree'
assert p.read_bytes()[:4] == b'META', 'En-tete NPDM invalide (attendu META)'
print('SUCCES : npdmtool a cree un main.npdm valide (signature META).')
PY
