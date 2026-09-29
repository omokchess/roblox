--!strict
--[[
	CombatVfx — 전투 이펙트 모음. (2026-09-28)

	맵 양식(블록)에 맞춰 **Neon 블록 조각**으로 짓는다. 빛번짐(Bloom)이 먹어 선명하게 빛난다.
	모든 이펙트는 한 곳(`Step`)에서 시간을 받는다 — 타격 정지(히트스톱) 때 연출 쪽이 dt 를 0 으로
	넘기면 이펙트도 같이 멈춘다(CombatDirector).

	쓰는 법: Vfx.Slash(cf, { Radius = 4, Arc = 150, Color = Color3... }) 처럼 부른다.
	각 함수의 cf/자리는 월드 기준이다. 모양 뜻은 함수 주석에.
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local CombatVfx = {}

type Effect = { T: number, D: number, Update: (alpha: number, dt: number) -> (), Cleanup: (() -> ())? }
local active: { Effect } = {}
local folder: Folder? = nil

-- 흔들림: 연출이 카메라에 더한다
CombatVfx.ShakeAmp = 0
local shakes: { { A: number, T: number, D: number } } = {}

local function root(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "CombatFx"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.CFrame = cf
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = root()
	return p
end

local function add(d: number, update: (number, number) -> (), cleanup: (() -> ())?)
	table.insert(active, { T = 0, D = math.max(0.01, d), Update = update, Cleanup = cleanup })
end

-- 매 프레임(연출이 부름). dt = 0 이면 멈춘다.
-- 연출기가 여럿(내 전투 + 관전)이어도 한 프레임에 한 번만 흐르게 한다(두 번 흐르면 효과가 두 배 빨라진다)
local lastStepAt = -1
function CombatVfx.Step(dt: number)
	local now = time()
	if now == lastStepAt then
		return
	end
	lastStepAt = now
	for i = #active, 1, -1 do
		local e = active[i]
		e.T += dt
		local alpha = math.min(1, e.T / e.D)
		e.Update(alpha, dt)
		if alpha >= 1 then
			table.remove(active, i)
			if e.Cleanup then
				e.Cleanup()
			end
		end
	end
	local amp = 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		s.T += dt
		if s.T >= s.D then
			table.remove(shakes, i)
		else
			amp = math.max(amp, s.A * (1 - s.T / s.D) ^ 2)
		end
	end
	CombatVfx.ShakeAmp = amp
end

function CombatVfx.Clear()
	for _, e in active do
		if e.Cleanup then
			e.Cleanup()
		end
	end
	active = {}
	shakes = {}
	if folder then
		folder:ClearAllChildren()
	end
end

local function fadeOut(x: number, start: number): number
	return math.clamp((x - start) / (1 - start), 0, 1)
end

--=== 화면 ===--

function CombatVfx.Shake(amplitude: number, duration: number?)
	table.insert(shakes, { A = amplitude, T = 0, D = duration or 0.3 })
end

--=== 칼날 궤적(초승달) ===--
--[[
	cf 의 오른쪽(X)·위(Y) 평면에 원호를 긋는다. 각도 0 = +X, 90 = +Y.
	From → To 로 빠르게 그어지고(Sweep 초), 가운데가 두껍고 끝이 가는 초승달 모양이 된다.
	opts: Radius, From, To(도), Width(두께), Depth(깊이), Color, Core(속색), Sweep, Life, Segments
]]
function CombatVfx.Slash(cf: CFrame, opts: { [string]: any })
	local r = opts.Radius or 4
	local a0, a1 = math.rad(opts.From or -60), math.rad(opts.To or 90)
	local n = opts.Segments or 16
	local width = opts.Width or 0.9
	local depth = opts.Depth or 0.14
	local color = opts.Color or Color3.fromRGB(230, 240, 255)
	local core = opts.Core or Color3.new(1, 1, 1)
	local sweep = opts.Sweep or 0.07
	local life = opts.Life or 0.32
	local segs = {}
	local step = (a1 - a0) / n
	local chord = 2 * r * math.sin(math.abs(step) / 2) + 0.12
	for i = 0, n - 1 do
		local a = a0 + step * (i + 0.5)
		local u = (i + 0.5) / n
		local thick = width * math.sin(u * math.pi) ^ 0.7 + 0.05
		local pos = cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
		local seg = pos * CFrame.Angles(0, 0, a + math.pi / 2)
		local outer = part(Vector3.new(chord, thick, depth), seg, color)
		local inner = part(Vector3.new(chord, thick * 0.45, depth * 1.4), seg * CFrame.new(0, -thick * 0.15, 0), core)
		outer.Transparency, inner.Transparency = 1, 1
		table.insert(segs, { outer, inner, u, thick, seg })
	end
	local total = sweep + life
	add(total, function(alpha)
		local t = alpha * total
		for _, s in segs do
			local shown = t >= sweep * s[3]
			local age = math.max(0, t - sweep * s[3]) / life
			local fade = if shown then math.clamp(age, 0, 1) else 1
			local grow = 1 - fade * 0.6
			s[1].Transparency = if shown then 0.05 + fade * 0.95 else 1
			s[2].Transparency = if shown then fade else 1
			s[1].Size = Vector3.new(s[1].Size.X, s[4] * grow, s[1].Size.Z)
			s[2].Size = Vector3.new(s[2].Size.X, s[4] * 0.45 * grow, s[2].Size.Z)
		end
	end, function()
		for _, s in segs do
			s[1]:Destroy()
			s[2]:Destroy()
		end
	end)
end

--=== 찌르기 줄기 ===--
-- from 에서 dir 쪽으로 길이 length 의 빛줄기가 튀어나갔다 사라진다. 끝에 작은 고리.
function CombatVfx.Thrust(from: Vector3, dir: Vector3, opts: { [string]: any })
	local length = opts.Length or 6
	local color = opts.Color or Color3.fromRGB(220, 235, 255)
	local width = opts.Width or 0.35
	local d = dir.Unit
	local base = CFrame.lookAt(from, from + d)
	local streak = part(Vector3.new(width, width, 0.1), base, color)
	local core = part(Vector3.new(width * 0.4, width * 0.4, 0.1), base, Color3.new(1, 1, 1))
	add(opts.Life or 0.28, function(alpha)
		local extend = math.min(1, alpha / 0.25)
		local len = length * (1 - (1 - extend) ^ 3)
		local thin = 1 - fadeOut(alpha, 0.3)
		streak.Size = Vector3.new(width * thin, width * thin, len)
		core.Size = Vector3.new(width * 0.4 * thin, width * 0.4 * thin, len * 1.02)
		streak.CFrame = base * CFrame.new(0, 0, -len / 2)
		core.CFrame = streak.CFrame
		streak.Transparency = fadeOut(alpha, 0.4)
		core.Transparency = fadeOut(alpha, 0.25)
	end, function()
		streak:Destroy()
		core:Destroy()
	end)
	CombatVfx.Ring(CFrame.lookAt(from + d * length, from + d * length * 2) * CFrame.Angles(0, 0, 0), { R0 = 0.3, R1 = 1.6, Color = color, Life = 0.25, Width = 0.18, Facing = true })
end

--=== 고리 ===--
--[[
	cf 의 XZ 평면(바닥에 눕힌 고리)에 원을 그리며 퍼진다. Facing=true 면 XY 평면(정면을 보는 고리).
	opts: R0, R1, Width, Height, Color, Life, Segments
]]
function CombatVfx.Ring(cf: CFrame, opts: { [string]: any })
	local n = opts.Segments or 18
	local color = opts.Color or Color3.new(1, 1, 1)
	local r0, r1 = opts.R0 or 0.5, opts.R1 or 5
	local w = opts.Width or 0.3
	local h = opts.Height or 0.15
	local facing = opts.Facing == true
	local segs = {}
	for _ = 1, n do
		table.insert(segs, part(Vector3.new(1, h, w), cf, color))
	end
	add(opts.Life or 0.45, function(alpha)
		local e = 1 - (1 - alpha) ^ 3
		local r = r0 + (r1 - r0) * e
		local chord = 2 * r * math.sin(math.pi / n) + 0.1
		for i, s in segs do
			local a = (i - 0.5) / n * math.pi * 2
			if facing then
				s.CFrame = cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a + math.pi / 2) * CFrame.Angles(math.pi / 2, 0, 0)
			else
				s.CFrame = cf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(0, -a + math.pi / 2, 0)
			end
			s.Size = Vector3.new(chord, h * (1 - alpha * 0.5), w * (1 - alpha * 0.6))
			s.Transparency = fadeOut(alpha, 0.35)
		end
	end, function()
		for _, s in segs do
			s:Destroy()
		end
	end)
end

--=== 충격파(납작한 원판) ===--
function CombatVfx.Shockwave(pos: Vector3, opts: { [string]: any })
	local color = opts.Color or Color3.fromRGB(255, 255, 255)
	local r1 = opts.Radius or 8
	local disc = part(Vector3.new(0.3, 1, 1), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.Transparency = 0.3
	add(opts.Life or 0.4, function(alpha)
		local e = 1 - (1 - alpha) ^ 4
		local d = r1 * 2 * e + 0.5
		disc.Size = Vector3.new(0.12 + 0.3 * (1 - alpha), d, d)
		disc.Transparency = 0.35 + 0.65 * alpha
	end, function()
		disc:Destroy()
	end)
	CombatVfx.Ring(CFrame.new(pos + Vector3.new(0, 0.1, 0)), { R0 = 0.5, R1 = r1 * 1.1, Color = color, Life = (opts.Life or 0.4) * 1.1, Width = 0.5, Height = 0.35 })
end

--=== 파편 튀기 ===--
--[[
	pos 에서 조각 count 개가 사방(또는 dir 쪽 원뿔)으로 튄다. 중력으로 떨어지며 줄어든다.
	opts: Count, Color, Size, Speed, Spread(원뿔 각, dir 있을 때), Dir, Gravity, Life, Material
]]
function CombatVfx.Burst(pos: Vector3, opts: { [string]: any })
	local count = opts.Count or 10
	local color = opts.Color or Color3.fromRGB(255, 240, 200)
	local size = opts.Size or 0.35
	local speed = opts.Speed or 22
	local gravity = opts.Gravity or 60
	local rng = Random.new()
	local bits = {}
	for _ = 1, count do
		local v: Vector3
		if opts.Dir then
			local d = (opts.Dir :: Vector3).Unit
			local spread = math.rad(opts.Spread or 45)
			local cf = CFrame.lookAt(Vector3.zero, d) * CFrame.Angles(rng:NextNumber(-spread, spread), rng:NextNumber(-spread, spread), 0)
			v = cf.LookVector * speed * rng:NextNumber(0.5, 1.1)
		else
			v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1.3), rng:NextNumber(-1, 1)).Unit * speed * rng:NextNumber(0.5, 1.1)
		end
		local s = size * rng:NextNumber(0.6, 1.4)
		local c = if opts.Colors then opts.Colors[rng:NextInteger(1, #opts.Colors)] else color
		local p = part(Vector3.new(s, s, s), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), c, opts.Material)
		table.insert(bits, { p, v, s, Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)) })
	end
	add(opts.Life or 0.6, function(alpha, dt)
		for _, b in bits do
			b[2] -= Vector3.new(0, gravity * dt, 0)
			b[1].CFrame = (b[1].CFrame + b[2] * dt) * CFrame.Angles(b[4].X * dt, b[4].Y * dt, b[4].Z * dt)
			local s = b[3] * (1 - alpha ^ 2)
			b[1].Size = Vector3.new(s, s, s)
			b[1].Transparency = fadeOut(alpha, 0.6)
		end
	end, function()
		for _, b in bits do
			b[1]:Destroy()
		end
	end)
end

--=== 빛 번쩍 ===--
-- 둥근 빛(glow.png)이 커지며 사라지고, 점광원이 잠깐 켜진다.
function CombatVfx.Flash(pos: Vector3, opts: { [string]: any })
	local color = opts.Color or Color3.new(1, 1, 1)
	local size = opts.Size or 8
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), color)
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Parent = anchor
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Image = "rbxasset://textures/glow.png"
	img.ImageColor3 = color
	img.Parent = bb
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 1.6
	light.Brightness = opts.Brightness or 4
	light.Shadows = false
	light.Parent = anchor
	add(opts.Life or 0.3, function(alpha)
		local s = 0.4 + alpha * 0.9
		img.Size = UDim2.fromScale(s, s)
		img.ImageTransparency = alpha
		light.Brightness = (opts.Brightness or 4) * (1 - alpha)
	end, function()
		anchor:Destroy()
	end)
end

--=== 불꽃 튐(입자) ===--
function CombatVfx.Sparks(pos: Vector3, opts: { [string]: any })
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.Texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(opts.Color or Color3.fromRGB(255, 230, 160))
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.Size or 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(0.25, opts.Lifetime or 0.55)
	e.Speed = NumberRange.new(opts.MinSpeed or 8, opts.Speed or 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Acceleration = opts.Accel or Vector3.new(0, -20, 0)
	e.Rate = 0
	e.Parent = anchor
	e:Emit(opts.Count or 18)
	Debris:AddItem(anchor, 1.2)
end

-- 연기·먼지(입자)
function CombatVfx.Dust(pos: Vector3, opts: { [string]: any })
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(opts.Color or Color3.fromRGB(170, 160, 140))
	e.LightInfluence = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, opts.Size or 1.4), NumberSequenceKeypoint.new(1, (opts.Size or 1.4) * 2.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(4, opts.Speed or 12)
	e.SpreadAngle = Vector2.new(180, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Drag = 5
	e.Rate = 0
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = anchor
	e:Emit(opts.Count or 14)
	Debris:AddItem(anchor, 1.5)
end

--=== 기둥(빛·물기둥) ===--
function CombatVfx.Pillar(pos: Vector3, opts: { [string]: any })
	local h = opts.Height or 14
	local w = opts.Width or 2.4
	local color = opts.Color or Color3.fromRGB(255, 240, 190)
	local p = part(Vector3.new(w, 0.1, w), CFrame.new(pos), color)
	local c = part(Vector3.new(w * 0.4, 0.1, w * 0.4), CFrame.new(pos), Color3.new(1, 1, 1))
	add(opts.Life or 0.5, function(alpha)
		local rise = math.min(1, alpha / 0.2)
		local hh = h * (1 - (1 - rise) ^ 3)
		local thin = 1 - fadeOut(alpha, 0.3)
		p.Size = Vector3.new(w * thin, hh, w * thin)
		c.Size = Vector3.new(w * 0.4 * thin, hh * 1.01, w * 0.4 * thin)
		p.CFrame = CFrame.new(pos + Vector3.new(0, hh / 2, 0))
		c.CFrame = p.CFrame
		p.Transparency = 0.15 + 0.85 * fadeOut(alpha, 0.35)
		c.Transparency = fadeOut(alpha, 0.2)
	end, function()
		p:Destroy()
		c:Destroy()
	end)
end

--=== 빔(두 점 사이) ===--
function CombatVfx.Beam(from: Vector3, to: Vector3, opts: { [string]: any })
	local color = opts.Color or Color3.fromRGB(120, 220, 255)
	local w = opts.Width or 1.2
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
	local outer = part(Vector3.new(w, w, len), cf, color)
	local core = part(Vector3.new(w * 0.4, w * 0.4, len), cf, Color3.new(1, 1, 1))
	add(opts.Life or 0.45, function(alpha)
		local pulse = 1 + math.sin(alpha * 40) * 0.12
		local thin = (1 - fadeOut(alpha, 0.55)) * pulse
		local open = math.min(1, alpha / 0.08)
		outer.Size = Vector3.new(w * thin * open, w * thin * open, len)
		core.Size = Vector3.new(w * 0.4 * thin, w * 0.4 * thin, len)
		outer.Transparency = 0.2 + 0.8 * fadeOut(alpha, 0.5)
		core.Transparency = fadeOut(alpha, 0.4)
	end, function()
		outer:Destroy()
		core:Destroy()
	end)
end

--=== 번개 ===--
function CombatVfx.Lightning(from: Vector3, to: Vector3, opts: { [string]: any })
	local color = opts.Color or Color3.fromRGB(150, 230, 255)
	local n = opts.Segments or 7
	local rng = Random.new()
	local points = { from }
	for i = 1, n - 1 do
		local p = from:Lerp(to, i / n) + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * (opts.Jitter or 1.2)
		table.insert(points, p)
	end
	table.insert(points, to)
	local segs = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		table.insert(segs, part(Vector3.new(0.18, 0.18, len), CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2), color))
	end
	add(opts.Life or 0.22, function(alpha)
		for _, s in segs do
			s.Transparency = if alpha > 0.5 and math.random() < 0.3 then 1 else alpha
		end
	end, function()
		for _, s in segs do
			s:Destroy()
		end
	end)
end

--=== 날아가는 것 ===--
--[[
	from → to 로 time 초에 날아간다. Arc 만큼 포물선으로 뜬다. build() 가 날아갈 모델(파트 하나 또는 Model)을 만든다.
	onArrive 는 도착 순간에 부른다(깨짐·폭발 이펙트).
]]
function CombatVfx.Projectile(from: Vector3, to: Vector3, opts: { [string]: any })
	local time = opts.Time or 0.35
	local arc = opts.Arc or 0
	local spin = opts.Spin or 0
	local object: any = if opts.Build then opts.Build() else part(Vector3.new(0.6, 0.6, 0.6), CFrame.new(from), opts.Color or Color3.new(1, 1, 1))
	if typeof(object) == "Instance" and not object.Parent then
		object.Parent = root()
	end
	add(time, function(alpha)
		local p = from:Lerp(to, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * arc, 0)
		local ahead = from:Lerp(to, math.min(1, alpha + 0.05)) + Vector3.new(0, math.sin(math.min(1, alpha + 0.05) * math.pi) * arc, 0)
		local cf = CFrame.lookAt(p, ahead + Vector3.new(0, 1e-3, 0)) * CFrame.Angles(0, 0, spin * alpha * math.pi * 2)
		if object:IsA("Model") then
			object:PivotTo(cf)
		else
			object.CFrame = cf
		end
		if opts.TrailColor and math.random() < 0.7 then
			local t = part(Vector3.new(0.25, 0.25, 0.25), CFrame.new(p), opts.TrailColor)
			TweenService:Create(t, TweenInfo.new(0.25), { Size = Vector3.new(0.02, 0.02, 0.02), Transparency = 1 }):Play()
			Debris:AddItem(t, 0.3)
		end
	end, function()
		object:Destroy()
		if opts.OnArrive then
			opts.OnArrive(to)
		end
	end)
end

--=== 음표(음악가) ===--
function CombatVfx.Notes(pos: Vector3, opts: { [string]: any })
	local glyphs = { "♪", "♫", "♬", "♩" }
	local rng = Random.new()
	for i = 1, opts.Count or 5 do
		local anchor = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)) * (opts.Spread or 1.5)), Color3.new(1, 1, 1))
		anchor.Transparency = 1
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(1.6, 1.6)
		bb.LightInfluence = 0
		bb.Parent = anchor
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = glyphs[rng:NextInteger(1, #glyphs)]
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = opts.Color or Color3.fromRGB(255, 214, 110)
		t.TextStrokeTransparency = 0.4
		t.TextStrokeColor3 = Color3.fromRGB(90, 60, 10)
		t.Parent = bb
		local start = anchor.Position
		local drift = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(2, 4), rng:NextNumber(-1, 1)) * (opts.Rise or 1)
		local delay = (i - 1) * (opts.Stagger or 0.04)
		add((opts.Life or 0.9) + delay, function(alpha, _)
			local a = math.clamp((alpha * ((opts.Life or 0.9) + delay) - delay) / (opts.Life or 0.9), 0, 1)
			anchor.CFrame = CFrame.new(start + drift * (1 - (1 - a) ^ 2))
			t.TextTransparency = if a <= 0 then 1 else fadeOut(a, 0.55)
			t.TextStrokeTransparency = if a <= 0 then 1 else 0.4 + 0.6 * fadeOut(a, 0.55)
			t.Rotation = math.sin(a * 12) * 18
		end, function()
			anchor:Destroy()
		end)
	end
end

--=== 모여드는 것(중력·기 모으기) ===--
function CombatVfx.Implode(pos: Vector3, opts: { [string]: any })
	local rng = Random.new()
	local color = opts.Color or Color3.fromRGB(160, 120, 255)
	local r = opts.Radius or 7
	local bits = {}
	for _ = 1, opts.Count or 14 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 1), rng:NextNumber(-1, 1)).Unit
		local s = rng:NextNumber(0.2, 0.45)
		local p = part(Vector3.new(s, s, s * 3), CFrame.lookAt(pos + dir * r, pos), color)
		table.insert(bits, { p, dir, s, rng:NextNumber(0, 0.3) })
	end
	local life = opts.Life or 0.6
	add(life, function(alpha)
		for _, b in bits do
			local a = math.clamp((alpha - b[4]) / (1 - b[4]), 0, 1)
			local d = r * (1 - a ^ 2)
			b[1].CFrame = CFrame.lookAt(pos + b[2] * d, pos) * CFrame.new(0, 0, 0)
			b[1].Transparency = if a <= 0 then 1 else fadeOut(a, 0.8)
		end
	end, function()
		for _, b in bits do
			b[1]:Destroy()
		end
	end)
end

--=== 피해 숫자 ===--
function CombatVfx.Number(pos: Vector3, text: string, opts: { [string]: any })
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 70)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = opts.Color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = opts.Stroke or Color3.fromRGB(30, 20, 20)
	label.TextStrokeTransparency = 0
	label.Parent = bb
	local rng = Random.new()
	local drift = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, 0)
	local big = opts.Big == true
	add(opts.Life or 0.9, function(alpha)
		-- 튀어 올라 커졌다가 살짝 줄고, 위로 뜨며 사라진다
		local pop = if alpha < 0.12 then (alpha / 0.12) * (if big then 1.5 else 1.25) else (if big then 1.5 else 1.25) - math.min(1, (alpha - 0.12) / 0.15) * (if big then 0.4 else 0.25)
		label.Size = UDim2.fromScale(pop, pop)
		anchor.CFrame = CFrame.new(pos + drift * alpha + Vector3.new(0, 2.4 * (1 - (1 - alpha) ^ 2), 0))
		label.TextTransparency = fadeOut(alpha, 0.7)
		label.TextStrokeTransparency = fadeOut(alpha, 0.7)
	end, function()
		anchor:Destroy()
	end)
end

--=== 맞은 몸 번쩍 ===--
function CombatVfx.HitFlash(model: Instance, opts: { [string]: any }?)
	local o = opts or {}
	local h = Instance.new("Highlight")
	h.FillColor = o.Color or Color3.new(1, 1, 1)
	h.OutlineColor = o.Color or Color3.new(1, 1, 1)
	h.FillTransparency = 0.15
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	add(o.Life or 0.16, function(alpha)
		h.FillTransparency = 0.15 + 0.85 * alpha
		h.OutlineTransparency = alpha
	end, function()
		h:Destroy()
	end)
end

-- 잠깐 떠 있는 조각(돌벽·방패 같은 것): cf 에서 솟아 hold 동안 있다가 가라앉는다
function CombatVfx.Block(cf: CFrame, size: Vector3, opts: { [string]: any })
	local p = part(size, cf * CFrame.new(0, -size.Y, 0), opts.Color or Color3.fromRGB(150, 145, 135), opts.Material or Enum.Material.Slate)
	p.Transparency = 0
	local rise, hold = opts.Rise or 0.18, opts.Hold or 0.6
	local total = rise + hold + 0.25
	add(total, function(alpha)
		local t = alpha * total
		local y = 0
		if t < rise then
			-- 땅속에서 솟는다
			y = -size.Y * (1 - t / rise) ^ 3
		elseif t >= rise + hold then
			-- 가라앉으며 사라진다
			local a = (t - rise - hold) / 0.25
			y = -size.Y * a
			p.Transparency = a
		end
		p.CFrame = cf * CFrame.new(0, y, 0)
	end, function()
		p:Destroy()
	end)
end

-- 이 모듈 밖에서 부품이 필요할 때(무기 복제 날리기 등)
CombatVfx.Part = part
CombatVfx.Folder = root

return CombatVfx
