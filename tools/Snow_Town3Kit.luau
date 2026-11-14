--!nocheck
--[[
	Snow_Town3Kit.luau — 2026-11-14. 설원 마을 3판 새 건물 키트(models/snow3 → models/SnowTown3Kit.fbx)를 가른다.
	Snow_TownKit.luau 와 같은 방식. 가져온 모델 이름 SnowTown3Kit, 원점 표지 SnowTown3Origin_Marker.
	틀은 ServerStorage.SnowKit3.<모델 이름> 에 넣는다(같은 이름은 갈아 끼움, 이번에 없는 틀은 그대로 — 건물이 몇 채씩 나눠 들어온다).
	메시 앞머리 → 모델 이름 표는 tools/snow3_kit.json(models.<이름>.prefix)에서 받는다.
	json 의 new_materials 에 있는데 SKIN 에 없는 이름은 보고에 "모르는 재질"로 적고 Timber 로 대신한다(멈추지 않음).

	돌리는 순서(총괄):
	  1. 프로젝트 루트를 로컬 서버(35001)로 띄운다.  2. Studio 에서 Ctrl+M 으로 models/SnowTown3Kit.fbx 를 가져온다(Workspace.SnowTown3Kit).
	  3. bash tools/job.sh tools/Snow_Town3Kit.luau   (또는 커맨드 바 로더)   4. 보고: /snowtown3kit
	끝에 틀마다 발자국(base/all)을 재서 json 값과 0.5 넘게 다르면 "발자국 차이"로 보고한다.
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
	Steel = { RGB(180, 188, 198), M.Metal },
	PaintGreen = { RGB(62, 110, 90), M.Wood },
	SnowDrift = { RGB(238, 243, 247), M.Snow },
	Rail = { RGB(58, 60, 66), M.Metal },
	Brass = { RGB(184, 145, 63), M.Metal },
	Copper = { RGB(176, 106, 63), M.Metal },
	Verdigris = { RGB(95, 158, 140), M.CorrodedMetal },
	Timber = { RGB(90, 62, 44), M.WoodPlanks },
	RoofMetal = { RGB(53, 56, 64), M.Metal },
	SnowCap = { RGB(238, 243, 247), M.Snow },
	Glow = { RGB(225, 140, 60), M.Neon },
	Core = { RGB(255, 55, 75), M.Neon },
	Soot = { RGB(43, 42, 44), M.Slate },
	Char = { RGB(31, 27, 26), M.Wood },
	Canvas = { RGB(203, 190, 158), M.Fabric },
	Banner = { RGB(124, 43, 46), M.Fabric },
	Wood = { RGB(138, 90, 54), M.Wood },
	Glass = { RGB(200, 225, 235), M.Glass },
	Leather = { RGB(74, 46, 36), M.Leather },
	Vent = { RGB(255, 255, 255), M.SmoothPlastic },
	SignBlue = { RGB(58, 95, 168), M.SmoothPlastic },
	SignGold = { RGB(201, 162, 58), M.SmoothPlastic },
	SignTeal = { RGB(62, 156, 147), M.SmoothPlastic },
	SignRed = { RGB(168, 58, 58), M.SmoothPlastic },
	SignPurple = { RGB(107, 74, 160), M.SmoothPlastic },
	Dial = { RGB(242, 232, 200), M.SmoothPlastic },
	Marble = { RGB(225, 225, 228), M.Marble },
	DarkStone = { RGB(40, 40, 44), M.Slate },
	Felt = { RGB(46, 107, 69), M.Fabric },
	GlowTeal = { RGB(79, 224, 200), M.Neon },
	Paint = { RGB(230, 226, 214), M.SmoothPlastic },
	WinGlass = { RGB(191, 217, 230), M.Glass },
	LampPt = { RGB(255, 255, 255), M.SmoothPlastic },
	DarkLog = { RGB(59, 42, 31), M.Wood }, -- 3판 새 재질(통나무 짙은 색)
}
local HULL = { RoofMetal = true, SnowCap = true, Canvas = true }
local NOCOLLIDE = { Glow = true, Core = true, Banner = true, Vent = true, LampPt = true, GlowTeal = true }

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local function skin(p, key)
	local s = SKIN[key]
	if not s then
		say("모르는 재질 %s (Timber 로 대신) — %s", key, p.Name)
		key = "Timber"
		s = SKIN.Timber
	end
	p.Color = s[1]
	p.Material = s[2]
	p.Anchored = true
	p.CanCollide = not NOCOLLIDE[key]
	p.CastShadow = not NOCOLLIDE[key]
	p.CollisionFidelity = HULL[key] and Enum.CollisionFidelity.Hull or Enum.CollisionFidelity.PreciseConvexDecomposition
	p.RenderFidelity = Enum.RenderFidelity.Precise
	if key == "Glass" then
		p.Transparency = 0.55
		p.CastShadow = false
	elseif key == "WinGlass" then
		p.Transparency = 0.78
		p.CastShadow = false
	end
	if key == "Vent" or key == "LampPt" then
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
	end
	if key == "Vent" then
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

local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true

local ok, err = pcall(function()
	local spec = HS:JSONDecode(HS:GetAsync("http://127.0.0.1:35001/tools/snow3_kit.json", true))
	for name in pairs(spec.new_materials or {}) do
		if not SKIN[name] then
			say("모르는 재질 %s (json new_materials — Timber 로 대신)", name)
		end
	end
	local PREFIX = {}
	for name, m in pairs(spec.models) do
		PREFIX[m.prefix] = name
	end

	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("SnowKit3")
	if not kit then
		kit = Instance.new("Folder")
		kit.Name = "SnowKit3"
		kit.Parent = SS
	end
	local imp = workspace:FindFirstChild("SnowTown3Kit")
	if imp then
		local marker = assert(imp:FindFirstChild("SnowTown3Origin_Marker", true), "원점 표지가 없다")
		local o = marker.Position
		say("표지 %.2f %.2f %.2f", o.X, o.Y, o.Z)
		local groups = {}
		for _, p in ipairs(imp:GetDescendants()) do
			if p:IsA("BasePart") and p ~= marker then
				local pre, key = p.Name:match("^([^_]+)_(.+)$")
				local name = pre and PREFIX[pre]
				if name then
					groups[name] = groups[name] or {}
					table.insert(groups[name], { p = p, key = key })
				else
					say("모르는 앞머리 %s (json 에 없음 — 건너뜀)", p.Name)
				end
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
				skin(e.p, e.key)
				e.p.Parent = m
			end
			m.WorldPivot = CFrame.new()
			m.Parent = kit
			n += 1
		end
		-- 건너뛴 메시가 남아 있으면 가져온 모델을 지우지 않는다
		local left = 0
		for _, p in ipairs(imp:GetDescendants()) do
			if p:IsA("BasePart") and p ~= marker then
				left += 1
			end
		end
		if left == 0 then
			imp:Destroy()
		else
			say("가져온 모델에 못 가른 메시 %d 개 — SnowTown3Kit 을 남겨 둔다", left)
		end
		say("새 틀 %d 종", n)
	else
		say("Workspace.SnowTown3Kit 이 없다 — 기존 틀 발자국만 잰다")
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
		local js = spec.models[name]
		if js then
			local d = math.max(
				math.abs(b[1] - js.base.x0), math.abs(b[2] - js.base.x1), math.abs(b[3] - js.base.z0), math.abs(b[4] - js.base.z1),
				math.abs(a[1] - js.all.x0), math.abs(a[2] - js.all.x1), math.abs(a[3] - js.all.z0), math.abs(a[4] - js.all.z1)
			)
			if d > 0.5 then
				say("발자국 차이 %s: json 과 최대 %.2f 다름", name, d)
			end
		else
			say("json 에 없는 틀 %s", name)
		end
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/snowtown3kit", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("snowtown3kit", #report, ok)
