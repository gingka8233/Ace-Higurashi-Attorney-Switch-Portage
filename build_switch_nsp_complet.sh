#!/usr/bin/env bash
# Ace Higurashi Attorney - The Curry Turnabout
# NSP installed application with its OWN ARM64 code (NSO) and game data (RomFS).
# This does NOT create an NRO forwarder.
set -euo pipefail
# Mise a jour 2026-10-21 : resolution robuste des executables .exe sous MSYS2.

TITLE='Ace Higurashi Attorney - The Curry Turnabout'
PUBLISHER='Nisejimai Sale'
TITLE_ID="${TITLE_ID:-0100A0CE48490000}" # Custom homebrew id. Change if conflicting.
VERSION='1.0.0'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDER="$ROOT/build_switch_nro_nisejimai.sh"
JSON_TEMPLATE="$ROOT/npdm_template.json"
KEYS="${KEYS:-${HOME}/.switch/prod.keys}"
PACKER="${HACBREWPACK:-hacbrewpack}"

# Convert a Windows path in KEYS to MSYS format, without printing its contents.
if [[ "$KEYS" =~ ^[A-Za-z]:[\\/] ]] && command -v cygpath >/dev/null 2>&1; then
    KEYS="$(cygpath -u "$KEYS")"
fi

fail(){ printf '\nERREUR: %s\n' "$*" >&2; exit 1; }

# devkitPro Switch tools are usually installed in $DEVKITPRO/tools/bin.
# This directory may be missing from PATH in MSYS, although the tools are present.
# Keep the compiler directory available as well (required for the corrected NRO build).
if [[ -z "${DEVKITPRO:-}" && -d /opt/devkitpro/tools/bin ]]; then
    export DEVKITPRO=/opt/devkitpro
fi
if [[ -n "${DEVKITPRO:-}" ]]; then
    # MSYS may receive a Windows-style DEVKITPRO value from PowerShell.
    if [[ "$DEVKITPRO" =~ ^[A-Za-z]:[\\/] ]] && command -v cygpath >/dev/null 2>&1; then
        DEVKITPRO="$(cygpath -u "$DEVKITPRO")"
        export DEVKITPRO
    fi
    export PATH="$DEVKITPRO/tools/bin:$DEVKITPRO/devkitA64/bin:$PATH"
fi

# hacBrewPack est souvent copie manuellement a la racine de C:\devkitPro.
# Si l'utilisateur ne donne pas HACBREWPACK, on cherche aussi ces emplacements.
# Une variable HACBREWPACK explicitement definie garde la priorite.
if [[ -z "${HACBREWPACK:-}" ]]; then
    for candidate in \
        "$ROOT/hacbrewpack.exe" \
        /c/devkitPro/hacbrewpack.exe \
        /c/devkitpro/hacbrewpack.exe \
        "${DEVKITPRO:-/opt/devkitpro}/hacbrewpack.exe" \
        "${DEVKITPRO:-/opt/devkitpro}/tools/bin/hacbrewpack.exe"; do
        if [[ -f "$candidate" ]]; then
            PACKER="$candidate"
            break
        fi
    done
fi

# MSYS devkitPro distribue les outils Win32 sous le nom *.exe. Selon le
# shell, command -v elf2nso peut echouer meme quand elf2nso.exe existe.
# Resoudre les chemins de facon explicite plutot que se fier au PATH seul.
resolve_tool() {
    local name="$1" candidate dir
    if [[ "$name" == */* || "$name" == *\\* ]]; then
        if [[ "$name" =~ ^[A-Za-z]:[\\/] ]] && command -v cygpath >/dev/null 2>&1; then
            name="$(cygpath -u "$name")"
        fi
        for candidate in "$name" "$name.exe"; do
            if [[ -f "$candidate" ]]; then printf '%s\n' "$candidate"; return 0; fi
        done
        return 1
    fi
    for candidate in "$name" "$name.exe"; do
        if command -v "$candidate" >/dev/null 2>&1; then
            command -v "$candidate"
            return 0
        fi
    done
    for dir in "${DEVKITPRO:-/opt/devkitpro}/tools/bin" "${DEVKITPRO:-/opt/devkitpro}/devkitA64/bin"; do
        for candidate in "$dir/$name" "$dir/$name.exe"; do
            if [[ -f "$candidate" ]]; then printf '%s\n' "$candidate"; return 0; fi
        done
    done
    return 1
}

for tool in bash python3; do
    command -v "$tool" >/dev/null 2>&1 || fail "Outil absent: $tool"
done
ELF2NSO_BIN="$(resolve_tool elf2nso)" || fail 'elf2nso(.exe) introuvable dans devkitPro/tools/bin. Installer switch-tools dans devkitPro MSYS.'
NPDMTOOL_BIN="$(resolve_tool npdmtool)" || fail 'npdmtool(.exe) introuvable dans devkitPro/tools/bin. Installer switch-tools dans devkitPro MSYS.'
NACPTOOL_BIN="$(resolve_tool nacptool)" || fail 'nacptool(.exe) introuvable dans devkitPro/tools/bin. Installer switch-tools dans devkitPro MSYS.'

if [[ "${1:-}" == --check-tools ]]; then
    printf 'devkitPro: %s\n' "${DEVKITPRO:-non defini}"
    printf '%-22s %s\n' 'elf2nso:' "$ELF2NSO_BIN" 'npdmtool:' "$NPDMTOOL_BIN" 'nacptool:' "$NACPTOOL_BIN"
    if COMPILER_BIN="$(resolve_tool aarch64-none-elf-g++)"; then
        printf '%-22s %s\n' 'Compilateur ARM64:' "$COMPILER_BIN"
    else
        printf 'ATTENTION: compilateur aarch64-none-elf-g++ introuvable.\n'
    fi
    if PACKER_BIN="$(resolve_tool "$PACKER")"; then
        printf '%-22s %s\n' 'hacBrewPack:' "$PACKER_BIN"
    else
        printf 'ATTENTION: hacBrewPack introuvable. Chemin teste: %s\n' "$PACKER"
        printf 'Verification directe: ls -l /c/devkitPro/hacbrewpack.exe\n'
    fi
    printf 'OK : elf2nso, npdmtool et nacptool detectes, y compris versions .exe.\n'
    exit 0
elif [[ "$#" -ne 0 ]]; then
    fail 'Argument inconnu (option prise en charge: --check-tools).'
fi
PACKER_BIN="$(resolve_tool "$PACKER")" || fail 'hacbrewpack(.exe) non trouve. Indiquer HACBREWPACK=/chemin/vers/hacbrewpack.exe.'
[[ -s "$JSON_TEMPLATE" ]] || fail "npdm_template.json est manquant. Extraire le ZIP entier."
[[ -s "$ROOT/icon.jpg" ]] || fail "icon.jpg est manquant. Extraire le ZIP entier."
[[ -s "$KEYS" ]] || fail "Fichier de cles introuvable: $KEYS. Utiliser KEYS=/chemin/vers/prod.keys (cles de votre propre console, jamais fournies par le kit)."
[[ "$TITLE_ID" =~ ^01[[:xdigit:]]{14}$ ]] || fail "TITLE_ID invalide; attendu: 16 chiffres hexadecimaux commencant par 01."
TITLE_ID="${TITLE_ID,,}"
[[ -s "$ROOT/game/0.txt" && -s "$ROOT/game/arc.nsa" && -s "$ROOT/game/default.ttf" ]] || fail "Ressources absentes dans game/. Conserver le dossier game/ du kit de portage."
[[ -s "$BUILDER" ]] || fail "Le script build_switch_nro_nisejimai.sh est introuvable. Extraire le ZIP entier."

# Avoid Makefile/hacbrewpack path breakage due to spaces.
TEMP_BASE="${TMPDIR:-/tmp}"
[[ "$TEMP_BASE" =~ [[:space:]] ]] && TEMP_BASE=/tmp
WORK="$(mktemp -d "$TEMP_BASE/aha-full-nsp.XXXXXXXX")"
LOG="$WORK/nro_build.log"
ENGINE_STAGE=''
cleanup() {
    if [[ "${KEEP_NSP_WORK:-0}" == 1 ]]; then
       printf '\nIntermediaires conserves: %s\n' "$WORK"
       [[ -z "$ENGINE_STAGE" ]] || printf 'Compilation moteur conservee: %s\n' "$ENGINE_STAGE"
    else
       [[ -z "$ENGINE_STAGE" ]] || rm -rf -- "$ENGINE_STAGE"
       rm -rf -- "$WORK"
    fi
}
trap cleanup EXIT

printf '\n=== 1/4 Compilation du moteur ARM64 CORRIGE ===\n'
# Uses the last known-good engine patches (SDL2_ttf, English spaces, original menu).
# KEEP_STAGE permits conversion of that EXACT working ELF into ExeFS main.
KEEP_STAGE=1 bash "$BUILDER" 2>&1 | tee "$LOG"
ENGINE_STAGE="$(sed -n 's/^Sources de compilation conservees: //p' "$LOG" | tail -n 1)"
[[ -n "$ENGINE_STAGE" && -d "$ENGINE_STAGE/ONScripter-NX" ]] || fail "Impossible de retrouver les objets du build NRO corrige."
ENGINE="$ENGINE_STAGE/ONScripter-NX"
ELF="$(find "$ENGINE" -maxdepth 1 -type f -name '*.elf' -print -quit)"
[[ -n "$ELF" && -s "$ELF" ]] || fail "L'ELF ARM64 n'a pas ete conserve dans $ENGINE"

printf '\n=== 2/4 ExeFS: NSO + NPDM (pas de lanceur NRO) ===\n'
mkdir -p "$WORK/exefs" "$WORK/control" "$WORK/romfs" "$WORK/nsp-out" "$WORK/nca-out" "$WORK/hac-tmp"
"$ELF2NSO_BIN" "$ELF" "$WORK/exefs/main"
[[ -s "$WORK/exefs/main" ]] || fail 'Conversion ELF -> NSO echouee.'

python3 - "$JSON_TEMPLATE" "$WORK/npdm.json" "$TITLE_ID" <<'PY'
import json, pathlib, sys
source, dest, tid = sys.argv[1:]
obj = json.loads(pathlib.Path(source).read_text(encoding='utf-8'))
for k in ('title_id', 'title_id_range_min', 'title_id_range_max'):
    obj[k] = '0x' + tid
obj['name'] = 'AceHigurashi' # NPDM internal name, Home Menu uses NACP title
pathlib.Path(dest).write_text(json.dumps(obj, indent=2) + '\n', encoding='utf-8')
PY
"$NPDMTOOL_BIN" "$WORK/npdm.json" "$WORK/exefs/main.npdm"
[[ -s "$WORK/exefs/main.npdm" ]] || fail 'Creation NPDM echouee.'

printf '\n=== 3/4 RomFS (jeu integral) + Control (nom/editeur/icone) ===\n'
cp -R "$ROOT/game/." "$WORK/romfs/"
# titleid argument is required in both NACP and NPDM.
"$NACPTOOL_BIN" --create "$TITLE" "$PUBLISHER" "$VERSION" "$WORK/control/control.nacp" "--titleid=$TITLE_ID"
cp "$ROOT/icon.jpg" "$WORK/control/icon_AmericanEnglish.dat"
cp "$ROOT/icon.jpg" "$WORK/control/icon_BritishEnglish.dat"
python3 - "$WORK" "$TITLE" "$PUBLISHER" "$TITLE_ID" <<'PY'
from pathlib import Path
import struct, sys
w, name, author, tid = sys.argv[1:]
w = Path(w)
assert (w/'exefs/main').read_bytes()[:4] == b'NSO0', 'main is not NSO0'
assert (w/'exefs/main.npdm').read_bytes()[:4] == b'META', 'main.npdm is invalid'
c = (w/'control/control.nacp').read_bytes()
assert len(c) == 0x4000, 'unexpected NACP length'
assert c[:0x200].split(b'\x00')[0].decode('utf-8') == name, 'NACP title mismatch'
assert c[0x200:0x300].split(b'\x00')[0].decode('utf-8') == author, 'NACP publisher mismatch'
assert struct.unpack_from('<Q', c, 0x3038)[0] == int(tid,16), 'NACP title-id mismatch'
for f in ['0.txt', 'arc.nsa', 'default.ttf']:
    assert (w/'romfs'/f).stat().st_size > 0, 'Missing RomFS file: ' + f
im=(w/'control/icon_AmericanEnglish.dat').read_bytes()
assert im[:3]==b'\xff\xd8\xff', 'icon is not JPEG'
print('Verifications: NSO0, META, NACP, title-id, scenario, NSA et police: OK.')
PY

printf '\n=== 4/4 HacBrewPack: NSP autonome avec NCAs ExeFS et RomFS ===\n'
# No Nintendo assets, boot logos or console keys are included in this kit.
"$PACKER_BIN" -k "$KEYS" --nologo \
    --exefsdir "$WORK/exefs" \
    --romfsdir "$WORK/romfs" \
    --controldir "$WORK/control" \
    --tempdir "$WORK/hac-tmp" \
    --ncadir "$WORK/nca-out" \
    --nspdir "$WORK/nsp-out"

mapfile -d '' PACKED < <(find "$WORK/nsp-out" -maxdepth 2 -type f -iname '*.nsp' -print0)
[[ "${#PACKED[@]}" == 1 ]] || fail "NSP absent ou ambigu apres HacBrewPack (${#PACKED[@]} fichiers)."
TARGET_DIR="$ROOT/dist/switch/$TITLE"
mkdir -p "$TARGET_DIR"
TARGET="$TARGET_DIR/$TITLE.nsp"
cp -- "${PACKED[0]}" "$TARGET"
python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys,struct
p=Path(sys.argv[1]); b=p.read_bytes()[:0x30]
assert b[:4]==b'PFS0', 'Fichier final non reconnu comme PFS0/NSP'
count=struct.unpack_from('<I', b, 4)[0]
assert count >= 2, 'NSP incomplet: aucun ensemble de NCAs reconnu'
print(f'NSP PFS0: {count} entrees, {p.stat().st_size:,} octets')
PY
printf '\nSUCCES: NSP construit (pas un forwarder):\n  %s\n' "$TARGET"
printf 'EXEFS main=NSO + RomFS embarque. Le NRO n est pas requis au lancement.\n'
printf 'ATTENTION: lancement, rendu et sauvegardes restent a valider sur Switch CFW.\n'
