--!strict
--[[
	Fx/Duelist — 결투사 이펙트. 강철빛 흰-청 선과 핏빛 붉은색 두 가지만 쓴다(절제). (2026-09-28)
	찌르기는 "선 하나", 패링은 "불꽃 한 점" — 크게 번지지 않고 날카롭게.
]]
local Common = require(script.Parent.Common)
local c = Common.c

local STEEL = c(214, 234, 255)
local EDGE = c(150, 200, 255)
local RED = c(220, 30, 40)

local Fx = {}

function Fx.Appel(ctx: any)
	local foot = ctx.Root.Position + ctx.Forward * 1.2
	Common.Land(ctx.Vfx, Vector3.new(foot.X, ctx.Ground, foot.Z), 0.6)
end

-- 찌르기 타격: 칼끝에서 대상까지 선이 꽂히고, 뒤로 불꽃·피가 뚫고 나간다
local function pierce(ctx: any, at: Vector3, dir: Vector3, scale: number)
	local Vfx = ctx.Vfx
	Vfx.Thrust(at - dir * 3, dir, { Length = 6 * scale, Color = STEEL, Width = 0.3 * scale })
	Vfx.Flash(at, { Color = EDGE, Size = 5 * scale, Life = 0.18 })
	Vfx.Sparks(at + dir * 0.6, { Color = STEEL, Count = math.floor(12 * scale), Speed = 26 })
	Common.Blood(Vfx, at + dir * 0.8, dir, math.floor(8 * scale), 20 * scale)
end

function Fx.Pierce(ctx: any, _ev: any, at: Vector3?)
	pierce(ctx, at or ctx.Target, ctx.Forward, 1)
end

function Fx.PierceBack(ctx: any, _ev: any, at: Vector3?)
	pierce(ctx, at or ctx.Target, -ctx.Forward, 1.1)
end

function Fx.PierceBig(ctx: any, _ev: any, at: Vector3?)
	local p = at or ctx.Target
	pierce(ctx, p, ctx.Forward, 1.5)
	ctx.Vfx.Ring(CFrame.lookAt(p, p + ctx.Forward), { R0 = 0.4, R1 = 3.2, Color = STEEL, Life = 0.3, Width = 0.22, Facing = true })
end

-- 뽑아내며 칼끝 튕김: 작은 핏방울이 위로 흩어진다
function Fx.Flick(ctx: any)
	local tip = ctx.Tip()
	if tip then
		Common.Blood(ctx.Vfx, tip, Vector3.new(0, 1, 0) + ctx.Forward * -0.3, 5, 12)
	end
end

function Fx.ParrySpark(ctx: any)
	local p = ctx.Tip() or (ctx.Root.Position + ctx.Forward * 2)
	local mid = p:Lerp(ctx.Root.Position + Vector3.new(0, 0.8, 0), 0.4)
	ctx.Vfx.Flash(mid, { Color = c(255, 240, 200), Size = 9, Life = 0.2, Brightness = 6 })
	ctx.Vfx.Sparks(mid, { Color = c(255, 220, 150), Count = 26, Speed = 30 })
	ctx.Vfx.Ring(CFrame.lookAt(mid, mid + ctx.Forward), { R0 = 0.3, R1 = 2.6, Color = c(255, 236, 190), Life = 0.25, Width = 0.18, Facing = true })
	ctx.Vfx.Shake(0.25, 0.18)
end

function Fx.Riposte(ctx: any)
	local from = ctx.Root.Position + Vector3.new(0, 0.6, 0) + ctx.Forward * 2
	ctx.Vfx.Thrust(from, ctx.Forward, { Length = 5, Color = STEEL, Width = 0.22 })
end

function Fx.BlockSpark(ctx: any)
	local p = ctx.Tip() or (ctx.Root.Position + ctx.Forward * 1.5)
	local mid = p:Lerp(ctx.Root.Position + Vector3.new(0, 1, 0), 0.5)
	ctx.Vfx.Sparks(mid, { Color = c(255, 190, 110), Count = 18, Speed = 22 })
	ctx.Vfx.Flash(mid, { Color = c(255, 200, 140), Size = 5, Life = 0.15 })
	ctx.Vfx.Shake(0.18, 0.15)
end

function Fx.Salute(ctx: any)
	local tip = ctx.Tip()
	if tip then
		ctx.Vfx.Flash(tip, { Color = STEEL, Size = 3, Life = 0.35, Brightness = 3 })
	end
end

function Fx.Focus(ctx: any)
	local ground = Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z)
	ctx.Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.12, 0)), { R0 = 4.5, R1 = 1.4, Color = EDGE, Life = 0.6, Width = 0.16, Height = 0.05 })
	ctx.Vfx.Implode(ctx.Root.Position + Vector3.new(0, 1.2, 0), { Color = EDGE, Radius = 5, Count = 12, Life = 0.5 })
end

function Fx.FocusSnap(ctx: any)
	local head = ctx.Root.Position + Vector3.new(0, 1.6, 0)
	ctx.Vfx.Flash(head, { Color = EDGE, Size = 4, Life = 0.25, Brightness = 5 })
	ctx.Vfx.Ring(CFrame.new(Vector3.new(ctx.Root.Position.X, ctx.Ground + 0.12, ctx.Root.Position.Z)), { R0 = 1, R1 = 4, Color = EDGE, Life = 0.35, Width = 0.2, Height = 0.06 })
end

-- 검 끝을 쏘아라 — 모으기: 칼끝에 별빛이 맺히고 빛가루가 빨려든다
function Fx.Glint(ctx: any)
	local tip = ctx.Tip() or ctx.Root.Position
	ctx.Vfx.Implode(tip, { Color = STEEL, Radius = 4, Count = 16, Life = 0.4 })
	ctx.Vfx.Flash(tip, { Color = c(255, 255, 255), Size = 3.5, Life = 0.4, Brightness = 5 })
end

-- 검 끝을 쏘아라 — 타격: 대상을 가르는 긴 흰 선, 뒤따라 붉은 선이 터진다
function Fx.PointBlank(ctx: any, _ev: any, at: Vector3?)
	local Vfx = ctx.Vfx
	local p = at or ctx.Target
	local dir = ctx.Forward
	Vfx.Thrust(p - dir * 8, dir, { Length = 16, Color = STEEL, Width = 0.5, Life = 0.4 })
	Vfx.Flash(p, { Color = c(255, 255, 255), Size = 12, Life = 0.3, Brightness = 8 })
	Vfx.Ring(CFrame.lookAt(p, p + dir), { R0 = 0.5, R1 = 5, Color = STEEL, Life = 0.35, Width = 0.3, Facing = true })
	Vfx.Sparks(p, { Color = STEEL, Count = 30, Speed = 36 })
	task.delay(0.12, function()
		Vfx.Beam(p - dir * 6, p + dir * 6, { Color = RED, Width = 0.35, Life = 0.6 })
		Common.Blood(Vfx, p, dir + Vector3.new(0, 0.4, 0), 22, 26)
		Common.Blood(Vfx, p, -dir + Vector3.new(0, 0.6, 0), 10, 14)
	end)
end

-- 피 털기: 칼 옆으로 핏방울이 흩뿌려진다
function Fx.Chiburi(ctx: any)
	local tip = ctx.Tip() or ctx.Root.Position
	local side = ctx.Root.RightVector
	Common.Blood(ctx.Vfx, tip, side + Vector3.new(0, -0.3, 0), 9, 16)
end

function Fx.GuardRing(ctx: any)
	Common.GuardRing(ctx.Vfx, ctx, EDGE)
end

function Fx.Meditate(ctx: any)
	Common.Meditate(ctx.Vfx, Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z), EDGE)
end

return Fx
