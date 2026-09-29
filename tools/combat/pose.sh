#!/usr/bin/env bash
# 모션 하나를 키 시각마다 찍어 본다(빠른 확인용). 쓰는 법: bash tools/combat/pose.sh <직업> <모션> <무기Id> [장수|k]
set -e
cd "$(dirname "$0")/../.."
LUNE=/c/Users/hhksh/AppData/Local/Microsoft/WinGet/Packages/Lune.Lune_Microsoft.Winget.Source_8wekyb3d8bbwe/lune.exe
$LUNE run tools/combat/export_motions.luau >/dev/null
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/combat/preview_motion.py -- "$1" "$2" "${4:-k}" "$3" 2>&1 | grep -E "rror|찍음" || true
