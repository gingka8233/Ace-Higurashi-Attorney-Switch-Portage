#!/usr/bin/env python3
"""Importe les ressources depuis une copie originale (ZIP) du fangame PC.

Exclut volontairement les EXE, DLL, sauvegardes et fichiers non necessaires.
Aucun contenu du jeu n'est distribue avec les scripts du depot.
"""
from __future__ import annotations
import argparse
from pathlib import Path, PurePosixPath
import shutil
import sys
import zipfile

REQUIRED = {"0.txt", "arc.nsa", "default.ttf"}
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".webp"}
MAX_UNCOMPRESSED = 2 * 1024 * 1024 * 1024


def find_base(names: list[str]) -> str:
    matches = []
    normalized = {n.replace("\\", "/") for n in names}
    for name in normalized:
        if name.endswith("/0.txt") or name == "0.txt":
            base = name[:-len("0.txt")]
            if all(base + r in normalized for r in REQUIRED):
                matches.append(base)
    if len(matches) != 1:
        raise ValueError("Impossible d'identifier un unique dossier contenant 0.txt, arc.nsa et default.ttf.")
    return matches[0]


def is_game_asset(relative: PurePosixPath) -> bool:
    parts = relative.parts
    if len(parts) == 1:
        return parts[0] in REQUIRED
    return len(parts) >= 2 and parts[0] == 'img' and relative.suffix.lower() in IMAGE_SUFFIXES


def import_zip(archive: Path, dest: Path, overwrite: bool) -> int:
    with zipfile.ZipFile(archive) as zf:
        names = [i.filename.replace('\\', '/') for i in zf.infolist() if not i.is_dir()]
        base = find_base(names)
        valid = []
        total = 0
        for info in zf.infolist():
            if info.is_dir():
                continue
            name = info.filename.replace('\\', '/')
            if not name.startswith(base):
                continue
            relative = PurePosixPath(name[len(base):])
            if relative.is_absolute() or '..' in relative.parts or not is_game_asset(relative):
                continue
            if info.file_size > MAX_UNCOMPRESSED:
                raise ValueError(f"Fichier trop volumineux: {name}")
            total += info.file_size
            if total > MAX_UNCOMPRESSED:
                raise ValueError("Archive depassant la limite de securite de 2 Gio")
            valid.append((info, relative))
        present = {str(r) for _, r in valid}
        if not REQUIRED.issubset(present):
            raise ValueError("Les trois fichiers indispensables du jeu sont absents.")
        collisions = [str(r) for _, r in valid if (dest / Path(*r.parts)).exists()]
        if collisions and not overwrite:
            raise FileExistsError("Fichiers deja presents dans game/: " + ', '.join(collisions[:5]) + ". Ajouter --force pour les remplacer.")
        for info, relative in valid:
            target = dest.joinpath(*relative.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info) as src, target.open('wb') as out:
                shutil.copyfileobj(src, out, length=1024 * 1024)
        return len(valid)


def main() -> int:
    parser = argparse.ArgumentParser(description="Importer un ZIP original du jeu dans game/ sans distribuer ses donnees")
    parser.add_argument('zip', type=Path, help='Archive ZIP PC originale du fangame')
    parser.add_argument('--force', action='store_true', help='Remplacer les fichiers existants dans game/')
    args = parser.parse_args()
    dest = Path(__file__).resolve().parent.parent / 'game'
    try:
        count = import_zip(args.zip, dest, args.force)
    except (FileNotFoundError, zipfile.BadZipFile, OSError, ValueError) as exc:
        parser.exit(1, f'ERREUR: {exc}\n')
    print(f'OK : {count} fichiers du jeu importes dans {dest}')
    print('Executable Windows et sauvegardes exclus. Executer : bash build.sh verify')
    return 0

if __name__ == '__main__':
    sys.exit(main())
