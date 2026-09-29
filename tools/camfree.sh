#!/usr/bin/env bash
# camfree.sh — 편집 카메라를 스튜디오 기본(Fixed)으로 되돌린다(우클릭 회전·WASD 가 다시 된다). cam.sh 뒤에 꼭. 2026-09-29
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/swamp/_camfree.luau"
printf 'workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed\n' > "$T"
bash "$HERE/job.sh" "$T"
