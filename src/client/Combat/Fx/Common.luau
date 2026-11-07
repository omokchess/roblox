--!strict
--[[
	Fx/Common — 직업 이펙트가 같이 쓰는 조합과 기본 타격. (2026-09-28)

	이펙트 함수 모양: function(ctx, ev, at: Vector3?)
	  ctx.Vfx      CombatVfx
	  ctx.Root     시전자 HumanoidRootPart CFrame (앞 = LookVector)
	  ctx.Forward  적 쪽 방향(수평 단위 벡터)
	  ctx.Tip(slot?) / ctx.Base(slot?)   무기 끝·밑동 월드 자리(slot 기본 "W")
	  ctx.Hand(side?)  손 자리("R"/"L")
	  ctx.Target   첫 대상 가슴 높이 자리(없으면 앞 6칸)
	  ctx.Targets  이번 타격 대상들 자리
	  ctx.Ground   시전자 발밑 높이(y)
	  ctx.Weapons  CombatWeapons(오브 대형·병 숨기기 등)
	  ctx.Actor    시전자 배우(Model·Home·Pos …)
	  ctx.Shot(초, fn)  컷신 카메라 — fn(진행도 0~1, 지난 초) → 카메라 CFrame. Shot() 이면 전투 카메라로 돌려준다
	  ctx.Sound(id, 크기?, 빠르기?)  효과음 한 번(관전 화면에선 소리 없음)
	at 은 Hit 사건일 때 맞은 대상 자리다.
]]
local CombatRig = require(script.Parent.Parent.CombatRig)
local CombatVfx = require(script.Parent.Parent.CombatVfx)

local Common = {}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
Common.c = c

--[[
	ctx.Vfx 를 k 배로 키운 것으로 감싼다(크기·반지름·굵기 옵션만). 쓰는 곳:
	  디버그 보스 페이즈(Fx/Debug), 단계 스킬(CombatDirector — 특이점·붕괴·분쇄·크레셴도의 단계, 2026-10-03)
]]
local SCALE_KEYS = { "Size", "Radius", "R0", "R1", "Width", "Height" }
function Common.ScaledVfx(Vfx: any, k: number): any
	if k == 1 then
		return Vfx
	end
	return setmetatable({}, {
		__index = function(_, name)
			local f = Vfx[name]
			if type(f) ~= "function" then
				return f
			end
			return function(...)
				local args = table.pack(...)
				for i = 1, args.n do
					local a = args[i]
					if type(a) == "table" and (a.Size or a.Radius or a.R1 or a.Width or a.Height) then
						local opts = table.clone(a)
						for _, key in SCALE_KEYS do
							if type(opts[key]) == "number" then
								opts[key] *= k
							end
						end
						args[i] = opts
					end
				end
				return f(table.unpack(args, 1, args.n))
			end
		end,
	})
end

--[[
	2026-11-06 팩 묶음·플립북(ctx.Vfx.Pack / ctx.Vfx.Flipbook) — 크기는 Size 키로 줘서 ScaledVfx 가 같이 키운다.
	쓴 팩: Anime/Slash-Impact-01 · Anime/Blood-Punch-01 · Anime/Shield-01 · Anime/Crack-01 · Loose/Sparkles
	쓴 플립북(Grid4x4): Loose/Flash-3 rbxassetid://11372587580(번쩍) · Anime/Blood-Punch-01 Blood1 16668936898(피)
]]
local FLASH = "rbxassetid://11372587580"
local BLOOD_FLIP = "rbxassetid://16668936898"

local function fade(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, (a + b) / 2), NumberSequenceKeypoint.new(1, b) })
end

Common.BLOOD = { c(170, 16, 24), c(120, 8, 16), c(210, 40, 40) }

-- 피 튀김(dir 쪽 원뿔)
function Common.Blood(Vfx: any, at: Vector3, dir: Vector3?, count: number?, speed: number?)
	Vfx.Burst(at, { Count = count or 10, Colors = Common.BLOOD, Size = 0.28, Speed = speed or 18, Dir = dir, Spread = 55, Gravity = 70, Life = 0.7, Material = Enum.Material.SmoothPlastic })
	-- 팩 피 튀김 + 피 안개 플립북(번지는 붉은 막)
	local n = math.clamp((count or 10) / 10, 0.4, 3)
	Vfx.Pack("Anime/Blood-Punch-01", CFrame.new(at), { Size = 0.6 * n, Count = 0.5 })
	Vfx.Flipbook(at, { Texture = BLOOD_FLIP, Layout = "Grid4x4", Size = 3.2 * n, Life = 0.5, Color = c(170, 16, 24), Rotation = 180, Transparency = fade(0.15, 1) })
end

-- 기본 타격: 번쩍 + 조각 + 불꽃
function Common.Impact(Vfx: any, at: Vector3, color: Color3?, size: number?)
	local s = size or 1
	Vfx.Flash(at, { Color = color or Color3.new(1, 1, 1), Size = 7 * s, Life = 0.22 })
	Vfx.Burst(at, { Count = math.floor(8 * s), Color = color or c(255, 244, 220), Size = 0.3 * s, Speed = 20 * s, Life = 0.45 })
	Vfx.Sparks(at, { Color = color, Count = math.floor(14 * s) })
	-- 팩 베기 충격 + 번쩍 플립북(가운데 흰빛이 한 번 터진다)
	Vfx.Pack("Anime/Slash-Impact-01", CFrame.new(at), { Size = 0.7 * s, Tint = color, Count = 0.5 })
	Vfx.Flipbook(at, { Texture = FLASH, Layout = "Grid4x4", Size = 5 * s, Life = 0.3, Color = color or Color3.new(1, 1, 1), LightEmission = 0.8, Rotation = 180, Transparency = fade(0.2, 1) })
end

-- 땅 먼지 + 바닥 고리
function Common.Land(Vfx: any, ground: Vector3, size: number?, color: Color3?)
	local s = size or 1
	Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.15, 0)), { R0 = 0.6, R1 = 4 * s, Color = color or c(230, 225, 210), Life = 0.35, Width = 0.25, Height = 0.08 })
end

-- 명상: 발밑 고리 + 떠오르는 빛가루
function Common.Meditate(Vfx: any, ground: Vector3, color: Color3)
	Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.12, 0)), { R0 = 3.5, R1 = 1.2, Color = color, Life = 1.1, Width = 0.18, Height = 0.06 })
	Vfx.Sparks(ground + Vector3.new(0, 0.5, 0), { Color = color, Count = 16, MinSpeed = 2, Speed = 5, Accel = Vector3.new(0, 6, 0), Lifetime = 1.2, Size = 0.35 })
	Vfx.Pack("Loose/Sparkles", CFrame.new(ground + Vector3.new(0, 0.8, 0)), { Size = 1.2, Tint = color })
end

-- 가드: 발밑 고리 + 앞쪽 세로 고리
function Common.GuardRing(Vfx: any, ctx: any, color: Color3)
	Vfx.Ring(CFrame.new(Vector3.new(ctx.Root.Position.X, ctx.Ground + 0.15, ctx.Root.Position.Z)), { R0 = 1, R1 = 3.4, Color = color, Life = 0.5, Width = 0.3, Height = 0.1 })
	local front = ctx.Root.Position + ctx.Forward * 1.6
	Vfx.Ring(CFrame.lookAt(front, front + ctx.Forward), { R0 = 0.4, R1 = 2.4, Color = color, Life = 0.4, Width = 0.2, Facing = true })
	-- 막기 불꽃: 앞쪽 방패 팩 + 번쩍 플립북
	local mid = front + Vector3.new(0, 1.2, 0)
	Vfx.Pack("Anime/Shield-01", CFrame.lookAt(mid, mid + ctx.Forward), { Size = 0.7, Tint = color })
	Vfx.Flipbook(mid, { Texture = FLASH, Layout = "Grid4x4", Size = 4, Life = 0.3, Color = color, LightEmission = 0.8, Rotation = 180, Transparency = fade(0.25, 1) })
end

--[[
	칼 궤적 원호. center 를 중심으로 forward(적 쪽)와 "위" 가 이루는 판에 긋는다.
	tilt = 판을 앞 축으로 기울인 각(0 = 세로로 내려치기, 90 = 가로베기, 45 = 대각)
	from/to = 판 안의 각(0 = 앞, 90 = 위, 180 = 뒤, -90 = 아래)
]]
function Common.Arc(ctx: any, center: Vector3, tilt: number, from: number, to: number, opts: { [string]: any }?)
	local o = table.clone(opts or {})
	local fwd = ctx.Forward
	local up = (CFrame.fromAxisAngle(fwd, math.rad(tilt)) * Vector3.new(0, 1, 0)).Unit
	o.From, o.To = from, to
	ctx.Vfx.Slash(CFrame.fromMatrix(center, fwd, up), o)
end

-- 음표 탄환: 빛나는 조각에 음표 글자가 붙어 날아간다
function Common.NoteBolt(Vfx: any, from: Vector3, to: Vector3, time: number, color: Color3, arc: number?)
	Vfx.Projectile(from, to, {
		Time = time,
		Arc = arc or 0.8,
		TrailColor = color,
		Build = function()
			local p = Vfx.Part(Vector3.new(0.45, 0.45, 0.45), CFrame.new(from), color)
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(2, 2)
			bb.LightInfluence = 0
			bb.Parent = p
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = if math.random() < 0.5 then "♪" else "♫"
			t.TextScaled = true
			t.Font = Enum.Font.GothamBlack
			t.TextColor3 = color
			t.TextStrokeTransparency = 0.3
			t.Parent = bb
			return p
		end,
	})
end

-- 땅 위에 번지는 금(from 에서 dir 쪽으로 length 만큼, 지그재그 조각)
function Common.Crack(Vfx: any, from: Vector3, dir: Vector3, length: number, color: Color3, life: number?)
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = d:Cross(Vector3.new(0, 1, 0))
	local rng = Random.new()
	local p = from
	local n = math.max(3, math.floor(length / 1.4))
	for i = 1, n do
		local q = from + d * (length * i / n) + side * rng:NextNumber(-0.7, 0.7)
		local len = (q - p).Magnitude
		local seg = Vfx.Part(Vector3.new(0.22, 0.08, len), CFrame.lookAt(p, q) * CFrame.new(0, 0, -len / 2), color)
		task.delay(life or 0.9, function()
			seg:Destroy()
		end)
		p = q
	end
end

-- 돌 조각 튀기
function Common.Rubble(Vfx: any, at: Vector3, count: number?, color: Color3?)
	Vfx.Burst(at, { Count = count or 10, Colors = { color or Color3.fromRGB(150, 140, 125), Color3.fromRGB(110, 102, 92), Color3.fromRGB(180, 172, 158) }, Size = 0.55, Speed = 20, Gravity = 70, Life = 0.9, Material = Enum.Material.Slate })
end

--[[
	별 레이저 문법 공용(2026-11-07 — 조율자 셉텐트리오네스 · 칼리스토 북두칠성이 같이 쓴다). 조율자의 값이 기본이다.
	easing: Common.sine · expoOut(급가속 뒤 급정지) · quadIn(서서히 붙는 가속)
	Common.SeptLaser(ctx, top, g, size, grow, life, pal?)  별(top() 이 돌려주는 자리, 매 프레임 읽음)에서 바닥 g 로 grow 초에 뻗어 life 초 머물다 가늘어지는 겹 레이저.
	  뻗는 동안 빛고리 셋이 줄기를 감고, 닿으면 번쩍 · 충격파 · 파편. size = 굵기 배.
	  pal = { Layers = { { 색, 굵기, 투명도 }, ... }, Ring, Flash, Shock, Burst = { 색들 } }
	Common.SeptScar(a, b, pal?, total?)  두 점 사이 바닥에 선 자국이 타오르고(0.3초) total(기본 5)초 동안 남았다 사라진다. pal = { Core, Glow }
]]
function Common.sine(x: number): number
	return -(math.cos(math.pi * math.clamp(x, 0, 1)) - 1) / 2
end
function Common.expoOut(x: number): number
	x = math.clamp(x, 0, 1)
	return if x >= 1 then 1 else 1 - 2 ^ (-10 * x)
end
function Common.quadIn(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x
end

local SEPT_PAL = {
	Layers = { { c(110, 180, 255), 1.4, 0.55 }, { c(190, 214, 255), 0.7, 0.3 }, { c(255, 250, 235), 0.26, 0 } },
	Ring = c(190, 214, 255),
	Flash = c(255, 250, 235),
	Shock = c(110, 180, 255),
	Burst = { c(110, 180, 255), c(255, 250, 235) },
	Core = c(255, 250, 235),
	Glow = c(110, 180, 255),
}
function Common.SeptLaser(ctx: any, top: () -> Vector3, g: Vector3, size: number, grow: number, life: number, pal: { [string]: any }?)
	local p = pal or SEPT_PAL
	local layers = p.Layers or SEPT_PAL.Layers
	local parts: { Part } = {}
	for k, layer in layers do
		parts[k] = CombatVfx.Part(Vector3.new(0.1, 0.1, 0.05), CFrame.new(g), layer[1])
		parts[k].Transparency = 1
	end
	CombatVfx.Timed(grow + life, function(t)
		local a = t * (grow + life)
		local from = top()
		local head = from:Lerp(g, math.min(1, a / grow))
		local len = math.max(0.05, (head - from).Magnitude)
		local cf = CFrame.lookAt(from, if len > 0.06 then head else from - Vector3.new(0, 0.1, 0), ctx.Forward) * CFrame.new(0, 0, -len / 2)
		local fd = math.clamp((a - grow) / life, 0, 1)
		local w = size * (1 - fd) ^ 2 * (1 + 0.15 * math.sin(a * 50)) -- 꼬리는 제곱으로 날카롭게 끊긴다
		for k, layer in layers do
			local d = 0.03 + layer[2] * w
			parts[k].Size, parts[k].CFrame = Vector3.new(d, d, len), cf
			parts[k].Transparency = layer[3] + (1 - layer[3]) * fd
		end
	end, function()
		for _, part in parts do
			part:Destroy()
		end
	end)
	for k = 1, 3 do
		task.delay(grow * k / 3, function()
			local from = top()
			local at = from:Lerp(g, k / 3)
			ctx.Vfx.Ring(CFrame.lookAt(at, at + (g - from).Unit, ctx.Forward), {
				R0 = 0.4 * size,
				R1 = 2.2 * size,
				Color = p.Ring or SEPT_PAL.Ring,
				Life = 0.2,
				Width = 0.1 * size,
				Facing = true,
				Segments = 16,
			})
		end)
	end
	task.delay(grow, function()
		ctx.Vfx.Flash(g, { Color = p.Flash or SEPT_PAL.Flash, Size = 6 * size, Life = 0.2, Brightness = 6 })
		ctx.Vfx.Shockwave(Vector3.new(g.X, ctx.Ground + 0.1, g.Z), { Color = p.Shock or SEPT_PAL.Shock, Radius = 5 * size, Life = 0.3 })
		ctx.Vfx.Burst(g, { Count = 8, Colors = p.Burst or SEPT_PAL.Burst, Size = 0.2, Speed = 14, Gravity = 20, Life = 0.5 })
	end)
end

function Common.SeptScar(a: Vector3, b: Vector3, pal: { [string]: any }?, total: number?)
	local p = pal or SEPT_PAL
	local len = math.max(0.05, (b - a).Magnitude)
	local cf = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
	local core = CombatVfx.Part(Vector3.new(0.5, 0.06, len), cf, p.Core or SEPT_PAL.Core)
	local glow = CombatVfx.Part(Vector3.new(1.6, 0.05, len), cf, p.Glow or SEPT_PAL.Glow)
	local TOTAL = total or 5
	local fadeFrom = TOTAL - 1.2
	CombatVfx.Timed(TOTAL, function(t)
		local a2 = t * TOTAL
		local blaze = 1 - math.min(1, a2 / 0.3)
		local fd = math.clamp((a2 - fadeFrom) / 1.2, 0, 1)
		core.Size = Vector3.new(0.22 + 0.9 * blaze, 0.06, len)
		glow.Size = Vector3.new(0.9 + 2.4 * blaze, 0.05, len)
		core.Transparency = 0.15 + 0.85 * fd
		glow.Transparency = 0.55 + 0.45 * fd - 0.4 * blaze
	end, function()
		core:Destroy()
		glow:Destroy()
	end)
end

--[[
	서포팅(버프 · 보호막 · 회복 · 도발 등 아군에게 거는) 이펙트가 그릴 자리: 실제로 효과를 받는 아군 캐릭터만. (2026-11-07 사용자)
	ctx.Allies = 효과를 받는 아군 Actor 목록(시전자 포함 가능 — 각 Actor 는 .Pos(HumanoidRootPart CFrame) · .Ground(발밑까지 높이))을 CombatDirector 가 넘겨주면 그들을,
	없으면(아직 안 넘겨줌 · 솔로 전투) 시전자 자신만 돌려준다. 칸 전체(AllyTiles)에 찍지 않는다.
	돌려주는 것: { { Pos = 몸 가운데, Ground = 발밑 y } }
]]
function Common.Recipients(ctx: any): { { Pos: Vector3, Ground: number } }
	local out = {}
	for _, a in ctx.Allies or {} do
		if a.Pos then
			table.insert(out, { Pos = a.Pos.Position, Ground = a.Pos.Position.Y + (a.Ground or -3) })
		end
	end
	if #out == 0 then
		table.insert(out, { Pos = ctx.Root.Position, Ground = ctx.Ground })
	end
	return out
end

function Common.Head(ctx: any): Vector3
	return ctx.Root.Position + Vector3.new(0, 1.6, 0)
end

function Common.Feet(ctx: any): Vector3
	return Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z)
end

--[[
	필드 상자(전투 공간의 앞 u · 옆 v · 높이 y). 적 진영 칸(ctx.EnemyTiles — 전투 화면이 넘겨준다)의 가운데들에서 u·v 범위를 잡고
	칸 반 칸만큼 넓힌다. 칸을 모르면(전시장) 첫 대상을 첫 열 가운데로 6×3 칸을 어림한다.
	돌려주는 것: { Base, F, R, U0, U1, V0, V1, Y0, Y1 } — 월드 점 = Base + F·u + R·v + (0, y, 0)
]]
local PITCH = 6
function Common.FieldBox(ctx: any): any
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local home = ctx.Actor.Home.Position
	local base = Vector3.new(home.X, ctx.Ground, home.Z)
	local centers = {}
	if ctx.EnemyTiles and #ctx.EnemyTiles > 0 then
		for _, t in ctx.EnemyTiles do
			table.insert(centers, t.Position)
		end
	else
		local t0 = ctx.Targets[1] or ctx.Target
		for x = 0, 5 do
			for y = -1, 1 do
				table.insert(centers, t0 + f * (x * PITCH) + r * (y * PITCH))
			end
		end
	end
	local u0, u1, v0, v1 = math.huge, -math.huge, math.huge, -math.huge
	for _, center in centers do
		local d = center - base
		u0, u1 = math.min(u0, d:Dot(f)), math.max(u1, d:Dot(f))
		v0, v1 = math.min(v0, d:Dot(r)), math.max(v1, d:Dot(r))
	end
	local m = PITCH / 2 + 1
	return { Base = base, F = f, R = r, U0 = u0 - m, U1 = u1 + m, V0 = v0 - m, V1 = v1 + m, Y0 = 0.15, Y1 = 5 }
end

function Common.BoxWorld(box: any, l: Vector3): Vector3
	return box.Base + box.F * l.X + box.R * l.Y + Vector3.new(0, l.Z, 0)
end

-- 효과음 한 번(rbxassetid 숫자, 짧은 소리). 6초 뒤 지운다
function Common.Sound(id: number, volume: number?, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 6)
end

--[[
	잔상(분신) — 시전자 모델을 복제해 pose 자세로 cf(HumanoidRootPart 자리)에 세운 빛 몸. (2026-10-25 청의 검사)
	pose 는 모션 파일의 자세 표(Root·관절·W·O). 돌려주는 것: { Model, Vanish(초?) } — Vanish 하면 그 초에 걸쳐 사라진다.
	opts: Color, Transparency(보일 때, 기본 0.45), FadeIn(초), Life(안전장치 — 이 초가 지나면 저절로 사라진다, 기본 6)
	플레이어 캐릭터는 Archivable 이 꺼져 있어 잠깐 켜고 복제한다. 대본·소리·옷·얼굴·Humanoid 는 뺀다(관절 Motor6D 만 남는다).
]]
local STRIP = { "LuaSourceContainer", "Sound", "Decal", "Clothing", "ShirtGraphic", "Highlight", "ParticleEmitter", "Trail", "Beam", "Light", "SurfaceAppearance", "BillboardGui", "Humanoid", "BodyColors" }
function Common.Ghost(ctx: any, pose: any, cf: CFrame, opts: { [string]: any }?): any?
	local o = opts or {}
	local src = ctx.Actor and ctx.Actor.Model
	if not src then
		return nil
	end
	local was = src.Archivable
	src.Archivable = true
	local ok, model = pcall(function()
		return src:Clone()
	end)
	src.Archivable = was
	if not ok or not model then
		return nil
	end
	for _, d in model:GetDescendants() do
		for _, class in STRIP do
			if d:IsA(class) then
				d:Destroy()
				break
			end
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		model:Destroy()
		return nil
	end
	local color = o.Color or Color3.fromRGB(90, 170, 255)
	local parts: { { Part: BasePart, Base: number } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d == root
			d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = false, false, false, false
			d.Massless = true
			-- 숨긴 시전자(LocalTransparencyModifier)에서 복제해도 잔상은 보이게
			d.LocalTransparencyModifier = 0
			if d ~= root then
				d.Material = Enum.Material.Neon
				d.Color = color
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
				-- 원래 안 보이던 부품(무기 쥐는 점 등)은 그대로 안 보이게
				table.insert(parts, { Part = d, Base = math.max(o.Transparency or 0.45, d.Transparency) })
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
	root.Transparency = 1
	root.CFrame = cf
	local rig = CombatRig.new(model)
	for _, slot in { "W", "O" } do
		local m = model:FindFirstChild("CombatGrip" .. slot, true)
		if m and m:IsA("Motor6D") then
			rig:SetWeaponMotor(slot, m)
		end
	end
	rig:Apply(pose)
	local function fadeAll(k: number)
		for _, p in parts do
			p.Part.Transparency = p.Base + (1 - p.Base) * k
		end
	end
	fadeAll(1)
	model.Parent = CombatVfx.Folder()
	local ghost = { Model = model, Gone = false }
	CombatVfx.Timed(o.FadeIn or 0.08, function(a)
		if not ghost.Gone then
			fadeAll(1 - a)
		end
	end)
	function ghost.Vanish(d: number?)
		if ghost.Gone then
			return
		end
		ghost.Gone = true
		CombatVfx.Timed(d or 0.25, function(a)
			fadeAll(a)
		end, function()
			model:Destroy()
		end)
	end
	task.delay(o.Life or 6, function()
		ghost.Vanish(0.3)
	end)
	return ghost
end

return Common
