#!/usr/bin/env bash
# cam.sh ex ey ez tx ty tz — StudioJobs 폴러로 편집 카메라를 옮긴다(스튜디오 스크린샷 찍기 전). 2026-09-29
# 편집 카메라는 Scriptable 이어야 스크립트 CFrame 을 따른다. 그런데 Scriptable 이면 스튜디오 우클릭 회전이 막히고
# 그 값이 플레이스에 저장된다(2026-09-29 사용자 신고 두 번) → 10초 뒤 저절로 Fixed 로 되돌린다(그 안에 찍을 것).
# 더 길게 잡고 싶으면 바로 이어 cam.sh 를 다시 부르면 된다(늦은 되돌림은 마지막 부름 것만 한다).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/swamp/_cam.luau"
cat > "$T" <<LUA
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 70
cam.CFrame = CFrame.lookAt(Vector3.new($1, $2, $3), Vector3.new($4, $5, $6))
local token = os.clock()
_G.CamToken = token
task.delay(10, function()
	if _G.CamToken == token then
		cam.CameraType = Enum.CameraType.Fixed
	end
end)
LUA
bash "$HERE/job.sh" "$T"
