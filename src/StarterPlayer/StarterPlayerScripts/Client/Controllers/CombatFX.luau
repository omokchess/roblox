--!strict
-- 전투 연출 (클라이언트 전용)
--   타격 스파크/피 튀김, 떠오르는 피해 숫자, 패링 섬광, 무기 궤적, 적 공격 예고(빨간 발광 + 바닥 표시),
--   범위 공격 경고원 → 폭발, 투사체 로컬 시뮬레이션, 효과음

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MoveDefs = require(Shared.Combat.MoveDefs)
local StatusDefs = require(Shared.Combat.StatusDefs)
local SoundConfig = require(Shared.Combat.SoundConfig)
local CombatBus = require(script.Parent.CombatBus)
local UIKit = require(script.Parent.UIKit)

local CombatFX = {}

local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local folder: Folder
local projectiles: { [number]: { part: BasePart, pos: Vector3, vel: Vector3, def: MoveDefs.ProjectileDef, target: number?, born: number } } = {}
local areas: { [number]: { disc: BasePart, ring: BasePart, at: number, start: number, r: number } } = {}

local function anchoredPart(name: string, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = folder
	return p
end

local function sound(name: string, pos: Vector3?, parent: Instance?)
	local cfg = SoundConfig[name]
	if not cfg or cfg.Id == "" then
		return
	end
	local host: Instance
	if parent then
		host = parent
	elseif pos then
		host = anchoredPart("Snd", CFrame.new(pos), Vector3.one)
		Debris:AddItem(host, 3)
	else
		host = folder
	end
	local s = Instance.new("Sound")
	s.SoundId = cfg.Id
	s.Volume = cfg.Volume
	s.PlaybackSpeed = cfg.Speed * (0.93 + math.random() * 0.14)
	s.RollOffMaxDistance = 160
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.Parent = host
	s:Play()
	Debris:AddItem(s, 3)
end

local function burst(pos: Vector3, color: Color3, count: number, speed: number, size: number, texture: string?, lifetime: number?)
	local p = anchoredPart("Burst", CFrame.new(pos), Vector3.new(0.5, 0.5, 0.5))
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture or TEX_SPARK
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Rate = 0
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new((lifetime or 0.35) * 0.6, lifetime or 0.35)
	e.Drag = 6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	e:Emit(count)
	Debris:AddItem(p, 2)
end

local function ring(pos: Vector3, color: Color3, radius: number, duration: number, thickness: number?)
	local p = anchoredPart("Ring", CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(thickness or 0.2, 1, 1))
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.2
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(thickness or 0.2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, duration + 0.1)
end

local function flash(pos: Vector3, color: Color3, size: number)
	local p = anchoredPart("Flash", CFrame.new(pos), Vector3.new(size, size, size))
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 5
	light.Brightness = 3
	light.Parent = p
	TweenService:Create(p, TweenInfo.new(0.22), { Size = Vector3.new(size * 2.4, size * 2.4, size * 2.4), Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
	Debris:AddItem(p, 0.3)
end

-- ── 피해 숫자 ────────────────────────────────────────────
local function popup(pos: Vector3, text: string, color: Color3, scale: number, sub: string?)
	local p = anchoredPart("Popup", CFrame.new(pos + Vector3.new((math.random() - 0.5) * 2, 1.5, (math.random() - 0.5) * 2)), Vector3.one)
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(160 * scale, 60 * scale)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.MaxDistance = 140
	g.StudsOffset = Vector3.new(0, 0, 0)
	g.Parent = p
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, if sub then 0.65 else 1)
	l.Text = text
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.Parent = g
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = Color3.fromRGB(20, 12, 8)
	st.Parent = l
	if sub then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.62)
		s.Size = UDim2.fromScale(1, 0.38)
		s.Text = sub
		s.Font = Enum.Font.GothamBold
		s.TextScaled = true
		s.TextColor3 = color
		s.Parent = g
		local st2 = st:Clone()
		st2.Parent = s
	end
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.3
	uiScale.Parent = g
	TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = p.CFrame + Vector3.new(0, 3.5, 0) }):Play()
	task.delay(0.55, function()
		for _, d in g:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(p, 1.0)
end

-- ── 무기 궤적 ────────────────────────────────────────────
local function trailFor(model: Model?): Trail?
	local w = model and model:FindFirstChild("SwampWeapon")
	local anchor = w and w:FindFirstChild("Anchor")
	return anchor and anchor:FindFirstChild("SwingTrail") :: Trail?
end

local function swingTrail(model: Model?, move: MoveDefs.Move, offset: number)
	local trail = trailFor(model)
	if not trail then
		return
	end
	local startIn = math.max(0, move.Windup - 0.04 - offset)
	local duration = move.Active + 0.08
	task.delay(startIn, function()
		trail.Enabled = true
		task.delay(duration, function()
			trail.Enabled = false
		end)
	end)
end

-- ── 적 공격 예고 ─────────────────────────────────────────
local function telegraph(model: Model, move: MoveDefs.Move, aim: Vector3?, offset: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 60, 40)
	h.OutlineColor = Color3.fromRGB(255, 200, 120)
	h.FillTransparency = 1
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	local windup = math.max(0.1, move.Windup - offset)
	TweenService:Create(h, TweenInfo.new(windup, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { FillTransparency = 0.35 }):Play()
	Debris:AddItem(h, windup + 0.15)
	-- 바닥 표시
	local hb = move.Hitbox
	if not hb then
		return
	end
	local dir = aim or root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 0, -1)
	end
	local ground = root.Position - Vector3.new(0, (model:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight + root.Size.Y / 2 - 0.15, 0)
	local base = CFrame.lookAt(ground, ground + dir.Unit)
	local indicator: Part
	if hb.Shape == "Sphere" or hb.Shape == "Arc" then
		local r = (hb.Radius or hb.Range or 6)
		local off = hb.Offset or Vector3.zero
		local cf = base * CFrame.new(off.X, 0, off.Z) * CFrame.Angles(0, 0, math.rad(90))
		indicator = anchoredPart("Tele", cf, Vector3.new(0.12, r * 2, r * 2))
		indicator.Shape = Enum.PartType.Cylinder
	else
		local size = hb.Size or Vector3.new(hb.Width or 3, 1, hb.Length or 8)
		local off = hb.Offset or Vector3.new(0, 0, -size.Z / 2)
		if hb.Shape == "Line" then
			off = Vector3.new(0, 0, -(hb.Length or 8) / 2)
		end
		indicator = anchoredPart("Tele", base * CFrame.new(off.X, 0, off.Z), Vector3.new(size.X, 0.12, size.Z))
	end
	indicator.Material = Enum.Material.Neon
	indicator.Color = Color3.fromRGB(255, 70, 40)
	indicator.Transparency = 0.85
	TweenService:Create(indicator, TweenInfo.new(windup, Enum.EasingStyle.Linear), { Transparency = 0.55 }):Play()
	Debris:AddItem(indicator, windup + 0.1)
end

-- ── 범위 공격 ────────────────────────────────────────────
local AREA_COLORS: { [string]: Color3 } = {
	PoisonCloud = Color3.fromRGB(120, 230, 80),
	RootSpike = Color3.fromRGB(200, 90, 50),
}

local function areaStart(data: any)
	local pos = data.p :: Vector3
	local r = tonumber(data.r) or 6
	local color = AREA_COLORS[data.v] or Color3.fromRGB(255, 80, 60)
	local cf = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local ringPart = anchoredPart("AreaRing", cf, Vector3.new(0.1, r * 2, r * 2))
	ringPart.Shape = Enum.PartType.Cylinder
	ringPart.Material = Enum.Material.Neon
	ringPart.Color = color
	ringPart.Transparency = 0.75
	local disc = anchoredPart("AreaFill", cf * CFrame.new(0.02, 0, 0), Vector3.new(0.12, 0.2, 0.2))
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 0.45
	areas[data.id] = { disc = disc, ring = ringPart, at = tonumber(data.at) or 0, start = workspace:GetServerTimeNow(), r = r }
end

local function areaBoom(data: any)
	local a = areas[data.id]
	areas[data.id] = nil
	if a then
		a.disc:Destroy()
		a.ring:Destroy()
	end
	local pos = data.p :: Vector3
	local r = tonumber(data.r) or 6
	if data.v == "RootSpike" then
		for i = 1, 7 do
			local ang = i / 7 * math.pi * 2
			local off = Vector3.new(math.cos(ang), 0, math.sin(ang)) * r * 0.45 * math.random()
			local h = 4 + math.random() * 4
			local spike = anchoredPart("Spike", CFrame.new(pos + off - Vector3.new(0, h, 0)) * CFrame.Angles(math.rad(math.random(-15, 15)), 0, math.rad(math.random(-15, 15))), Vector3.new(1.2, h, 1.2))
			spike.Transparency = 0
			spike.Material = Enum.Material.Wood
			spike.Color = Color3.fromRGB(78, 62, 48)
			TweenService:Create(spike, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = spike.CFrame + Vector3.new(0, h * 0.9, 0) }):Play()
			task.delay(0.9, function()
				TweenService:Create(spike, TweenInfo.new(0.4), { CFrame = spike.CFrame - Vector3.new(0, h, 0) }):Play()
			end)
			Debris:AddItem(spike, 1.5)
		end
		burst(pos, Color3.fromRGB(120, 90, 60), 18, 20, 1.2, TEX_SMOKE, 0.6)
		sound("Slam", pos)
	else
		burst(pos + Vector3.new(0, 1, 0), AREA_COLORS[data.v] or Color3.new(1, 1, 1), 40, 16, 2.4, TEX_SMOKE, 1.2)
		burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(200, 255, 150), 20, 20, 0.6)
		ring(pos + Vector3.new(0, 0.3, 0), AREA_COLORS[data.v] or Color3.new(1, 1, 1), r, 0.4)
		sound("Splash", pos)
	end
end

-- ── 투사체 ───────────────────────────────────────────────
local function projStart(data: any)
	local def = MoveDefs.Projectiles[data.k]
	if not def then
		return
	end
	local part = anchoredPart("Proj", CFrame.new(data.o), Vector3.new(1, 1, 1))
	part.Transparency = 0
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.4, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.4, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = part
	if def.Visual == "PoisonOrb" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.8, 1.8, 1.8)
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(150, 255, 100)
		trail.Color = ColorSequence.new(Color3.fromRGB(150, 255, 100))
		local l = Instance.new("PointLight")
		l.Color = part.Color
		l.Range = 12
		l.Brightness = 2
		l.Parent = part
		sound("Cast", data.o)
	else
		part.Size = Vector3.new(0.35, 0.35, 7)
		part.Material = Enum.Material.Wood
		part.Color = Color3.fromRGB(150, 120, 90)
		trail.Color = ColorSequence.new(Color3.fromRGB(230, 230, 210))
		local tip = anchoredPart("Tip", part.CFrame, Vector3.new(0.5, 0.5, 1.2))
		tip.Transparency = 0
		tip.Material = Enum.Material.Metal
		tip.Color = Color3.fromRGB(180, 184, 190)
		tip.Parent = part
		sound("SwingHeavy", data.o)
	end
	projectiles[data.id] = { part = part, pos = data.o, vel = data.v, def = def, target = data.tg, born = tonumber(data.t) or 0 }
end

local function projEnd(data: any)
	local p = projectiles[data.id]
	projectiles[data.id] = nil
	if p then
		p.part:Destroy()
		if p.def.Visual == "PoisonOrb" then
			burst(data.p, Color3.fromRGB(140, 255, 90), 26, 14, 1.4, TEX_SMOKE, 0.8)
		else
			burst(data.p, Color3.fromRGB(230, 230, 210), 12, 18, 0.5)
		end
	end
end

local function stepProjectiles(dt: number)
	for _, p in projectiles do
		local def = p.def
		if def.Homing and p.target then
			local m = CombatBus.Model(p.target)
			local r = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local to = r.Position - p.pos
				if to.Magnitude > 1 then
					local speed = p.vel.Magnitude
					local cur = p.vel.Unit
					local want = to.Unit
					local ang = math.acos(math.clamp(cur:Dot(want), -1, 1))
					local f = if ang > 1e-4 then math.min(1, def.Homing * dt / ang) else 1
					p.vel = cur:Lerp(want, f).Unit * speed
				end
			end
		end
		p.vel -= Vector3.new(0, def.Gravity * dt, 0)
		p.pos += p.vel * dt
		if p.vel.Magnitude > 0.1 then
			p.part.CFrame = CFrame.lookAt(p.pos, p.pos + p.vel)
			local tip = p.part:FindFirstChild("Tip") :: BasePart?
			if tip then
				tip.CFrame = p.part.CFrame * CFrame.new(0, 0, -3.8)
			end
		end
		if workspace:GetServerTimeNow() - p.born > 4 then
			p.part:Destroy()
		end
	end
	local t = workspace:GetServerTimeNow()
	for _, a in areas do
		local k = math.clamp((t - a.start) / math.max(0.05, a.at - a.start), 0, 1)
		a.disc.Size = Vector3.new(0.12, a.r * 2 * k, a.r * 2 * k)
	end
end

-- ── 이벤트 처리 ──────────────────────────────────────────
local function modelPos(id: number?): Vector3?
	local m = CombatBus.Model(id)
	local r = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
	return r and r.Position
end

local function onEvent(kind: string, data: any, isLocal: boolean)
	if type(data) ~= "table" then
		return
	end
	if kind == "Action" then
		local move = MoveDefs.Moves[data.m]
		local model = CombatBus.Model(data.i)
		if not move or not model then
			return
		end
		if CombatBus.IsLocal(data.i) and not isLocal then
			return
		end
		local offset = if isLocal then 0 else math.clamp(workspace:GetServerTimeNow() - (data.t or 0), 0, 0.3)
		swingTrail(model, move, offset)
		if move.Hitbox and move.Damage > 0 then
			task.delay(math.max(0, move.Windup - 0.05 - offset), function()
				local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				sound(if move.Type == "Heavy" or move.Poise >= 40 then "SwingHeavy" else "Swing", nil, root)
			end)
		end
		if move.Telegraph and model:GetAttribute("EnemyType") then
			telegraph(model, move, data.d, offset)
		end
	elseif kind == "Hit" then
		local pos = (data.p :: Vector3?) or modelPos(data.v)
		if not pos then
			return
		end
		local victim = CombatBus.Model(data.v)
		local isEnemyVictim = victim ~= nil and victim:GetAttribute("EnemyType") ~= nil
		if data.b then
			burst(pos, Color3.fromRGB(255, 230, 160), 10, 22, 0.5)
			popup(pos, tostring(data.n), Color3.fromRGB(190, 190, 180), 0.7, "방어")
			sound("Block", pos)
			return
		end
		local color = if isEnemyVictim then Color3.fromRGB(255, 244, 220) else UIKit.Colors.Bad
		local scale = 0.9
		local sub: string? = nil
		if data.c then
			color = UIKit.Colors.Crit
			scale = 1.3
			sub = "치명타!"
		end
		if data.bk then
			sub = (if sub then sub .. " " else "") .. "백어택"
			scale += 0.1
		end
		if data.r then
			sub = "반격!"
			color = Color3.fromRGB(255, 214, 120)
			scale = 1.4
		end
		popup(pos, tostring(data.n), color, scale, sub)
		local blood = if isEnemyVictim then Color3.fromRGB(110, 180, 70) else Color3.fromRGB(190, 30, 30)
		burst(pos, Color3.fromRGB(255, 240, 200), 8, 26, 0.45)
		burst(pos, blood, 14, 16, 0.7, TEX_SMOKE, 0.5)
		sound(if (tonumber(data.hs) or 0) >= 0.09 then "HitHeavy" else "Hit", pos)
		if (tonumber(data.sh) or 0) >= 0.8 then
			ring(pos - Vector3.new(0, 2.5, 0), Color3.fromRGB(230, 210, 170), 12, 0.35)
		end
	elseif kind == "Tick" then
		local pos = modelPos(data.v)
		local def = StatusDefs[data.k or ""]
		if pos and def then
			popup(pos, tostring(data.n), def.Color, 0.6, nil)
		end
	elseif kind == "Burst" then
		local pos = modelPos(data.v)
		local def = StatusDefs[data.k or ""]
		if pos and def then
			popup(pos, tostring(data.n), def.Color, 1.2, def.Name .. "!")
			burst(pos, def.Color, 30, 22, 0.9, TEX_SMOKE, 0.6)
		end
	elseif kind == "Parry" then
		local pos = (data.p :: Vector3?) or modelPos(data.v)
		if pos then
			flash(pos, Color3.fromRGB(255, 240, 180), 2)
			ring(pos, Color3.fromRGB(255, 220, 140), 9, 0.3)
			burst(pos, Color3.fromRGB(255, 220, 140), 24, 34, 0.5)
			popup(pos, "패링!", Color3.fromRGB(255, 226, 130), 1.3, nil)
			sound("Parry", pos)
		end
	elseif kind == "GuardBreak" then
		local pos = (data.p :: Vector3?) or modelPos(data.v)
		if pos then
			popup(pos, "가드 브레이크!", UIKit.Colors.Bad, 1.1, nil)
			flash(pos, Color3.fromRGB(255, 120, 80), 1.6)
		end
	elseif kind == "Evade" then
		local pos = modelPos(data.v)
		if pos then
			popup(pos, "회피", Color3.fromRGB(170, 220, 255), 0.7, nil)
		end
	elseif kind == "Stagger" then
		if data.r == "Poise" then
			local pos = modelPos(data.i)
			if pos then
				popup(pos + Vector3.new(0, 2, 0), "경직!", Color3.fromRGB(255, 200, 90), 1, nil)
				ring(pos, Color3.fromRGB(255, 200, 90), 6, 0.3)
			end
		end
	elseif kind == "Dodge" then
		local pos = modelPos(data.i)
		if pos then
			burst(pos - Vector3.new(0, 2.5, 0), Color3.fromRGB(150, 140, 120), 10, 8, 1.4, TEX_SMOKE, 0.6)
			sound("Dodge", pos)
		end
	elseif kind == "Equip" then
		local m = CombatBus.Model(data.i)
		local root = m and m:FindFirstChild("HumanoidRootPart")
		if root then
			sound("Equip", nil, root)
		end
	elseif kind == "Died" then
		local m = CombatBus.Model(data.i)
		if m and m:GetAttribute("EnemyType") then
			local pos = modelPos(data.i)
			if pos then
				burst(pos, Color3.fromRGB(110, 170, 80), 30, 12, 1.8, TEX_SMOKE, 1.4)
				sound("Death", pos)
			end
			task.delay(2.4, function()
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and d.Transparency < 1 then
						TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
					end
				end
			end)
		end
	elseif kind == "Area" then
		areaStart(data)
	elseif kind == "AreaBoom" then
		areaBoom(data)
	elseif kind == "Proj" then
		projStart(data)
	elseif kind == "ProjEnd" then
		projEnd(data)
	end
end

function CombatFX.Start()
	local old = workspace:FindFirstChild("SwampFX")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "SwampFX"
	folder.Parent = workspace
	CombatBus.Subscribe(onEvent)
	RunService.PreRender:Connect(stepProjectiles)
end

return CombatFX
