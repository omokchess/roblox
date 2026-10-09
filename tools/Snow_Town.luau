--!nocheck
--[[
	Snow_Town.luau — 2026-10-09. 설원 새 마을(슈네라이히) 짓기(편집 모드, StudioJobs).
	자리 = tools/snow_town_plan.py(사용자 마을 확대 그림을 딴 손 표, 겹침 검사) → Snow_Town_data.luau:
	  python tools/snow_town_plan.py --town && sed '/--@@DATA@@/r tools/Snow_Town_data.luau' tools/Snow_Town.luau > tools/swamp/_town_run.luau && bash tools/job.sh tools/swamp/_town_run.luau
	틀 = ServerStorage.SnowKit(옛 키트 + Snow_TownKit 새 건물). workspace.Schneereich.마을 만 지우고 새로(안쪽방·스크립트는 그대로).
	건물: 틀 복제 → ScaleTo(배율) → 바닥 GROUND_Y 에 앞(-Z)이 yaw 쪽을 보게. 광장: 팔각 돌판 + 둘레 가스등 8. 길: 돌판 띠.
	보고: /snowtown
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local PAVE, PAVE2 = RGB(150, 146, 140), RGB(128, 124, 120)
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local function slab(name, cf, size, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color, p.Material = color, M.Cobblestone
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local ok, err = pcall(function()
	local kit = SS:FindFirstChild("SnowKit")
	assert(kit, "ServerStorage.SnowKit 없음")
	local city = workspace:FindFirstChild("Schneereich") or Instance.new("Folder")
	city.Name = "Schneereich"
	city.Parent = workspace
	local old = city:FindFirstChild("마을")
	if old then
		old:Destroy()
	end
	local town = Instance.new("Folder")
	town.Name = "마을"
	local bfolder = Instance.new("Folder")
	bfolder.Name = "건물"
	bfolder.Parent = town
	local n, missing = 0, {}
	for _, p in PLACE do
		local kind, x, z, sc, yaw, name = p[1], p[2], p[3], p[4], p[5], p[6]
		local src = kit:FindFirstChild(kind)
		if not src then
			missing[kind] = true
			continue
		end
		local m = src:Clone()
		m.Name = name
		m:SetAttribute("Kit", kind)
		if sc ~= 1 then
			m:ScaleTo(sc)
		end
		m:PivotTo(CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, math.rad(yaw), 0))
		m.Parent = bfolder
		n += 1
	end
	-- 광장: 팔각(네모 둘을 45° 엇갈려) 돌판, 가운데 띠 + 둘레 가스등
	local plaza = Instance.new("Folder")
	plaza.Name = "광장"
	plaza.Parent = town
	local cx, cz, R = PLAZA[1], PLAZA[2], PLAZA[3]
	local side = 2 * R * math.cos(math.rad(22.5))
	slab("광장판", CFrame.new(cx, GROUND_Y + 0.3, cz), Vector3.new(side, 1, side), PAVE, plaza)
	slab("광장판45", CFrame.new(cx, GROUND_Y + 0.32, cz) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(side, 1, side), PAVE, plaza)
	slab("광장안쪽", CFrame.new(cx, GROUND_Y + 0.36, cz) * CFrame.Angles(0, math.rad(22.5), 0), Vector3.new(R * 0.9, 1, R * 0.9), PAVE2, plaza)
	local lamp = kit:FindFirstChild("Gas_Lamp")
	if lamp then
		for k = 0, 7 do
			local a = math.rad(22.5 + 45 * k)
			local px, pz = cx + math.cos(a) * (R - 8), cz + math.sin(a) * (R - 8)
			local l = lamp:Clone()
			l:ScaleTo(1.4)
			l:PivotTo(CFrame.lookAt(Vector3.new(px, GROUND_Y + 0.8, pz), Vector3.new(cx, GROUND_Y + 0.8, cz)))
			l.Parent = plaza
		end
	end
	-- 길
	local roads = Instance.new("Folder")
	roads.Name = "길"
	roads.Parent = town
	for _, r in ROADS do
		local name, w, pts = r[1], r[2], r[3]
		for i = 1, #pts - 1 do
			local a, b = Vector3.new(pts[i][1], GROUND_Y + 0.25, pts[i][2]), Vector3.new(pts[i + 1][1], GROUND_Y + 0.25, pts[i + 1][2])
			local L = (b - a).Magnitude
			slab(name .. i, CFrame.lookAt((a + b) / 2, b), Vector3.new(w, 1, L + w * 0.5), if i % 2 == 0 then PAVE else PAVE2, roads)
		end
	end
	town.Parent = city
	for k in missing do
		say("틀 없음 %s", k)
	end
	say("마을: 건물 %d · 길 %d", n, #ROADS)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/snowtown", table.concat(lines, "\n"))
