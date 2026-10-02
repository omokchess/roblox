#!/usr/bin/env bash
# 한 자세 가까이(윗몸·무기). 쓰는 법: bash tools/combat/close.sh <직업> <모션> <시각> <무기Id> [방향(기본 90 = 게임 옆)]
set -e
cd "$(dirname "$0")/../.."
LUNE=/c/Users/hhksh/AppData/Local/Microsoft/WinGet/Packages/Lune.Lune_Microsoft.Winget.Source_8wekyb3d8bbwe/lune.exe
$LUNE run tools/combat/export_motions.luau >/dev/null
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/combat/preview_motion.py -- close "$1" "$2" "$3" "$4" "${5:-90}" "close_$1_${2//./_}_${3//./_}_${5:-90}" 2>&1 | grep -E "rror|찍음" || true
