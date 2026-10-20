#!/usr/bin/env bash
# Ace Higurashi Attorney - The Curry Turnabout
# Nintendo Switch: preserve English dialogue spaces, keep menus untouched, and set author metadata.
# This replaces build_switch_spacing_fixed.sh (do not use LETTER_GAP for this build).
set -euo pipefail

GAME_TITLE='Ace Higurashi Attorney - The Curry Turnabout'
GAME_PUBLISHER='Nisejimai Sale'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_SOURCE="${ENGINE_DIR:-$ROOT/work/ONScripter-NX}"
ENGINE_REF="${ENGINE_REF:-v0.3.1}"

# Some PowerShell->bash invocations do not inherit DEVKITPRO.
if [[ -z "${DEVKITPRO:-}" && -d /opt/devkitpro ]]; then
  export DEVKITPRO=/opt/devkitpro
fi
: "${DEVKITPRO:?Lance le terminal devkitPro MSYS (DEVKITPRO n est pas defini)}"
export DEVKITA64="${DEVKITA64:-$DEVKITPRO/devkitA64}"
export PATH="$DEVKITPRO/tools/bin:$DEVKITPRO/portlibs/switch/bin:$DEVKITA64/bin:$PATH"
for cmd in git make python3 aarch64-none-elf-g++ smpeg2-config makepkg patch; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERREUR: outil manquant: $cmd" >&2
    echo 'Sous devkitPro MSYS: pacman -S --needed base-devel patch dkp-toolchain-vars switch-smpeg2' >&2
    exit 1
  fi
done
if [[ ! -f "$DEVKITPRO/portlibs/switch/include/smpeg2/smpeg.h" ]]; then
  echo 'ERREUR: SMPEG2 manquant: pacman -S --needed switch-smpeg2' >&2
  exit 1
fi

if [[ ! -s "$ROOT/icon.jpg" ]]; then
  echo 'ERREUR: icon.jpg introuvable. Place l icone fournie a cote de ce script.' >&2
  exit 1
fi

python3 "$ROOT/tools/audit_game.py" "$ROOT/game"

if [[ ! -f "$ENGINE_SOURCE/Makefile" ]]; then
  mkdir -p "$(dirname "$ENGINE_SOURCE")"
  git clone --depth 1 --branch "$ENGINE_REF" \
    https://github.com/clamintus/ONScripter-NX.git "$ENGINE_SOURCE"
fi

# ALWAYS stage a fresh copy, to discard prior proportional-spacing/wrapping edits,
# avoid upstream's unquoted $(CURDIR), and keep the original checkout untouched.
STAGE_BASE="${TMPDIR:-/tmp}"
[[ "$STAGE_BASE" =~ [[:space:]] ]] && STAGE_BASE=/tmp
STAGE_DIR="$(mktemp -d "$STAGE_BASE/aha-dialogues.XXXXXXXX")"
if [[ "${KEEP_STAGE:-0}" != 1 ]]; then
  trap 'rm -rf -- "$STAGE_DIR"' EXIT
fi
ENGINE="$STAGE_DIR/ONScripter-NX"
mkdir -p "$ENGINE"
cp -a "$ENGINE_SOURCE/." "$ENGINE/"
rm -rf -- "$ENGINE/build"
rm -f -- "$ENGINE"/*.nro "$ENGINE"/*.elf "$ENGINE"/*.nacp "$ENGINE"/*.map

python3 - "$ENGINE" <<'PY'
import pathlib
import re
import sys

engine = pathlib.Path(sys.argv[1])
source_file = engine / 'source' / 'ScriptHandler.cpp'
makefile = engine / 'Makefile'
if not source_file.is_file() or not makefile.is_file():
    sys.exit('ERREUR: sources ONScripter-NX v0.3.1 introuvables.')

# Critical fix: in the Japanese-oriented lexer, SKIP_SPACE(buf) is executed
# after each character even inside an English dialogue. It erases the gaps
# between words before the font renderer receives the text.
# The engine already supports END_1BYTE_CHAR (its backtick mode), so use that
# mode for displayed text and stop dropping internal ASCII spaces.
raw = source_file.read_bytes()
text = raw.decode('latin-1')
if 'AHA-ENGLISH-TEXT-WHITESPACE-FIX' in text:
    sys.exit('ERREUR: checkout ONScripter deja modifie. Utilise une copie d origine v0.3.1.')

func = text.find('ScriptHandler::readToken(')
start = text.find('else if (ch & 0x80 ||', func)
end = text.find('if (loop_flag && ch == 0x0a', start)
if func < 0 or start < 0 or end < 0:
    sys.exit('ERREUR: structure readToken() inattendue, ENGINE_REF=v0.3.1 requis.')
block = text[start:end]
if block.count('SKIP_SPACE(buf);') != 2 or block.count('bool loop_flag = true;') != 1:
    sys.exit('ERREUR: readToken() a change: espaces ou statut introuvables.')
block = block.replace('bool loop_flag = true;',
    'bool loop_flag = true;\n'
    '        // AHA-ENGLISH-TEXT-WHITESPACE-FIX: honour spaces within game text.\n'
    '        end_status |= END_1BYTE_CHAR;', 1)
block = block.replace('SKIP_SPACE(buf);',
    '/* AHA: do not discard literal spaces inside text */')
# Old Japanese halfwidth-pair padding may insert a spurious blank after digits;
# it is not appropriate when a token is processed one byte at a time.
block, count = re.subn(r'if\s*\(\s*ch\s*>\s*=\s*\'0\'\s*&&',
    "if (!(end_status & END_1BYTE_CHAR) && ch>='0' &&", block, count=1)
if count != 1:
    sys.exit('ERREUR: condition de padding numerique introuvable.')
text = text[:start] + block + text[end:]
source_file.write_bytes(text.encode('latin-1'))

# The NACP name must match the complete official title as requested.
mk = makefile.read_text(encoding='utf-8')
mk, count = re.subn(
    r'(?m)^(\s*APP_TITLE\s*:=\s*)\$\(strip\s+\$\(GAME\)\s+\$\(HD\)\)\s*\(ONScripter-NX\)\s*$',
    lambda match: match.group(1) + '$(strip $(GAME))', mk, count=1)
if count != 1:
    sys.exit('ERREUR: definition APP_TITLE inattendue dans le Makefile.')
makefile.write_text(mk, encoding='utf-8')
print('Correction: espaces des dialogues conserves; geometrie des menus d origine.')
PY

# This is the same SDL2_ttf bug1433 workaround that improved the text.
if [[ ! -f "$ENGINE/Makefile.extlibs" || ! -f "$ENGINE/extlibs/SDL2_ttf/bug1433.patch" ]]; then
  echo 'ERREUR: correctif officiel SDL2_ttf absent (ONScripter-NX v0.3.1 requis).' >&2
  exit 1
fi
if [[ ! -s "$ENGINE/lib/libSDL2_ttf.a" || "${REBUILD_FONTLIB:-0}" == 1 ]]; then
  echo 'Compilation de SDL2_ttf corrigée...'
  (cd "$ENGINE" && make -f Makefile.extlibs)
fi
if [[ ! -s "$ENGINE/lib/libSDL2_ttf.a" || ! -f "$ENGINE/include/SDL2/SDL_ttf.h" ]]; then
  echo 'ERREUR: bibliotheque SDL2_ttf locale absente apres compilation.' >&2
  exit 1
fi

mkdir -p "$ENGINE/romfs"
cp -R "$ROOT/game/." "$ENGINE/romfs/"
# ONScripter-NX v0.3.1 reads ICON=icon.jpg via libnx/switch_rules,
# embedding the 256x256 JPEG directly into the resulting NRO.
cp "$ROOT/icon.jpg" "$ENGINE/icon.jpg"
echo 'Icone personnalisee 256x256 chargee : icon.jpg'

if [[ "${HD:-0}" == 1 ]]; then
  make -C "$ENGINE" -j "${JOBS:-2}" GAME="$GAME_TITLE" APP_AUTHOR="$GAME_PUBLISHER" ICON=icon.jpg ENABLE_HD=1
else
  make -C "$ENGINE" -j "${JOBS:-2}" GAME="$GAME_TITLE" APP_AUTHOR="$GAME_PUBLISHER" ICON=icon.jpg
fi

NRO="$(find "$ENGINE" -maxdepth 1 -type f -name '*.nro' -print -quit)"
if [[ -z "$NRO" ]]; then
  echo 'ERREUR: compilation terminee sans NRO produit.' >&2
  exit 1
fi
OUT="$ROOT/dist/switch/$GAME_TITLE"
mkdir -p "$OUT"
cp "$NRO" "$OUT/$GAME_TITLE.nro"
printf '\nNRO genere (icone integree): %s\n' "$OUT/$GAME_TITLE.nro"
echo 'Copie ce dossier sous /switch/ et supprime les anciens .nro pour eviter les confusions.'
if [[ "${KEEP_STAGE:-0}" == 1 ]]; then
  echo "Sources de compilation conservees: $STAGE_DIR"
fi
