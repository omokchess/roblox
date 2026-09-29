--!nocheck
--[[
	Swamp_Revert.luau — 2026-09-28. 늪지대 재작업을 되돌린다(돌리기 전 확인할 것).
	- Workspace.Surface.Swamp_늪지대 지움
	- 늪지대 지형(x 1384..3328, z 452..1700, y -12..16)을 공기로
	- 숨긴 흙 판(Gs_늪지대)을 SwampOld* 속성 값으로 되살림
	- 물빛을 원래 값(0.05, 0.33, 0.36)으로. 나머지 물 설정(투명·반사·물결)은 원래 값을 기록 못 해 그대로 둔다
	보고: /swamprevert
]]
local out = {}
local ok, err = pcall(function()
	local f = workspace.Surface:FindFirstChild("Swamp_늪지대")
	if f then
		f:Destroy()
		out[#out + 1] = "배치 지움"
	end
	workspace.Terrain:FillBlock(CFrame.new(2356, 2, 1076), Vector3.new(1944, 28, 1248), Enum.Material.Air)
	local n = 0
	for _, p in ipairs(workspace.Surface.World["G_늪지대"]:GetChildren()) do
		local t = p:GetAttribute("SwampOldTransparency")
		if t ~= nil then
			p.Transparency = t
			p.CanCollide = p:GetAttribute("SwampOldCollide")
			p.CanQuery = p:GetAttribute("SwampOldQuery")
			p.CastShadow = p:GetAttribute("SwampOldShadow")
			p.CanTouch = true
			for _, k in ipairs({ "SwampOldTransparency", "SwampOldCollide", "SwampOldQuery", "SwampOldShadow" }) do
				p:SetAttribute(k, nil)
			end
			n += 1
		end
	end
	workspace.Terrain.WaterColor = Color3.new(0.05, 0.33, 0.36)
	out[#out + 1] = "지형 비움, 흙 판 되살림 " .. n
end)
if not ok then
	out[#out + 1] = "ERR " .. tostring(err)
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/swamprevert", table.concat(out, "\n"))
