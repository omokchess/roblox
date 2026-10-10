--!nocheck
--[[
	Snow_TownKit.luau — 2026-10-09. models/build_steam_town.py 합본 SnowTownKit.fbx(설원 마을 새 건물)를 가른다(Snow_Kit.luau 와 같은 방식).
	가져온 모델 이름 SnowTownKit, 원점 표지 SnowTownOrigin_Marker. 틀은 같은 ServerStorage.SnowKit 에 더한다.
	(아래는 Snow_Kit.luau 설명 그대로)

	Workspace.SnowKit 의 메시를 이름 앞머리로 모델별로 나누고, 원점 표지(SnowOrigin_Marker)를
	빼서 블렌더 원점을 피벗으로 되찾는다. 재질은 아래 SKIN 표대로 입힌다.
	표지 둘은 여기서 속을 채운다.
	  Vent    보이지 않게 하고 김(ParticleEmitter)을 단다
	  LampPt  보이지 않게 하고 따뜻한 점광원을 단다
	틀은 ServerStorage.SnowKit 에 넣는다. 끝에 모든 틀의 로컬 발자국을 잰다.
]]

local RGB = Color3.fromRGB
local M = Enum.Material
local SKIN = {
	Brick = { RGB(122, 64, 52), M.Brick },
	BrickDark = { RGB(90, 67, 61), M.Brick },
	Stone = { RGB(85, 86, 92), M.Slate },
	StoneTrim = { RGB(140, 139, 138), M.Concrete },
	Iron = { RGB(58, 60, 66), M.Metal },
	IronLight = { RGB(94, 98, 107), M.DiamondPlate },
	Brass = { RGB(184, 145, 63), M.Metal },
	Copper = { RGB(176, 106, 63), M.Metal },
	Verdigris = { RGB(95, 158, 140), M.CorrodedMetal },
	Timber = { RGB(90, 62, 44), M.WoodPlanks },
	RoofMetal = { RGB(53, 56, 64), M.Metal },
	SnowCap = { RGB(238, 243, 247), M.Snow },
	Glow = { RGB(225, 140, 60), M.Neon },
	Core = { RGB(255, 55, 75), M.Neon }, -- 감정의 열기. 네온은 밝게 뜨므로 붉은 쪽으로 세게 잡는다
	Soot = { RGB(43, 42, 44), M.Slate },
	Char = { RGB(31, 27, 26), M.Wood },
	Canvas = { RGB(203, 190, 158), M.Fabric },
	Banner = { RGB(124, 43, 46), M.Fabric },
	Wood = { RGB(138, 90, 54), M.Wood },
	Glass = { RGB(200, 225, 235), M.Glass }, -- 반투명으로 둔다 (skin 아래)
	Leather = { RGB(74, 46, 36), M.Leather },
	Vent = { RGB(255, 255, 255), M.SmoothPlastic },
	SignBlue = { RGB(58, 95, 168), M.SmoothPlastic },
	SignGold = { RGB(201, 162, 58), M.SmoothPlastic },
	SignTeal = { RGB(62, 156, 147), M.SmoothPlastic },
	SignRed = { RGB(168, 58, 58), M.SmoothPlastic },
	SignPurple = { RGB(107, 74, 160), M.SmoothPlastic },
	Dial = { RGB(242, 232, 200), M.SmoothPlastic },
	LampPt = { RGB(255, 255, 255), M.SmoothPlastic },
}
-- 지붕과 눈은 껍데기, 불빛은 부딪히지 않는다. 나머지는 모양대로 잡는다.
-- 조각 여럿이 든 메시를 상자로 잡으면 굴뚝까지 한 덩이 벽이 된다
local HULL = { RoofMetal = true, SnowCap = true, Canvas = true }
local NOCOLLIDE = { Glow = true, Core = true, Banner = true, Vent = true, LampPt = true }

local PREFIX = {
	Clock = "Clock_Tower", Obs = "Observatory", Casino = "Casino_Hall", Fact = "Steam_Factory",
	ShopB = "Shop_Blue", ShopG = "Shop_Gold", ShopT = "Shop_Teal", ShopR = "Shop_Red",
	Inn = "Inn_House", Ticket = "Ticket_Booth", UGate = "Under_Gate",
	-- 천문대 2판(들어가는 건물·도는 돔·극축 둘레로 도는 망원경·태양계 모형 팔) + 놀이터·연못 소품 (build_steam_obs.py)
	ObsDome = "Observatory_Dome", ObsScope = "Observatory_Scope",
	OrrA = "Orrery_A", OrrB = "Orrery_B", OrrC = "Orrery_C", OrrD = "Orrery_D",
	PSwing = "Play_Swing", PSlide = "Play_Slide", PSaw = "Play_Seesaw", PRoundB = "Play_RoundBase", PRound = "Play_Round",
	PDome = "Play_Dome", PBench = "Park_Bench", PSnow = "Snowman", PSled = "Sled",
}
-- 피벗을 원점(바닥 가운데)이 아닌 곳에 두는 틀. 톱니는 굴대 가운데를 축으로 돌고,
-- 꺾인 관은 꺾인 자리를 관 끝에 맞춘다(build_steam.py pipe_bend90 의 P)
local PIVOT = {
	Gear_24 = "hub", Gear_16 = "hub", Gear_10 = "hub",
	Pipe_Bend90 = Vector3.new(0, 4, 0),
}

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local function skin(p, key, modelName)
	local s = assert(SKIN[key], "모르는 재질 이름 " .. p.Name)
	p.Color = s[1]
	p.Material = s[2]
	p.Anchored = true
	p.CanCollide = not NOCOLLIDE[key] and modelName ~= "Airship"
	p.CastShadow = not NOCOLLIDE[key]
	p.CollisionFidelity = HULL[key] and Enum.CollisionFidelity.Hull
		or Enum.CollisionFidelity.PreciseConvexDecomposition
	p.RenderFidelity = Enum.RenderFidelity.Precise
	if key == "Glass" then
		p.Transparency = 0.55
		p.CastShadow = false
	end
	if key == "Vent" or key == "LampPt" then
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
	end
	if key == "Vent" then
		-- 김. 굴뚝 위로 천천히 올라가며 흩어진다
		local e = Instance.new("ParticleEmitter")
		e.Name = "Steam"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(RGB(235, 235, 240), RGB(200, 200, 208))
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.6, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
		e.Lifetime = NumberRange.new(3, 5)
		e.Rate = 5
		e.Speed = NumberRange.new(3, 5)
		e.SpreadAngle = Vector2.new(12, 12)
		e.Acceleration = Vector3.new(2, 1, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.LightInfluence = 1
		e.Parent = p
	elseif key == "LampPt" then
		local l = Instance.new("PointLight")
		l.Color = RGB(255, 190, 120)
		l.Brightness = 1.6
		l.Range = 20
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
	local kit = SS:FindFirstChild("SnowKit")
	if not kit then
		kit = Instance.new("Folder")
		kit.Name = "SnowKit"
		kit.Parent = SS
	end
	local imp = workspace:FindFirstChild("SnowTownKit")
	if imp then
		local marker = assert(imp:FindFirstChild("SnowTownOrigin_Marker", true), "원점 표지가 없다")
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
			local pv = PIVOT[name]
			if pv == "hub" then
				-- 살과 굴대가 든 쇠 메시의 가운데가 톱니 가운데다
				for _, p in ipairs(m:GetChildren()) do
					if p.Name:match("_Iron$") then
						m.WorldPivot = CFrame.new(p.Position)
					end
				end
			elseif pv then
				m.WorldPivot = CFrame.new(pv)
			end
			m.Parent = kit
			n += 1
		end
		imp:Destroy()
		say("새 틀 %d 종", n)
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
		local b = { math.huge, -math.huge, math.huge, -math.huge }
		local a = { math.huge, -math.huge, math.huge, -math.huge, -math.huge }
		for _, q in ipairs(parts) do
			local e, c = q.e, q.c
			a[1], a[2] = math.min(a[1], c.X - e.X), math.max(a[2], c.X + e.X)
			a[3], a[4] = math.min(a[3], c.Z - e.Z), math.max(a[4], c.Z + e.Z)
			a[5] = math.max(a[5], c.Y + e.Y)
			if c.Y - e.Y < minY + 0.3 then
				b[1], b[2] = math.min(b[1], c.X - e.X), math.max(b[2], c.X + e.X)
				b[3], b[4] = math.min(b[3], c.Z - e.Z), math.max(b[4], c.Z + e.Z)
			end
		end
		say("%s base %.1f %.1f %.1f %.1f all %.1f %.1f %.1f %.1f h %.1f minY %.2f n %d",
			name, b[1], b[2], b[3], b[4], a[1], a[2], a[3], a[4], a[5], minY, #parts)
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snowtownkit", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("snowtownkit", #report, ok)
