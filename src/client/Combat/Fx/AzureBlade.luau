--!strict
--[[
	Fx/AzureBlade — 청의 검사 이펙트. 푸른 칼빛·흰 섬광·잔상·물·검로. (2026-10-25, 같은 날 사용자 말 설명으로 다시 짬)

	  집중 베기     조금 뽑다 챙 멈춤(Ching) → 잔상을 남기고(Slip) 앞 두 칸을 블링크로 지나 작게 기운 검흔(SmallCuts) → 딸깍 → 잔상을 남기고 제자리로
	  진 발도술     천천히 뽑다(DrawGlint) 칼이 빠지는 순간(Release) 왼쪽 아래로 사선베기(KesaArc) →
	                몹 앞에 서로 다른 베기 자세의 잔상을 타격 수만큼(Ghosts) → 타격마다 잔상이 하나씩 사라지며 벤다(GhostCut)
	  발도술의 절정 반쯤 뽑다 "챙" 하고 멈춰 드러난 날에 빛(Ching) → 사라져(Vanish) 줄 끝에 이미 벤 자세로 서고,
	                지나간 자리에 불규칙한 곧은 검로(PeakPath) → 줄 전체를 가르는 곧은 칼날들이 반짝일 때마다 타격(RowFlash).
	                (2026-10-26 사용자) 제 줄을 따라 곧게 가고, 검로·칼날은 위아래로 ±TILT° 안에서 제각각 기울며 크기는 MARK 배
	  공간의 이해   (2026-10-26 다시) 블링크 다섯 번(Blink — 선 자리에 그 자세 잔상)으로 적진을 가로질러 줄 끝에서 꽂으면(카메라는 그동안
	                등 뒤에서 따라가다 돌아온다: CamFollow · CamFree) → 적 진영 칸 경계마다 격자로 반듯하게 썰린 검흔(GridCut)이
	                반짝이다 한꺼번에 터지며 필드 전체를 벤다(GridFlash · GridHit)
	효과음: 로블록스 효과음 모음(ProSoundEffects). 챙 = 칼 뽑는 쇳소리 — 바꾸려면 SOUND 의 숫자만 고친다.
	잔상 자세는 모션 파일의 Poses(tools/combat/design/azure_gen.py 가 만든다).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Common = require(script.Parent.Common)
local CombatVfx = require(script.Parent.Parent.CombatVfx)
local c = Common.c

local AZURE = c(90, 170, 255)
local ICE = c(200, 232, 255)
local WHITE = c(245, 250, 255)

local SOUND = { Ching = 9119742466 }
-- 발도술의 절정 검로·칼날이 줄 방향에서 위아래로 기우는 무작위 범위(±도)
local TILT = 70

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
	아니면 Life 초 뒤 사라진다. opts: Width, Color, Grow, Life, Delay, Keep, Bits(터질 때 조각 수)
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
		CombatVfx.Burst(mid, { Count = opts.Bits or 6, Colors = { ICE, WHITE, AZURE }, Size = 0.18, Speed = 14, Gravity = 8, Life = 0.45 })
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

-- 대상 자리에 엇갈린 벤 자국 몇 줄(작은 원호를 여러 기울기로). width = 원호 굵기(기본 0.35)
local function cuts(ctx: any, at: Vector3, n: number, radius: number, width: number?)
	local rng = Random.new()
	for i = 1, n do
		local tilt = rng:NextNumber(-80, 80)
		local center = at + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.5, 0.7), rng:NextNumber(-0.6, 0.6))
		task.delay((i - 1) * 0.025, function()
			Common.Arc(ctx, center, tilt, -70, 70, { Radius = radius, Width = width or 0.35, Depth = 0.06, Color = AZURE, Core = WHITE, Sweep = 0.03, Life = 0.22 })
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

-- 검흔 크기 배율(선 굵기 · 벤 자국 원호 · 위아래로 뻗는 높이) — 2026-10-26 사용자 "3배정도"
local MARK = 3

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

--[[
	줄(a → b, 제 줄을 따라 곧게) 위 한 점을 가운데로, 줄 방향에서 위아래로 ±TILT° 무작위로 기운 곧은 선의 두 끝.
	선은 땅 위 0.1 ~ top(기본 4.5×MARK) 안에 든다 — 많이 기운 선은 그 높이만큼 길게 위아래로 뻗고, 가운데 높이를 그에 맞춰 올린다.
	side = 줄 옆 방향(가운데를 옆으로 흩뜨린다)
]]
local function tilted(rng: Random, a: Vector3, b: Vector3, ground: number, side: Vector3, longest: number, ceiling: number?): (Vector3, Vector3)
	local d = flat(b - a)
	local top = ceiling or 4.5 * MARK
	local th = math.rad(rng:NextNumber(-TILT, TILT))
	local sin = math.abs(math.sin(th))
	local len = math.min(longest * rng:NextNumber(0.55, 1), (top - 0.1) / math.max(0.05, sin))
	local half = len / 2 * sin
	local mid = a:Lerp(b, rng:NextNumber(0.1, 0.9)) + side * rng:NextNumber(-1.1, 1.1)
	local lowest = ground + 0.1 + half
	mid = Vector3.new(mid.X, lowest + rng:NextNumber(0, math.max(0, math.min(2.5, ground + top - half - lowest))), mid.Z)
	local dir = d * math.cos(th) + Vector3.yAxis * math.sin(th)
	return mid - dir * (len / 2), mid + dir * (len / 2)
end

-- 지나간 자리: 출발 → 지금 자리 사이에 불규칙한 곧은 검로들(자리·기울기·길이가 제각각)
function Fx.PeakPath(ctx: any)
	local s = st(ctx)
	local a = s.peakFrom or ctx.Actor.Home.Position
	local b = ctx.Root.Position
	local side = flat(b - a):Cross(Vector3.yAxis)
	local rng = Random.new()
	for k = 1, 7 do
		local p0, p1 = tilted(rng, a, b, ctx.Ground, side, (b - a).Magnitude * 0.6)
		stroke(p0, p1, { Width = rng:NextNumber(0.06, 0.18) * MARK, Grow = 0.05, Life = 1.3, Delay = (k - 1) * 0.015 })
	end
end

-- 줄 전체를 가르는 곧은 칼날들이 반짝 — 한 번 반짝일 때마다 타격(대상이 여럿이어도 칼날은 한 번만 긋는다)
function Fx.RowFlash(ctx: any, ev: any, at: Vector3?)
	local s = st(ctx)
	if s.rowEv ~= ev then
		s.rowEv = ev
		local a = s.peakFrom or ctx.Actor.Home.Position
		local b = ctx.Root.Position
		local side = flat(b - a):Cross(Vector3.yAxis)
		local rng = Random.new()
		for k = 1, 5 do
			local p0, p1 = tilted(rng, a, b, ctx.Ground, side, (b - a).Magnitude * 1.1)
			stroke(p0, p1, { Width = rng:NextNumber(0.07, 0.2) * MARK, Color = if k % 2 == 0 then ICE else AZURE, Grow = 0.03, Life = 0.16, Delay = (k - 1) * 0.02 })
		end
		for _ = 1, 3 do
			local q = a:Lerp(b, rng:NextNumber(0.1, 0.9))
			twinkle(ctx, Vector3.new(q.X, ctx.Ground + rng:NextNumber(0.8, 4), q.Z), 1.1 * MARK)
		end
	end
	local p = at or ctx.Target
	cuts(ctx, p, 2, 2.4 * MARK, 0.35 * MARK)
	ctx.Vfx.Sparks(p, { Color = ICE, Count = 10, Speed = 20 })
end

--=== 집중 베기(2026-10-26 — 발도술 셋과 같은 결로 작게) ===--

-- 블링크로 빠지는 순간: 선 자리에 그 자세(ev.p)의 잔상을 남긴다(출발 자리를 적어 둔다 — 작은 검흔이 여기서 시작)
function Fx.Slip(ctx: any, ev: any)
	local s = st(ctx)
	s.slipFrom = ctx.Root.Position
	local g = Common.Ghost(ctx, pose((ev and ev.p) or "DRAW1"), ctx.Root, { Transparency = 0.55, FadeIn = 0.01 })
	if g then
		task.delay(0.15, function()
			g.Vanish(0.3)
		end)
	end
	ctx.Vfx.Flash(ctx.Root.Position, { Color = ICE, Size = 4, Life = 0.15, Brightness = 4 })
end

-- 지나간 앞 두 칸에 작게 기운 곧은 검흔 몇 줄이 반짝(발도술의 절정 칼날의 작은 판)
function Fx.SmallCuts(ctx: any)
	local s = st(ctx)
	local a = s.slipFrom or ctx.Actor.Home.Position
	local b = ctx.Root.Position
	local side = flat(b - a):Cross(Vector3.yAxis)
	local rng = Random.new()
	for k = 1, 4 do
		local p0, p1 = tilted(rng, a, b, ctx.Ground, side, (b - a).Magnitude * 0.6, 3.4)
		stroke(p0, p1, { Width = rng:NextNumber(0.08, 0.16), Color = if k % 2 == 0 then ICE else AZURE, Grow = 0.04, Life = 0.35, Delay = (k - 1) * 0.03 })
	end
	for _ = 1, 2 do
		local q = a:Lerp(b, rng:NextNumber(0.3, 0.9))
		twinkle(ctx, Vector3.new(q.X, ctx.Ground + rng:NextNumber(1, 2.4), q.Z), 0.9)
	end
end

--=== 공간의 이해(2026-10-26 다시 — 연속 블링크로 줄 끝까지 → 꽂음 → 격자 검흔이 필드 전체를 벤다) ===--

-- 카메라: 블링크하는 동안 등 뒤 오른쪽 위에서 시전자를 따라간다(적 쪽 방향 기준, 지금 화면에서 부드럽게 넘어온다).
-- 꽂을 때 놓아(CamFree) 전투 카메라로 돌아와 필드 전체의 격자를 보인다
local function follow(ctx: any, back: number, right: number, up: number, ahead: number)
	local s = st(ctx)
	local actor = ctx.Actor
	local f = flat(actor.Home.LookVector)
	local r = f:Cross(Vector3.yAxis)
	local cam = workspace.CurrentCamera
	local at: Vector3 = s.camAt or (if cam then cam.CFrame.Position else actor.Pos.Position - f * back)
	local look: Vector3 = s.camLook or (actor.Pos.Position + f * ahead)
	local last = 0
	ctx.Shot(10, function(_, t)
		local dt = math.max(0, t - last)
		last = t
		local p = actor.Pos.Position
		local k = 1 - math.exp(-dt * 7)
		at = at:Lerp(p - f * back + r * right + Vector3.yAxis * up, k)
		look = look:Lerp(p + f * ahead + Vector3.yAxis * 0.6, k)
		s.camAt, s.camLook = at, look
		return CFrame.lookAt(at, look)
	end)
end

function Fx.CamFollow(ctx: any)
	local s = st(ctx)
	s.camAt, s.camLook = nil, nil
	follow(ctx, 7.5, 4.5, 5.2, 5)
end

function Fx.CamFree(ctx: any)
	local s = st(ctx)
	s.camAt, s.camLook = nil, nil
	ctx.Shot()
end

-- 블링크: 선 자리에 그 순간 자세(ev.p)의 잔상을 남기고 사라져 몇 칸 앞에 나타나며, 지나간 길을 가는 빛줄로 벤다
function Fx.Blink(ctx: any, ev: any)
	local from = ctx.Root
	local g = Common.Ghost(ctx, pose((ev and ev.p) or "OUT"), from, { Transparency = 0.5, FadeIn = 0.01 })
	if g then
		task.delay(0.12, function()
			g.Vanish(0.3)
		end)
	end
	ctx.Vfx.Flash(from.Position, { Color = ICE, Size = 4, Life = 0.15, Brightness = 4 })
	task.delay(0.05, function()
		local to = ctx.Actor.Pos.Position
		local lift = Vector3.new(0, 0.3, 0)
		stroke(from.Position + lift, to + lift, { Width = 0.07, Color = ICE, Grow = 0.03, Life = 0.25 })
		ctx.Vfx.Flash(to, { Color = WHITE, Size = 4, Life = 0.15, Brightness = 5 })
		Common.Arc(ctx, to + Vector3.new(0, 0.4, 0) + ctx.Forward, math.random(-60, 60), -60, 80, { Radius = 3.2, Width = 0.5, Color = AZURE, Core = WHITE, Sweep = 0.04, Life = 0.2 })
	end)
end

--[[
	격자 선 자리(전투 공간의 앞 u · 옆 v 좌표)와 칸 간격. 선은 **칸 정중앙**을 지나 교차점이 칸 가운데에 온다
	(2026-10-26 사용자: 칸 경계에서 0.5칸 옮기기). 적 진영 칸(ctx.EnemyTiles — 전투 화면이 넘겨준다)의 가운데들에서
	겹치지 않는 u·v 값을 모은다. 칸을 모르면(전시장) 첫 대상을 첫 열 가운데로 6×3 칸을 어림한다.
]]
local PITCH = 6
local function gridLines(ctx: any): ({ number }, { number }, number, number)
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local origin = ctx.Actor.Home.Position
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
	local function bounds(axis: Vector3): { number }
		local vals = {}
		for _, center in centers do
			local x = math.round((center - origin):Dot(axis) * 2) / 2
			if not table.find(vals, x) then
				table.insert(vals, x)
			end
		end
		table.sort(vals)
		local pitch = PITCH
		for i = 2, #vals do
			pitch = math.min(pitch, vals[i] - vals[i - 1])
		end
		return vals, pitch
	end
	local us, pu = bounds(f)
	local vs, pv = bounds(r)
	return us, vs, pu, pv
end

-- 꽂은 뒤: 필드 전체에 격자로 반듯하게 썰린 검흔 — 칸 정중앙을 지나는 바닥·가슴 높이 두 겹 가로세로(필드 가장자리까지) +
-- 칸 가운데(교차점)마다 세로 선이 앞에서 뒤로 차례로 그어지고 반짝인다
function Fx.GridCut(ctx: any)
	local s = st(ctx)
	s.grid = {}
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local home = ctx.Actor.Home.Position
	local base = Vector3.new(home.X, ctx.Ground, home.Z)
	local us, vs, pu, pv = gridLines(ctx)
	local function at(u: number, v: number, y: number): Vector3
		return base + f * u + r * v + Vector3.new(0, y, 0)
	end
	local u0, u1, v0, v1 = us[1] - pu / 2, us[#us] + pu / 2, vs[1] - pv / 2, vs[#vs] + pv / 2
	local span = math.max(1, u1 - u0)
	local function delay(u: number): number
		return 0.3 * (u - u0) / span
	end
	for _, y in { 0.1, 1.6 } do
		for _, v in vs do
			table.insert(s.grid, stroke(at(u0, v, y), at(u1, v, y), { Width = 0.1, Color = ICE, Grow = 0.3, Keep = true, Bits = 2 }))
		end
		for _, u in us do
			table.insert(s.grid, stroke(at(u, v0, y), at(u, v1, y), { Width = 0.1, Grow = 0.12, Delay = delay(u), Keep = true, Bits = 2 }))
		end
	end
	for _, u in us do
		for _, v in vs do
			table.insert(s.grid, stroke(at(u, v, 0), at(u, v, 3.2), { Width = 0.08, Color = ICE, Grow = 0.1, Delay = delay(u) + 0.05, Keep = true, Bits = 2 }))
		end
	end
	task.delay(0.32, function()
		for _ = 1, 7 do
			twinkle(ctx, at(us[math.random(#us)], vs[math.random(#vs)], 1.6), 1.3)
		end
	end)
end

-- 격자가 한꺼번에 번쩍이며 터진다
function Fx.GridFlash(ctx: any)
	local s = st(ctx)
	for i, m in s.grid or {} do
		task.delay(math.min(0.08, i * 0.002), m.Burst)
	end
	s.grid = {}
	ctx.Vfx.Flash(ctx.EnemyCenter, { Color = WHITE, Size = 18, Life = 0.35, Brightness = 6 })
end

function Fx.GridHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	cuts(ctx, p, 2, 2.4)
	ctx.Vfx.Burst(p, { Count = 8, Colors = { ICE, AZURE, WHITE }, Size = 0.3, Speed = 16, Gravity = 10, Life = 0.6 })
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
