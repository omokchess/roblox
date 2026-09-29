--!nocheck
--[[
	RegionAtmosphere_Setup.luau — 옛 스튜디오 전용 바이옴 조명 스크립트를 끈다(지우지 않음). (2026-09-29)
	새것은 src/client/RegionAtmosphere.luau(저장소, init.client 가 켬). 되돌리려면 BiomeAtmosphere.Enabled = true.
]]
local old = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("BiomeAtmosphere")
if old then
	old.Enabled = false
end
pcall(function()
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/atmo_setup", old and "옛 스크립트 끔" or "옛 스크립트 없음")
end)
