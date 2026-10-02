#!/usr/bin/env bash
# 한 자세 네 방향(게임 옆 90 · 앞 3/4 45 · 앞 0 · 뒤 3/4 135). 쓰는 법: bash tools/combat/views.sh <직업> <모션> <시각> <무기Id>
set -e
cd "$(dirname "$0")/../.."
LUNE=/c/Users/hhksh/AppData/Local/Microsoft/WinGet/Packages/Lune.Lune_Microsoft.Winget.Source_8wekyb3d8bbwe/lune.exe
$LUNE run tools/combat/export_motions.luau >/dev/null
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P tools/combat/preview_motion.py -- views "$1" "$2" "$3" "$4" "views_$1_${2//./_}" 2>&1 | grep -E "rror|찍음" || true
