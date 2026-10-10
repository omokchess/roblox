#!/usr/bin/env bash
# camrel.sh <모델 이름> bx by bz tx ty tz — 마을 안 그 이름 모델(처음 것)의 블렌더 좌표(x, y, z)로 편집 카메라를 옮긴다(실내 점검용, 2026-10-10)
# 블렌더 (x, y, z) → 로블록스 로컬 (-x, z, y). 10초 뒤 Fixed 로 되돌린다(cam.sh 와 같음)
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/swamp/_camrel.luau"
cat > "$T" <<LUA
local town = workspace.Schneereich["마을"]
local m
for _, d in town:GetDescendants() do
	if d:IsA("Model") and d.Name == "$1" then
		m = d
		break
	end
end
local pv = m:GetPivot()
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 70
cam.CFrame = CFrame.lookAt(pv * Vector3.new(-($2), $4, $3), pv * Vector3.new(-($5), $7, $6))
local token = os.clock()
_G.CamToken = token
task.delay(10, function()
	if _G.CamToken == token then
		cam.CameraType = Enum.CameraType.Fixed
	end
end)
LUA
bash "$HERE/job.sh" "$T"
