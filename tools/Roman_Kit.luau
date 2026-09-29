--!nocheck
--[[
	Roman_Kit.luau — 2026-09-28. 블렌더 합본 RomanKit.fbx 를 칼로도르 폴리스(화산섬 로마풍 도시) 틀로 가른다.

	Workspace.RomanKit 의 메시를 이름 앞머리로 모델별로 나누고, 원점 표지(RomanOrigin_Marker)를
	빼서 블렌더 원점을 피벗으로 되찾는다. 재질은 아래 SKIN 표대로 입힌다.
	표지 둘은 여기서 속을 채운다.
	  Vent    보이지 않게 하고 불(불화로·불의 글라디우스·거인상 불그릇) 또는 김(목욕장·수도교·분수)·
	          검은 입김(봉인된 거인)을 단다
	  LampPt  보이지 않게 하고 따뜻한 점광원을 단다(봉인된 거인은 붉게)
	틀은 ServerStorage.RomanKit 에 넣는다. 끝에 모든 틀의 로컬 발자국을 잰다(보고 /romankit).
]]

local RGB = Color3.fromRGB
local M = Enum.Material
-- 2026-09-29 폐허: 그을리고 바랜 칙칙한 빛(원래 값은 backup/2026-09-29_motions_original 의 옛 키트 FBX 와 짝)
local SKIN = {
	Marble = { RGB(167, 161, 148), M.Marble },
	MarbleWall = { RGB(156, 149, 136), M.Marble },
	MarbleDark = { RGB(124, 118, 107), M.Marble },
	Travertine = { RGB(154, 144, 123), M.Limestone },
	Plaster = { RGB(158, 147, 129), M.Plaster },
	PlasterOchre = { RGB(137, 110, 87), M.Plaster },
	PlasterRed = { RGB(104, 64, 54), M.Plaster },
	Brick = { RGB(108, 73, 59), M.Brick },
	Tile = { RGB(104, 68, 54), M.ClayRoofTiles },
	Basalt = { RGB(42, 39, 40), M.Basalt },
	BasaltLight = { RGB(74, 69, 67), M.Basalt },
	Porphyry = { RGB(76, 42, 43), M.Marble },
	Bronze = { RGB(92, 74, 48), M.Metal },
	Verdigris = { RGB(63, 98, 88), M.CorrodedMetal },
	Gold = { RGB(122, 100, 64), M.Metal },
	Wood = { RGB(62, 49, 40), M.WoodPlanks },
	Iron = { RGB(51, 50, 53), M.CorrodedMetal },
	Lava = { RGB(255, 84, 24), M.Neon },
	Rune = { RGB(255, 170, 60), M.Neon },
	Fabric = { RGB(90, 42, 38), M.Fabric },
	HotWater = { RGB(74, 124, 118), M.Glass },
	Glow = { RGB(225, 140, 60), M.Neon },
	Garden = { RGB(90, 90, 58), M.Ground },
	Sand = { RGB(138, 126, 102), M.Sand },
	Terracotta = { RGB(122, 80, 64), M.SmoothPlastic },
	Vent = { RGB(255, 255, 255), M.SmoothPlastic },
	LampPt = { RGB(255, 255, 255), M.SmoothPlastic },
}
-- 기와·천은 껍데기, 불빛은 부딪히지 않는다. 나머지는 모양대로
local HULL = { Tile = true, Fabric = true }
local NOCOLLIDE = { Glow = true, Lava = true, Rune = true, Fabric = true, Vent = true, LampPt = true, HotWater = true }

local PREFIX = {
	TIg = "Temple_Ignus", TSm = "Temple_Small", Bas = "Basilica", Thm = "Thermae", AmQ = "Amph_Quarter",
	Dom = "Domus", InA = "Insula_A", InB = "Insula_B", Tab = "Taberna_Row", Pal = "Palatium", Pri = "Principia",
	Brk = "Barracks", Wtc = "Watchtower", Crn = "Crane", FGl = "Fire_Gladius", Aqd = "Aqueduct_Span",
	Brg = "Bridge_Span", Wal = "Wall_Seg", Wtw = "Wall_Tower", Gat = "City_Gate", TAr = "Triumphal_Arch",
	Col = "Colossus", GHd = "Giant_Head", GHn = "Giant_Hand", GFt = "Giant_Foot", SGi = "Sealed_Giant",
	SOb = "Seal_Obelisk", Stt = "Statue_Human", Aqu = "Aquila", VCl = "Victory_Column", Brz = "Brazier",
	Fnt = "Fountain", Mkt = "Market_Stall", Amp = "Amphorae", RTm = "Ruin_Temple", CDr = "Column_Drums",
	-- 폐허 두 번째 판(2026-09-29): 무너진 모양이 다르다
	Dom2 = "Domus_2", InA2 = "Insula_A_2", InB2 = "Insula_B_2", Tab2 = "Taberna_Row_2", Brk2 = "Barracks_2", Wal2 = "Wall_Seg_2",
}
-- Vent 가 무엇을 뿜는지
local FIRE = { Brazier = true, Fire_Gladius = true, Colossus = true }
local SMOKE = { Sealed_Giant = true }

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local function fire(p, big)
	local f = Instance.new("Fire")
	f.Size = big and 7 or 4
	f.Heat = big and 9 or 6
	f.Color = RGB(255, 120, 40)
	f.SecondaryColor = RGB(255, 60, 20)
	f.Parent = p
end

local function steam(p, dark)
	local e = Instance.new("ParticleEmitter")
	e.Name = dark and "Breath" or "Steam"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	if dark then
		e.Color = ColorSequence.new(RGB(60, 50, 50), RGB(30, 26, 28))
	else
		e.Color = ColorSequence.new(RGB(240, 240, 244), RGB(210, 210, 216))
	end
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, dark and 0.35 or 0.5),
		NumberSequenceKeypoint.new(0.6, 0.78),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, dark and 3 or 1.5), NumberSequenceKeypoint.new(1, dark and 14 or 7) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = dark and 3 or 4
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Acceleration = Vector3.new(1, 1.2, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.LightInfluence = 1
	e.Parent = p
end

local function skin(p, key, modelName)
	local s = assert(SKIN[key], "모르는 재질 이름 " .. p.Name)
	p.Color = s[1]
	p.Material = s[2]
	p.Anchored = true
	p.CanCollide = not NOCOLLIDE[key]
	p.CastShadow = not NOCOLLIDE[key]
	p.CollisionFidelity = HULL[key] and Enum.CollisionFidelity.Hull
		or Enum.CollisionFidelity.PreciseConvexDecomposition
	p.RenderFidelity = Enum.RenderFidelity.Precise
	if key == "HotWater" then
		p.Transparency = 0.25
		p.CastShadow = false
	end
	if key == "Vent" or key == "LampPt" then
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
	end
	if key == "Vent" then
		if FIRE[modelName] then
			fire(p, modelName ~= "Brazier")
		else
			steam(p, SMOKE[modelName])
		end
	elseif key == "LampPt" then
		local l = Instance.new("PointLight")
		if modelName == "Sealed_Giant" then
			l.Color = RGB(255, 90, 40)
			l.Brightness = 3
			l.Range = 40
		else
			l.Color = RGB(255, 184, 110)
			l.Brightness = 1.4
			l.Range = 22
		end
		l.Shadows = false
		l.Parent = p
	end
end

local function halfExtents(part, frame)
	local r = frame:ToObjectSpace(part.CFrame)
	local s = part.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("RomanKit")
	if not kit then
		kit = Instance.new("Folder")
		kit.Name = "RomanKit"
		kit.Parent = SS
	end
	local imp = workspace:FindFirstChild("RomanKit")
	if imp then
		local marker = assert(imp:FindFirstChild("RomanOrigin_Marker", true), "원점 표지가 없다")
		local o = marker.Position
		say("표지 %.2f %.2f %.2f", o.X, o.Y, o.Z)
		local groups = {}
		for _, p in ipairs(imp:GetDescendants()) do
			if p:IsA("BasePart") and p ~= marker then
				local pre, key = p.Name:match("^([^_]+)_(.+)$")
				local name = assert(PREFIX[pre], "모르는 앞머리 " .. p.Name)
				groups[name] = groups[name] or {}
				table.insert(groups[name], { p = p, key = key })
			end
		end
		local n = 0
		for name, list in pairs(groups) do
			local old = kit:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local m = Instance.new("Model")
			m.Name = name
			for _, e in ipairs(list) do
				e.p.CFrame = e.p.CFrame - o
				skin(e.p, e.key, name)
				e.p.Parent = m
			end
			m.WorldPivot = CFrame.new()
			m.Parent = kit
			n += 1
		end
		imp:Destroy()
		say("새 틀 %d 종", n)
	else
		-- 가져온 것이 없으면 있는 틀에 SKIN 빛만 다시 입힌다(색표를 고친 뒤). 폐허라 창 불빛·등불은 뗀다
		local n = 0
		for _, p in ipairs(kit:GetDescendants()) do
			local key = p:IsA("BasePart") and p.Name:match("^[^_]+_(.+)$")
			if (key == "Glow" or key == "LampPt") and p.Parent.Name ~= "Sealed_Giant" then
				p:Destroy()
			elseif key and SKIN[key] then
				p.Color, p.Material = SKIN[key][1], SKIN[key][2]
				n += 1
			end
		end
		say("빛 다시 입힘 %d", n)
	end
	local names = {}
	for _, m in ipairs(kit:GetChildren()) do
		names[#names + 1] = m.Name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local m = kit[name]
		local frame = m:GetPivot()
		local minY = math.huge
		local parts = {}
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local e, c = halfExtents(p, frame)
				parts[#parts + 1] = { e = e, c = c }
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local a = { math.huge, -math.huge, math.huge, -math.huge, -math.huge }
		for _, q in ipairs(parts) do
			local e, c = q.e, q.c
			a[1], a[2] = math.min(a[1], c.X - e.X), math.max(a[2], c.X + e.X)
			a[3], a[4] = math.min(a[3], c.Z - e.Z), math.max(a[4], c.Z + e.Z)
			a[5] = math.max(a[5], c.Y + e.Y)
		end
		say("%s x %.1f..%.1f z %.1f..%.1f h %.1f minY %.2f n %d", name, a[1], a[2], a[3], a[4], a[5], minY, #parts)
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/romankit", table.concat(report, "\n"))
end)
print("romankit", #report, ok)
