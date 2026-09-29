--!strict
--[[
	Fx/WallMason — 월 메이슨 이펙트. 돌·먼지·금빛 불꽃. (2026-09-28)
	장인답게 **정확한 한 점**: 정 끝에서 튀는 불꽃, 땅에서 솟는 돌벽, 금이 달려가 벽을 허문다.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local STONE = c(165, 158, 145)
local GOLD = c(255, 210, 110)
local SPARK = c(255, 236, 190)

local Fx = {}

function Fx.Stomp(ctx: any)
	Common.Land(ctx.Vfx, Common.Feet(ctx), 0.8, STONE)
end

function Fx.GroundTap(ctx: any)
	local p = Common.Feet(ctx) + ctx.Forward * 1.8
	ctx.Vfx.Sparks(p + Vector3.new(0, 0.2, 0), { Color = SPARK, Count = 10 })
	ctx.Vfx.Ring(CFrame.new(p + Vector3.new(0, 0.12, 0)), { R0 = 0.3, R1 = 1.6, Color = GOLD, Life = 0.3, Width = 0.1, Height = 0.05 })
end

-- 방어: 발 앞 땅에서 돌벽이 쿵 솟는다
function Fx.StoneWall(ctx: any)
	local Vfx = ctx.Vfx
	local base = Common.Feet(ctx) + ctx.Forward * 2.2
	local cf = CFrame.lookAt(base, base + ctx.Forward)
	Vfx.Block(cf * CFrame.new(0, 1.6, 0), Vector3.new(3.6, 3.2, 0.9), { Color = STONE, Material = Enum.Material.Slate, Rise = 0.1, Hold = 0.55 })
	Vfx.Block(cf * CFrame.new(-1.4, 1.1, 0.3), Vector3.new(1.2, 2.2, 1), { Color = c(140, 134, 124), Material = Enum.Material.Slate, Rise = 0.12, Hold = 0.5 })
	Vfx.Dust(base, { Count = 10, Color = STONE, Size = 1.2 })
	Common.Rubble(Vfx, base + Vector3.new(0, 0.5, 0), 6, STONE)
end

function Fx.RollDust(ctx: any)
	ctx.Vfx.Dust(Common.Feet(ctx), { Count = 8, Color = STONE, Size = 1 })
end

-- 정 다듬기: 정 끝에서 불꽃이 튄다(톡)
function Fx.ChiselTap(ctx: any)
	local p = ctx.Tip("O") or (ctx.Root.Position + ctx.Forward * 2)
	ctx.Vfx.Sparks(p, { Color = SPARK, Count = 12, Speed = 18 })
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 3, Life = 0.12 })
end

-- 쾅: 대상 표면이 깨지며 돌 조각과 금빛 불꽃
function Fx.ChiselHit(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	Vfx.Flash(p, { Color = GOLD, Size = 8, Life = 0.25, Brightness = 6 })
	Vfx.Sparks(p, { Color = SPARK, Count = 28, Speed = 30 })
	Common.Rubble(Vfx, p, 10, STONE)
	Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.3, R1 = 2.4, Color = GOLD, Life = 0.3, Width = 0.18, Facing = true })
end

-- 뒷벽 허물기: 땅을 친 자리에서 금이 대상과 그 뒤까지 달려가며 돌이 솟구친다
function Fx.WallBreakWave(ctx: any)
	local Vfx = ctx.Vfx
	local start = Common.Feet(ctx) + ctx.Forward * 2
	Vfx.Shockwave(start + Vector3.new(0, 0.1, 0), { Color = GOLD, Radius = 4, Life = 0.35 })
	Common.Crack(Vfx, start, ctx.Forward, 14, c(90, 80, 70), 1.3)
	for i = 1, 5 do
		task.delay(i * 0.05, function()
			local p = start + ctx.Forward * (i * 2.6)
			Vfx.Block(CFrame.new(p) * CFrame.Angles(0, math.rad(i * 37), 0) * CFrame.new(0, 0.7, 0), Vector3.new(1.4, 1.4 + i * 0.25, 1.4), { Color = STONE, Material = Enum.Material.Slate, Rise = 0.08, Hold = 0.25 })
			Vfx.Dust(p, { Count = 5, Color = STONE, Size = 1 })
		end)
	end
end

function Fx.Rubble(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	Common.Rubble(ctx.Vfx, p, 12, STONE)
	ctx.Vfx.Flash(p, { Color = GOLD, Size = 6, Life = 0.2 })
end

function Fx.GoldTap(ctx: any)
	local p = Common.Feet(ctx) + ctx.Forward * 1.8
	ctx.Vfx.Ring(CFrame.new(p + Vector3.new(0, 0.12, 0)), { R0 = 0.5, R1 = 3.4, Color = GOLD, Life = 0.4, Width = 0.2, Height = 0.06 })
	ctx.Vfx.Sparks(p, { Color = SPARK, Count = 12 })
end

-- 축성: 둘레에 금빛 돌기둥 넷이 솟고 빛이 오른다
function Fx.Consecrate(ctx: any)
	local Vfx = ctx.Vfx
	local feet = Common.Feet(ctx)
	Vfx.Shockwave(feet + Vector3.new(0, 0.1, 0), { Color = GOLD, Radius = 7, Life = 0.5 })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local p = feet + Vector3.new(math.cos(a) * 3.2, 0, math.sin(a) * 3.2)
		Vfx.Block(CFrame.new(p + Vector3.new(0, 1.3, 0)), Vector3.new(1.1, 2.6, 1.1), { Color = c(200, 185, 150), Material = Enum.Material.Slate, Rise = 0.15, Hold = 0.9 })
		Vfx.Pillar(p, { Color = GOLD, Height = 7, Width = 1.2, Life = 0.8 })
	end
	Vfx.Sparks(feet + Vector3.new(0, 1, 0), { Color = GOLD, Count = 26, Accel = Vector3.new(0, 5, 0) })
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), GOLD)
end

return Fx
