--!strict
--[[
	Fx/AzureBlade — 청의 검사 이펙트. 푸른 칼빛·흰 섬광·잔상·물·검로. (2026-10-25, 같은 날 사용자 말 설명으로 다시 짬)

	  진 발도술     천천히 뽑다(DrawGlint) 칼이 빠지는 순간(Release) 왼쪽 아래로 사선베기(KesaArc) →
	                몹 앞에 서로 다른 베기 자세의 잔상을 타격 수만큼(Ghosts) → 타격마다 잔상이 하나씩 사라지며 벤다(GhostCut)
	  발도술의 절정 반쯤 뽑다 "챙" 하고 멈춰 드러난 날에 빛(Ching) → 사라져(Vanish) 줄 끝에 이미 벤 자세로 서고,
	                지나간 자리에 불규칙한 곧은 검로(PeakPath) → 줄 전체를 가르는 곧은 칼날들이 반짝일 때마다 타격(RowFlash).
	                검로·칼날은 ±TILT° 안에서 제각각 기운다(2026-10-26 사용자)
	  공간의 이해   (2026-10-26 다시, 참고 엘든 링 말레니아) 카메라가 등 뒤에서 따라간다(CamFollow) — 착지 베기·두 바퀴 회전·강한 가로베기의
	                칼끝 길이 그대로 검로로 새겨지고(Carve) → 잔상 하나가 곧게 등 뒤로(GhostRush) → 그 출발점에서 둘째 잔상이
	                오른쪽·왼쪽·오른쪽으로 휘며 돌아와 몸에 겹친다(GhostWeave) → 꽂는 순간 검로가 한꺼번에 터진다(TrailBurst · BurstHit)
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

--[[
	줄(a → b) 위 한 점을 가운데로, 줄 방향에서 위아래로 ±TILT° 무작위로 기운 곧은 선의 두 끝.
	기울수록 짧게 — 두 끝이 땅 위 0.1 ~ 4.5 안에 들게 길이를 줄인다. side = 줄 옆 방향(가운데를 옆으로 흩뜨린다)
]]
local function tilted(rng: Random, a: Vector3, b: Vector3, ground: number, side: Vector3, longest: number): (Vector3, Vector3)
	local d = flat(b - a)
	local mid = a:Lerp(b, rng:NextNumber(0.1, 0.9)) + side * rng:NextNumber(-1.1, 1.1)
	mid = Vector3.new(mid.X, ground + rng:NextNumber(0.9, 2.3), mid.Z)
	local th = math.rad(rng:NextNumber(-TILT, TILT))
	local dir = d * math.cos(th) + Vector3.yAxis * math.sin(th)
	local room = math.min(mid.Y - ground - 0.1, ground + 4.5 - mid.Y)
	local len = math.min(longest * rng:NextNumber(0.55, 1), 2 * room / math.max(0.05, math.abs(math.sin(th))))
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
		local side = flat(b - a):Cross(Vector3.yAxis)
		local rng = Random.new()
		for k = 1, 5 do
			local p0, p1 = tilted(rng, a, b, ctx.Ground, side, (b - a).Magnitude * 1.1)
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

--=== 공간의 이해(2026-10-26 다시 — 참고 엘든 링 말레니아) ===--

-- 카메라: 등 뒤 오른쪽 위에서 시전자를 따라간다. 도는 몸을 따라 돌지 않게 적 쪽(집의 앞) 방향을 기준으로 하고,
-- 지금 화면에서 부드럽게 넘어온다(앞 카메라 자리를 이어 받는다)
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
	s.camAt, s.camLook, s.marks = nil, nil, {}
	-- 적이 사이에 끼어 가리지 않게 조금 높고 오른쪽으로(2026-10-26 전시장 확인)
	follow(ctx, 7.5, 4.5, 5.2, 5)
end

-- 검로가 터지기 직전: 조금 물러나 넓게
function Fx.CamWide(ctx: any)
	follow(ctx, 11, 7, 8, 3)
end

function Fx.CamFree(ctx: any)
	local s = st(ctx)
	s.camAt, s.camLook = nil, nil
	ctx.Shot()
end

-- 칼끝 길을 d 초 동안 그대로 검로로 새긴다(착지 베기 · 두 바퀴 회전 · 강한 가로베기 — 나중에 TrailBurst 로 터진다)
function Fx.Carve(ctx: any, ev: any)
	local s = st(ctx)
	s.marks = s.marks or {}
	local function point(): Vector3?
		local b, t = ctx.Base("W"), ctx.Tip("W")
		return if b and t then b:Lerp(t, 0.85) else nil
	end
	local prev = point()
	CombatVfx.Timed((ev and ev.d) or 0.2, function()
		local p = point()
		if p and prev and (p - prev).Magnitude > 0.35 then
			table.insert(s.marks, stroke(prev, p, { Width = 0.1, Grow = 0.02, Keep = true }))
			prev = p
		elseif p and not prev then
			prev = p
		end
	end)
end

-- 잔상 하나가 적진 저편에서 시전자 왼쪽을 스쳐 등 뒤로 곧게 돌진한다(지나간 길이 검로 — 카메라가 오른쪽 뒤라 왼쪽으로 지나야 보인다)
function Fx.GhostRush(ctx: any)
	local s = st(ctx)
	s.marks = s.marks or {}
	local actor = ctx.Actor
	local f = flat(actor.Home.LookVector)
	local r = f:Cross(Vector3.yAxis)
	local p = actor.Pos.Position
	local from, to = p + f * 11 - r * 1.4, p - f * 3.5 - r * 1.4
	s.ghostFrom = from
	local g = Common.Ghost(ctx, pose("RUSH"), CFrame.lookAt(from, from - f), { Transparency = 0.45, FadeIn = 0.04 })
	ctx.Vfx.Flash(from, { Color = ICE, Size = 5, Life = 0.2, Brightness = 4 })
	if not g then
		return
	end
	local root = g.Model:FindFirstChild("HumanoidRootPart") :: BasePart
	local lift = Vector3.new(0, ctx.Ground + 1.3 - p.Y, 0)
	local prev = from + lift
	CombatVfx.Timed(0.28, function(a)
		local q = from:Lerp(to, a)
		root.CFrame = CFrame.lookAt(q, q - f)
		local m = q + lift
		if (m - prev).Magnitude > 0.6 then
			table.insert(s.marks, stroke(prev, m, { Width = 0.15, Grow = 0.02, Keep = true }))
			prev = m
		end
	end, function()
		g.Vanish(0.2)
	end)
end

-- 첫 잔상이 떠난 자리에서 둘째 잔상이 (가는 쪽 기준) 오른쪽·왼쪽·오른쪽으로 휘며 돌아와 시전자 몸에 겹친다
function Fx.GhostWeave(ctx: any)
	local s = st(ctx)
	s.marks = s.marks or {}
	local actor = ctx.Actor
	local from: Vector3 = s.ghostFrom or (actor.Pos.Position + flat(actor.Home.LookVector) * 11)
	local g = Common.Ghost(ctx, pose("RUSH"), CFrame.new(from), { Transparency = 0.45, FadeIn = 0.04 })
	ctx.Vfx.Flash(from, { Color = ICE, Size = 5, Life = 0.2, Brightness = 4 })
	if not g then
		return
	end
	local root = g.Model:FindFirstChild("HumanoidRootPart") :: BasePart
	local function at(a: number): Vector3
		local to = actor.Pos.Position
		local right = flat(to - from):Cross(Vector3.yAxis)
		return from:Lerp(to, a) + right * (math.sin(a * math.pi * 3) * 2.8)
	end
	local lift = Vector3.new(0, ctx.Ground + 1.3 - from.Y, 0)
	local prev = from + lift
	CombatVfx.Timed(0.55, function(a)
		local q = at(a)
		local nxt = at(math.min(1, a + 0.02))
		if (nxt - q).Magnitude > 1e-3 then
			root.CFrame = CFrame.lookAt(q, Vector3.new(nxt.X, q.Y, nxt.Z))
		end
		local m = q + lift
		if (m - prev).Magnitude > 0.5 then
			table.insert(s.marks, stroke(prev, m, { Width = 0.15, Grow = 0.02, Keep = true }))
			prev = m
		end
	end, function()
		ctx.Vfx.Flash(actor.Pos.Position, { Color = WHITE, Size = 6, Life = 0.2, Brightness = 5 })
		g.Vanish(0.12)
	end)
end

-- 검집에 꽂는 순간: 새겨 둔 검로가 한꺼번에 터진다
function Fx.TrailBurst(ctx: any)
	local s = st(ctx)
	for i, m in s.marks or {} do
		task.delay(math.min(0.12, i * 0.003), m.Burst)
	end
	s.marks = {}
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
