--!strict
-- Fx/Slime — 슬라임 이펙트: 끈적한 초록 방울, 산성 거품. (2026-09-28)
local Common = require(script.Parent.Common)
local c = Common.c

local GOO = { c(110, 230, 96), c(70, 190, 70), c(160, 250, 140) }
local ACID = c(170, 255, 90)

local Fx = {}

local function goo(Vfx: any, at: Vector3, dir: Vector3?, count: number, speed: number)
	Vfx.Burst(at, { Count = count, Colors = GOO, Size = 0.4, Speed = speed, Dir = dir, Spread = 60, Gravity = 55, Life = 0.7, Material = Enum.Material.Glass })
end

function Fx.SlimeSplat(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	goo(ctx.Vfx, p, -ctx.Forward + Vector3.new(0, 0.6, 0), 14, 20)
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 2.8, Color = GOO[1], Life = 0.3, Width = 0.3, Facing = true })
	ctx.Vfx.Shake(0.3, 0.2)
end

function Fx.SlimeLand(ctx: any)
	local g = Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z)
	goo(ctx.Vfx, g + Vector3.new(0, 0.3, 0), Vector3.new(0, 1, 0), 6, 10)
	ctx.Vfx.Ring(CFrame.new(g + Vector3.new(0, 0.12, 0)), { R0 = 1, R1 = 3.2, Color = GOO[2], Life = 0.3, Width = 0.25, Height = 0.08 })
end

-- 산성 침: 입에서 방울이 포물선으로 날아간다(도착은 Hit 사건과 맞춘다: 0.34초)
function Fx.SlimeSpit(ctx: any)
	local mouth = (ctx.Root * CFrame.new(0, 1.3, -1.9)).Position
	local target = ctx.Target
	local Vfx = ctx.Vfx
	Vfx.Projectile(mouth, target, {
		Time = 0.34,
		Arc = 1.6,
		Build = function()
			local p = Vfx.Part(Vector3.new(0.7, 0.7, 0.7), CFrame.new(mouth), ACID, Enum.Material.Neon)
			return p
		end,
		TrailColor = GOO[1],
	})
	goo(Vfx, mouth, ctx.Forward, 5, 10)
end

function Fx.SlimeAcid(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	goo(ctx.Vfx, p, Vector3.new(0, 1, 0), 12, 16)
	ctx.Vfx.Flash(p, { Color = ACID, Size = 6, Life = 0.25 })
	ctx.Vfx.Dust(p - Vector3.new(0, 1, 0), { Color = c(190, 240, 150), Count = 8, Size = 0.9, Speed = 6 })
end

function Fx.SlimeMelt(ctx: any)
	local g = Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z)
	goo(ctx.Vfx, g + Vector3.new(0, 0.6, 0), Vector3.new(0, 1, 0), 18, 22)
	ctx.Vfx.Ring(CFrame.new(g + Vector3.new(0, 0.1, 0)), { R0 = 1.5, R1 = 4.5, Color = GOO[2], Life = 0.6, Width = 0.4, Height = 0.06 })
end

return Fx
