#!/usr/bin/env sh
# 정적 검사: Rojo sourcemap -> luau-lsp 타입 검사 + selene 린트
# 필요: rojo, luau-lsp, selene (rokit install), Roblox 타입 정의 파일
set -e
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:-$HOME/tools}"
DEFS="${LUAU_DEFS:-$TOOLS/globalTypes.d.luau}"
"$TOOLS/rojo" sourcemap default.project.json -o sourcemap.json --include-non-scripts
"$TOOLS/luau-lsp" analyze --sourcemap=sourcemap.json --definitions="$DEFS" --settings=tools/luau-lsp.json \
  --ignore="**/Generated/**" src plugin "$@"
# selene 은 roblox std 생성(selene generate-roblox-std)이 가능한 환경에서만 실행
if [ -f roblox.yml ] || [ -f roblox.yaml ]; then
  "$TOOLS/selene" --display-style=quiet src plugin
fi
