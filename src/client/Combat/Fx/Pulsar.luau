--!strict
--[[
	Fx/Pulsar — 펄서 이펙트. 청록 자기장·빔·섬광. (2026-09-28)
	오브 대형 바꾸기는 무기(CombatWeapons:SetOrbMode)가 하고, 여기는 빛만 그린다.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local CYAN = c(110, 220, 255)
local WHITE = c(235, 250, 255)
local DEEP = c(40, 110, 200)

local Fx = {}

local function orbCenter(ctx: any): Vector3
	return ctx.Root.Position + ctx.Forward * 2.4 + Vector3.new(0, 0.6, 0)
end

function Fx.Touchdown(ctx: any)
	local feet = Common.Feet(ctx)
	ctx.Vfx.Ring(CFrame.new(feet + Vector3.new(0, 0.12, 0)), { R0 = 0.5, R1 = 4, Color = CYAN, Life = 0.5, Width = 0.2, Height = 0.05 })
	ctx.Vfx.Sparks(feet + Vector3.new(0, 0.3, 0), { Color = CYAN, Count = 12, Accel = Vector3.new(0, 4, 0) })
end

function Fx.OrbShield(ctx: any)
	local front = ctx.Root.Position + ctx.Forward * 2.4 + Vector3.new(0, 0.6, 0)
	local cf = CFrame.lookAt(front, front + ctx.Forward)
	ctx.Vfx.Ring(cf, { R0 = 0.5, R1 = 2.4, Color = CYAN, Life = 0.5, Width = 0.25, Facing = true })
	local tri = ctx.Vfx.Part(Vector3.new(2.6, 2.6, 0.08), cf, CYAN)
	tri.Transparency = 0.6
	task.delay(0.4, function()
		tri:Destroy()
	end)
end

-- 순간 이동 잔상: 원래 자리에 번쩍 + 빛가루
function Fx.Blink(ctx: any)
	local at = ctx.Root.Position
	ctx.Vfx.Flash(at, { Color = CYAN, Size = 7, Life = 0.25, Brightness = 5 })
	ctx.Vfx.Burst(at, { Count = 12, Color = CYAN, Size = 0.2, Speed = 8, Gravity = 0, Life = 0.4 })
	ctx.Vfx.Ring(CFrame.lookAt(at, at + ctx.Forward), { R0 = 1.5, R1 = 0.2, Color = WHITE, Life = 0.2, Width = 0.12, Facing = true })
end

-- 자기권: 몸을 둘러 도는 고리 셋(높이 다르게) + 발밑 파동
function Fx.Magnetosphere(ctx: any)
	local Vfx = ctx.Vfx
	local base = ctx.Root.Position
	for i = 0, 2 do
		task.delay(i * 0.08, function()
			local cf = CFrame.new(base + Vector3.new(0, -0.8 + i * 0.9, 0)) * CFrame.Angles(math.rad(12 * (i - 1)), 0, math.rad(15 * (1 - i)))
			Vfx.Ring(cf, { R0 = 1.2, R1 = 4.2, Color = if i == 1 then WHITE else CYAN, Life = 0.7, Width = 0.18, Height = 0.1 })
		end)
	end
	Vfx.Shockwave(Common.Feet(ctx) + Vector3.new(0, 0.1, 0), { Color = DEEP, Radius = 6, Life = 0.5 })
	Vfx.Sparks(base, { Color = CYAN, Count = 24, Speed = 16, Accel = Vector3.new(0, 0, 0) })
end

function Fx.Charge(ctx: any)
	ctx.Vfx.Implode(orbCenter(ctx), { Color = CYAN, Radius = 4, Count = 16, Life = 0.3 })
end

function Fx.ConvergeBeam(ctx: any)
	local from = orbCenter(ctx)
	ctx.Vfx.Beam(from, ctx.Target + ctx.Forward * 2, { Color = CYAN, Width = 1.3, Life = 0.4 })
	ctx.Vfx.Flash(from, { Color = WHITE, Size = 6, Life = 0.25, Brightness = 6 })
	ctx.Vfx.Ring(CFrame.lookAt(from, from + ctx.Forward), { R0 = 0.3, R1 = 2, Color = CYAN, Life = 0.25, Width = 0.18, Facing = true })
end

function Fx.BeamHit(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	ctx.Vfx.Flash(p, { Color = CYAN, Size = 8, Life = 0.25 })
	ctx.Vfx.Sparks(p, { Color = WHITE, Count = 18, Speed = 24 })
	ctx.Vfx.Lightning(p + Vector3.new(0, 1.5, 0), p - Vector3.new(0, 1.2, 0), { Color = CYAN })
end

function Fx.FlareGather(ctx: any)
	local chest = ctx.Root.Position + ctx.Forward * 0.8 + Vector3.new(0, 0.4, 0)
	ctx.Vfx.Implode(chest, { Color = WHITE, Radius = 3, Count = 12, Life = 0.2 })
end

-- 섬광: 시전자 앞에서 눈부신 빛이 터지고, 대상 줄을 따라 번쩍임이 달린다
function Fx.Flare(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local chest = ctx.Root.Position + ctx.Forward * 0.8 + Vector3.new(0, 0.4, 0)
	Vfx.Flash(chest, { Color = WHITE, Size = 22, Life = 0.45, Brightness = 10 })
	Vfx.Ring(CFrame.lookAt(chest, chest + ctx.Forward), { R0 = 0.5, R1 = 6, Color = WHITE, Life = 0.4, Width = 0.3, Facing = true })
	local p = at or ctx.Target
	task.delay(0.08, function()
		Vfx.Flash(p, { Color = CYAN, Size = 10, Life = 0.35, Brightness = 6 })
		Vfx.Sparks(p, { Color = WHITE, Count = 20 })
	end)
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Common.Feet(ctx), CYAN)
end

return Fx
