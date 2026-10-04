#!/usr/bin/env bash
# 직업 하나의 모든 모션을 찍어 한 장(sheet_<직업>.png)으로 묶는다.
# 쓰는 법: bash tools/combat/render_class.sh <직업> <무기 Id> [장수(기본 7)]
set -e
cd "$(dirname "$0")/../.."
B="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
N="${3:-7}"
# 모션 자료(motions.json)를 먼저 새로 뽑는다(2026-10-04: 안 뽑으면 옛 모션으로 그렸다)
"/c/Users/hhksh/AppData/Local/Microsoft/WinGet/Packages/Lune.Lune_Microsoft.Winget.Source_8wekyb3d8bbwe/lune.exe" run tools/combat/export_motions.luau >/dev/null
"$B" -b -P tools/combat/preview_motion.py -- "$1" all "$N" "$2" 2>&1 | grep -E "rror" || true
cd tools/combat/out
D="$(pwd -W)"
# 두 장: _a = 대기·들림·내려놓임·피격·방어·회피, _b = 스킬
A=()
for f in Idle Held Drop Hit Guard Dodge; do [ -f "$1_$f.png" ] && A+=("$D/$1_$f.png"); done
"$B" -b -P ../sheet.py -- "$D/sheet_$1_a.png" "${A[@]}" 2>&1 | grep -E "rror|묶음" || true
A=()
for f in $1_Skills_*.png; do A+=("$D/$f"); done
"$B" -b -P ../sheet.py -- "$D/sheet_$1_b.png" "${A[@]}" 2>&1 | grep -E "rror|묶음" || true
