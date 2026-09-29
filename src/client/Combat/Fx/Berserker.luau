--!strict
--[[
	Fx/Berserker — 광전사 이펙트. 피·검붉은 기운·돌. (2026-09-28)
	모든 것이 크다: 긴 타격 정지, 깊은 구덩이, 핏빛 초승달.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local BLOOD = c(200, 20, 24)
local DARK = c(60, 6, 10)
local EMBER = c(255, 90, 60)

local Fx = {}

function Fx.Crater(ctx: any)
	local Vfx = ctx.Vfx
	local feet = Common.Feet(ctx)
	Vfx.Shockwave(feet + Vector3.new(0, 0.1, 0), { Color = BLOOD, Radius = 6, Life = 0.45 })
	Common.Rubble(Vfx, feet + Vector3.new(0, 0.5, 0), 14)
	Vfx.Dust(feet, { Count = 14, Size = 1.6, Speed = 14 })
	for k = 0, 5 do
		Common.Crack(Vfx, feet, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 6 * math.pi * 2) * ctx.Forward, 3.5, DARK)
	end
end

function Fx.Roar(ctx: any)
	local Vfx = ctx.Vfx
	local head = Common.Head(ctx)
	for i = 0, 2 do
		task.delay(i * 0.07, function()
			Vfx.Ring(CFrame.lookAt(head, head + ctx.Forward), { R0 = 0.5, R1 = 3 + i * 1.5, Color = if i == 1 then EMBER else BLOOD, Life = 0.35, Width = 0.2, Facing = true })
		end)
	end
	Vfx.Shake(0.35, 0.4)
end

function Fx.HaftBlock(ctx: any)
	local p = ctx.Root.Position + ctx.Forward * 1.6 + Vector3.new(0, 0.6, 0)
	ctx.Vfx.Sparks(p, { Color = EMBER, Count = 20 })
	ctx.Vfx.Flash(p, { Color = EMBER, Size = 5, Life = 0.2 })
	ctx.Vfx.Shake(0.2, 0.15)
end

function Fx.ShoulderCheck(ctx: any)
	local p = ctx.Root.Position + ctx.Forward * 1.4
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 2.6, Color = BLOOD, Life = 0.25, Width = 0.2, Facing = true })
	ctx.Vfx.Dust(Common.Feet(ctx), { Count = 6, Size = 1 })
	ctx.Vfx.Shake(0.25, 0.2)
end

-- 핏빛 분쇄 준비: 몸에서 피가 끓어오른다
function Fx.BloodBoil(ctx: any)
	local Vfx = ctx.Vfx
	Vfx.Burst(ctx.Root.Position, { Count = 12, Colors = Common.BLOOD, Size = 0.3, Speed = 8, Gravity = -10, Life = 0.6 })
	Vfx.Ring(CFrame.new(Common.Feet(ctx) + Vector3.new(0, 0.12, 0)), { R0 = 3.5, R1 = 1, Color = BLOOD, Life = 0.35, Width = 0.2, Height = 0.06 })
end

-- 핏빛 분쇄: 핏빛 초승달이 내려꽂히고 구덩이에서 피가 솟구친다
function Fx.BloodCrash(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local ground = Vector3.new(p.X, ctx.Ground, p.Z)
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 2 + Vector3.new(0, 1, 0), 0, 160, -50, { Radius = 4.2, Color = BLOOD, Core = EMBER, Width = 1.3, Sweep = 0.04 })
	Vfx.Flash(p, { Color = BLOOD, Size = 14, Life = 0.35, Brightness = 7 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = BLOOD, Radius = 8, Life = 0.5 })
	Vfx.Pillar(ground, { Color = BLOOD, Height = 8, Width = 3, Life = 0.4 })
	Common.Blood(Vfx, p, Vector3.new(0, 1, 0), 26, 26)
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 16)
	for k = 0, 6 do
		Common.Crack(Vfx, ground, CFrame.fromAxisAngle(Vector3.new(0, 1, 0), k / 7 * math.pi * 2) * ctx.Forward, 5, DARK, 1.3)
	end
end

function Fx.AxeSlashA(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 1, 0), -45, 140, -60, { Radius = 4, Color = BLOOD, Core = EMBER, Width = 1.1, Sweep = 0.04 })
	Common.Blood(ctx.Vfx, p, ctx.Forward + Vector3.new(0, 0.4, 0), 12, 20)
	ctx.Vfx.Flash(p, { Color = BLOOD, Size = 7, Life = 0.2 })
end

function Fx.AxeSlashB(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Arc(ctx, ctx.Root.Position + ctx.Forward * 1.5 + Vector3.new(0, 1, 0), 45, 140, -60, { Radius = 4.4, Color = BLOOD, Core = EMBER, Width = 1.3, Sweep = 0.04 })
	Common.Blood(ctx.Vfx, p, ctx.Forward + Vector3.new(0, 0.6, 0), 16, 24)
	ctx.Vfx.Flash(p, { Color = BLOOD, Size = 9, Life = 0.25 })
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 3, Color = BLOOD, Life = 0.3, Width = 0.22, Facing = true })
end

-- 회오리: 몸 둘레 핏빛 원호 + 흙먼지
function Fx.Whirl(ctx: any)
	Common.Arc(ctx, ctx.Root.Position + Vector3.new(0, 0.3, 0), 90, 180, -180, { Radius = 4.6, Color = BLOOD, Core = EMBER, Width = 1, Sweep = 0.22, Life = 0.25, Segments = 26 })
	ctx.Vfx.Dust(Common.Feet(ctx), { Count = 10, Size = 1.2, Speed = 14 })
end

function Fx.BurstBlast(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local ground = Common.Feet(ctx) + ctx.Forward * 3
	Vfx.Flash(ground + Vector3.new(0, 1, 0), { Color = EMBER, Size = 16, Life = 0.4, Brightness = 9 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.1, 0), { Color = BLOOD, Radius = 9, Life = 0.55 })
	Vfx.Shockwave(ground + Vector3.new(0, 0.2, 0), { Color = EMBER, Radius = 5, Life = 0.35 })
	Common.Rubble(Vfx, ground + Vector3.new(0, 0.5, 0), 20)
	Vfx.Dust(ground, { Count = 18, Size = 2, Speed = 18 })
	if at then
		Common.Blood(Vfx, at, Vector3.new(0, 1, 0), 10, 18)
	end
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), BLOOD)
end

return Fx
