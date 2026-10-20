# Ace Higurashi Attorney - The Curry Turnabout — Nintendo Switch (NRO / NSP)

**Native ARM64 port of the PC NScripter/ONScripter-EN fangame**, based on
[ONScripter-NX](https://github.com/clamintus/ONScripter-NX). This repository lets
users **build their own copy** from the original PC game files:

| Option | Output | How to launch | Game data included |
| --- | --- | --- | --- |
| **NRO** | `.nro` | Homebrew Menu | Yes, in the NRO RomFS |
| **Standalone NSP** | `.nsp` | Installed application on a homebrew-enabled Switch | Yes, in the NSP ExeFS (NSO) and RomFS; **not a forwarder** |

**Title:** Ace Higurashi Attorney - The Curry Turnabout  
**Displayed publisher:** Nisejimai Sale  
**Icon:** Custom 256 × 256 illustration (JPEG)  
**Engine:** ONScripter-NX `v0.3.1` with fixes specific to the English script.

> [!IMPORTANT]
> The scripts are provided **without the game data, Nintendo keys,  or hacBrewPack**. Import a legally obtained copy of the PC game, and dump your own keys.

## Quick start (Windows / PowerShell)

Install **devkitPro** and open a **devkitPro MSYS** terminal (recommended).
You can also run the commands from PowerShell if `bash` points to
`/opt/devkitpro/msys2/usr/bin/bash`. Do not enter `export` commands directly
in PowerShell.

### 1. Dependencies

In **devkitPro MSYS**:

```bash
pacman -S --needed switch-dev switch-tools \
  switch-sdl2 switch-sdl2_image switch-sdl2_mixer switch-sdl2_ttf \
  switch-smpeg2 switch-libvorbis base-devel patch dkp-toolchain-vars \
  git python
```

Building also requires `make`, `makepkg`, `sdl2-config`, and `smpeg2-config`.
The NRO build script compiles a patched version of SDL2_ttf locally (using the
patch supplied by ONScripter-NX) without modifying your system installation.
The first build downloads the engine source and may take a while.

### 2. Import the original PC game

For example, place this repository at `C:\AceHigurashi_Switch_Port_Kit`, then
run the following from its root directory:

```bash
bash build.sh prepare /c/path/to/Ace.Higurashi.Attorney.-.The.Curry.Turnabout.zip
bash build.sh verify
```

Alternatively, manually copy `0.txt`, `arc.nsa`, `default.ttf`, and the `img/`
folder from the original game into `game/`. The import script **skips `.exe`,
`.dll`, and save files**, and preserves the script's CP932 encoding.

### 3. Choose a build format

**Option A — NRO (Homebrew Menu):**

```bash
bash build.sh nro
```

Output:

```text
dist/switch/Ace Higurashi Attorney - The Curry Turnabout/
  Ace Higurashi Attorney - The Curry Turnabout.nro
```

Copy the generated folder into `/switch/` on your microSD card, then start
the NRO through Homebrew Menu. If needed, run Homebrew Menu in full-memory
mode (*title override*) instead of launching it through the Album applet.

**Option B — Complete NSP, no external NRO:**

```bash
bash build.sh doctor
bash build.sh nsp
```

The script rebuilds the NRO **to obtain the same patched ELF executable**,
converts that ELF into an NSO, builds `main.npdm`, generates the NACP control
data, and packages an NSP with its own RomFS. This is **not a forwarder**.
Packaging also requires [hacBrewPack](https://github.com/pplatoon/hacBrewPack)
and keys obtained from your own Switch. See the next section.

Output:

```text
dist/switch/Ace Higurashi Attorney - The Curry Turnabout/
  Ace Higurashi Attorney - The Curry Turnabout.nro
  Ace Higurashi Attorney - The Curry Turnabout.nsp
```

To build both formats in one run (without starting two separate builds):

```bash
bash build.sh both
```

Running `bash build.sh` with no arguments opens a small interactive menu.

## NSP-specific setup

### Install hacBrewPack

Download or build [hacBrewPack](https://github.com/pplatoon/hacBrewPack)
separately. Example Windows location:

```text
C:\devkitPro\hacbrewpack.exe
```

The build script automatically searches this location. Otherwise, in
**PowerShell**:

```powershell
$env:HACBREWPACK = "/c/another-folder/hacbrewpack.exe"
```

Or in **devkitPro MSYS**:

```bash
export HACBREWPACK=/c/another-folder/hacbrewpack.exe
```

### Keys from your own console

hacBrewPack requires a set of keys dumped from **your own Switch**. The
project neither includes nor downloads any keys. Never share these files,
and **never commit them to Git**.

In PowerShell (before running `bash build.sh nsp`):

```powershell
$env:KEYS = "/c/private/path/to/prod.keys"
```

In devkitPro MSYS:

```bash
export KEYS=/c/private/path/to/prod.keys
```

By default, the script also checks `~/.switch/prod.keys`. The NSP option
supports a custom `TITLE_ID` to avoid conflicts with other homebrew:

```bash
TITLE_ID=0100A0CE48490000 bash build.sh nsp
```

The example value `0100A0CE48490000` is **not** an officially reserved
Title ID. Do not use it if another application already has that ID. The
NPDM/NACP use this identifier during packaging.

## Available commands

| Command | Purpose |
| --- | --- |
| `bash build.sh nro` | Build an NRO with the engine and resources in its RomFS |
| `bash build.sh nsp` | Build a standalone NSP; an intermediate NRO is also copied to `dist/` |
| `bash build.sh both` | Produce both outputs during a single NSP build |
| `bash build.sh prepare <archive.zip>` | Import only the required game files |
| `bash build.sh verify` | Check the game resources and CP932 script |
| `bash build.sh doctor` | Check `elf2nso`, `npdmtool`, `nacptool`, the ARM64 compiler, and hacBrewPack |
| `bash test_npdm.sh` | Independently test the corrected NPDM template |

Advanced options (devkitPro MSYS): `HD=1`, `JOBS=4`, `ENGINE_REF=v0.3.1`,
`TITLE_ID=…`, `HACBREWPACK=…`, `KEYS=…`, and `KEEP_NSP_WORK=1` to preserve NSP
intermediate files. **Do not change `ENGINE_REF` without reviewing the patches:**
they target the layout of version `v0.3.1`.

## Why are text-rendering patches needed?

The fangame contains a **2,325-line** script with **61 labels**, encoded in
CP932, and an NSA archive containing **131 resources**. Unpatched versions
of ONScripter-NX may drop the spaces between English words. An early attempt
at proportional letter spacing could also cause menu text to overflow. This
repository:

1. Applies the SDL2_ttf patch provided by the ONScripter-NX author.
2. Adapts the tokenizer to **preserve ASCII spaces in dialogue**.
3. Keeps the original menu positioning and line-wrapping behavior.
4. Keeps `0.txt` in CP932 encoding (**do not convert it to UTF-8**).

The PC game already used ONScripter-EN: **decompiling the Windows EXE is not
required** for this port. ONScripter-NX runs the original script natively on
ARM64. It is a native script engine/interpreter, not a translation of every
NScripter statement into machine code.

## Repository structure

```text
.
├── README.md
├── build.sh                          # Select nro / nsp / both
├── build_switch_nro_nisejimai.sh     # NRO build + text fixes
├── build_switch_nsp_complet.sh       # NSP ExeFS + RomFS build
├── npdm_template.json               # Tested NPDM profile
├── icon.jpg                         # Supplied icon (check rights)
├── test_npdm.sh
├── tools/
│   ├── prepare_game.py              # Import from original PC ZIP
│   ├── audit_game.py                # File audit
│   └── unpack_nsa.py                # Optional NSA extraction
├── game/README.md                   # Users must provide PC game files
├── tests/                           # Tests without SDK or game data
└── .github/workflows/               # GitHub Actions static checks
```

The `game/`, `work/`, and `dist/` directories, as well as key files, are
covered by `.gitignore`. **Still review `git status` before publishing.**

## Repository tests (no console or SDK required)

The GitHub Actions workflow runs only static checks: Bash syntax, NPDM JSON,
and import-tool tests. **It does not build** an NRO/NSP or prove that either
will work on a Switch.

Run locally:

```bash
bash -n build.sh build_switch_nro_nisejimai.sh build_switch_nsp_complet.sh test_npdm.sh
python3 -m unittest discover -s tests -v
```

## Troubleshooting

| Symptom | Likely cause / fix |
| --- | --- |
| `export` is not recognized | You're using PowerShell. Run `bash build.sh …` or open devkitPro MSYS. |
| `smpeg2-config: command not found` | Install `switch-smpeg2` and check that `DEVKITPRO/portlibs/switch/bin` is in `PATH`. |
| Missing `smpeg2/smpeg.h` | Install `switch-smpeg2`. |
| Garbled text | Use the patched NRO build script and rebuilt SDL2_ttf library. |
| Missing spaces in dialogue | Do not reuse the old `build_switch_spacing_fixed.sh`; use this repository's scripts. |
| Overflowing menu text | Same cause: use the engine's original layout geometry, as preserved here. |
| Missing `elf2nso` | Run `bash build.sh doctor`; check `switch-tools` and `elf2nso.exe` under devkitPro MSYS. |
| Missing `hacbrewpack` | Place `hacbrewpack.exe` in `C:\devkitPro\` or set `HACBREWPACK`. |
| `Failed to parse descriptor json` | Use the included `npdm_template.json`; check with `bash test_npdm.sh`. |
| `Failed to get ... (field not present)` | Some messages are informational. Verify the NPDM output and its `META` signature. |
| Ryujinx `MissingKeyException` | The test environment has an issue with keys/firmware before the game starts. Do not share keys. |
| NSP is created but shows a black screen | Check RomFS inclusion, NPDM, logs, and behavior when installed. |
| Build path contains spaces | The build uses a temporary engine copy in a path without spaces. |

## Testing and limitations

The **NRO** has been tested successfully, and the **NSP** launched
in Ryujinx Canary after correcting the keys and firmware configuration.
This **does not guarantee** that every story branch, save, control, transition,
or Switch version will work correctly.

Before a release, test the title screen and icon, all dialogue and choices,
music and sound effects, save/load, exiting the game, handheld and docked
modes, potential Title ID conflicts, and Homebrew Menu free-memory limits.

## Credits, licenses, and distribution

- Original game : **Nisejimai Sale**. This repository does not claim to represent the publisher.
- Original NScripter / ONScripter engines: their respective authors.
- [ONScripter-NX](https://github.com/clamintus/ONScripter-NX) Switch port: clamintus; **GPL-2.0** license (see upstream `COPYING`).
- SDL2_ttf fix: patch and attribution are available in ONScripter-NX.
- NSP packaging: [hacBrewPack](https://github.com/pplatoon/hacBrewPack), a third-party tool to install separately.
- Nintendo Switch and related trademarks belong to their respective owners.

## Useful links

- [ONScripter-NX](https://github.com/clamintus/ONScripter-NX)
- [devkitPro documentation](https://devkitpro.org/)
- [hacBrewPack](https://github.com/pplatoon/hacBrewPack)