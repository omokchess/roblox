--!strict
--[[
	Fx/WallBreaker — 월 브레이커 이펙트. 주황 수정빛과 부서지는 돌. (2026-09-28)
	다 부순다: 크게 패는 구덩이, 사방으로 튀는 돌, 한 바퀴 휩쓰는 큰 호.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local EMBER = c(255, 160, 80)
local HOT = c(255, 220, 160)
local ROCK = c(120, 100, 80)

local Fx = {}

function Fx.ButtSlam(ctx: any)
	local p = Common.Feet(ctx) + ctx.Forward * 1.2
	Common.Land(ctx.Vfx, p, 0.9, c(170, 150, 120))
	Common.Crack(ctx.Vfx, p, ctx.Forward, 3, ROCK)
	Common.Crack(ctx.Vfx, p, -ctx.Forward, 2.5, ROCK)
end

function Fx.Riled(ctx: any)
	ctx.Vfx.Burst(Common.Head(ctx), { Count = 6, Color = EMBER, Size = 0.2, Speed = 10, Gravity = 20, Life = 0.4 })
end

function Fx.StaffBlock(ctx: any)
	local p = ctx.Root.Position + Vector3.new(0, 2.2, 0) + ctx.Forward * 0.6
	ctx.Vfx.Sparks(p, { Color = HOT, Count = 18 })
	ctx.Vfx.Flash(p, { Color = EMBER, Size = 5, Life = 0.2 })
	ctx.Vfx.Shake(0.18, 0.15)
end

function Fx.VaultLand(ctx: any)
	Common.Land(ctx.Vfx, Common.Feet(ctx), 0.8, c(170, 150, 120))
end

-- 쪼개기: 곡괭이가 박힌 자리 — 구덩이, 돌 조각, 주황 불꽃
function Fx.PickSlam(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	Vfx.Flash(p, { Color = EMBER, Size = 10, Life = 0.3, Brightness = 6 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = EMBER, Radius = 4.5, Life = 0.4 })
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 16, ROCK)
	Vfx.Sparks(p, { Color = HOT, Count = 24, Speed = 28 })
	for k = 0, 4 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 5 * math.pi * 2) * ctx.Forward, 3.5, ROCK)
	end
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 1, 0), 0, 150, -50, { Radius = 3.6, Color = EMBER, Core = HOT, Width = 0.9, Sweep = 0.05 })
end

function Fx.Yank(ctx: any)
	local p = Common.Feet(ctx) + ctx.Forward * 3
	Common.Rubble(ctx.Vfx, p + Vector3.new(0, 0.4, 0), 6, ROCK)
	ctx.Vfx.Dust(p, { Count = 6, Color = c(160, 140, 115) })
end

-- 무너뜨리기: 한 바퀴 휩쓰는 큰 가로 호
function Fx.Sweep(ctx: any)
	Common.Arc(ctx, ctx.Root.Position + Vector3.new(0, 0.2, 0), 90, 200, -160, { Radius = 5.5, Color = EMBER, Core = HOT, Width = 1.2, Sweep = 0.16, Life = 0.3, Segments = 24 })
end

function Fx.SweepHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = EMBER, Size = 7, Life = 0.25 })
	Common.Rubble(ctx.Vfx, p, 8, ROCK)
	ctx.Vfx.Dust(Vector3.new(p.X, ctx.Ground, p.Z), { Count = 8, Color = c(160, 140, 115) })
	-- 대상 줄 전체를 쓸었다는 표시: 옆으로 긴 흙먼지 띠
	local side = ctx.Forward:Cross(Vector3.new(0, 1, 0))
	for i = -2, 2 do
		ctx.Vfx.Dust(Vector3.new(p.X, ctx.Ground, p.Z) + side * (i * 3), { Count = 4, Color = c(160, 140, 115), Size = 1.1 })
	end
end

-- 허물다 모으기: 머리 위 풍차 둘레로 불씨가 빨려든다
function Fx.Windmill(ctx: any)
	local Vfx = ctx.Vfx
	local above = ctx.Root.Position + Vector3.new(0, 3, 0)
	for i = 0, 3 do
		task.delay(i * 0.16, function()
			Vfx.Implode(above, { Color = if i % 2 == 0 then EMBER else HOT, Radius = 6, Count = 12, Life = 0.35 })
			Vfx.Ring(CFrame.new(above), { R0 = 3, R1 = 1.5, Color = EMBER, Life = 0.25, Width = 0.15, Height = 0.08 })
		end)
	end
end

-- 허물다 타격: 큰 폭발 + 깊은 구덩이 + 불기둥
function Fx.TearDownBlast(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	Vfx.Flash(p, { Color = HOT, Size = 18, Life = 0.4, Brightness = 10 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = EMBER, Radius = 10, Life = 0.55 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.2, 0), { Color = HOT, Radius = 6, Life = 0.35 })
	Vfx.Pillar(ground, { Color = EMBER, Height = 12, Width = 4, Life = 0.5 })
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 26, ROCK)
	Vfx.Dust(ground, { Count = 20, Color = c(160, 140, 115), Size = 2, Speed = 18 })
	for k = 0, 7 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 8 * math.pi * 2) * ctx.Forward, 6, ROCK, 1.4)
	end
end

-- 제 살 깎기: 자기 가슴에서 금이 번지며 주황 빛이 샌다
function Fx.SelfStrike(ctx: any)
	local chest = ctx.Root.Position + ctx.Forward * 0.5 + Vector3.new(0, 0.4, 0)
	ctx.Vfx.Flash(chest, { Color = EMBER, Size = 6, Life = 0.25 })
	ctx.Vfx.Burst(chest, { Count = 10, Colors = { EMBER, HOT, ROCK }, Size = 0.3, Speed = 14, Life = 0.5 })
	Common.Blood(ctx.Vfx, chest, ctx.Forward, 6, 10)
end

function Fx.Roar(ctx: any)
	local head = Common.Head(ctx)
	ctx.Vfx.Ring(CFrame.lookAt(head, head + ctx.Forward), { R0 = 0.6, R1 = 4, Color = EMBER, Life = 0.4, Width = 0.2, Facing = true })
	ctx.Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 1, R1 = 5, Color = EMBER, Life = 0.5, Width = 0.25, Height = 0.06 })
	ctx.Vfx.Shake(0.3, 0.35)
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), EMBER)
end

return Fx
