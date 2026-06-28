#!/usr/bin/env python3
"""Extract .SMK cutscenes from GOG Carmageddon / Splat Pack disc images."""

from __future__ import annotations

import argparse
import os
import struct
import sys

SECTOR_IN = 2352
SECTOR_OUT = 2048
DATA_OFF = 16


def gog_to_iso_bytes(gog_path: str) -> bytes:
    size = os.path.getsize(gog_path)
    sectors = size // SECTOR_IN
    out = bytearray(sectors * SECTOR_OUT)
    with open(gog_path, "rb") as src:
        for i in range(sectors):
            src.seek(i * SECTOR_IN + DATA_OFF)
            out[i * SECTOR_OUT : (i + 1) * SECTOR_OUT] = src.read(SECTOR_OUT)
    return bytes(out)


def parse_dir(data: bytes, lba: int, size: int) -> list[tuple[str, int, int, int]]:
    off = lba * SECTOR_OUT
    chunk = data[off : off + size]
    pos = 0
    entries: list[tuple[str, int, int, int]] = []
    while pos < len(chunk):
        rec_len = chunk[pos]
        if rec_len == 0:
            pos = ((pos // SECTOR_OUT) + 1) * SECTOR_OUT
            if pos >= len(chunk):
                break
            continue
        flags = chunk[pos + 25]
        name_len = chunk[pos + 32]
        name_bytes = chunk[pos + 33 : pos + 33 + name_len]
        name = name_bytes.decode("ascii", "replace").split(";")[0]
        if name_len == 1 and name_bytes[0] in (0, 1):
            name = "." if name_bytes[0] == 0 else ".."
        clba = struct.unpack_from("<I", chunk, pos + 2)[0]
        csz = struct.unpack_from("<I", chunk, pos + 10)[0]
        entries.append((name, clba, csz, flags))
        pos += rec_len
    return entries


def walk_files(data: bytes, lba: int, size: int, prefix: str = ""):
    for name, clba, csz, flags in parse_dir(data, lba, size):
        if name in (".", ".."):
            continue
        path = f"{prefix}/{name}" if prefix else name
        if flags & 0x02:
            yield from walk_files(data, clba, csz, path)
        else:
            yield path, clba, csz


def find_gog_image(game_dir: str) -> tuple[str, str] | None:
    for gog_name, dat_name in (("GAME.GOG", "GAME.DAT"), ("SPLAT.GOG", "SPLAT.DAT")):
        gog_path = os.path.join(game_dir, gog_name)
        if os.path.isfile(gog_path):
            dat_path = os.path.join(game_dir, dat_name)
            return gog_path, dat_path if os.path.isfile(dat_path) else ""
    return None


def extract_cutscenes(game_dir: str, *, remove_images: bool) -> int:
    found = find_gog_image(game_dir)
    if found is None:
        print(f"skip: no GAME.GOG or SPLAT.GOG in {game_dir}", file=sys.stderr)
        return 0

    gog_path, dat_path = found
    out_dir = os.path.join(game_dir, "DATA", "CUTSCENE")
    os.makedirs(out_dir, exist_ok=True)

    print(f"reading {gog_path}")
    iso_data = gog_to_iso_bytes(gog_path)

    pvd = iso_data[16 * SECTOR_OUT : 17 * SECTOR_OUT]
    if pvd[1:6] != b"CD001":
        print(f"error: {gog_path} is not a recognizable ISO9660 image", file=sys.stderr)
        return 1

    root_lba = struct.unpack_from("<I", pvd, 158)[0]
    root_sz = struct.unpack_from("<I", pvd, 166)[0]
    files = list(walk_files(iso_data, root_lba, root_sz))
    smk_files = [entry for entry in files if entry[0].upper().replace("\\", "/").endswith(".SMK")]

    if not smk_files:
        print(f"warning: no .SMK files found in {gog_path}", file=sys.stderr)
    else:
        print(f"extracting {len(smk_files)} cutscene(s) to {out_dir}")
        for path, lba, sz in smk_files:
            name = os.path.basename(path.replace("\\", "/")).upper()
            out_path = os.path.join(out_dir, name)
            payload = iso_data[lba * SECTOR_OUT : lba * SECTOR_OUT + sz]
            with open(out_path, "wb") as f:
                f.write(payload)
            print(f"  {name} ({sz} bytes, sig={payload[:4]!r})")

    if remove_images:
        os.remove(gog_path)
        print(f"removed {gog_path}")
        if dat_path:
            os.remove(dat_path)
            print(f"removed {dat_path}")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "game_dirs",
        nargs="*",
        help="Carmageddon or Splat Pack install directories (default: current directory)",
    )
    parser.add_argument(
        "--keep-images",
        action="store_true",
        help="Do not delete .GOG / .DAT files after extraction",
    )
    args = parser.parse_args()

    dirs = args.game_dirs or [os.getcwd()]
    status = 0
    extracted_any = False

    for game_dir in dirs:
        game_dir = os.path.abspath(game_dir)
        if not os.path.isdir(game_dir):
            print(f"error: not a directory: {game_dir}", file=sys.stderr)
            status = 1
            continue
        if find_gog_image(game_dir) is not None:
            extracted_any = True
        rc = extract_cutscenes(game_dir, remove_images=not args.keep_images)
        if rc != 0:
            status = rc

    if not extracted_any and status == 0:
        return 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
