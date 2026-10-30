--!strict
--[[
	Fx/AzureBlade — 청의 검사 이펙트. 푸른 칼빛·흰 섬광·잔상·물·검로. (2026-10-25, 같은 날 사용자 말 설명으로 다시 짬)

	  집중 베기     조금 뽑다 챙 멈춤(Ching) → 잔상을 남기고(Slip) 앞 두 칸을 블링크로 지나 작게 기운 검흔(SmallCuts) → 딸깍 → 잔상을 남기고 제자리로
	  진 발도술     (2026-10-30 다시) 등에서 뽑아(DrawGlint · Release) 강하게 세로로 내리베면 세로 초승달 검기가 내 행 끝까지 날아가고
	                그 뒤를 선이 따라간다(WaveLaunch) → 행 전체 1타(WaveHit) → 칼을 꽂을 때 선에 빛이 달리며 2타(LineStrike)
	  발도술의 절정 반쯤 뽑다 "챙" 하고 멈춰 드러난 날에 빛(Ching) → 사라져(Vanish) 줄 끝에 이미 벤 자세로 서고,
	                지나간 자리에 불규칙한 곧은 검로(PeakPath) → 줄 전체를 가르는 곧은 칼날들이 반짝일 때마다 타격(RowFlash).
	                (2026-10-26 사용자) 제 줄을 따라 곧게 가고, 검로·칼날은 위아래로 ±TILT° 안에서 제각각 기울며 크기는 MARK 배
	  공간의 이해   (2026-10-30 다시, 컷신) 발치 확대(CamFoot) · 내딛기(StepDust) → 오른쪽 등 뒤에서 달리기 준비(CamShoulder) →
	                박차는 순간 사라져(Disappear) 보이지 않게 블링크 17번 — 진영을 고르게 나눈 칸마다(층화 표본) 베기 잔상 · 절정 급 곧은 검흔 ·
	                앞 잔상에서 이어지는 곧은 선(Phantom), 카메라는 오른쪽 위로 올라
	                적 진영을 점점 빠르게 한 바퀴 돌다 멈춘다(CamOrbit) → 제자리를 베며 나타나(Return) 꽂으면 흑백(CutClick) →
	                검흔·선이 하나씩 파바바박 터지는 17연타(MarkHit) → 임팩트 프레임(FinalBreak) → 모션이 끝나면 카메라가 돌아간다
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
	local mark = { From = from, To = to }
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
		task.delay(30, mark.Burst)
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

--=== 진 발도술(2026-10-30 다시 — 강한 세로베기로 검기를 날려 내 행(라인) 전체를 벤다) ===--

--[[
	내 행(시전자 라인)의 적 진영 끝까지 앞 거리. 적 칸 중 옆 거리가 시전자와 같은 칸들의 가장 먼 앞 거리 + 반 칸.
	칸을 모르면(전시장) 가장 먼 대상 너머 한 칸.
]]
local function rowReach(ctx: any): number
	local f = ctx.Forward
	local r = f:Cross(Vector3.yAxis)
	local home = ctx.Actor.Home.Position
	local far = -math.huge
	for _, t in ctx.EnemyTiles or {} do
		local d = t.Position - home
		if math.abs(d:Dot(r)) < 2 then
			far = math.max(far, d:Dot(f) + 3)
		end
	end
	if far == -math.huge then
		for _, p in ctx.Targets do
			far = math.max(far, (p - home):Dot(f) + 6)
		end
	end
	return if far == -math.huge then 18 else far
end

--[[
	강한 세로베기 → 검기: 앞으로 볼록한 세로 초승달이 WAVE_TIME 초에 행 끝까지 날아가고(그 뒤를 선이 따라 자란다 —
	stroke 의 Grow 곡선 1-(1-a)^3 와 같은 곡선으로 움직인다), 끝에 닿으면 행을 세로로 가르는 빛 벽이 서고 행을 따라 바닥 선이 남는다.
	선들은 칼을 꽂을 때(LineStrike) 다시 벤다. (2026-10-30 사용자: "행 전체 타격으로" — 처음엔 열로 잘못 말했다)
]]
local WAVE_TIME = 0.22
function Fx.WaveLaunch(ctx: any)
	local s = st(ctx)
	local f = ctx.Forward
	local start = ctx.Root.Position + f * 1.6 + Vector3.new(0, 0.7, 0)
	local home = ctx.Actor.Home.Position
	local finish = start + f * math.max(4, rowReach(ctx) - (start - home):Dot(f))
	s.waveLines = {}
	table.insert(s.waveLines, stroke(start, finish, { Width = 0.06, Color = ICE, Grow = WAVE_TIME, Keep = true, Bits = 3 }))
	ctx.Vfx.Flash(start, { Color = WHITE, Size = 5, Life = 0.18, Brightness = 6 })
	local n, radius = 10, 2.7
	local segs = {}
	for i = 1, n do
		table.insert(segs, CombatVfx.Part(Vector3.new(0.1, 0.1, 0.5), CFrame.new(start), if i == n / 2 or i == n / 2 + 1 then WHITE else AZURE))
	end
	local function arcPoint(center: Vector3, k: number, grow: number): Vector3
		local th = math.rad(-75 + 150 * k)
		return center + (Vector3.yAxis * math.sin(th) + f * ((math.cos(th) - 1) * 0.55)) * (radius * grow)
	end
	CombatVfx.Timed(WAVE_TIME, function(a)
		local center = start:Lerp(finish, 1 - (1 - a) ^ 3)
		local grow = 0.85 + 0.35 * a
		for i, seg in segs do
			local p0, p1 = arcPoint(center, (i - 1) / n, grow), arcPoint(center, i / n, grow)
			local w = 0.08 + 0.42 * math.sin(math.pi * (i - 0.5) / n)
			seg.Size = Vector3.new(w * 0.35, w, (p1 - p0).Magnitude + 0.05)
			seg.CFrame = CFrame.lookAt(p0:Lerp(p1, 0.5), p1)
		end
	end, function()
		for _, seg in segs do
			seg:Destroy()
		end
		-- 행을 세로로 가르는 빛 벽(잠깐 — 검기가 지나간 길) + 행을 따라 바닥에 남는 선
		local g0 = Vector3.new(start.X, ctx.Ground, start.Z)
		local g1 = Vector3.new(finish.X, ctx.Ground, finish.Z)
		local length = (g1 - g0).Magnitude
		local wall = CombatVfx.Part(Vector3.new(0.06, 4.4, length), CFrame.lookAt(g0:Lerp(g1, 0.5), g1) * CFrame.new(0, 2.2, 0), WHITE)
		CombatVfx.Timed(0.3, function(t)
			wall.Transparency = t
			wall.Size = Vector3.new(0.06 + 0.5 * t, 4.4 + 1.2 * t, length)
		end, function()
			wall:Destroy()
		end)
		table.insert(s.waveLines, stroke(g0 + Vector3.new(0, 0.1, 0), g1 + Vector3.new(0, 0.1, 0), { Width = 0.05, Color = ICE, Grow = 0.06, Keep = true, Bits = 2 }))
		ctx.Vfx.Flash(finish, { Color = ICE, Size = 7, Life = 0.2, Brightness = 5 })
	end)
end

-- 1타: 검기가 내 행의 적들을 세로로 벤다
function Fx.WaveHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Arc(ctx, p, 0, 70, -70, { Radius = 2.4, Width = 0.5, Color = AZURE, Core = WHITE, Sweep = 0.03, Life = 0.2 })
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 10, Speed = 18 })
end

-- 2타(칼을 꽂는 순간): 검기를 따라간 선과 행을 따라 남은 바닥 선에 번개처럼 빛이 달리고 터진다
-- (대상이 여럿이어도 선은 첫 대상 때 한 번 — 목록을 비워 둔다. 사건 표는 쓸 때마다 같은 표라 그것으로 가리면 두 번째 사용부터 안 터진다)
function Fx.LineStrike(ctx: any, _ev: any, at: Vector3?)
	local s = st(ctx)
	local lines = s.waveLines or {}
	s.waveLines = {}
	for _, m in lines do
		if m.From then
			ctx.Vfx.Lightning(m.From, m.To, { Color = ICE })
		end
		m.Burst()
	end
	local p = at or ctx.Target
	cuts(ctx, p, 2, 2.4)
	ctx.Vfx.Sparks(p, { Color = ICE, Count = 10, Speed = 20 })
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

--=== 공간의 이해(2026-10-30 다시 — 컷신: 발 디딤 → 달리기 준비 → 보이지 않게 블링크 17번 → 제자리에서 납도 → 검흔 17개가 하나씩 터짐) ===--

--[[
	필드 상자(전투 공간의 앞 u · 옆 v · 높이 y). 적 진영 칸(ctx.EnemyTiles — 전투 화면이 넘겨준다)의 가운데들에서 u·v 범위를 잡고
	칸 반 칸만큼 넓힌다. 칸을 모르면(전시장) 첫 대상을 첫 열 가운데로 6×3 칸을 어림한다.
	돌려주는 것: { Base, F, R, U0, U1, V0, V1, Y0, Y1 } — 월드 점 = Base + F·u + R·v + (0, y, 0)
]]
local PITCH = 6
local function fieldBox(ctx: any): any
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

local function boxWorld(box: any, l: Vector3): Vector3
	return box.Base + box.F * l.X + box.R * l.Y + Vector3.new(0, l.Z, 0)
end

--[[
	화면 색(애니 연출): 시간이 멎은 듯 빛이 빠지고(CutClick) → 한 프레임 흑백 대비(임팩트 프레임) → 하얗게 번쩍였다 돌아온다(SpaceBreak).
	Lighting 의 ColorCorrectionEffect 하나를 배우마다 돌려 쓴다. 관전 화면(ctx.Quiet)은 손대지 않는다.
]]
local function grading(ctx: any): ColorCorrectionEffect?
	if ctx.Quiet then
		return nil
	end
	local s = st(ctx)
	if not s.cc or not s.cc.Parent then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "AzureBladeCut"
		cc.Parent = game:GetService("Lighting")
		s.cc = cc
		-- 안전장치: 스킬이 끊겨도 4초 뒤엔 없앤다
		task.delay(4, function()
			if cc.Parent then
				cc:Destroy()
			end
		end)
	end
	return s.cc
end

local function sineInOut(x: number): number
	return -(math.cos(math.pi * x) - 1) / 2
end

--[[
	카메라 굴곡(2026-10-30 사용자: "카메라 움직임 함수에 굴곡을 추가해서 딱딱 끊기는 느낌이 없게").
	컷신 카메라는 샷끼리 넘겨줄 때 빠르기가 0 이 되게 이어 붙인다(발치 → 어깨 너머 → 공전 → 맺음 자리 → 모션이 끝나면 감독이 0.45초 sineInOut 으로 놓음).
	공전 각 = 4x³ − 3x⁴: 빠르기 12x²(1−x) — 0 에서 아주 천천히 일어나 2/3 지점까지 점점 빨라지고, 끝에서 부드럽게 0 으로 멈춘다.
]]
local function orbitEase(x: number): number
	return x * x * x * (4 - 3 * x)
end

-- 끌며 멈추기 1 − (1−x)⁴(1+4x): 빠르기 20x(1−x)³ — 0 에서 일어나 1/4 지점에서 가장 빠르고, 긴 꼬리로 천천히 끌며 멈춘다
-- (2026-10-30 사용자: "카메라가 어깨 너머에서 멈출 때 더 끌면서 멈추는 느낌으로")
local function dragOut(x: number): number
	return 1 - (1 - x) ^ 4 * (1 + 4 * x)
end

-- 들머리: 내딛는 오른발을 무릎 높이에서 내려다보며 확대(조금씩 다가간다 — 발과 발밑 땅이 화면 가운데)
function Fx.CamFoot(ctx: any)
	local s = st(ctx)
	local home = ctx.Actor.Home
	local g = ctx.Ground - home.Y
	local look = home * Vector3.new(0.5, g + 0.25, -0.8)
	local a0, a1 = home * Vector3.new(2.7, g + 1.6, -3.7), home * Vector3.new(2.1, g + 1.25, -2.9)
	-- 어깨 너머 샷(0.45초)이 시작할 때 딱 멈추도록 0.45초에 감속해 닿는다
	ctx.Shot(0.45, function(u)
		local cf = CFrame.lookAt(a0:Lerp(a1, 1 - (1 - u) ^ 2), look)
		s.cam = cf
		return cf
	end)
end

-- 달리기 준비: 시전자의 오른쪽 등 뒤(어깨 너머로 적 진영을 본다). 발치에서 빠르게 넘어와 SETTLE 초 동안 끌며 멈추고(dragOut),
-- 사라지는 순간(ev.d 초)까지 천천히 다가간다(버티는 동안에도 멈춰 있지 않고, 공전이 시작할 때 빠르기 0 으로 넘겨준다).
-- 2026-10-30 사용자: "끌리는 게 못해도 2초는 돼야" — 0.6 → 2초(모션도 준비 자세를 그만큼 더 버틴다)
local SETTLE = 2
function Fx.CamShoulder(ctx: any, ev: any)
	local s = st(ctx)
	local home = ctx.Actor.Home
	local d = (ev and ev.d) or 0.76
	local from: CFrame = s.cam or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame) or home
	local goal = CFrame.lookAt(home * Vector3.new(3.1, 1.9, 6.6), home * Vector3.new(-0.6, 0, -12))
	ctx.Shot(d, function(_, t)
		local tt = math.min(t, d)
		local dolly = goal * CFrame.new(0, 0, -0.9 * sineInOut(tt / d))
		local cf = from:Lerp(dolly, dragOut(math.min(1, tt / math.min(SETTLE, d))))
		s.cam = cf
		return cf
	end)
end

--[[
	블링크 동안 한 방향으로만 도는 카메라 한 줄기: 어깨 너머 자리에서 시전자 오른쪽으로 돌기 시작해 위로 천천히 올라 적 진영
	(필드 상자 — 잔상이 흩어지는 곳)을 비추고(RISE 초) → 진영 가운데를 점점 빠르게 돌다 → 끝에서 부드럽게 감속해 ev.d 초(시전자가 제자리에
	나타나는 순간)에 **맺음 자리**(시전자 오른쪽 뒤 높이 — 어깨 너머로 시전자와 진영을 함께 담는다)에 닿아 멈추고, 검흔이 다 터질 때까지 그대로 둔다.
	전투 카메라로는 공격(모션)이 다 끝난 뒤 감독이 Shot 을 놓으며 돌아간다(2026-10-30 사용자: "검기들이 터지기 직전에 카메라가 기존 화면에
	딱 고정되는데, 그러지 말고 공격이 완전히 종료된 후에 카메라가 원위치로" — 전엔 전투 카메라 자리에서 멈췄다).
	각 φ 는 진영 가운데에서 본 수평 방향(월드 x·z). 처음부터 끝까지 φ 가 한 방향으로만 늘어난다(한 바퀴 + 맺음 자리 각까지).
	2026-10-30 사용자: "카메라가 움직였다가 역방향으로 돌아(대략 2초 위치)" — 올라가는 길과 도는 길이 따로라 방향이 꺾였다 → 한 줄기로.
]]
function Fx.CamOrbit(ctx: any, ev: any)
	local s = st(ctx)
	local total = (ev and ev.d) or 2.4
	local RISE = 0.75
	local box = fieldBox(ctx)
	local center = boxWorld(box, Vector3.new((box.U0 + box.U1) / 2, (box.V0 + box.V1) / 2, 1))
	local r0 = math.max(box.U1 - box.U0, box.V1 - box.V0) / 2 + 4
	local home = ctx.Actor.Home.Position
	local base = CFrame.lookAt(home + box.R * 11 - box.F * 8 + Vector3.new(0, 12, 0), home + box.F * ((center - home):Dot(box.F) * 0.55))
	local from: CFrame = s.cam or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame) or base
	local look0 = from.Position + from.LookVector * 10
	local function polar(p: Vector3): (number, number, number)
		local d = p - center
		return math.atan2(d.Z, d.X), Vector3.new(d.X, 0, d.Z).Magnitude, d.Y
	end
	local phiS, rS, hS = polar(from.Position)
	local phiE, r1, h1 = polar(base.Position)
	-- 도는 방향: 처음 움직임이 시전자 오른쪽(box.R)으로 가는 쪽. 한 바퀴 + 그 방향으로 맺음 자리 각까지
	local dir = if Vector3.new(-math.sin(phiS), 0, math.cos(phiS)):Dot(box.R) >= 0 then 1 else -1
	local sweep = 2 * math.pi + (dir * (phiE - phiS)) % (2 * math.pi)
	ctx.Shot(total, function(_, t)
		local tt = math.min(t, total)
		local k = orbitEase(tt / total)
		local swept = sweep * k
		-- 반지름: 어깨 너머 → (RISE 초에 걸쳐) 진영 둘레 r0 → (나머지 동안) 맺음 자리 r1 — 둘 다 sineInOut 이라 이음매에서 빠르기 0.
		-- 높이: 도는 내내 한 곡선으로 조금씩 올라간다(어깨 높이 → 맺음 자리 높이, 2026-10-30 사용자 "돌면서 약간 위로 올라가게도 …
		-- 바라보는 방향은 여전히 적 진영" — 바라보는 곳은 진영 가운데 그대로)
		local rise = sineInOut(math.min(1, tt / RISE))
		local grow = sineInOut(math.clamp((tt - RISE) / math.max(0.1, total - RISE), 0, 1))
		local rad = rS + (r0 - rS) * rise + (r1 - r0) * grow
		local a = phiS + dir * swept
		local pos = center + Vector3.new(math.cos(a) * rad, hS + (h1 - hS) * sineInOut(tt / total), math.sin(a) * rad)
		-- 끝 20% 동안 바라보는 방향을 맺음 자리의 방향으로 맞춘다(끝에서 자리·방향이 맺음 자리와 같다)
		local w = sineInOut(math.clamp((k - 0.8) / 0.2, 0, 1))
		local cf = CFrame.new(pos) * CFrame.lookAt(pos, look0:Lerp(center, rise)).Rotation:Lerp(base.Rotation, w)
		s.cam = cf
		return cf
	end)
end

-- 발을 내딛는 순간 발치에 먼지·고리
function Fx.StepDust(ctx: any)
	local feet = Common.Feet(ctx)
	Common.Land(ctx.Vfx, feet, 0.45)
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.1, 0)), { R0 = 0.3, R1 = 2.2, Color = ICE, Life = 0.35, Width = 0.08, Height = 0.03 })
end

-- 시전자 몸(무기까지)을 내 화면에서만 숨긴다/보인다(LocalTransparencyModifier — 원래 투명도는 건드리지 않는다)
local function setHidden(model: Instance, hidden: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = if hidden then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
end

-- 박차는 순간 사라진다(블링크 동안 보이지 않는다). 안전장치: 모션이 끊기면 다시 보인다
function Fx.Disappear(ctx: any)
	local s = st(ctx)
	local actor = ctx.Actor
	s.hidden = true
	s.phantoms = {}
	s.markEv = nil
	s.slots = nil -- 첫 Phantom 이 이번 시전의 잔상 자리들을 새로 고른다
	-- 달려 나가는 도중이라 몸(Torso)은 제자리보다 앞에 있다 — 번쩍·먼지·선을 몸 자리에서
	local torso = actor.Model:FindFirstChild("Torso") :: BasePart?
	local body = if torso then torso.Position else ctx.Root.Position
	s.lastAt = body -- 잔상을 잇는 선은 사라진 자리에서 시작한다
	ctx.Vfx.Flash(body, { Color = WHITE, Size = 6, Life = 0.18, Brightness = 6 })
	ctx.Vfx.Dust(Vector3.new(body.X, ctx.Ground, body.Z), { Color = ICE, Count = 12 })
	stroke(body, body + ctx.Forward * 9, { Width = 0.06, Color = ICE, Grow = 0.05, Life = 0.25 })
	setHidden(actor.Model, true)
	task.spawn(function()
		repeat
			task.wait(0.25)
		until not s.hidden or not actor.Model.Parent or not actor.Animator:IsBusy()
		if s.hidden then
			s.hidden = false
			setHidden(actor.Model, false)
		end
	end)
end

--[[
	잔상 자세마다 그 베기가 지나간 곧은 검로(시작 → 끝, 몸 공간 — 오른쪽 x · 위 y · 앞 −z, 뿌리 기준. 땅은 y −3).
	베고 난 끝 자세만 쓴다 — 2026-10-30 사용자: "매 동작은 항상 베는 동작이어야 해. 검을 들고서 있는 동작은 없애"(OUT·ZAN 뺌),
	"검로들은 다 직선으로".
]]
local PHANTOM_CUTS = {
	DRAWCUT = { Vector3.new(-4, 0.5, -2.5), Vector3.new(4.5, 0.3, -1.5) }, -- 뽑으며 수평으로 오른쪽까지
	SWEEP = { Vector3.new(4.5, 0.2, -2), Vector3.new(-4.5, 0.4, -2.5) }, -- 오른쪽 → 왼쪽 크게
	CUTDOWN = { Vector3.new(0.3, 4.5, -2.5), Vector3.new(0.2, -2.8, -3.2) }, -- 위 → 앞 아래
	KESA = { Vector3.new(3, 4, -2), Vector3.new(-3, -2.8, -2.8) }, -- 오른 어깨 위 → 왼 아래
	RISE = { Vector3.new(-2.5, -2.6, -2.5), Vector3.new(3, 4.5, -1.5) }, -- 왼 아래 → 오른 위
	SLASHR = { Vector3.new(-4.5, 0.8, -2.5), Vector3.new(4.5, -0.3, -2) }, -- 오른쪽 아래로 조금 기운 가로베기
	SKYRISE = { Vector3.new(-2, -2, -2), Vector3.new(2.5, 5.5, -1.5) }, -- 뛰어올라 오른 위로
	SIDEKESA = { Vector3.new(3.5, 2.5, -1), Vector3.new(-3, -2.8, -2.5) }, -- 틀어 낮게 왼 아래로
	BACKSWEEP = { Vector3.new(-4, 0.5, -1.5), Vector3.new(4, 0.2, 2.5) }, -- 뒤돌며 휩쓸기
}
local PHANTOM_POSES = { "DRAWCUT", "SWEEP", "CUTDOWN", "KESA", "RISE", "SLASHR", "SKYRISE", "SIDEKESA", "BACKSWEEP" }
-- 검로 크기: 2026-10-30 사용자 "검로 크기를 더 키워주고(발도술의 절정 급)" — 길이 1.6배, 굵기는 절정의 PeakPath 와 같은 범위(× MARK)
-- → 같은 날 "굵기를 60%정도로 줄이고, 길이를 40% 더 늘리자" — 길이 1.6 × 1.4, 굵기 × 0.6
local CUT_LENGTH = 1.6 * 1.4
local CUT_WIDTH = { 0.6 * 0.06 * MARK, 0.6 * 0.16 * MARK }

--[[
	cf(뿌리) 둘레에 name 자세의 곧은 검로 두 끝(조금씩 흔들고 scale 배 늘인다).
	땅 밑으로 내려가는 끝은 같은 줄을 따라 땅 높이까지만 줄인다(꺾지 않아 곧게 남는다).
]]
local function cutLine(ctx: any, rng: Random, name: string, cf: CFrame, scale: number): (Vector3, Vector3)
	local cut = PHANTOM_CUTS[name]
	local function jitter(v: Vector3): Vector3
		return cf * (v + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4)))
	end
	local a, b = jitter(cut[1]), jitter(cut[2])
	local mid, half = a:Lerp(b, 0.5), (b - a) * (scale * rng:NextNumber(0.9, 1.2) / 2)
	local floor = ctx.Ground + 0.1
	local function above(p: Vector3): Vector3
		if p.Y >= floor or mid.Y <= floor then
			return Vector3.new(p.X, math.max(p.Y, floor), p.Z)
		end
		return mid + (p - mid) * ((mid.Y - floor) / (mid.Y - p.Y))
	end
	return above(mid - half), above(mid + half)
end

--[[
	잔상 자리 고르기 — 2026-10-30 사용자: "잔상 위치가 가끔씩 겹치거나, 혹은 특정 구역이 비어보이는 문제를 수정".
	층화 표본(jittered grid): 적 진영(필드 상자 안쪽 = 적 칸 범위)을 잔상 수에 맞춘 nu × nv 칸으로 나누고(칸이 정사각형에 가깝게 —
	6 × 3 진영이면 적 칸과 같다) 칸 순서를 섞어 블링크마다 한 칸씩, 칸 가운데 50% 안의 무작위 자리를 쓴다.
	→ 모든 구역에 고르게 하나씩(비는 구역 없음) · 이웃 잔상은 칸의 절반 이상 떨어진다(겹침 없음) · 순서는 무작위라 이리저리 튄다.
]]
local PHANTOMS = 17 -- 모션의 Phantom 사건 수(SpaceCut HitWeights 17 과 같다)
local function phantomSlots(box: any, rng: Random): { Vector3 }
	local u0, v0 = box.U0 + 1, box.V0 + 1
	local lu, lv = box.U1 - 1 - u0, box.V1 - 1 - v0
	local nv = math.max(1, math.floor(math.sqrt(PHANTOMS * lv / lu) + 0.5))
	local nu = math.ceil(PHANTOMS / nv)
	local cells = {}
	for i = 0, nu - 1 do
		for j = 0, nv - 1 do
			table.insert(cells, Vector2.new(i, j))
		end
	end
	for k = #cells, 2, -1 do -- 섞기(Fisher–Yates)
		local m = rng:NextInteger(1, k)
		cells[k], cells[m] = cells[m], cells[k]
	end
	local slots = {}
	for _, cell in cells do
		local u = u0 + (cell.X + 0.5 + rng:NextNumber(-0.25, 0.25)) * lu / nu
		local v = v0 + (cell.Y + 0.5 + rng:NextNumber(-0.25, 0.25)) * lv / nv
		table.insert(slots, boxWorld(box, Vector3.new(u, v, 0)))
	end
	return slots
end

--[[
	블링크 한 번: 고른 자리에, 무작위로 돈 베기 자세(바로 앞 잔상과는 다른 자세)의 잔상 하나 + 그 베기가 지나간 곧은 검흔 하나 +
	바로 앞 자리(첫 번째는 박찬 자리)에서 이어지는 곧은 선 하나. 셋 다 칼을 꽂은 뒤 MarkHit 가 하나씩 터뜨린다.
]]
function Fx.Phantom(ctx: any)
	local s = st(ctx)
	s.phantoms = s.phantoms or {}
	local rng = Random.new()
	if not s.slots or #s.slots == 0 then
		s.slots = phantomSlots(fieldBox(ctx), rng)
	end
	local foot = table.remove(s.slots) :: Vector3
	local at = Vector3.new(foot.X, ctx.Actor.Home.Y, foot.Z)
	local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local name
	repeat
		name = PHANTOM_POSES[rng:NextInteger(1, #PHANTOM_POSES)]
	until name ~= s.lastPhantom
	s.lastPhantom = name
	local ghost = Common.Ghost(ctx, pose(name), cf, { Transparency = 0.5, FadeIn = 0.03, Life = 30 })
	local a, b = cutLine(ctx, rng, name, cf, CUT_LENGTH)
	local width = rng:NextNumber(CUT_WIDTH[1], CUT_WIDTH[2])
	local mark = stroke(a, b, { Width = width, Color = ICE, Grow = 0.05, Keep = true, Bits = 4 })
	local link = stroke(s.lastAt or ctx.Actor.Home.Position, at, { Width = 0.1, Color = AZURE, Grow = 0.04, Keep = true, Bits = 2 })
	s.lastAt = at
	table.insert(s.phantoms, { Ghost = ghost, Mark = mark, Link = link, Width = width, At = a:Lerp(b, 0.5) })
	ctx.Vfx.Flash(at, { Color = ICE, Size = 4, Life = 0.15, Brightness = 4 })
end

-- 마지막 잔상에서 제자리로 이어지는 선을 그으며, 제자리를 가로로 베며 나타난다(SLASHR 의 곧은 검로가 한 번 번쩍)
function Fx.Return(ctx: any)
	local s = st(ctx)
	s.hidden = false
	setHidden(ctx.Actor.Model, false)
	if s.lastAt then
		stroke(s.lastAt, ctx.Actor.Home.Position, { Width = 0.1, Color = AZURE, Grow = 0.04, Life = 0.35 })
		s.lastAt = nil
	end
	local a, b = cutLine(ctx, Random.new(), "SLASHR", ctx.Actor.Home, CUT_LENGTH)
	stroke(a, b, { Width = CUT_WIDTH[2], Color = ICE, Grow = 0.04, Life = 0.35 })
	ctx.Vfx.Flash(ctx.Root.Position, { Color = WHITE, Size = 6, Life = 0.2, Brightness = 6 })
	ctx.Vfx.Dust(Common.Feet(ctx), { Color = ICE, Count = 10 })
end

-- 딸깍: 칼을 꽂는 소리와 함께 세상이 멎는다(빛이 빠지고 차가운 빛 — 사용자가 좋다고 한 흑백)
function Fx.CutClick(ctx: any)
	Fx.Click(ctx)
	ctx.Sound(SOUND.Ching, 0.55, 1.6)
	local cc = grading(ctx)
	if cc then
		CombatVfx.Timed(0.12, function(a)
			cc.Saturation = -0.85 * a
			cc.Contrast = 0.3 * a
			cc.Brightness = -0.06 * a
			cc.TintColor = Color3.new(1, 1, 1):Lerp(c(205, 225, 255), a)
		end)
	end
end

-- 17연타 한 번: 남은 잔상·검흔 중 무작위 하나가 번쩍이며 터진다(파바바박 — 대상이 여럿이어도 터지는 검흔은 한 사건에 하나).
-- 터질 때도 곧게: 같은 줄을 따라 양 끝으로 조금 더 뻗는 흰 획(원호 없음)
function Fx.MarkHit(ctx: any, ev: any, at: Vector3?)
	local s = st(ctx)
	if s.markEv ~= ev then
		s.markEv = ev
		local list = s.phantoms or {}
		if #list > 0 then
			local p = table.remove(list, math.random(#list))
			p.Mark.Burst()
			p.Link.Burst()
			if p.Ghost then
				p.Ghost.Vanish(0.15)
			end
			ctx.Vfx.Flash(p.At, { Color = WHITE, Size = 5, Life = 0.12, Brightness = 6 })
			local d = (p.Mark.To - p.Mark.From).Unit
			stroke(p.Mark.From - d, p.Mark.To + d, { Width = p.Width * 1.3, Color = WHITE, Grow = 0.03, Life = 0.12 })
		end
	end
	if at then
		ctx.Vfx.Sparks(at, { Color = ICE, Count = 4, Speed = 14 })
	end
end

-- 마지막: 임팩트 프레임(흑백 강한 대비) · 흰 번쩍 · 남은 잔상·검흔 정리 → 색이 돌아온다
function Fx.FinalBreak(ctx: any)
	local s = st(ctx)
	for _, p in s.phantoms or {} do
		p.Mark.Burst()
		p.Link.Burst()
		if p.Ghost then
			p.Ghost.Vanish(0.2)
		end
	end
	s.phantoms = {}
	local field = ctx.EnemyCenter
	ctx.Vfx.Flash(field, { Color = WHITE, Size = 22, Life = 0.4, Brightness = 7 })
	ctx.Vfx.Shockwave(Vector3.new(field.X, ctx.Ground + 0.1, field.Z), { Color = ICE, Radius = 16, Life = 0.55 })
	local cc = grading(ctx)
	if cc then
		CombatVfx.Timed(0.6, function(a)
			if a < 0.12 then
				cc.Saturation, cc.Contrast, cc.Brightness = -1, 1.4, 0.05
				cc.TintColor = Color3.new(1, 1, 1)
			else
				local k = (a - 0.12) / 0.88
				cc.Saturation = -1 + k
				cc.Contrast = 0.5 * (1 - k)
				cc.Brightness = 0.45 * (1 - k) ^ 2
			end
		end, function()
			cc:Destroy()
			s.cc = nil
		end)
	end
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
