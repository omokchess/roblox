--!nocheck
--[[
	Snow_Field.luau — 2026-10-09. 설원 지상 마무리(편집 모드, StudioJobs): 보스룸·휴식처 2/8·동굴 입구 둘레·3번 입구 잠금·눈 나무·큰 바위.
	자료 tools/snow_field_plan.py → Snow_Field_data.luau:
	  python tools/snow_field_plan.py && sed '/--@@DATA@@/r tools/Snow_Field_data.luau' tools/Snow_Field.luau > tools/swamp/_field_run.luau && bash tools/job.sh tools/swamp/_field_run.luau
	Surface.R_설원3_장식 만 지우고 새로. 나무 = ServerStorage.ForestKit 틀의 잎을 눈 색으로(사용자 참고 사진: 하얀·푸른 잎 덩어리).
	표지: BossArena(속성 Region·Radius) · QuestItem(속성 QuestItem) · QuestLock(속성 QuestLocked·Entrance) · Campfire(불·빛). 보고: /snowfield
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
local M = Enum.Material

--@@DATA@@

local SKIN = {
	ArenaStone = { RGB(88, 94, 102), M.Slate },
	ArenaIce = { RGB(170, 205, 230), M.Glacier },
	PillarRock = { RGB(100, 110, 106), M.Slate },
	PillarRock2 = { RGB(88, 97, 95), M.Slate },
	SnowCap = { RGB(238, 243, 247), M.Snow },
	RestStone = { RGB(120, 118, 112), M.Slate },
	FireRock = { RGB(70, 66, 62), M.Basalt },
	Timber = { RGB(90, 62, 44), M.WoodPlanks },
	Grate = { RGB(58, 60, 66), M.DiamondPlate },
}
local LEAF = { LeafA = RGB(232, 240, 248), LeafB = RGB(196, 212, 228) }
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local S = workspace.Surface
	local old = S:FindFirstChild("R_설원3_장식")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "R_설원3_장식"
	local fold = {}
	local function folder(n)
		if not fold[n] then
			local f = Instance.new("Folder")
			f.Name = n
			f.Parent = root
			fold[n] = f
		end
		return fold[n]
	end
	for i, b in BOXES do
		local g = b[1]
		local s = SKIN[g]
		local p = Instance.new("Part")
		p.Name = g .. i
		p.Anchored = true
		p.Size = Vector3.new(b[5], b[6], b[7])
		p.CFrame = CFrame.new(b[2], b[3], b[4]) * CFrame.Angles(0, math.rad(b[8]), 0)
		p.Color, p.Material = s[1], s[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = folder(if g == "ArenaStone" or g == "ArenaIce" then "보스룸" else "돌")
	end
	local kit = SS:FindFirstChild("SnowKit")
	for _, k in KITS do
		local src = kit and kit:FindFirstChild(k[1])
		if src then
			local m = src:Clone()
			m:ScaleTo(k[6])
			m:PivotTo(CFrame.new(k[2], k[3], k[4]) * CFrame.Angles(0, math.rad(k[5]), math.rad(12)))
			m.Parent = folder("보스룸")
		end
	end
	for _, mk in MARKS do
		local name, x, y, z, attrs = mk[1], mk[2], mk[3], mk[4], mk[5]
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(2, 2, 2)
		p.CFrame = CFrame.new(x, y, z)
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
		if name == "Campfire" then
			p.Transparency = 1
			local f = Instance.new("Fire")
			f.Size = 6
			f.Heat = 8
			f.Parent = p
			local l = Instance.new("PointLight")
			l.Color = RGB(255, 170, 90)
			l.Range = 28
			l.Brightness = 2
			l.Parent = p
		elseif name == "QuestItem" then
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(2.2, 2.2, 2.2)
			p.Material = M.Neon
			p.Color = RGB(150, 200, 255)
			local l = Instance.new("PointLight")
			l.Color = RGB(150, 200, 255)
			l.Range = 14
			l.Parent = p
		else
			p.Transparency = 1
			p.CanQuery = false
		end
		p.Parent = folder("표지")
	end
	-- 눈 나무
	local fk = SS:FindFirstChild("ForestKit")
	local pieces = {}
	for _, m in (fk and fk:GetChildren()) or {} do
		local list = {}
		for _, c in m:GetChildren() do
			if c:IsA("BasePart") and c.Name ~= "Origin" then
				list[#list + 1] = c
			end
		end
		pieces[m.Name] = list
	end
	local nt = 0
	for i, t in TREES do
		local list = pieces[t[1]]
		if not list then
			continue
		end
		local base = CFrame.new(t[2], t[3], t[4]) * CFrame.Angles(0, math.rad(t[5]), 0)
		local sc = t[6]
		local model = Instance.new("Model")
		model.Name = t[1]
		for _, src in list do
			local p = src:Clone()
			p.Size = src.Size * sc
			p.CFrame = base * CFrame.new(src.Position * sc) * src.CFrame.Rotation
			if LEAF[p.Name] then
				p.Color = LEAF[p.Name]
				p.Material = M.Snow
			end
			p.Parent = model
		end
		model.Parent = folder("나무")
		nt += 1
		if nt % 300 == 0 then
			task.wait()
		end
	end
	root.Parent = S
	say("설원 장식: 상자 %d · 키트 %d · 표지 %d · 나무 %d", #BOXES, #KITS, #MARKS, nt)
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/snowfield", table.concat(lines, "\n"))
