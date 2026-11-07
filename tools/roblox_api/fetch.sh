#!/bin/sh
# 로블록스 공식 API 덤프를 받는다 → tools/roblox_api/API-Dump.json (git 에는 안 올림 — .gitignore)
#   sh tools/roblox_api/fetch.sh [저장경로]
# 검사기(tools/roblox_api.luau · tools/check_roblox_api.py)가 쓴다. 스튜디오가 새로 나오면 다시 받을 것.
set -e
OUT="${1:-$(dirname "$0")/API-Dump.json}"
VER=$(curl -fsS https://setup.rbxcdn.com/versionQTStudio)
curl -fsS "https://setup.rbxcdn.com/${VER}-API-Dump.json" -o "$OUT"
echo "받음: $VER -> $OUT"
