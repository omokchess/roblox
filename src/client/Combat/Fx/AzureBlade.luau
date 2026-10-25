--!strict
--[[
	Fx/AzureBlade — 청의 검사 이펙트. 푸른 칼빛·흰 섬광·잔상·물·검로. (2026-10-25, 같은 날 사용자 말 설명으로 다시 짬)

	  진 발도술     천천히 뽑다(DrawGlint) 칼이 빠지는 순간(Release) 왼쪽 아래로 사선베기(KesaArc) →
	                몹 앞에 서로 다른 베기 자세의 잔상을 타격 수만큼(Ghosts) → 타격마다 잔상이 하나씩 사라지며 벤다(GhostCut)
	  발도술의 절정 반쯤 뽑다 "챙" 하고 멈춰 드러난 날에 빛(Ching) → 사라져(Vanish) 줄 끝에 이미 벤 자세로 서고,
	                지나간 자리에 불규칙한 곧은 검로(PeakPath) → 줄 전체를 가르는 곧은 칼날들이 반짝일 때마다 타격(RowFlash)
	  공간의 이해   컷신 — 물 위에 발을 올림(또옥: WaterStep · CamFoot) → 카메라가 오른쪽 위로 원을 그리며 느려진다(CamOrbit)
	                → 끝점에서 물 흐르듯 대상 사이를 지나며 검로 다섯(FlowMark · CamHold) → 등 검집에 꽂는 순간 한꺼번에 터진다
	                (FlowBurst · BurstHit) → 카메라를 돌려준다(CamFree)
	효과음: 로블록스 효과음 모음(ProSoundEffects). 챙 = 칼 뽑는 쇳소리, 또옥 = 물방울 — 바꾸려면 SOUND 의 숫자만 고친다.
	잔상 자세는 모션 파일의 Poses(tools/combat/design/azure_gen.py 가 만든다).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Common = require(script.Parent.Common)
local CombatVfx = require(script.Parent.Parent.CombatVfx)
local c = Common.c

local AZURE = c(90, 170, 255)
local ICE = c(200, 232, 255)
local WHITE = c(245, 250, 255)
local WATER = c(110, 190, 255)

local SOUND = { Ching = 9119742466, Drop = 9113358378 }

local Fx = {}

-- 잔상 자세(늦게 읽는다 — 모션 묶음은 처음 쓸 때 부른다)
local poses: any = nil
local function pose(name: string): any
	if not poses then
		poses = require(ReplicatedStorage.Shared.Combat.CombatMotions).Sets.AzureBlade.Poses
	end
	return poses[name]
end

-- 배우마다 스킬 동안 남겨 두는 것(잔상·검로·물·출발 자리·카메라 끝점)
local states: { [string]: any } = {}
local function st(ctx: any): any
	local id = if ctx.Actor then ctx.Actor.Id else "?"
	local s = states[id]
	if not s then
		s = {}
		states[id] = s
	end
	return s
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

local function tsuba(ctx: any): Vector3
	return ctx.Base("W") or ctx.Hand("R")
end

-- 검집 입(칼이 드나드는 곳)
local function mouth(ctx: any): Vector3
	return ctx.Base("O") or ctx.Hand("R")
end

--[[
	빛줄 한 획: from → to 로 grow 초에 그어진다. Keep 이면 남겨 두고 { Burst() } 를 돌려준다(검로 — 나중에 한꺼번에 터진다),
	아니면 Life 초 뒤 사라진다. opts: Width, Color, Grow, Life, Delay, Keep
]]
local function stroke(from: Vector3, to: Vector3, opts: { [string]: any }): any
	local w = opts.Width or 0.12
	local len = math.max(0.05, (to - from).Magnitude)
	local cf = CFrame.lookAt(from, to)
	local outer = CombatVfx.Part(Vector3.new(w, w, 0.05), cf, opts.Color or AZURE)
	local core = CombatVfx.Part(Vector3.new(w * 0.4, w * 0.4, 0.05), cf, WHITE)
	outer.Transparency, core.Transparency = 1, 1
	local grow = opts.Grow or 0.08
	local gone = false
	local function set(k: number, width: number)
		local l = math.max(0.05, len * k)
		local at = cf * CFrame.new(0, 0, -l / 2)
		outer.Size, outer.CFrame = Vector3.new(width, width, l), at
		core.Size, core.CFrame = Vector3.new(width * 0.4, width * 0.4, l), at
	end
	local function start()
		outer.Transparency, core.Transparency = 0.15, 0
		CombatVfx.Timed(grow, function(a)
			if not gone then
				set(1 - (1 - a) ^ 3, w)
			end
		end)
		if not opts.Keep then
			local life = opts.Life or 0.3
			CombatVfx.Timed(grow + life, function(a)
				local t = math.clamp((a * (grow + life) - grow) / life, 0, 1)
				outer.Transparency = 0.15 + 0.85 * t
				core.Transparency = t
			end, function()
				outer:Destroy()
				core:Destroy()
			end)
		end
	end
	if opts.Delay and opts.Delay > 0 then
		task.delay(opts.Delay, start)
	else
		start()
	end
	local mark = {}
	function mark.Burst()
		if gone then
			return
		end
		gone = true
		set(1, w)
		local mid = from:Lerp(to, 0.5)
		CombatVfx.Burst(mid, { Count = 6, Colors = { ICE, WHITE, AZURE }, Size = 0.18, Speed = 14, Gravity = 8, Life = 0.45 })
		CombatVfx.Timed(0.4, function(a)
			local k = 1 + 5 * a
			set(1, w * k)
			outer.Transparency = 0.1 + 0.9 * a
			core.Transparency = a
		end, function()
			outer:Destroy()
			core:Destroy()
		end)
	end
	if opts.Keep then
		-- 안전장치: 스킬이 끊겨 터지지 않으면 저절로 사라진다
		task.delay(10, mark.Burst)
	end
	return mark
end

-- 별빛 반짝(가로세로 가는 빛줄 두 개 + 번쩍)
local function twinkle(ctx: any, at: Vector3, size: number)
	ctx.Vfx.Flash(at, { Color = WHITE, Size = size * 2.4, Life = 0.22, Brightness = 5 })
	local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new()
	local right, up = look.RightVector * size, look.UpVector * size
	stroke(at - right, at + right, { Width = 0.07, Color = ICE, Grow = 0.03, Life = 0.18 })
	stroke(at - up * 0.7, at + up * 0.7, { Width = 0.06, Color = ICE, Grow = 0.03, Life = 0.16 })
end

-- 대상 자리에 엇갈린 벤 자국 몇 줄(작은 원호를 여러 기울기로)
local function cuts(ctx: any, at: Vector3, n: number, radius: number)
	local rng = Random.new()
	for i = 1, n do
		local tilt = rng:NextNumber(-80, 80)
		local center = at + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.5, 0.7), rng:NextNumber(-0.6, 0.6))
		task.delay((i - 1) * 0.025, function()
			Common.Arc(ctx, center, tilt, -70, 70, { Radius = radius, Width = 0.35, Depth = 0.06, Color = AZURE, Core = WHITE, Sweep = 0.03, Life = 0.22 })
		end)
	end
	ctx.Vfx.Flash(at, { Color = ICE, Size = 5, Life = 0.18, Brightness = 4 })
end

--=== 공통 ===--

function Fx.Glint(ctx: any)
	local p = tsuba(ctx)
	ctx.Vfx.Flash(p, { Color = WHITE, Size = 2.2, Life = 0.25, Brightness = 4 })
	ctx.Vfx.Sparks(p, { Color = ICE, Count = 5, MinSpeed = 2, Speed = 5 })
end

function Fx.Click(ctx: any)
	local p = tsuba(ctx)
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.2, R1 = 1.1, Color = ICE, Life = 0.18, Width = 0.08, Facing = true })
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 4, MinSpeed = 1, Speed = 3 })
end

function Fx.Touchdown(ctx: any)
	local feet = Common.Feet(ctx)
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.12, 0)), { R0 = 0.5, R1 = 3.6, Color = AZURE, Life = 0.4, Width = 0.18, Height = 0.05 })
	Common.Land(ctx.Vfx, feet, 0.6)
end

function Fx.Block(ctx: any)
	Common.GuardRing(ctx.Vfx, ctx, AZURE)
	ctx.Vfx.Sparks(ctx.Root.Position + ctx.Forward * 1.6, { Color = ICE, Count = 10, Speed = 14 })
end

-- 회피: 비켜서기 전 자리에 선 자세 그대로의 잔상이 남았다 흩어진다
function Fx.Afterimage(ctx: any)
	local g = Common.Ghost(ctx, pose("STANCE"), ctx.Root, { Transparency = 0.5, FadeIn = 0.03 })
	if g then
		task.delay(0.12, function()
			g.Vanish(0.35)
		end)
	end
	ctx.Vfx.Burst(ctx.Root.Position, { Count = 8, Color = ICE, Size = 0.16, Speed = 7, Gravity = 0, Life = 0.35 })
end

function Fx.SheathHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Impact(ctx.Vfx, p, ICE, 0.9)
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 2.4, Color = AZURE, Life = 0.25, Width = 0.2, Facing = true })
end

-- 집중 베기: 한순간 뽑는 섬광 + 앞을 가로지르는 넓은 원호
function Fx.DrawFlash(ctx: any)
	local hand = ctx.Hand("R")
	ctx.Vfx.Flash(hand, { Color = WHITE, Size = 7, Life = 0.2, Brightness = 7 })
	Common.Arc(ctx, ctx.Root.Position + Vector3.new(0, 0.4, 0), 88, -40, 120, { Radius = 5.6, Width = 0.9, Color = AZURE, Core = WHITE, Sweep = 0.04, Life = 0.28 })
end

function Fx.CutHit(ctx: any, _ev: any, at: Vector3?)
	cuts(ctx, at or ctx.Target, 2, 1.8)
end

--=== 천천히 뽑기 ===--

-- 검집에서 드러나는 날을 따라 빛이 미끄러진다(코등이 → 검집 입)
function Fx.DrawGlint(ctx: any)
	for i = 0, 3 do
		task.delay(i * 0.07, function()
			local p = tsuba(ctx):Lerp(mouth(ctx), 0.25 + i * 0.22)
			ctx.Vfx.Flash(p, { Color = ICE, Size = 1.6, Life = 0.16, Brightness = 3 })
		end)
	end
end

-- 칼끝이 검집을 빠져나오는 순간
function Fx.Release(ctx: any)
	local p = mouth(ctx)
	ctx.Vfx.Flash(p, { Color = WHITE, Size = 4, Life = 0.2, Brightness = 6 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.2, R1 = 1.6, Color = ICE, Life = 0.22, Width = 0.1, Facing = true })
	ctx.Vfx.Sparks(p, { Color = ICE, Count = 8, Speed = 10 })
end

--=== 진 발도술 ===--

-- 오른 어깨 위에서 왼쪽 아래로 크게 가르는 사선
function Fx.KesaArc(ctx: any)
	local center = ctx.Root.Position + Vector3.new(0, 0.5, 0) + ctx.Forward * 0.6
	Common.Arc(ctx, center, 40, 115, -75, { Radius = 5.4, Width = 1.0, Depth = 0.1, Color = AZURE, Core = WHITE, Sweep = 0.05, Life = 0.32 })
	ctx.Vfx.Flash(ctx.Hand("R"), { Color = WHITE, Size = 5, Life = 0.18, Brightness = 6 })
end

-- 몹 앞에 서로 다른 베기 자세의 잔상(타격 수만큼 — 사건의 c, 기본 3). 몹을 둘러 반원으로 서서 몹을 본다
local GHOST_POSES = { "DRAWCUT", "RISE", "CUTDOWN", "KESA", "SWEEP" }
function Fx.Ghosts(ctx: any, ev: any)
	local s = st(ctx)
	for _, g in s.ghosts or {} do
		g.Vanish(0.1)
	end
	s.ghosts = {}
	local n = (ev and ev.c) or 3
	local t = ctx.Target
	local toMe = flat(ctx.Root.Position - t)
	local y = ctx.Root.Position.Y
	for i = 1, n do
		task.delay((i - 1) * 0.1, function()
			local ang = if n == 1 then 0 else -60 + 120 * (i - 1) / (n - 1)
			local dir = CFrame.Angles(0, math.rad(ang), 0) * toMe
			local pos = Vector3.new(t.X, y, t.Z) + dir * 2.9
			local cf = CFrame.lookAt(pos, Vector3.new(t.X, y, t.Z))
			local g = Common.Ghost(ctx, pose(GHOST_POSES[(i - 1) % #GHOST_POSES + 1]), cf, { Transparency = 0.5 })
			if g then
				table.insert(s.ghosts, g)
			end
			ctx.Vfx.Flash(pos, { Color = ICE, Size = 4, Life = 0.18, Brightness = 4 })
			ctx.Vfx.Sparks(pos, { Color = ICE, Count = 6, Speed = 8 })
		end)
	end
end

-- 타격마다 잔상 하나가 번쩍이며 사라지고 몹에 벤 자국(한 사건에 대상이 여럿이어도 잔상은 하나)
function Fx.GhostCut(ctx: any, ev: any, at: Vector3?)
	local s = st(ctx)
	if s.cutEv ~= ev then
		s.cutEv = ev
		local g = s.ghosts and table.remove(s.ghosts, 1)
		if g then
			local p = g.Model:GetPivot().Position
			ctx.Vfx.Flash(p, { Color = WHITE, Size = 6, Life = 0.16, Brightness = 6 })
			g.Vanish(0.18)
		end
	end
	local p = at or ctx.Target
	cuts(ctx, p, 3, 2.2)
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 10, Speed = 20 })
end

--=== 발도술의 절정 ===--

-- 반쯤 뽑다 챙! — 드러난 날에 별빛
function Fx.Ching(ctx: any)
	ctx.Sound(SOUND.Ching, 0.8)
	local p = tsuba(ctx):Lerp(mouth(ctx), 0.55)
	twinkle(ctx, p, 1.6)
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 10, Speed = 9 })
end

-- 사라지는 순간: 반쯤 뽑은 자세의 잔상만 남는다(출발 자리를 적어 둔다 — 검로·줄 칼날이 여기서 시작)
function Fx.Vanish(ctx: any)
	local s = st(ctx)
	s.peakFrom = ctx.Root.Position
	local g = Common.Ghost(ctx, pose("DRAW2"), ctx.Root, { Transparency = 0.6, FadeIn = 0.01 })
	if g then
		task.delay(0.35, function()
			g.Vanish(0.4)
		end)
	end
	ctx.Vfx.Flash(ctx.Root.Position, { Color = ICE, Size = 6, Life = 0.2, Brightness = 5 })
	ctx.Vfx.Dust(Common.Feet(ctx), { Color = ICE, Count = 10 })
end

-- 지나간 자리: 출발 → 지금 자리 사이에 불규칙한 곧은 검로들(높이·기울기·길이가 제각각)
function Fx.PeakPath(ctx: any)
	local s = st(ctx)
	local a = s.peakFrom or ctx.Actor.Home.Position
	local b = ctx.Root.Position
	local d = flat(b - a)
	local side = d:Cross(Vector3.yAxis)
	local rng = Random.new()
	for k = 1, 7 do
		local u0 = rng:NextNumber(-0.05, 0.55)
		local u1 = math.min(1.05, u0 + rng:NextNumber(0.35, 0.8))
		local p0 = a:Lerp(b, u0) + side * rng:NextNumber(-1.1, 1.1)
		local p1 = a:Lerp(b, u1) + side * rng:NextNumber(-1.1, 1.1)
		p0 = Vector3.new(p0.X, ctx.Ground + rng:NextNumber(0.3, 2.4), p0.Z)
		p1 = Vector3.new(p1.X, p0.Y + rng:NextNumber(-0.6, 0.6), p1.Z)
		stroke(p0, p1, { Width = rng:NextNumber(0.06, 0.18), Grow = 0.05, Life = 1.3, Delay = (k - 1) * 0.015 })
	end
end

-- 줄 전체를 가르는 곧은 칼날들이 반짝 — 한 번 반짝일 때마다 타격(대상이 여럿이어도 칼날은 한 번만 긋는다)
function Fx.RowFlash(ctx: any, ev: any, at: Vector3?)
	local s = st(ctx)
	if s.rowEv ~= ev then
		s.rowEv = ev
		local a = s.peakFrom or ctx.Actor.Home.Position
		local b = ctx.Root.Position
		local d = flat(b - a)
		local side = d:Cross(Vector3.yAxis)
		local rng = Random.new()
		for k = 1, 4 do
			local h0 = ctx.Ground + rng:NextNumber(0.6, 2.6)
			local p0 = Vector3.new(a.X, h0, a.Z) + side * rng:NextNumber(-1, 1) - d * 1.5
			local p1 = Vector3.new(b.X, h0 + rng:NextNumber(-0.8, 0.8), b.Z) + side * rng:NextNumber(-1, 1) + d * 0.5
			stroke(p0, p1, { Width = rng:NextNumber(0.07, 0.2), Color = if k % 2 == 0 then ICE else AZURE, Grow = 0.03, Life = 0.16, Delay = (k - 1) * 0.02 })
		end
		for _ = 1, 3 do
			local q = a:Lerp(b, rng:NextNumber(0.1, 0.9))
			twinkle(ctx, Vector3.new(q.X, ctx.Ground + rng:NextNumber(0.8, 2.4), q.Z), 1.1)
		end
	end
	local p = at or ctx.Target
	cuts(ctx, p, 2, 2.4)
	ctx.Vfx.Sparks(p, { Color = ICE, Count = 10, Speed = 20 })
end

--=== 공간의 이해(컷신) ===--

local function quartOut(x: number): number
	return 1 - (1 - x) ^ 4
end

-- 들머리: 발치를 낮게 확대(조금씩 다가간다)
function Fx.CamFoot(ctx: any)
	local home = ctx.Actor.Home
	local g = ctx.Ground - home.Y
	local look = home * Vector3.new(0.5, g + 0.3, -0.35)
	local a0, a1 = home * Vector3.new(5.2, g + 1.0, -5.6), home * Vector3.new(4.1, g + 0.7, -4.4)
	local s = st(ctx)
	s.camFoot = { At = a1, Look = look }
	ctx.Shot(1.1, function(u)
		return CFrame.lookAt(a0:Lerp(a1, 1 - (1 - u) ^ 2), look)
	end)
end

-- 발치에서 오른쪽 위로 원을 그리며 올라간다(시전자를 보며, 끝점에 가까울수록 느려진다)
local PIVOT = Vector3.new(0, 0.6, 0)
local END_AZ, END_EL, END_R = math.rad(105), math.rad(38), 17
local function orbitPoint(home: CFrame, az: number, el: number, r: number): Vector3
	return home * (PIVOT + Vector3.new(math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el)) * r)
end
function Fx.CamOrbit(ctx: any)
	local home = ctx.Actor.Home
	local s = st(ctx)
	local from = if s.camFoot then s.camFoot.At else home * Vector3.new(2.1, -2.3, -2.2)
	local look0 = if s.camFoot then s.camFoot.Look else home * PIVOT
	local rel = home:PointToObjectSpace(from) - PIVOT
	local r0 = rel.Magnitude
	local az0, el0 = math.atan2(rel.X, -rel.Z), math.asin(math.clamp(rel.Y / r0, -1, 1))
	local actor = ctx.Actor
	s.camEnd = orbitPoint(home, END_AZ, END_EL, END_R)
	ctx.Shot(1.6, function(u)
		local e = quartOut(u)
		local p = orbitPoint(home, az0 + (END_AZ - az0) * e, el0 + (END_EL - el0) * e, r0 + (END_R - r0) * e)
		local chest = actor.Pos.Position + Vector3.new(0, 0.6, 0)
		return CFrame.lookAt(p, look0:Lerp(chest, math.min(1, u * 3)))
	end)
end

-- 끝점에 선 채 물 흐르듯 지나다니는 시전자를 부드럽게 따라 본다(적 진영 쪽으로 조금 당겨)
function Fx.CamHold(ctx: any)
	local s = st(ctx)
	local actor = ctx.Actor
	local at = s.camEnd or orbitPoint(actor.Home, END_AZ, END_EL, END_R)
	local enemies = ctx.EnemyCenter
	local function goal(): Vector3
		return (actor.Pos.Position + Vector3.new(0, 0.6, 0)):Lerp(enemies, 0.3)
	end
	local look = actor.Pos.Position + Vector3.new(0, 0.6, 0)
	local last = 0
	ctx.Shot(10, function(_, t)
		local dt = math.max(0, t - last)
		last = t
		look = look:Lerp(goal(), 1 - math.exp(-dt * 5))
		return CFrame.lookAt(at, look)
	end)
end

function Fx.CamFree(ctx: any)
	ctx.Shot()
end

-- 또옥 — 발끝이 닿은 자리에서 물 판이 번지고 물결이 퍼진다(물 판은 검로가 터질 때 사라진다)
function Fx.WaterStep(ctx: any)
	ctx.Sound(SOUND.Drop, 1)
	local s = st(ctx)
	s.marks, s.flowFrom = {}, nil
	local foot = ctx.Actor.Home * Vector3.new(0.5, 0, -0.35)
	local p = Vector3.new(foot.X, ctx.Ground + 0.04, foot.Z)
	if s.water then
		s.water:Destroy()
	end
	local disc = CombatVfx.Part(Vector3.new(0.05, 1, 1), CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 2), WATER, Enum.Material.Glass, Enum.PartType.Cylinder)
	disc.Transparency = 0.5
	disc.Reflectance = 0.3
	s.water = disc
	CombatVfx.Timed(1.2, function(a)
		local r = 0.6 + 26 * quartOut(a)
		disc.Size = Vector3.new(0.05, r, r)
	end)
	task.delay(12, function()
		if disc.Parent then
			disc:Destroy()
		end
	end)
	for i = 0, 2 do
		task.delay(i * 0.16, function()
			ctx.Vfx.Ring(CFrame.new(p + Vector3.new(0, 0.06, 0)), { R0 = 0.2, R1 = 2.5 + i * 1.8, Color = ICE, Life = 0.7 + i * 0.15, Width = 0.08, Height = 0.03 })
		end)
	end
	ctx.Vfx.Burst(p + Vector3.new(0, 0.1, 0), { Count = 8, Colors = { ICE, WHITE }, Size = 0.1, Speed = 5, Gravity = 30, Life = 0.5 })
end

-- 한 번 지나갈 때마다: 지나온 길(돌진의 휨 bend 와 같은 곡선)이 그대로 검로가 되고, 그 둘레에 다른 검로 둘이 새겨진다
function Fx.FlowMark(ctx: any, ev: any)
	local s = st(ctx)
	s.marks = s.marks or {}
	local h = ctx.Ground + 1.5
	local a = s.flowFrom or ctx.Actor.Home.Position
	local b = ctx.Root.Position
	a, b = Vector3.new(a.X, h, a.Z), Vector3.new(b.X, h, b.Z)
	local side = flat(b - a):Cross(Vector3.yAxis)
	local bend = (ev and ev.bend) or 0
	local prev = a
	for i = 1, 6 do
		local u = i / 6
		local q = a:Lerp(b, u) + side * (math.sin(u * math.pi) * bend)
		table.insert(s.marks, stroke(prev, q, { Width = 0.15, Grow = 0.04, Delay = (i - 1) * 0.015, Keep = true }))
		prev = q
	end
	local rng = Random.new()
	for k = 1, 2 do
		local mid = a:Lerp(b, rng:NextNumber(0.2, 0.8)) + Vector3.new(rng:NextNumber(-1.6, 1.6), rng:NextNumber(-0.9, 1.0), rng:NextNumber(-1.6, 1.6))
		local dir = (CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(math.rad(rng:NextNumber(-35, 35)), 0, 0)).LookVector
		local half = rng:NextNumber(1.6, 2.8)
		table.insert(s.marks, stroke(mid - dir * half, mid + dir * half, { Width = 0.09, Color = ICE, Grow = 0.06, Delay = 0.06 + k * 0.05, Keep = true }))
	end
	s.flowFrom = ctx.Root.Position
	ctx.Vfx.Flash(b, { Color = ICE, Size = 2.6, Life = 0.15, Brightness = 3 })
end

-- 등 검집에 꽂는 순간: 새겨 둔 검로가 한꺼번에 터지고 물 판이 걷힌다
function Fx.FlowBurst(ctx: any)
	local s = st(ctx)
	for i, m in s.marks or {} do
		task.delay(math.min(0.12, i * 0.004), m.Burst)
	end
	s.marks = {}
	local water = s.water
	s.water = nil
	if water then
		CombatVfx.Timed(0.7, function(a)
			water.Transparency = 0.5 + 0.5 * a
		end, function()
			water:Destroy()
		end)
	end
	ctx.Vfx.Flash(ctx.EnemyCenter, { Color = WHITE, Size = 16, Life = 0.35, Brightness = 6 })
end

function Fx.BurstHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	cuts(ctx, p, 3, 2.6)
	ctx.Vfx.Burst(p, { Count = 10, Colors = { ICE, AZURE, WHITE }, Size = 0.3, Speed = 16, Gravity = 10, Life = 0.6 })
end

--=== 도발·호흡 ===--

-- 도발: 튕긴 왼손 끝의 작은 고리 + 머리 위 번쩍(덤벼라)
function Fx.Taunt(ctx: any)
	local hand = ctx.Hand("L")
	ctx.Vfx.Ring(CFrame.lookAt(hand, hand + ctx.Forward), { R0 = 0.2, R1 = 1.6, Color = AZURE, Life = 0.35, Width = 0.1, Facing = true })
	ctx.Vfx.Flash(Common.Head(ctx) + Vector3.new(0, 1, 0), { Color = ICE, Size = 3, Life = 0.3, Brightness = 3 })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), AZURE)
end

return Fx
