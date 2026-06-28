#!/usr/bin/env bash
# Extract cutscene .SMK files from GOG disc images (GAME.GOG / SPLAT.GOG),
# then remove the image and cue files to save disk space.
#
# Usage:
#   ./unpack.sh [game_directory ...]
#   ./unpack.sh --keep-images [game_directory ...]
#
# With no directories, unpacks the current directory if it contains a GOG image.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extractor="${root}/tools/extract_gog_cutscenes.py"

if [[ ! -f "${extractor}" ]]; then
    echo "error: missing ${extractor}" >&2
    exit 1
fi

keep_images=0
dirs=()

for arg in "$@"; do
    case "${arg}" in
        --keep-images)
            keep_images=1
            ;;
        -h|--help)
            sed -n '2,10p' "$0"
            exit 0
            ;;
        *)
            dirs+=("${arg}")
            ;;
    esac
done

args=()
if [[ "${keep_images}" -eq 1 ]]; then
    args+=(--keep-images)
fi

if [[ ${#dirs[@]} -gt 0 ]]; then
    args+=("${dirs[@]}")
fi

exec python3 "${extractor}" "${args[@]}"
