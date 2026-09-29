--!strict
-- Fx/Debug — 보스 디버그 이펙트: 붉은 중단점 광선, 삭제(마젠타 조각), 패치(초록), 코어 덤프. (2026-09-29)
-- 자리는 부위 Pivot(바닥 가운데, 정면 = -Z) 기준. 부위 모양은 Combat/DebugBoss.luau.
local Common = require(script.Parent.Common)
local c = Common.c

local RED = c(255, 48, 60)
local MAGENTA = c(255, 70, 200)
local CYAN = c(70, 220, 255)
local GREEN = c(90, 255, 150)
local SHARDS = { MAGENTA, CYAN, c(40, 34, 60) }

local Fx = {}

-- 네모 글리치 조각이 튄다
local function shards(Vfx: any, at: Vector3, dir: Vector3?, count: number, speed: number, colors: { Color3 }?)
	Vfx.Burst(at, { Count = count, Colors = colors or SHARDS, Size = 0.5, Speed = speed, Dir = dir, Spread = 70, Gravity = 40, Life = 0.7, Material = Enum.Material.Neon })
end

-- 머리 얼굴의 중단점 자리
local function eye(ctx: any): Vector3
	return (ctx.Root * CFrame.new(0, 5.7, -2.2)).Position
end

function Fx.BeamCharge(ctx: any)
	local p = eye(ctx)
	ctx.Vfx.Flash(p, { Color = RED, Size = 3, Life = 0.35, Brightness = 3 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 2.4, R1 = 0.4, Color = RED, Life = 0.34, Width = 0.2, Facing = true })
end

function Fx.Beam(ctx: any)
	local from = eye(ctx)
	local to = ctx.Target
	ctx.Vfx.Beam(from, to, { Color = RED, Width = 1.6, Life = 0.4 })
	ctx.Vfx.Beam(from, to, { Color = c(255, 200, 200), Width = 0.5, Life = 0.3 })
	ctx.Vfx.Flash(from, { Color = RED, Size = 5, Life = 0.25 })
end

function Fx.BeamHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = RED, Size = 6, Life = 0.25 })
	shards(ctx.Vfx, p, -ctx.Forward, 8, 14, { RED, c(255, 200, 200) })
end

-- 삭제: 주먹이 닿은 바닥에서 마젠타 조각이 흩어지고 네모 고리가 퍼진다
function Fx.DeleteSlam(ctx: any)
	local p = ctx.Target
	local g = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
	shards(ctx.Vfx, g + Vector3.new(0, 0.5, 0), Vector3.new(0, 1, 0), 18, 20)
	ctx.Vfx.Ring(CFrame.new(g), { R0 = 1, R1 = 5, Color = MAGENTA, Life = 0.4, Width = 0.35, Height = 0.1, Segments = 4 })
end

function Fx.DeleteHit(ctx: any, _ev: any, at: Vector3?)
	ctx.Vfx.Flash(at or ctx.Target, { Color = MAGENTA, Size = 5, Life = 0.22 })
end

-- 강제 적용: 초록 반원으로 쓸고 지나간다
function Fx.PatchSweep(ctx: any)
	local p = ctx.Target
	ctx.Vfx.Slash(CFrame.lookAt(p, p + ctx.Forward) * CFrame.Angles(0, 0, math.rad(90)), { Radius = 5, Color = GREEN, Core = c(220, 255, 230), Width = 1.1, Life = 0.3 })
end

function Fx.PatchHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = GREEN, Size = 5, Life = 0.22 })
	shards(ctx.Vfx, p, -ctx.Forward, 6, 12, { GREEN, CYAN })
end

-- 패치 적용: 손바닥에서 초록빛(칸 색은 BattleClient 가 바꾼다)
function Fx.PatchApply(ctx: any)
	local palm = (ctx.Root * CFrame.new(-0.2, 3.7, -5.8)).Position
	ctx.Vfx.Flash(palm, { Color = GREEN, Size = 6, Life = 0.5, Brightness = 3 })
	ctx.Vfx.Sparks(palm, { Color = GREEN, Count = 16, Speed = 12 })
end

-- 코어 덤프: 결정에서 마젠타 충격파가 아군 진영까지 쓸고 간다
function Fx.CoreDump(ctx: any)
	local crystal = (ctx.Root * CFrame.new(0, 7.6, -12.1)).Position
	ctx.Vfx.Flash(crystal, { Color = MAGENTA, Size = 12, Life = 0.4, Brightness = 5 })
	shards(ctx.Vfx, crystal, ctx.Forward + Vector3.new(0, 0.4, 0), 24, 26)
	local g = Vector3.new(ctx.Target.X, ctx.Ground + 0.2, ctx.Target.Z)
	ctx.Vfx.Shockwave(g, { Color = MAGENTA, Radius = 16, Life = 0.5 })
end

function Fx.DumpHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = MAGENTA, Size = 7, Life = 0.25 })
	shards(ctx.Vfx, p, Vector3.new(0, 1, 0), 10, 14)
end

-- 널 포인터: 결정에서 붉은 충격파가 아군 쪽 두 라인으로
function Fx.NullPointer(ctx: any)
	local crystal = (ctx.Root * CFrame.new(0, 7.6, -12.1)).Position
	ctx.Vfx.Flash(crystal, { Color = RED, Size = 10, Life = 0.35, Brightness = 5 })
	ctx.Vfx.Beam(crystal, ctx.Target, { Color = RED, Width = 2.4, Life = 0.35 })
	shards(ctx.Vfx, crystal, ctx.Forward, 12, 22, { RED, c(40, 34, 60) })
end

function Fx.NullHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	local g = Vector3.new(p.X, ctx.Ground + 0.2, p.Z)
	ctx.Vfx.Ring(CFrame.new(g), { R0 = 1, R1 = 6, Color = RED, Life = 0.4, Width = 0.4, Height = 0.1, Segments = 4 })
	ctx.Vfx.Flash(p, { Color = RED, Size = 6, Life = 0.22 })
end

-- 메모리 누수: 등 위 오류 조각이 떠오르고 마젠타 조각비가 쏟아진다
function Fx.LeakRise(ctx: any)
	local top = (ctx.Root * CFrame.new(0, 17, 0)).Position
	ctx.Vfx.Sparks(top, { Color = MAGENTA, Count = 20, Speed = 10 })
end

function Fx.LeakHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	shards(ctx.Vfx, p + Vector3.new(0, 5, 0), Vector3.new(0, -1, 0), 14, 18)
	ctx.Vfx.Flash(p, { Color = MAGENTA, Size = 5, Life = 0.2 })
end

-- 부위가 부서진다: 검은 조각과 마젠타 번쩍임
function Fx.Break(ctx: any)
	local p = ctx.Root.Position + Vector3.new(0, 3, 0)
	ctx.Vfx.Flash(p, { Color = MAGENTA, Size = 10, Life = 0.4 })
	shards(ctx.Vfx, p, Vector3.new(0, 1, 0), 26, 22, { c(40, 34, 60), c(58, 52, 80), MAGENTA, CYAN })
	ctx.Vfx.Shake(0.4, 0.3)
end

return Fx
