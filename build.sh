#!/usr/bin/env bash
# Entrypoint pour les utilisateurs de ce depot. NRO/NSP partagent le moteur corrige.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
usage() {
cat <<'HELP'
Ace Higurashi Attorney - The Curry Turnabout | build Switch

  bash build.sh nro                  Compile le jeu en .nro (Homebrew Menu).
  bash build.sh nsp                  Compile un .nsp autonome (pas un forwarder).
  bash build.sh both                 Produit NRO + NSP en un seul build.
  bash build.sh prepare <jeu_pc.zip> Importe les ressources depuis ton ZIP PC.
  bash build.sh verify               Audite les ressources du jeu.
  bash build.sh doctor               Verifie les outils NSP de devkitPro.
  bash build.sh help                 Affiche cette aide.

Sous Windows, utiliser devkitPro MSYS ou PowerShell avec son 'bash' devkitPro.
NSP : exige hacBrewPack et les cles issues de sa propre console.
HELP
}
choice="${1:-}"
if [[ -z "$choice" ]]; then
  if [[ ! -t 0 ]]; then usage; exit 2; fi
  printf '\nChoisir une compilation :\n  1) NRO (Homebrew Menu)\n  2) NSP (application autonome)\n  3) Les deux\n  4) Verification des outils\n  5) Quitter\n> '
  read -r n
  case "$n" in 1) choice=nro;; 2) choice=nsp;; 3) choice=both;; 4) choice=doctor;; 5) exit 0;; *) usage; exit 2;; esac
else
  shift
fi
case "$choice" in
  nro)
    [[ "$#" -eq 0 ]] || { usage; exit 2; }
    bash "$ROOT/build_switch_nro_nisejimai.sh" ;;
  nsp|both)
    [[ "$#" -eq 0 ]] || { usage; exit 2; }
    if [[ "$choice" == both ]]; then
      echo 'Le build NSP compile deja le NRO : les deux fichiers seront disponibles dans dist/switch/.'
    fi
    bash "$ROOT/build_switch_nsp_complet.sh" ;;
  prepare)
    [[ "$#" -ge 1 ]] || { usage; exit 2; }
    python3 "$ROOT/tools/prepare_game.py" "$@" ;;
  verify)
    [[ "$#" -eq 0 ]] || { usage; exit 2; }
    python3 "$ROOT/tools/audit_game.py" "$ROOT/game" ;;
  doctor)
    [[ "$#" -eq 0 ]] || { usage; exit 2; }
    bash "$ROOT/build_switch_nsp_complet.sh" --check-tools ;;
  help|-h|--help)
    usage ;;
  *) usage; exit 2 ;;
esac
