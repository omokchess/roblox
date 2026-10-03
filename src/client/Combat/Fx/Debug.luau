--!strict
--[[
	Fx/Debug — 보스 디버그 이펙트. (2026-09-29, 2026-10-03 다시 씀 — 정십이면체가 투사체를 쏜다)

	2026-10-03 사용자: "돌아가거나, 움직이면서 투사체 같은 걸 발사하면서 공격". 자리는 부위 가운데(ctx.Root = 다면체 가운데,
	정면 = 아군 쪽 ctx.Forward). 쏘는 이펙트의 ev.d = 날아가는 초 — 모션의 Hit 시각에 닿게 맞춰 두었다(Motions/Debug.luau).
	  머리      붉은 중단점 탄 하나
	  서브코어-삭제   마젠타 삭제 조각 한 줌(아군 칸에 흩어져 꽂힌다)
	  서브코어-패치   휘어 날아가는 초록 탄 셋 / 패치 적용은 초록 빛방울을 아군 진영에 뿌린다
	  코어      큰 마젠타 덩어리(코어 덤프) · 붉은 화살표 탄 둘(널 포인터) · 하늘로 쏜 오류 조각이 쏟아짐(메모리 누수)
]]
local Common = require(script.Parent.Common)
local DebugBoss = require(script.Parent.Parent.DebugBoss)
local c = Common.c

local RED = c(255, 48, 60)
local MAGENTA = c(255, 70, 200)
local CYAN = c(70, 220, 255)
local GREEN = c(60, 235, 100)
local SHARDS = { MAGENTA, CYAN, c(40, 34, 60) }

local Fx = {}

-- 네모 글리치 조각이 튄다
local function shards(Vfx: any, at: Vector3, dir: Vector3?, count: number, speed: number, colors: { Color3 }?)
	Vfx.Burst(at, { Count = count, Colors = colors or SHARDS, Size = 0.5, Speed = speed, Dir = dir, Spread = 70, Gravity = 40, Life = 0.7, Material = Enum.Material.Neon })
end

-- 부위 반지름(다면체 둘레)
local function radius(ctx: any): number
	local key = ctx.Actor and ctx.Actor.BossKey
	return DebugBoss.Radius[key] or 2.3
end

-- 쏘는 자리: 다면체 앞면 바로 앞
local function muzzle(ctx: any): Vector3
	return ctx.Root.Position + ctx.Forward * (radius(ctx) + 0.6)
end

-- 날아가는 빛 덩어리(공 + 겉 빛)
local function orb(Vfx: any, size: number, color: Color3): () -> Model
	return function()
		local m = Instance.new("Model")
		local core = Vfx.Part(Vector3.one * size * 0.55, CFrame.new(), c(255, 240, 250), Enum.Material.Neon, Enum.PartType.Ball)
		local glow = Vfx.Part(Vector3.one * size, CFrame.new(), color, Enum.Material.Neon, Enum.PartType.Ball)
		glow.Transparency = 0.35
		core.Parent, glow.Parent = m, m
		m.PrimaryPart = glow
		m.Parent = Vfx.Folder()
		return m
	end
end

-- 날아가는 네모 조각(돈다)
local function cube(Vfx: any, size: number, color: Color3): () -> BasePart
	return function()
		return Vfx.Part(Vector3.one * size, CFrame.new(), color, Enum.Material.Neon)
	end
end

local function flight(ev: any, default: number): number
	return if ev and ev.d then ev.d else default
end

--=== 머리: 중단점 탄 ===--

function Fx.BeamCharge(ctx: any)
	local p = muzzle(ctx)
	ctx.Vfx.Flash(p, { Color = RED, Size = 3, Life = 0.35, Brightness = 3 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 2.4, R1 = 0.4, Color = RED, Life = 0.3, Width = 0.2, Facing = true })
	ctx.Vfx.Implode(p, { Color = RED, Radius = 3, Count = 8, Life = 0.25 })
end

function Fx.Bolt(ctx: any, ev: any)
	local from = muzzle(ctx)
	ctx.Vfx.Flash(from, { Color = RED, Size = 5, Life = 0.2 })
	-- 코어 뒤에서 쏠 때도 있어 살짝 위로 휘어 날린다
	ctx.Vfx.Projectile(from, ctx.Target, { Time = flight(ev, 0.16), Arc = 2, Build = orb(ctx.Vfx, 1.3, RED), TrailColor = RED })
end

function Fx.BeamHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = RED, Size = 6, Life = 0.25 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.5, R1 = 3.2, Color = RED, Life = 0.3, Width = 0.25, Facing = true })
	shards(ctx.Vfx, p, ctx.Forward, 8, 14, { RED, c(255, 200, 200) })
end

--=== 서브코어-삭제: 삭제 조각 한 줌 ===--

function Fx.DeleteCharge(ctx: any)
	ctx.Vfx.Implode(muzzle(ctx), { Color = MAGENTA, Radius = 4, Count = 12, Life = 0.24 })
end

function Fx.DeleteVolley(ctx: any, ev: any)
	local from = muzzle(ctx)
	local to = ctx.Target
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	ctx.Vfx.Flash(from, { Color = MAGENTA, Size = 5, Life = 0.2 })
	for i = 1, 7 do
		local spot = Vector3.new(to.X, ctx.Ground + 0.3, to.Z) + right * (i - 4) * 1.6 + ctx.Forward * ((i % 3) - 1) * 1.4
		ctx.Vfx.Projectile(from, spot, { Time = flight(ev, 0.2) * (0.85 + (i % 3) * 0.08), Arc = 1.5 + (i % 2), Spin = 1.5, Build = cube(ctx.Vfx, 0.55, if i % 3 == 0 then CYAN else MAGENTA), TrailColor = MAGENTA })
	end
end

function Fx.DeleteSlam(ctx: any)
	local p = ctx.Target
	local g = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
	shards(ctx.Vfx, g + Vector3.new(0, 0.5, 0), Vector3.new(0, 1, 0), 18, 20)
	ctx.Vfx.Ring(CFrame.new(g), { R0 = 1, R1 = 6, Color = MAGENTA, Life = 0.4, Width = 0.35, Height = 0.1, Segments = 4 })
end

function Fx.DeleteHit(ctx: any, _ev: any, at: Vector3?)
	ctx.Vfx.Flash(at or ctx.Target, { Color = MAGENTA, Size = 5, Life = 0.22 })
end

--=== 서브코어-패치 ===--

-- 강제 적용: 초록 탄 셋이 양옆·위로 휘어 한 점에 모인다
function Fx.PatchShot(ctx: any, ev: any)
	local from = muzzle(ctx)
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	ctx.Vfx.Flash(from, { Color = GREEN, Size = 5, Life = 0.2 })
	for i = -1, 1 do
		local start = from + right * i * 1.2
		ctx.Vfx.Projectile(start, ctx.Target, { Time = flight(ev, 0.22), Arc = 2.5 - math.abs(i), Build = orb(ctx.Vfx, 0.8, GREEN), TrailColor = GREEN })
	end
end

function Fx.PatchHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = GREEN, Size = 5, Life = 0.22 })
	shards(ctx.Vfx, p, ctx.Forward, 6, 12, { GREEN, CYAN })
end

-- 패치 적용: 초록빛을 내며 빛방울을 아군 진영 위로 흩뿌린다(칸 색은 BattleClient 가 바꾼다)
function Fx.PatchApply(ctx: any)
	local from = muzzle(ctx)
	ctx.Vfx.Flash(from, { Color = GREEN, Size = 7, Life = 0.5, Brightness = 3 })
	ctx.Vfx.Sparks(from, { Color = GREEN, Count = 16, Speed = 12 })
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	local field = Vector3.new(ctx.Root.X, ctx.Ground + 0.3, ctx.Root.Z) + ctx.Forward * 22
	for i = 1, 6 do
		local spot = field + right * ((i - 3.5) * 3) + ctx.Forward * ((i % 2) * 4 - 2)
		ctx.Vfx.Projectile(from, spot, {
			Time = 0.45 + i * 0.03,
			Arc = 5,
			Build = orb(ctx.Vfx, 0.6, GREEN),
			TrailColor = GREEN,
			OnArrive = function(p: Vector3)
				ctx.Vfx.Flash(p, { Color = GREEN, Size = 3, Life = 0.25 })
			end,
		})
	end
end

--=== 코어 ===--

-- 결정(코어 앞에 뜬 팔면체) 자리
local function crystal(ctx: any): Vector3
	return ctx.Root.Position + ctx.Forward * 7.8
end

function Fx.DumpCharge(ctx: any)
	local p = crystal(ctx)
	ctx.Vfx.Implode(p, { Color = MAGENTA, Radius = 9, Count = 18, Life = 0.32 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 6, R1 = 1, Color = MAGENTA, Life = 0.32, Width = 0.3, Facing = true })
end

-- 코어 덤프: 결정에서 큰 마젠타 덩어리를 쏜다(닿으면 DumpHit 가 아군 진영을 쓸어 터뜨린다)
function Fx.CoreDump(ctx: any, ev: any)
	local from = crystal(ctx)
	ctx.Vfx.Flash(from, { Color = MAGENTA, Size = 12, Life = 0.4, Brightness = 5 })
	shards(ctx.Vfx, from, ctx.Forward + Vector3.new(0, 0.4, 0), 14, 20)
	ctx.Vfx.Projectile(from, ctx.Target, { Time = flight(ev, 0.2), Arc = 2, Build = orb(ctx.Vfx, 3.2, MAGENTA), TrailColor = MAGENTA })
end

function Fx.DumpHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = MAGENTA, Size = 9, Life = 0.3, Brightness = 5 })
	shards(ctx.Vfx, p, Vector3.new(0, 1, 0), 14, 18)
	ctx.Vfx.Shockwave(Vector3.new(p.X, ctx.Ground + 0.2, p.Z), { Color = MAGENTA, Radius = 16, Life = 0.5 })
end

-- 널 포인터: 붉은 화살표 탄 둘(길쭉한 네온 + 끝 촉)이 두 갈래로
function Fx.NullPointer(ctx: any, ev: any)
	local from = crystal(ctx)
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	ctx.Vfx.Flash(from, { Color = RED, Size = 10, Life = 0.35, Brightness = 5 })
	for _, side in { -1, 1 } do
		local to = ctx.Target + right * side * 3
		ctx.Vfx.Projectile(from + right * side, to, {
			Time = flight(ev, 0.18),
			Build = function()
				local m = Instance.new("Model")
				local shaft = ctx.Vfx.Part(Vector3.new(0.35, 0.35, 2.8), CFrame.new(0, 0, 0.6), RED, Enum.Material.Neon)
				local tip = ctx.Vfx.Part(Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0, -1) * CFrame.Angles(math.rad(45), 0, math.rad(45)), c(255, 200, 200), Enum.Material.Neon)
				shaft.Parent, tip.Parent = m, m
				m.PrimaryPart = shaft
				m.Parent = ctx.Vfx.Folder()
				return m
			end,
			TrailColor = RED,
		})
	end
end

function Fx.NullHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	local g = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
	ctx.Vfx.Ring(CFrame.new(g), { R0 = 1, R1 = 6, Color = RED, Life = 0.4, Width = 0.4, Height = 0.1, Segments = 4 })
	ctx.Vfx.Flash(p, { Color = RED, Size = 6, Life = 0.22 })
end

-- 메모리 누수: 코어 위로 오류 조각을 쏘아 올렸다가(LeakRise) 아군 위로 쏟아붓는다(LeakRain)
function Fx.LeakRise(ctx: any)
	local top = ctx.Root.Position + Vector3.new(0, radius(ctx) + 1, 0)
	ctx.Vfx.Burst(top, { Count = 14, Colors = SHARDS, Size = 0.6, Speed = 30, Dir = Vector3.new(0, 1, 0), Spread = 25, Gravity = 10, Life = 0.4, Material = Enum.Material.Neon })
end

function Fx.LeakRain(ctx: any, ev: any)
	local sky = ctx.Root.Position + Vector3.new(0, radius(ctx) + 10, 0)
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	local to = ctx.Target
	for i = 1, 8 do
		local spot = Vector3.new(to.X, ctx.Ground + 0.3, to.Z) + right * ((i - 4.5) * 1.3) + ctx.Forward * (((i * 7) % 5) - 2)
		ctx.Vfx.Projectile(sky + right * (i - 4.5), spot, { Time = flight(ev, 0.22) * (0.9 + (i % 2) * 0.1), Arc = 3, Spin = 2, Build = cube(ctx.Vfx, 0.6, SHARDS[(i % 3) + 1]), TrailColor = MAGENTA })
	end
end

function Fx.LeakHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	shards(ctx.Vfx, p + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0), 12, 14)
	ctx.Vfx.Flash(p, { Color = MAGENTA, Size = 5, Life = 0.2 })
end

-- 부위가 부서진다: 검은 조각과 마젠타 번쩍임
function Fx.Break(ctx: any)
	local p = ctx.Root.Position
	ctx.Vfx.Flash(p, { Color = MAGENTA, Size = 4 + radius(ctx) * 1.6, Life = 0.4 })
	shards(ctx.Vfx, p, Vector3.new(0, 1, 0), 26, 22, { c(40, 34, 60), c(58, 52, 80), MAGENTA, CYAN })
	ctx.Vfx.Shake(0.4, 0.3)
end


--=== 2026-10-03: 페이즈 해금 스킬·궁극기·버프·충전 ===--

local EnemyDefinitions = require(game:GetService("ReplicatedStorage").Shared.EnemyDefinitions)
local BLUE = c(60, 120, 255)

-- 부위 색(EnemyDefinitions 의 Color — 예고 범위·레이저와 같은 색)
local function partColor(ctx: any): Color3
	local key = ctx.Actor and ctx.Actor.BossKey
	for _, part in EnemyDefinitions.Get("Debug").Parts or {} do
		if part.Key == key then
			return part.Color or MAGENTA
		end
	end
	return MAGENTA
end

-- 버프: 둘레 빛이 빨려 들었다가(모으기) 고리 둘이 퍼진다(퍼뜨리기)
function Fx.BuffGather(ctx: any)
	local col = partColor(ctx)
	ctx.Vfx.Implode(ctx.Root.Position, { Color = col, Radius = radius(ctx) * 2.5, Count = 14, Life = 0.35 })
end

function Fx.BuffPulse(ctx: any)
	local col = partColor(ctx)
	local p = ctx.Root.Position
	ctx.Vfx.Flash(p, { Color = col, Size = radius(ctx) * 3, Life = 0.4, Brightness = 4 })
	ctx.Vfx.Ring(CFrame.new(p), { R0 = radius(ctx), R1 = radius(ctx) * 3.2, Color = col, Life = 0.45, Width = 0.35, Height = 0.15 })
	ctx.Vfx.Ring(CFrame.new(p) * CFrame.Angles(math.rad(90), 0, 0), { R0 = radius(ctx), R1 = radius(ctx) * 2.6, Color = c(255, 240, 200), Life = 0.4, Width = 0.25, Height = 0.12 })
	ctx.Vfx.Sparks(p, { Color = col, Count = 18, Speed = 14 })
end

-- 충전: 큰 빛을 빨아들이고 떨린다(두 번 부른다)
function Fx.ChargeStart(ctx: any)
	local col = partColor(ctx)
	local p = ctx.Root.Position
	ctx.Vfx.Implode(p, { Color = col, Radius = radius(ctx) * 4, Count = 22, Life = 0.45 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = radius(ctx) * 3, R1 = radius(ctx) * 0.8, Color = col, Life = 0.45, Width = 0.4, Facing = true })
	ctx.Vfx.Shake(0.15, 0.2)
end

-- 스택 추적: 붉은 탄 셋이 열을 따라 줄지어
function Fx.StackBolt(ctx: any, ev: any)
	local from = muzzle(ctx)
	ctx.Vfx.Flash(from, { Color = RED, Size = 5, Life = 0.2 })
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	for i = -1, 1 do
		local to = ctx.Target + ctx.Forward * (i * 5) + right * 0.01
		ctx.Vfx.Projectile(from, to, { Time = flight(ev, 0.16) * (1 + i * 0.08), Arc = 1.5, Build = orb(ctx.Vfx, 0.9, RED), TrailColor = RED })
	end
end

-- 중단점 폭풍: 하늘에서 붉은 탄이 아군 진영 곳곳에 쏟아진다
function Fx.StormBolts(ctx: any, ev: any)
	local from = muzzle(ctx)
	ctx.Vfx.Flash(from, { Color = RED, Size = 8, Life = 0.3, Brightness = 5 })
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	local field = Vector3.new(ctx.Target.X, ctx.Ground + 0.3, ctx.Target.Z)
	for i = 1, 12 do
		local spot = field + right * (((i * 7) % 6) - 2.5) * 3 + ctx.Forward * (((i * 5) % 3) - 1) * 4
		ctx.Vfx.Projectile(from + Vector3.new(0, 4, 0), spot, { Time = flight(ev, 0.16) * (0.85 + (i % 4) * 0.06), Arc = 6, Build = orb(ctx.Vfx, 0.8, RED), TrailColor = RED })
	end
end

function Fx.StormHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Shockwave(Vector3.new(p.X, ctx.Ground + 0.2, p.Z), { Color = RED, Radius = 14, Life = 0.45 })
	ctx.Vfx.Flash(p, { Color = RED, Size = 7, Life = 0.25 })
end

-- 강제 종료: 3×3 네모 고리가 조여 든다
function Fx.ForceSlam(ctx: any)
	local p = ctx.Target
	local g = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
	ctx.Vfx.Ring(CFrame.new(g), { R0 = 9, R1 = 1.5, Color = MAGENTA, Life = 0.35, Width = 0.5, Height = 0.15, Segments = 4 })
	shards(ctx.Vfx, g + Vector3.new(0, 0.5, 0), Vector3.new(0, 1, 0), 14, 16)
end

-- 버그 심기: 마젠타·초록 씨앗이 칸마다 꽂힌다
function Fx.BugSeeds(ctx: any, ev: any)
	local from = muzzle(ctx)
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	local field = Vector3.new(ctx.Target.X, ctx.Ground + 0.3, ctx.Target.Z)
	for i = 1, 4 do
		local spot = if i == 1 then field else field + right * ((i - 2.5) * 5) + ctx.Forward * ((i % 2) * 4 - 2)
		ctx.Vfx.Projectile(from, spot, {
			Time = flight(ev, 0.22),
			Arc = 4,
			Spin = 2,
			Build = cube(ctx.Vfx, 0.55, if i % 2 == 0 then MAGENTA else GREEN),
			TrailColor = GREEN,
			OnArrive = function(at: Vector3)
				ctx.Vfx.Ring(CFrame.new(at), { R0 = 0.5, R1 = 3, Color = MAGENTA, Life = 0.3, Width = 0.25, Height = 0.1, Segments = 4 })
			end,
		})
	end
end

-- 커널 패닉: 결정에서 거대한 보랏빛 덩어리 → 아군 진영 전체를 덮는 충격파
function Fx.PanicBurst(ctx: any, ev: any)
	local from = crystal(ctx)
	ctx.Vfx.Flash(from, { Color = c(170, 120, 255), Size = 18, Life = 0.5, Brightness = 7 })
	ctx.Vfx.Projectile(from, ctx.Target, { Time = flight(ev, 0.2), Arc = 6, Build = orb(ctx.Vfx, 5, c(150, 100, 255)), TrailColor = MAGENTA })
	ctx.Vfx.Shake(0.5, 0.4)
end

function Fx.PanicHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	local g = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
	ctx.Vfx.Flash(p, { Color = c(170, 120, 255), Size = 14, Life = 0.4, Brightness = 8 })
	ctx.Vfx.Shockwave(g, { Color = c(150, 100, 255), Radius = 24, Life = 0.6 })
	ctx.Vfx.Shockwave(g + Vector3.new(0, 0.1, 0), { Color = MAGENTA, Radius = 14, Life = 0.4 })
	shards(ctx.Vfx, p, Vector3.new(0, 1, 0), 24, 22)
	ctx.Vfx.Shake(0.9, 0.5)
end

-- 무한 재귀: 라인·열 두 갈래 화살표 탄
function Fx.RecursionShot(ctx: any, ev: any)
	local from = crystal(ctx)
	local right = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	ctx.Vfx.Flash(from, { Color = RED, Size = 10, Life = 0.35, Brightness = 5 })
	for _, off in { right * 6, -right * 6, ctx.Forward * 5, -ctx.Forward * 5 } do
		ctx.Vfx.Projectile(from, ctx.Target + off, { Time = flight(ev, 0.18), Arc = 1, Build = orb(ctx.Vfx, 0.9, RED), TrailColor = MAGENTA })
	end
	ctx.Vfx.Projectile(from, ctx.Target, { Time = flight(ev, 0.18), Build = orb(ctx.Vfx, 1.4, c(255, 200, 200)), TrailColor = RED })
end

-- 블루스크린(궁극기): 푸른 빛을 크게 모아 → 화면을 덮는 푸른 번쩍임과 충격파
function Fx.BlueCharge(ctx: any)
	local p = crystal(ctx)
	ctx.Vfx.Implode(p, { Color = BLUE, Radius = 16, Count = 30, Life = 0.4 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 12, R1 = 1, Color = BLUE, Life = 0.4, Width = 0.5, Facing = true })
	ctx.Vfx.Shake(0.3, 0.4)
end

function Fx.BlueScreen(ctx: any, ev: any)
	local from = crystal(ctx)
	ctx.Vfx.Flash(from, { Color = BLUE, Size = 26, Life = 0.6, Brightness = 9 })
	ctx.Vfx.Projectile(from, ctx.Target, { Time = flight(ev, 0.2), Arc = 3, Build = orb(ctx.Vfx, 6, BLUE), TrailColor = c(200, 220, 255) })
end

function Fx.BlueHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	local g = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
	ctx.Vfx.Flash(p, { Color = BLUE, Size = 30, Life = 0.6, Brightness = 10 })
	ctx.Vfx.Shockwave(g, { Color = BLUE, Radius = 30, Life = 0.7 })
	ctx.Vfx.Shockwave(g + Vector3.new(0, 0.1, 0), { Color = c(220, 235, 255), Radius = 16, Life = 0.5 })
	ctx.Vfx.Shake(1.1, 0.6)
end

--[[
	아이디어 8(2026-10-03 사용자): 같은 스킬도 페이즈가 오를수록 커진다. 이펙트 크기·반지름·굵기를 페이즈마다 +15%
	(DebugBoss.Phase 는 BattleClient 가 스냅샷마다 맞춘다). 모든 Fx 함수를 감싸 ctx.Vfx 만 키운 것으로 바꿔 넘긴다.
]]
local SCALE_KEYS = { "Size", "Radius", "R0", "R1", "Width" }
local function scaledVfx(Vfx: any, k: number): any
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
					if type(a) == "table" and (a.Size or a.Radius or a.R1 or a.Width) then
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
for name, fn in Fx do
	Fx[name] = function(ctx: any, ...)
		local k = 1 + 0.15 * math.max(0, (DebugBoss.Phase or 1) - 1)
		if k == 1 then
			return fn(ctx, ...)
		end
		local scaled = table.clone(ctx)
		scaled.Vfx = scaledVfx(ctx.Vfx, k)
		return fn(scaled, ...)
	end
end

return Fx
