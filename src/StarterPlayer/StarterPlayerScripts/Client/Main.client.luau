--!strict
-- 클라이언트 진입점

local Controllers = script.Parent:WaitForChild("Controllers")

local order = {
	"CombatBus",
	"CameraController",
	"WorldFX",
	"AmbienceController",
	"FerryController",
	"LockOnController",
	"AnimationController",
	"CombatController",
	"CombatFX",
	"CombatHUD",
}

for _, name in order do
	local mod = require(Controllers:WaitForChild(name)) :: any
	local ok, err = pcall(mod.Start)
	if not ok then
		warn("[Swamp] 컨트롤러 시작 실패:", name, err)
	end
end
